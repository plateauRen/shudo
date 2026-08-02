import WKApp from "../App";
import StorageService from "./StorageService";
import { Channel, ChannelTypeGroup, ChannelTypePerson } from "wukongimjssdk";

export type ShudoFolderItem = {
  channel_id: string;
  channel_type: number;
  sort?: number;
};

export type ShudoFolder = {
  folder_id: string;
  name: string;
  sort: number;
  created_at?: string;
  items: ShudoFolderItem[];
};

export type SubChannelInfo = {
  parent_group_no: string;
  sub_group_no: string;
  title: string;
  creator_uid?: string;
  created_at?: string;
  name?: string;
  archived?: number;
};

type SubChannelMapEntry = {
  parent_group_no: string;
  title: string;
  is_sub_channel: boolean;
  archived?: number;
};

const CACHE_FOLDERS = "shudo-folders-cache";
const CACHE_SUBMAP = "shudo-subchannel-map";
export const TOPICS_GROUP_NAME = "话题";

/** Client for services/shudo-org — prefer same-origin /v1/shudo (dev proxy / nginx) */
export class ShudoOrgManager {
  private static _instance: ShudoOrgManager;
  static shared(): ShudoOrgManager {
    if (!this._instance) this._instance = new ShudoOrgManager();
    return this._instance;
  }

  folders: ShudoFolder[] = [];
  subChannelMap: Record<string, SubChannelMapEntry> = {};
  private listeners: Array<() => void> = [];

  addListener(fn: () => void) {
    this.listeners.push(fn);
  }
  removeListener(fn: () => void) {
    this.listeners = this.listeners.filter((x) => x !== fn);
  }
  private emit() {
    this.listeners.forEach((fn) => fn());
  }

  private baseURL(): string {
    // Same-origin avoids CORS (CRA setupProxy + nginx /v1/shudo)
    if (typeof window !== "undefined" && window.location?.host) {
      return `${window.location.protocol}//${window.location.host}/v1/shudo`;
    }
    try {
      const api = WKApp.apiClient.config.apiURL || "";
      const u = new URL(api, "http://127.0.0.1");
      return `${u.protocol}//${u.hostname}:8092/v1/shudo`;
    } catch {
      return "http://127.0.0.1:8092/v1/shudo";
    }
  }

  private headers(): Record<string, string> {
    const token = WKApp.loginInfo.token || "";
    const uid = WKApp.loginInfo.uid || "";
    return {
      "Content-Type": "application/json",
      token,
      uid,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    };
  }

  private async req<T = any>(
    method: string,
    path: string,
    body?: any
  ): Promise<T> {
    let resp: Response;
    try {
      resp = await fetch(`${this.baseURL()}${path}`, {
        method,
        headers: this.headers(),
        body: body !== undefined ? JSON.stringify(body) : undefined,
      });
    } catch (e: any) {
      const err: any = new Error(
        e?.message === "Failed to fetch"
          ? "无法连接分组服务，请确认 shudo-org(:8092) 已启动"
          : e?.message || "网络错误"
      );
      err.msg = err.message;
      throw err;
    }
    const text = await resp.text();
    let data: any = {};
    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      data = { msg: text };
    }
    if (!resp.ok) {
      const detail = data.detail || data.msg || `HTTP ${resp.status}`;
      const err: any = new Error(
        typeof detail === "string" ? detail : JSON.stringify(detail)
      );
      err.status = resp.status;
      err.msg = err.message;
      throw err;
    }
    return data as T;
  }

  loadCache() {
    try {
      const f = StorageService.shared.getItem(CACHE_FOLDERS);
      if (f) this.folders = JSON.parse(f);
    } catch {
      /* ignore */
    }
    try {
      const m = StorageService.shared.getItem(CACHE_SUBMAP);
      if (m) this.subChannelMap = JSON.parse(m);
    } catch {
      /* ignore */
    }
  }

  private saveFoldersCache() {
    StorageService.shared.setItem(CACHE_FOLDERS, JSON.stringify(this.folders));
  }
  private saveSubMapCache() {
    StorageService.shared.setItem(CACHE_SUBMAP, JSON.stringify(this.subChannelMap));
  }

  getTopicsGroup(): ShudoFolder | undefined {
    return this.folders.find((f) => f.name === TOPICS_GROUP_NAME);
  }

  async refreshFolders(): Promise<ShudoFolder[]> {
    this.loadCache();
    try {
      const data = await this.req<{ folders: ShudoFolder[] }>("GET", "/folders");
      this.folders = data.folders || [];
      this.saveFoldersCache();
      this.emit();
    } catch {
      /* keep cache */
    }
    return this.folders;
  }

  async createFolder(name: string): Promise<ShudoFolder> {
    const f = await this.req<ShudoFolder>("POST", "/folders", { name });
    await this.refreshFolders();
    return f;
  }

  async renameFolder(folderId: string, name: string): Promise<void> {
    await this.req("PUT", `/folders/${folderId}`, { name });
    await this.refreshFolders();
  }

  async deleteFolder(folderId: string): Promise<void> {
    await this.req("DELETE", `/folders/${folderId}`);
    await this.refreshFolders();
  }

  async setFolderItems(
    folderId: string,
    items: ShudoFolderItem[]
  ): Promise<void> {
    await this.req("PUT", `/folders/${folderId}/items`, { items });
    await this.refreshFolders();
  }

  async addChannelToFolder(
    folderId: string,
    channelId: string,
    channelType: number
  ): Promise<void> {
    const folder = this.folders.find((f) => f.folder_id === folderId);
    const items = [...(folder?.items || [])];
    if (
      items.some(
        (i) => i.channel_id === channelId && i.channel_type === channelType
      )
    ) {
      return;
    }
    items.push({ channel_id: channelId, channel_type: channelType });
    await this.setFolderItems(folderId, items);
  }

  async removeChannelFromFolder(
    folderId: string,
    channelId: string,
    channelType: number
  ): Promise<void> {
    const folder = this.folders.find((f) => f.folder_id === folderId);
    if (!folder) return;
    const items = (folder.items || []).filter(
      (i) => !(i.channel_id === channelId && i.channel_type === channelType)
    );
    await this.setFolderItems(folderId, items);
  }

  /** Folders that currently contain this channel */
  foldersContaining(channelId: string, channelType: number): ShudoFolder[] {
    return (this.folders || []).filter((f) =>
      this.folderContains(f, channelId, channelType)
    );
  }

  async refreshSubChannelMap(): Promise<void> {
    this.loadCache();
    try {
      const data = await this.req<{ map: Record<string, SubChannelMapEntry> }>(
        "GET",
        "/subchannels/map"
      );
      this.subChannelMap = data.map || {};
      this.saveSubMapCache();
      this.emit();
    } catch {
      /* keep cache */
    }
  }

  getSubChannelMeta(groupNo: string): SubChannelMapEntry | undefined {
    return this.subChannelMap[groupNo];
  }

  async listSubChannels(
    parentGroupNo: string,
    opts?: { includeArchived?: boolean }
  ): Promise<SubChannelInfo[]> {
    const q = opts?.includeArchived ? "?include_archived=1" : "";
    const data = await this.req<{ subchannels: SubChannelInfo[] }>(
      "GET",
      `/groups/${parentGroupNo}/subchannels${q}`
    );
    return data.subchannels || [];
  }

  async renameSubChannel(
    subGroupNo: string,
    title: string
  ): Promise<SubChannelInfo> {
    const updated = await this.req<SubChannelInfo>(
      "PATCH",
      `/subchannels/${subGroupNo}`,
      { title }
    );
    await this.refreshSubChannelMap();
    return updated;
  }

  async setSubChannelArchived(
    subGroupNo: string,
    archived: boolean
  ): Promise<SubChannelInfo> {
    const updated = await this.req<SubChannelInfo>(
      "PATCH",
      `/subchannels/${subGroupNo}`,
      { archived }
    );
    await this.refreshSubChannelMap();
    await this.refreshFolders();
    return updated;
  }

  async deleteSubChannel(
    subGroupNo: string,
    opts?: { disband?: boolean }
  ): Promise<void> {
    const disband = opts?.disband === false ? 0 : 1;
    await this.req(
      "DELETE",
      `/subchannels/${subGroupNo}?disband=${disband}`
    );
    await this.refreshSubChannelMap();
    await this.refreshFolders();
  }

  /**
   * 解析私聊对方 uid。
   * Hermes 等客服/机器人会话 channelID 常为 `userUid@robotUid`。
   */
  resolvePersonPeerUid(
    channel?: { channelID: string; channelType: number } | null,
    fromUid?: string
  ): string {
    const me = WKApp.loginInfo.uid || "";
    const open = WKApp.shared.openChannel;
    const normalize = (raw?: string) => {
      const id = (raw || "").trim();
      if (!id) return "";
      if (id.includes("@")) {
        const [left, right] = id.split("@", 2);
        // user@robot → 对方是机器人
        if (right && right !== me) return right;
        if (left && left !== me) return left;
        return right || left || "";
      }
      return id !== me ? id : "";
    };
    const candidates = [
      open?.channelType === ChannelTypePerson ? open.channelID : "",
      channel?.channelType === ChannelTypePerson ? channel.channelID : "",
      fromUid || "",
    ];
    for (const id of candidates) {
      const peer = normalize(id);
      if (peer) return peer;
    }
    return "";
  }

  /**
   * 话题父键：群用 groupNo；私聊用 dm:{peer}（与 shudo-org 一致）。
   */
  parentKeyForChannel(channel?: Channel | null, fromUid?: string): string {
    if (!channel) return "";
    if (channel.channelType === ChannelTypePerson) {
      const peer =
        this.resolvePersonPeerUid(channel, fromUid) || channel.channelID;
      let key = `dm:${peer}`;
      if (key.length > 40) key = key.slice(0, 40);
      return key;
    }
    if (channel.channelType === ChannelTypeGroup) {
      return channel.channelID;
    }
    return "";
  }

  /** 当前会话是否可作为话题父级（群父 / 私聊；已是话题则否） */
  canHostTopics(channel?: Channel | null): boolean {
    if (!channel) return false;
    if (channel.channelType === ChannelTypePerson) return true;
    if (channel.channelType !== ChannelTypeGroup) return false;
    return !this.getSubChannelMeta(channel.channelID);
  }

  /** 从私聊（含 Hermes 机器人）创建话题，服务端绕过非好友校验 */
  async createTopicFromPerson(
    peerUid: string,
    title: string,
    fromUid?: string,
    seed?: { payload?: Record<string, any>; fromUid?: string }
  ): Promise<SubChannelInfo> {
    const me = WKApp.loginInfo.uid || "";
    let peer = (peerUid || "").trim();
    const from = (fromUid || "").trim();
    if ((!peer || peer === me) && from && from !== me) {
      peer = from;
    }
    // user@robot
    if (peer.includes("@")) {
      peer = this.resolvePersonPeerUid(
        { channelID: peer, channelType: ChannelTypePerson },
        from
      );
    }
    if (!peer || peer === me) {
      const err: any = new Error("无效的会话对象");
      err.msg = err.message;
      throw err;
    }
    const created = await this.req<SubChannelInfo>(
      "POST",
      "/topics/from-person",
      {
        title,
        peer_uid: peer,
        from_uid: from || undefined,
        seed_payload: seed?.payload,
        seed_from_uid: seed?.fromUid || from || undefined,
      }
    );
    await this.refreshSubChannelMap();
    await this.refreshFolders();
    return created;
  }

  async createSubChannel(
    parentGroupNo: string,
    title: string,
    seed?: { payload?: Record<string, any>; fromUid?: string }
  ): Promise<SubChannelInfo> {
    const created = await this.req<SubChannelInfo>(
      "POST",
      `/groups/${parentGroupNo}/subchannels`,
      {
        title,
        seed_payload: seed?.payload,
        seed_from_uid: seed?.fromUid,
      }
    );
    await this.refreshSubChannelMap();
    await this.refreshFolders();
    return created;
  }

  async syncSubChannelMembers(parentGroupNo: string): Promise<void> {
    await this.req("POST", `/groups/${parentGroupNo}/subchannels/sync-members`);
  }

  channelKey(channelId: string, channelType: number): string {
    return `${channelType}:${channelId}`;
  }

  folderContains(
    folder: ShudoFolder,
    channelId: string,
    channelType: number
  ): boolean {
    return folder.items.some(
      (i) => i.channel_id === channelId && i.channel_type === channelType
    );
  }
}

export const shudoOrgManager = ShudoOrgManager.shared();
