"""
Shudo org extension: conversation folders + group sub-channels.

Auth: forward client `token` to TangSengDaoDao API; resolve uid via Redis
`token:{token}` (upstream convention) with HTTP fallback.

Routes under /v1/shudo/...
"""

from __future__ import annotations

import base64
import io
import json
import os
import time
import uuid
from typing import Any, Optional

import httpx
import pymysql
import redis
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None  # type: ignore

app = FastAPI(title="Shudo Org", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

TS_API_URL = os.getenv("TS_API_URL", "http://tangsengdaodaoserver:8090/v1").rstrip("/")
IM_API_URL = os.getenv(
    "SHUDO_IM_API_URL",
    os.getenv("TS_WUKONGIM_APIURL", "http://wukongim:5001"),
).rstrip("/")
MYSQL_DSN = os.getenv(
    "SHUDO_MYSQL_DSN",
    os.getenv(
        "TS_DB_MYSQLADDR",
        "root:password@tcp(mysql)/im?charset=utf8mb4&parseTime=true&loc=Local",
    ),
)
REDIS_ADDR = os.getenv("SHUDO_REDIS_ADDR", os.getenv("TS_DB_REDISADDR", "redis:6379"))


def parse_mysql_dsn(dsn: str) -> dict:
    """Parse Go-style DSN: user:pass@tcp(host:port)/db?params -> pymysql kwargs."""
    user_pass, rest = dsn.split("@", 1)
    user, password = user_pass.split(":", 1)
    # tcp(host)/db or tcp(host:port)/db
    host_part, db_part = rest.split(")/", 1)
    host_port = host_part.split("tcp(", 1)[1]
    if ":" in host_port:
        host, port_s = host_port.split(":", 1)
        port = int(port_s)
    else:
        host, port = host_port, 3306
    database = db_part.split("?", 1)[0]
    return {
        "host": host,
        "port": port,
        "user": user,
        "password": password,
        "database": database,
        "charset": "utf8mb4",
        "autocommit": True,
        "cursorclass": pymysql.cursors.DictCursor,
    }


MYSQL_KW = parse_mysql_dsn(MYSQL_DSN)


def redis_client() -> redis.Redis:
    host, _, port = REDIS_ADDR.partition(":")
    return redis.Redis(host=host or "redis", port=int(port or 6379), decode_responses=True)


def db():
    return pymysql.connect(**MYSQL_KW)


def init_schema() -> None:
    ddl = [
        """
        CREATE TABLE IF NOT EXISTS shudo_sub_channel (
          id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          parent_group_no VARCHAR(40) NOT NULL,
          sub_group_no VARCHAR(40) NOT NULL,
          title VARCHAR(80) NOT NULL,
          creator_uid VARCHAR(40) NOT NULL,
          archived TINYINT NOT NULL DEFAULT 0,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY uk_sub (sub_group_no),
          KEY idx_parent (parent_group_no)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        """,
        """
        CREATE TABLE IF NOT EXISTS shudo_folder (
          id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          folder_id VARCHAR(40) NOT NULL,
          uid VARCHAR(40) NOT NULL,
          name VARCHAR(40) NOT NULL,
          sort INT NOT NULL DEFAULT 0,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY uk_folder (folder_id),
          KEY idx_uid (uid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        """,
        """
        CREATE TABLE IF NOT EXISTS shudo_folder_item (
          id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          folder_id VARCHAR(40) NOT NULL,
          uid VARCHAR(40) NOT NULL,
          channel_id VARCHAR(40) NOT NULL,
          channel_type SMALLINT NOT NULL,
          sort INT NOT NULL DEFAULT 0,
          UNIQUE KEY uk_item (folder_id, channel_id, channel_type),
          KEY idx_folder (folder_id),
          KEY idx_uid (uid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        """,
    ]
    conn = db()
    try:
        with conn.cursor() as cur:
            for sql in ddl:
                cur.execute(sql)
            # migrate older installs that lack archived
            try:
                cur.execute(
                    "ALTER TABLE shudo_sub_channel "
                    "ADD COLUMN archived TINYINT NOT NULL DEFAULT 0"
                )
            except Exception:
                pass
    finally:
        conn.close()


@app.on_event("startup")
def on_startup() -> None:
    for i in range(30):
        try:
            init_schema()
            return
        except Exception:
            time.sleep(1)
    init_schema()


class AuthUser(BaseModel):
    uid: str
    token: str


def normalize_auth_uid(uid: Optional[str]) -> Optional[str]:
    """Strip agent-channel form `user@robot` and enforce varchar(40)."""
    if not uid:
        return None
    u = str(uid).strip()
    if "@" in u:
        u = u.split("@", 1)[0].strip()
    if not u:
        return None
    if len(u) > 40:
        u = u[:40]
    return u


async def require_user(
    token: Optional[str] = Header(default=None, alias="token"),
    authorization: Optional[str] = Header(default=None),
    uid_header: Optional[str] = Header(default=None, alias="uid"),
) -> AuthUser:
    t = (token or "").strip()
    if not t and authorization:
        parts = authorization.split(" ", 1)
        t = parts[1].strip() if len(parts) == 2 else authorization.strip()
    if not t:
        raise HTTPException(status_code=401, detail="请先登录！")

    claimed = normalize_auth_uid(uid_header)
    uid: Optional[str] = None
    try:
        r = redis_client()
        raw = r.get(f"token:{t}")
        if raw:
            uid = normalize_auth_uid(str(raw))
    except Exception:
        uid = None

    if not uid:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                f"{TS_API_URL}/group/my", headers={"token": t}, params={"limit": 1}
            )
            if resp.status_code != 200:
                raise HTTPException(status_code=401, detail="请先登录！")
        uid = claimed
        if not uid:
            raise HTTPException(status_code=401, detail="无法解析用户，请重新登录")
    # Redis-resolved uid is source of truth; ignore mismatched client uid header

    return AuthUser(uid=str(uid), token=t)


TOPICS_FOLDER_NAME = "话题"


def normalize_topic_title(raw: str) -> str:
    title = (raw or "").strip().lstrip("#").strip()
    if not title:
        raise HTTPException(status_code=400, detail="名称不能为空")
    if len(title) > 40:
        title = title[:40]
    return title


def is_subchannel_group(group_no: str) -> bool:
    """True if group_no is already a Shudo topic (nested parents forbidden)."""
    if not group_no or group_no.startswith("dm:"):
        return False
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM shudo_sub_channel WHERE sub_group_no=%s LIMIT 1",
                (group_no,),
            )
            return cur.fetchone() is not None
    finally:
        conn.close()


def assert_can_be_topic_parent(parent: str) -> None:
    if parent.startswith("dm:"):
        return
    if is_subchannel_group(parent):
        raise HTTPException(status_code=400, detail="话题内不能再创建话题")


def folder_is_topics_system(folder_id: str, uid: str) -> bool:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT name FROM shudo_folder WHERE folder_id=%s AND uid=%s LIMIT 1",
                (folder_id, uid),
            )
            row = cur.fetchone()
            return bool(row and row.get("name") == TOPICS_FOLDER_NAME)
    finally:
        conn.close()


def assert_folder_mutable(folder_id: str, uid: str) -> None:
    if folder_is_topics_system(folder_id, uid):
        raise HTTPException(status_code=400, detail="系统「话题」分组不可修改或删除")


def ensure_topics_folder(uid: str) -> str:
    """Ensure default「话题」分组 exists; return folder_id."""
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT folder_id FROM shudo_folder WHERE uid=%s AND name=%s LIMIT 1",
                (uid, TOPICS_FOLDER_NAME),
            )
            row = cur.fetchone()
            if row:
                return row["folder_id"]
            folder_id = uuid.uuid4().hex
            cur.execute(
                "INSERT INTO shudo_folder (folder_id, uid, name, sort) VALUES (%s,%s,%s,%s)",
                (folder_id, uid, TOPICS_FOLDER_NAME, 0),
            )
            return folder_id
    finally:
        conn.close()


def add_channel_to_folder(
    uid: str, folder_id: str, channel_id: str, channel_type: int
) -> None:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id FROM shudo_folder_item
                WHERE folder_id=%s AND uid=%s AND channel_id=%s AND channel_type=%s
                LIMIT 1
                """,
                (folder_id, uid, channel_id, channel_type),
            )
            if cur.fetchone():
                return
            cur.execute(
                "SELECT COALESCE(MAX(sort), -1) + 1 AS s FROM shudo_folder_item WHERE folder_id=%s AND uid=%s",
                (folder_id, uid),
            )
            sort = int((cur.fetchone() or {}).get("s") or 0)
            cur.execute(
                """
                INSERT INTO shudo_folder_item (folder_id, uid, channel_id, channel_type, sort)
                VALUES (%s,%s,%s,%s,%s)
                """,
                (folder_id, uid, channel_id, channel_type, sort),
            )
    finally:
        conn.close()


def user_is_robot(uid: str) -> bool:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT robot FROM user WHERE uid=%s LIMIT 1", (uid,))
            row = cur.fetchone()
            if row and int(row.get("robot") or 0) == 1:
                return True
            cur.execute(
                "SELECT 1 FROM robot WHERE robot_id=%s OR username=%s LIMIT 1",
                (uid, uid),
            )
            return bool(cur.fetchone())
    except Exception:
        return False
    finally:
        conn.close()


def ensure_group_member(group_no: str, uid: str, *, robot: int = 0) -> None:
    """Insert/restore group_member without friend checks (needed for bots like Hermes)."""
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, is_deleted FROM group_member
                WHERE group_no=%s AND uid=%s LIMIT 1
                """,
                (group_no, uid),
            )
            row = cur.fetchone()
            if row:
                cur.execute(
                    """
                    UPDATE group_member
                    SET is_deleted=0, status=1, robot=%s, version=version+1
                    WHERE group_no=%s AND uid=%s
                    """,
                    (robot, group_no, uid),
                )
            else:
                cur.execute(
                    """
                    INSERT INTO group_member
                      (group_no, uid, remark, role, version, is_deleted, status,
                       vercode, robot, invite_uid, forbidden_expir_time)
                    VALUES (%s,%s,'',0,1,0,1,'',%s,'',0)
                    """,
                    (group_no, uid, robot),
                )
            cur.execute(
                "UPDATE `group` SET version=version+1 WHERE group_no=%s",
                (group_no,),
            )
    finally:
        conn.close()


async def create_named_group(
    creator_uid: str, title: str, member_uids: list[str]
) -> str:
    """
    Create a named group without upstream group/create friend checks.
    Writes MySQL (group / group_member / group_setting) then registers WuKongIM channel.
    Upstream rejects members=[] with「群成员不能为空」, and bots with「非好友」.
    """
    creator_uid = normalize_auth_uid(creator_uid) or creator_uid
    members: list[str] = []
    seen = {creator_uid}
    for raw in member_uids:
        uid = (raw or "").strip()
        if not uid or uid in seen:
            continue
        if "@" in uid:
            # user@robot → keep robot id as member
            left, right = uid.split("@", 1)
            uid = right if right and right != creator_uid else left
        uid = uid.strip()
        if not uid or uid in seen or uid == creator_uid:
            continue
        seen.add(uid)
        members.append(uid)

    group_no = uuid.uuid4().hex
    name = title if title.startswith("#") else f"#{title}"
    if len(name) > 40:
        name = name[:40]

    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO `group`
                  (group_no, name, creator, status, forbidden, invite,
                   forbidden_add_friend, allow_view_history_msg, version,
                   notice, avatar, is_upload_avatar, group_type, category,
                   allow_member_pinned_message)
                VALUES (%s,%s,%s,1,0,1,0,1,1,'','',0,0,'topic',0)
                """,
                (group_no, name, creator_uid),
            )
            # owner
            cur.execute(
                """
                INSERT INTO group_member
                  (group_no, uid, remark, role, version, is_deleted, status,
                   vercode, robot, invite_uid, forbidden_expir_time)
                VALUES (%s,%s,'',1,1,0,1,'',0,'',0)
                """,
                (group_no, creator_uid),
            )
            cur.execute(
                """
                INSERT INTO group_setting
                  (uid, group_no, remark, mute, top, show_nick, save,
                   chat_pwd_on, revoke_remind, join_group_remind, screenshot,
                   receipt, version, flame, flame_second)
                VALUES (%s,%s,'',0,0,0,0,0,1,0,0,0,0,0,0)
                """,
                (creator_uid, group_no),
            )
            for uid in members:
                robot = 1 if user_is_robot(uid) else 0
                cur.execute(
                    """
                    INSERT INTO group_member
                      (group_no, uid, remark, role, version, is_deleted, status,
                       vercode, robot, invite_uid, forbidden_expir_time)
                    VALUES (%s,%s,'',0,1,0,1,'',%s,'',0)
                    """,
                    (group_no, uid, robot),
                )
                cur.execute(
                    """
                    INSERT INTO group_setting
                      (uid, group_no, remark, mute, top, show_nick, save,
                       chat_pwd_on, revoke_remind, join_group_remind, screenshot,
                       receipt, version, flame, flame_second)
                    VALUES (%s,%s,'',0,0,0,0,0,1,0,0,0,0,0,0)
                    """,
                    (uid, group_no),
                )
    finally:
        conn.close()

    subscribers = [creator_uid, *members]
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(
            f"{IM_API_URL}/channel",
            json={
                "channel_id": group_no,
                "channel_type": 2,
                "large": 0,
                "ban": 0,
                "subscribers": subscribers,
            },
        )
        if resp.status_code >= 400:
            # Channel may already exist; try adding subscribers
            add = await client.post(
                f"{IM_API_URL}/channel/subscriber_add",
                json={
                    "channel_id": group_no,
                    "channel_type": 2,
                    "subscribers": subscribers,
                    "reset": 0,
                },
            )
            if add.status_code >= 400:
                detail = "IM 频道注册失败"
                try:
                    detail = (resp.text or add.text or detail)[:200]
                except Exception:
                    pass
                raise HTTPException(status_code=502, detail=detail)

    return group_no


def make_topic_avatar_png(size: int = 200) -> bytes:
    """Dedicated topic avatar: brand-orange tile with a crisp '#' (no member collage)."""
    assert Image is not None
    from PIL import ImageDraw

    bg = (255, 69, 0)  # brand orange
    img = Image.new("RGB", (size, size), bg)
    draw = ImageDraw.Draw(img)
    # Soft rounded overlay via corner erase is heavy; draw # with bars (font-free, no stretch)
    ink = (255, 255, 255)
    # Two vertical bars + two horizontal bars → #
    t = max(10, size // 10)  # stroke thickness
    gap = size // 5
    # verticals
    v1 = size // 2 - gap // 2 - t // 2
    v2 = size // 2 + gap // 2 - t // 2
    top, bot = size // 4, size - size // 4
    draw.rectangle([v1, top, v1 + t, bot], fill=ink)
    draw.rectangle([v2, top, v2 + t, bot], fill=ink)
    # horizontals
    h1 = size // 2 - gap // 2 - t // 2
    h2 = size // 2 + gap // 2 - t // 2
    left, right = size // 4, size - size // 4
    draw.rectangle([left, h1, right, h1 + t], fill=ink)
    draw.rectangle([left, h2, right, h2 + t], fill=ink)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


async def generate_and_upload_group_avatar(
    group_no: str, member_uids: list[str], token: str
) -> None:
    """Upload a dedicated topic avatar (not a stretched member collage)."""
    if Image is None:
        return
    png = make_topic_avatar_png(200)
    async with httpx.AsyncClient(timeout=20.0) as client:
        files = {"file": ("topic_avatar.png", png, "image/png")}
        await client.post(
            f"{TS_API_URL}/groups/{group_no}/avatar",
            headers={"token": token},
            files=files,
        )


async def send_im_payload(
    from_uid: str, channel_id: str, payload: dict, *, channel_type: int = 2
) -> None:
    """Inject a message into WuKongIM so it appears in the topic history."""
    raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    body = {
        "header": {"no_persist": 0, "red_dot": 1, "sync_once": 0},
        "from_uid": from_uid,
        "channel_id": channel_id,
        "channel_type": channel_type,
        "payload": base64.b64encode(raw).decode("ascii"),
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(f"{IM_API_URL}/message/send", json=body)
        if resp.status_code >= 400:
            raise HTTPException(
                status_code=502,
                detail=f"写入话题消息失败: {(resp.text or '')[:160]}",
            )


async def add_member_allowing_bot(
    client: httpx.AsyncClient, token: str, group_no: str, uid: str
) -> None:
    """Try official members API; on friend-check failure, write DB for bots/peers."""
    headers = {"token": token}
    resp = await client.post(
        f"{TS_API_URL}/groups/{group_no}/members",
        headers=headers,
        json={"members": [uid]},
    )
    if resp.status_code < 400:
        # also ensure IM subscriber
        try:
            await client.post(
                f"{IM_API_URL}/channel/subscriber_add",
                json={
                    "channel_id": group_no,
                    "channel_type": 2,
                    "subscribers": [uid],
                    "reset": 0,
                },
            )
        except Exception:
            pass
        return
    msg = ""
    try:
        msg = str(resp.json().get("msg") or "")
    except Exception:
        msg = resp.text or ""
    # 非好友 / not friend → SQL fallback (esp. Hermes robot)
    robot = 1 if user_is_robot(uid) else 0
    if robot or ("好友" in msg) or ("friend" in msg.lower()) or resp.status_code in (
        400,
        403,
    ):
        ensure_group_member(group_no, uid, robot=robot)
        try:
            await client.post(
                f"{IM_API_URL}/channel/subscriber_add",
                json={
                    "channel_id": group_no,
                    "channel_type": 2,
                    "subscribers": [uid],
                    "reset": 0,
                },
            )
        except Exception:
            pass
        return
    raise HTTPException(status_code=resp.status_code, detail=msg or "拉人失败")


def parent_member_uids(parent_group_no: str) -> list[str]:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT uid FROM group_member
                WHERE group_no=%s AND is_deleted=0 AND status=1
                """,
                (parent_group_no,),
            )
            rows = cur.fetchall() or []
            return [r["uid"] for r in rows]
    finally:
        conn.close()


def assert_group_member(group_no: str, uid: str) -> None:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM group_member
                WHERE group_no=%s AND uid=%s AND is_deleted=0 AND status=1
                LIMIT 1
                """,
                (group_no, uid),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=403, detail="不是群成员")
    finally:
        conn.close()


def group_member_role(group_no: str, uid: str) -> Optional[int]:
    """Return member role (1=owner, 2=admin, 0=member) or None if not a member."""
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT role FROM group_member
                WHERE group_no=%s AND uid=%s AND is_deleted=0 AND status=1
                LIMIT 1
                """,
                (group_no, uid),
            )
            row = cur.fetchone()
            if not row:
                return None
            return int(row.get("role") or 0)
    finally:
        conn.close()


def get_subchannel_row(sub_group_no: str) -> dict:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, parent_group_no, sub_group_no, title, creator_uid,
                       COALESCE(archived, 0) AS archived, created_at
                FROM shudo_sub_channel WHERE sub_group_no=%s LIMIT 1
                """,
                (sub_group_no,),
            )
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="话题不存在")
            return row
    finally:
        conn.close()


def assert_can_manage_subchannel(sub_group_no: str, uid: str) -> dict:
    """Creator, topic owner/admin, or parent-group owner/admin may manage."""
    row = get_subchannel_row(sub_group_no)
    if row.get("creator_uid") == uid:
        return row
    role = group_member_role(sub_group_no, uid)
    if role in (1, 2):
        return row
    parent = row.get("parent_group_no") or ""
    if parent and not str(parent).startswith("dm:"):
        prole = group_member_role(parent, uid)
        if prole in (1, 2):
            return row
    if role is None:
        raise HTTPException(status_code=403, detail="不是该话题成员")
    raise HTTPException(status_code=403, detail="仅创建者或管理员可操作")


def remove_channel_from_all_folders(channel_id: str, channel_type: int = 2) -> None:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM shudo_folder_item WHERE channel_id=%s AND channel_type=%s",
                (channel_id, channel_type),
            )
    finally:
        conn.close()


def remove_channel_from_user_folders(
    uid: str, channel_id: str, channel_type: int = 2
) -> None:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                DELETE FROM shudo_folder_item
                WHERE uid=%s AND channel_id=%s AND channel_type=%s
                """,
                (uid, channel_id, channel_type),
            )
    finally:
        conn.close()


def soft_remove_group_member(group_no: str, uid: str) -> None:
    """Mark member deleted in MySQL (upstream kick may fail for bots / permission)."""
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE group_member
                SET is_deleted=1, status=0, version=version+1
                WHERE group_no=%s AND uid=%s AND is_deleted=0
                """,
                (group_no, uid),
            )
            cur.execute(
                "UPDATE `group` SET version=version+1 WHERE group_no=%s",
                (group_no,),
            )
    finally:
        conn.close()


async def remove_member_best_effort(
    client: httpx.AsyncClient, token: str, group_no: str, uid: str
) -> bool:
    """
    Remove member via bulk DELETE API (client convention), then SQL + IM fallback.
    Returns True if removal applied somehow.
    """
    headers = {"token": token}
    ok = False
    try:
        resp = await client.request(
            "DELETE",
            f"{TS_API_URL}/groups/{group_no}/members",
            headers=headers,
            json={"members": [uid]},
        )
        if resp.status_code < 400:
            ok = True
    except Exception:
        pass
    # Always soft-delete locally so sync is consistent even if API rejects
    try:
        soft_remove_group_member(group_no, uid)
        ok = True
    except Exception:
        pass
    try:
        await client.post(
            f"{IM_API_URL}/channel/subscriber_remove",
            json={
                "channel_id": group_no,
                "channel_type": 2,
                "subscribers": [uid],
            },
        )
    except Exception:
        pass
    remove_channel_from_user_folders(uid, group_no, 2)
    return ok


def rename_group_display(group_no: str, title: str) -> None:
    name = title if title.startswith("#") else f"#{title}"
    if len(name) > 40:
        name = name[:40]
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE `group` SET name=%s, version=version+1 WHERE group_no=%s",
                (name, group_no),
            )
    finally:
        conn.close()


async def disband_group_best_effort(group_no: str, token: str) -> None:
    """Disband via upstream API, then soft-close in MySQL as fallback."""
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            await client.delete(
                f"{TS_API_URL}/groups/{group_no}/disband",
                headers={"token": token},
            )
    except Exception:
        pass
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE `group` SET status=0, version=version+1 WHERE group_no=%s",
                (group_no,),
            )
            cur.execute(
                """
                UPDATE group_member
                SET is_deleted=1, version=version+1
                WHERE group_no=%s AND is_deleted=0
                """,
                (group_no,),
            )
    finally:
        conn.close()


def serialize_subchannel(row: dict) -> dict:
    return {
        "parent_group_no": row["parent_group_no"],
        "sub_group_no": row["sub_group_no"],
        "title": row["title"],
        "creator_uid": row.get("creator_uid"),
        "archived": int(row.get("archived") or 0),
        "created_at": str(row["created_at"]) if row.get("created_at") is not None else None,
        "name": f"#{row['title']}",
    }


# ---------- health ----------


@app.get("/health")
def health() -> dict:
    return {"ok": True}


# ---------- folders ----------


class FolderCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=40)


class FolderUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=40)
    sort: Optional[int] = None


class FolderItem(BaseModel):
    channel_id: str
    channel_type: int


class FolderItemsPut(BaseModel):
    items: list[FolderItem] = Field(default_factory=list)


@app.get("/v1/shudo/folders")
def list_folders(user: AuthUser = Depends(require_user)) -> dict:
    ensure_topics_folder(user.uid)
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT folder_id, name, sort, created_at FROM shudo_folder WHERE uid=%s ORDER BY sort ASC, id ASC",
                (user.uid,),
            )
            folders = cur.fetchall() or []
            out = []
            for f in folders:
                cur.execute(
                    """
                    SELECT channel_id, channel_type, sort FROM shudo_folder_item
                    WHERE folder_id=%s AND uid=%s ORDER BY sort ASC, id ASC
                    """,
                    (f["folder_id"], user.uid),
                )
                items = cur.fetchall() or []
                out.append(
                    {
                        "folder_id": f["folder_id"],
                        "name": f["name"],
                        "sort": f["sort"],
                        "created_at": str(f["created_at"]),
                        "items": [
                            {
                                "channel_id": i["channel_id"],
                                "channel_type": i["channel_type"],
                                "sort": i["sort"],
                            }
                            for i in items
                        ],
                    }
                )
            return {"folders": out}
    finally:
        conn.close()


@app.post("/v1/shudo/folders")
def create_folder(body: FolderCreate, user: AuthUser = Depends(require_user)) -> dict:
    name = body.name.strip()
    if name == TOPICS_FOLDER_NAME:
        raise HTTPException(status_code=400, detail="「话题」为系统分组名，不可占用")
    folder_id = uuid.uuid4().hex
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COALESCE(MAX(sort), -1) + 1 AS s FROM shudo_folder WHERE uid=%s",
                (user.uid,),
            )
            sort = int((cur.fetchone() or {}).get("s") or 0)
            cur.execute(
                "INSERT INTO shudo_folder (folder_id, uid, name, sort) VALUES (%s,%s,%s,%s)",
                (folder_id, user.uid, name, sort),
            )
        return {"folder_id": folder_id, "name": name, "sort": sort, "items": []}
    finally:
        conn.close()


@app.put("/v1/shudo/folders/{folder_id}")
def update_folder(
    folder_id: str, body: FolderUpdate, user: AuthUser = Depends(require_user)
) -> dict:
    assert_folder_mutable(folder_id, user.uid)
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT folder_id FROM shudo_folder WHERE folder_id=%s AND uid=%s",
                (folder_id, user.uid),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="文件夹不存在")
            if body.name is not None:
                name = body.name.strip()
                if name == TOPICS_FOLDER_NAME:
                    raise HTTPException(
                        status_code=400, detail="「话题」为系统分组名，不可占用"
                    )
                cur.execute(
                    "UPDATE shudo_folder SET name=%s WHERE folder_id=%s AND uid=%s",
                    (name, folder_id, user.uid),
                )
            if body.sort is not None:
                cur.execute(
                    "UPDATE shudo_folder SET sort=%s WHERE folder_id=%s AND uid=%s",
                    (body.sort, folder_id, user.uid),
                )
        return {"ok": True}
    finally:
        conn.close()


@app.delete("/v1/shudo/folders/{folder_id}")
def delete_folder(folder_id: str, user: AuthUser = Depends(require_user)) -> dict:
    assert_folder_mutable(folder_id, user.uid)
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM shudo_folder_item WHERE folder_id=%s AND uid=%s",
                (folder_id, user.uid),
            )
            cur.execute(
                "DELETE FROM shudo_folder WHERE folder_id=%s AND uid=%s",
                (folder_id, user.uid),
            )
        return {"ok": True}
    finally:
        conn.close()


@app.put("/v1/shudo/folders/{folder_id}/items")
def put_folder_items(
    folder_id: str, body: FolderItemsPut, user: AuthUser = Depends(require_user)
) -> dict:
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT folder_id FROM shudo_folder WHERE folder_id=%s AND uid=%s",
                (folder_id, user.uid),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="文件夹不存在")
            cur.execute(
                "DELETE FROM shudo_folder_item WHERE folder_id=%s AND uid=%s",
                (folder_id, user.uid),
            )
            for idx, item in enumerate(body.items):
                cur.execute(
                    """
                    INSERT INTO shudo_folder_item (folder_id, uid, channel_id, channel_type, sort)
                    VALUES (%s,%s,%s,%s,%s)
                    """,
                    (folder_id, user.uid, item.channel_id, item.channel_type, idx),
                )
        return {"ok": True, "count": len(body.items)}
    finally:
        conn.close()


# ---------- sub-channels ----------


class SubChannelCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=40)
    seed_payload: Optional[dict] = None
    seed_from_uid: Optional[str] = Field(default=None, max_length=120)


@app.get("/v1/shudo/groups/{parent}/subchannels")
def list_subchannels(
    parent: str,
    include_archived: int = 0,
    user: AuthUser = Depends(require_user),
) -> dict:
    # Real groups require membership. dm:{peer} only returns topics the caller belongs to.
    if not parent.startswith("dm:"):
        assert_group_member(parent, user.uid)
    conn = db()
    try:
        with conn.cursor() as cur:
            if parent.startswith("dm:"):
                if include_archived:
                    cur.execute(
                        """
                        SELECT s.parent_group_no, s.sub_group_no, s.title, s.creator_uid,
                               COALESCE(s.archived, 0) AS archived, s.created_at
                        FROM shudo_sub_channel s
                        INNER JOIN group_member m
                          ON m.group_no = s.sub_group_no AND m.uid=%s
                         AND m.is_deleted=0 AND m.status=1
                        WHERE s.parent_group_no=%s
                        ORDER BY archived ASC, s.id ASC
                        """,
                        (user.uid, parent),
                    )
                else:
                    cur.execute(
                        """
                        SELECT s.parent_group_no, s.sub_group_no, s.title, s.creator_uid,
                               COALESCE(s.archived, 0) AS archived, s.created_at
                        FROM shudo_sub_channel s
                        INNER JOIN group_member m
                          ON m.group_no = s.sub_group_no AND m.uid=%s
                         AND m.is_deleted=0 AND m.status=1
                        WHERE s.parent_group_no=%s AND COALESCE(s.archived, 0)=0
                        ORDER BY s.id ASC
                        """,
                        (user.uid, parent),
                    )
            elif include_archived:
                cur.execute(
                    """
                    SELECT parent_group_no, sub_group_no, title, creator_uid,
                           COALESCE(archived, 0) AS archived, created_at
                    FROM shudo_sub_channel
                    WHERE parent_group_no=%s
                    ORDER BY archived ASC, id ASC
                    """,
                    (parent,),
                )
            else:
                cur.execute(
                    """
                    SELECT parent_group_no, sub_group_no, title, creator_uid,
                           COALESCE(archived, 0) AS archived, created_at
                    FROM shudo_sub_channel
                    WHERE parent_group_no=%s AND COALESCE(archived, 0)=0
                    ORDER BY id ASC
                    """,
                    (parent,),
                )
            rows = cur.fetchall() or []
            return {"subchannels": [serialize_subchannel(r) for r in rows]}
    finally:
        conn.close()


@app.get("/v1/shudo/subchannels/map")
def subchannels_map(user: AuthUser = Depends(require_user)) -> dict:
    """Map sub_group_no -> {parent, title} for conversations the user belongs to."""
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT s.parent_group_no, s.sub_group_no, s.title,
                       COALESCE(s.archived, 0) AS archived
                FROM shudo_sub_channel s
                INNER JOIN group_member m
                  ON m.group_no = s.sub_group_no AND m.uid=%s AND m.is_deleted=0 AND m.status=1
                WHERE COALESCE(s.archived, 0)=0
                """,
                (user.uid,),
            )
            rows = cur.fetchall() or []
            mapping = {
                r["sub_group_no"]: {
                    "parent_group_no": r["parent_group_no"],
                    "title": r["title"],
                    "is_sub_channel": True,
                    "archived": 0,
                }
                for r in rows
            }
            return {"map": mapping}
    finally:
        conn.close()


def resolve_dm_peer_uid(peer: str, user_uid: str, from_uid: str = "") -> str:
    """Normalize DM peer; agent channels use `userUid@robotUid`."""
    peer = (peer or "").strip()
    from_uid = (from_uid or "").strip()

    def unwrap(cid: str) -> str:
        if not cid:
            return ""
        if "@" in cid:
            left, right = cid.split("@", 1)
            if right and right != user_uid:
                return right
            if left and left != user_uid:
                return left
            return right or left
        return cid

    peer = unwrap(peer)
    if (not peer or peer == user_uid) and from_uid and from_uid != user_uid:
        peer = unwrap(from_uid)
    if not peer or peer == user_uid:
        return ""
    return peer


class PersonTopicCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=40)
    peer_uid: str = Field(..., min_length=1, max_length=120)
    # 当 channel_id 误为自己时，用消息发送方兜底（Hermes 等机器人）
    from_uid: Optional[str] = Field(default=None, max_length=120)
    # 原消息 payload（写入话题历史）；如 {"type":1,"content":"..."}
    seed_payload: Optional[dict] = None
    seed_from_uid: Optional[str] = Field(default=None, max_length=120)


@app.post("/v1/shudo/topics/from-person")
async def create_topic_from_person(
    body: PersonTopicCreate, user: AuthUser = Depends(require_user)
) -> dict:
    """Create a topic from a DM (incl. Hermes bot) without friend-check failures."""
    title = normalize_topic_title(body.title)
    peer = resolve_dm_peer_uid(body.peer_uid, user.uid, body.from_uid or "")
    if not peer:
        raise HTTPException(status_code=400, detail="无效的会话对象")

    # 直接写库 + 注册 IM，避开 group/create 的「群成员不能为空 / 非好友」
    sub_no = await create_named_group(user.uid, title, [peer])

    try:
        await generate_and_upload_group_avatar(
            sub_no, [user.uid, peer], user.token
        )
    except Exception:
        pass

    # Seed always attributed to the authenticated creator (ignore client seed_from_uid).
    if body.seed_payload and isinstance(body.seed_payload, dict):
        try:
            await send_im_payload(user.uid, sub_no, body.seed_payload)
        except Exception:
            # 不阻断建群；客户端仍可再发
            pass
    else:
        # 至少写入一条话题标题提示
        try:
            await send_im_payload(
                user.uid,
                sub_no,
                {"type": 1, "content": f"话题「{title}」"},
            )
        except Exception:
            pass

    parent_key = f"dm:{peer}"
    if len(parent_key) > 40:
        parent_key = parent_key[:40]
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO shudo_sub_channel (parent_group_no, sub_group_no, title, creator_uid)
                VALUES (%s,%s,%s,%s)
                """,
                (parent_key, sub_no, title, user.uid),
            )
    finally:
        conn.close()

    channel_type_group = 2
    topics_id = ensure_topics_folder(user.uid)
    add_channel_to_folder(user.uid, topics_id, sub_no, channel_type_group)

    return {
        "parent_group_no": parent_key,
        "sub_group_no": sub_no,
        "title": title,
        "name": f"#{title}",
        "creator_uid": user.uid,
        "peer_uid": peer,
    }


@app.post("/v1/shudo/groups/{parent}/subchannels")
async def create_subchannel(
    parent: str, body: SubChannelCreate, user: AuthUser = Depends(require_user)
) -> dict:
    assert_can_be_topic_parent(parent)
    assert_group_member(parent, user.uid)
    title = normalize_topic_title(body.title)
    members = parent_member_uids(parent)
    if user.uid not in members:
        members.append(user.uid)

    others = [u for u in members if u != user.uid]
    sub_no = await create_named_group(user.uid, title, others)

    try:
        await generate_and_upload_group_avatar(sub_no, members, user.token)
    except Exception:
        pass

    # Seed always attributed to the authenticated creator (ignore client seed_from_uid).
    if body.seed_payload and isinstance(body.seed_payload, dict):
        try:
            await send_im_payload(user.uid, sub_no, body.seed_payload)
        except Exception:
            pass

    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO shudo_sub_channel (parent_group_no, sub_group_no, title, creator_uid)
                VALUES (%s,%s,%s,%s)
                """,
                (parent, sub_no, title, user.uid),
            )
    finally:
        conn.close()

    # 新建话题自动归入各成员的「话题」分组（至少 creator；其余成员同步写入）
    channel_type_group = 2
    for member_uid in members:
        try:
            topics_id = ensure_topics_folder(member_uid)
            add_channel_to_folder(member_uid, topics_id, sub_no, channel_type_group)
        except Exception:
            pass

    return {
        "parent_group_no": parent,
        "sub_group_no": sub_no,
        "title": title,
        "name": f"#{title}",
        "creator_uid": user.uid,
    }


@app.post("/v1/shudo/groups/{parent}/subchannels/sync-members")
async def sync_subchannel_members(
    parent: str, user: AuthUser = Depends(require_user)
) -> dict:
    """
    Mirror parent membership into all active child sub-channels:
    - add missing parent members (API + bot-friendly SQL fallback)
    - remove members who left the parent (bulk DELETE + SQL + IM)
    - keep 「话题」folder items in sync for added/removed users
    """
    if parent.startswith("dm:"):
        # DM-rooted topics only have the two peers; skip parent-membership mirror
        return {"ok": True, "subchannels": 0, "added": 0, "removed": 0, "skipped": "dm"}
    assert_group_member(parent, user.uid)
    parent_uids = set(parent_member_uids(parent))
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT sub_group_no FROM shudo_sub_channel
                WHERE parent_group_no=%s AND COALESCE(archived, 0)=0
                """,
                (parent,),
            )
            subs = [r["sub_group_no"] for r in (cur.fetchall() or [])]
    finally:
        conn.close()

    if not subs:
        return {"ok": True, "subchannels": 0, "added": 0, "removed": 0}

    added = 0
    removed = 0
    errors: list[str] = []
    async with httpx.AsyncClient(timeout=45.0) as client:
        for sub in subs:
            sub_uids = set(parent_member_uids(sub))
            to_add = sorted(parent_uids - sub_uids)
            # Never kick the sub-group owner solely via sync mismatch; still remove
            # if they left parent (owner should follow parent roster).
            to_remove = sorted(sub_uids - parent_uids)

            for uid in to_add:
                try:
                    await add_member_allowing_bot(client, user.token, sub, uid)
                    added += 1
                    try:
                        topics_id = ensure_topics_folder(uid)
                        add_channel_to_folder(uid, topics_id, sub, 2)
                    except Exception:
                        pass
                except Exception as e:
                    errors.append(f"add {uid}->{sub}: {e}")

            for uid in to_remove:
                try:
                    if await remove_member_best_effort(
                        client, user.token, sub, uid
                    ):
                        removed += 1
                except Exception as e:
                    errors.append(f"remove {uid}->{sub}: {e}")

    result: dict[str, Any] = {
        "ok": True,
        "subchannels": len(subs),
        "added": added,
        "removed": removed,
    }
    if errors:
        result["errors"] = errors[:20]
    return result


class SubChannelPatch(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=40)
    archived: Optional[bool] = None


@app.patch("/v1/shudo/subchannels/{sub_group_no}")
async def patch_subchannel(
    sub_group_no: str,
    body: SubChannelPatch,
    user: AuthUser = Depends(require_user),
) -> dict:
    """Rename and/or archive/unarchive a sub-channel (topic)."""
    if body.title is None and body.archived is None:
        raise HTTPException(status_code=400, detail="无变更")
    row = assert_can_manage_subchannel(sub_group_no, user.uid)
    title = row["title"]
    archived = int(row.get("archived") or 0)

    if body.title is not None:
        title = normalize_topic_title(body.title)
        rename_group_display(sub_group_no, title)

    if body.archived is not None:
        archived = 1 if body.archived else 0
        if archived:
            remove_channel_from_all_folders(sub_group_no, 2)

    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE shudo_sub_channel
                SET title=%s, archived=%s
                WHERE sub_group_no=%s
                """,
                (title, archived, sub_group_no),
            )
            cur.execute(
                """
                SELECT parent_group_no, sub_group_no, title, creator_uid,
                       COALESCE(archived, 0) AS archived, created_at
                FROM shudo_sub_channel WHERE sub_group_no=%s LIMIT 1
                """,
                (sub_group_no,),
            )
            updated = cur.fetchone() or row
    finally:
        conn.close()

    # Unarchive: restore into each active topic member's 「话题」 folder
    if body.archived is False:
        for member_uid in parent_member_uids(sub_group_no):
            try:
                topics_id = ensure_topics_folder(member_uid)
                add_channel_to_folder(member_uid, topics_id, sub_group_no, 2)
            except Exception:
                pass

    return serialize_subchannel(updated)


@app.delete("/v1/shudo/subchannels/{sub_group_no}")
async def delete_subchannel(
    sub_group_no: str,
    disband: int = 1,
    user: AuthUser = Depends(require_user),
) -> dict:
    """Delete sub-channel metadata; by default also disband the underlying group."""
    assert_can_manage_subchannel(sub_group_no, user.uid)
    remove_channel_from_all_folders(sub_group_no, 2)
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM shudo_sub_channel WHERE sub_group_no=%s",
                (sub_group_no,),
            )
    finally:
        conn.close()

    if disband:
        await disband_group_best_effort(sub_group_no, user.token)

    return {"ok": True, "sub_group_no": sub_group_no, "disbanded": bool(disband)}
