import React, { Component } from "react";
import { Button, Input, Modal, Toast } from "@douyinfe/semi-ui";
import { Channel, ChannelTypeGroup } from "wukongimjssdk";
import WKApp from "../../App";
import {
  shudoOrgManager,
  SubChannelInfo,
} from "../../Service/ShudoOrgManager";

type Props = {
  parent: Channel;
};

type State = {
  list: SubChannelInfo[];
  title: string;
  loading: boolean;
  showArchived: boolean;
  renaming: string | null;
  renameValue: string;
};

export default class SubChannelsPanel extends Component<Props, State> {
  state: State = {
    list: [],
    title: "",
    loading: false,
    showArchived: false,
    renaming: null,
    renameValue: "",
  };

  /** 从会话列表 / 消息菜单打开管理面板（不依赖频道设置路由） */
  static open(parent: Channel) {
    Modal.info({
      title: "话题",
      icon: null,
      width: 480,
      footer: null,
      maskClosable: true,
      content: <SubChannelsPanel parent={parent} />,
    });
  }

  parentKey(): string {
    return shudoOrgManager.parentKeyForChannel(this.props.parent);
  }

  componentDidMount() {
    this.reload();
  }

  async reload() {
    const parentKey = this.parentKey();
    const { showArchived } = this.state;
    if (!parentKey) return;
    this.setState({ loading: true });
    try {
      const list = await shudoOrgManager.listSubChannels(parentKey, {
        includeArchived: showArchived,
      });
      this.setState({ list });
    } catch (e: any) {
      Toast.error(e?.msg || e?.message || "加载话题失败");
    } finally {
      this.setState({ loading: false });
    }
  }

  async onRename(s: SubChannelInfo) {
    const t = this.state.renameValue.trim().replace(/^#+/, "");
    if (!t) {
      Toast.warning("请输入名称");
      return;
    }
    try {
      await shudoOrgManager.renameSubChannel(s.sub_group_no, t);
      Toast.success("已改名");
      this.setState({ renaming: null, renameValue: "" });
      await this.reload();
    } catch (e: any) {
      Toast.error(e?.msg || e?.message || "改名失败");
    }
  }

  onArchive(s: SubChannelInfo, archived: boolean) {
    Modal.confirm({
      title: archived ? "归档话题？" : "取消归档？",
      content: archived
        ? `「#${s.title}」将从列表与「话题」分组隐藏，会话记录保留。`
        : `恢复「#${s.title}」到活跃列表。`,
      onOk: async () => {
        try {
          await shudoOrgManager.setSubChannelArchived(s.sub_group_no, archived);
          Toast.success(archived ? "已归档" : "已恢复");
          await this.reload();
        } catch (e: any) {
          Toast.error(e?.msg || e?.message || "操作失败");
          throw e;
        }
      },
    });
  }

  onDelete(s: SubChannelInfo) {
    Modal.confirm({
      title: "删除话题？",
      content: `将删除「#${s.title}」并解散该群。此操作不可恢复。`,
      okType: "danger",
      onOk: async () => {
        try {
          await shudoOrgManager.deleteSubChannel(s.sub_group_no);
          Toast.success("已删除");
          await this.reload();
        } catch (e: any) {
          Toast.error(e?.msg || e?.message || "删除失败");
          throw e;
        }
      },
    });
  }

  render() {
    const { parent } = this.props;
    const { list, title, loading, showArchived, renaming, renameValue } =
      this.state;
    const parentKey = this.parentKey();
    const isDm = parentKey.startsWith("dm:");
    const isSub =
      parent.channelType === ChannelTypeGroup &&
      !!shudoOrgManager.getSubChannelMeta(parent.channelID);
    if (isSub || !parentKey) {
      return (
        <div style={{ padding: 16, color: "var(--wk-color-font-tip, #8A9199)" }}>
          当前已是话题，请在所属群或私聊中管理。
        </div>
      );
    }
    return (
      <div style={{ padding: 16 }}>
        <div
          style={{
            marginBottom: 12,
            fontSize: 13,
            color: "var(--wk-color-font-tip, #8A9199)",
          }}
        >
          {isDm
            ? "从私聊创建的话题会归入「话题」分组。可改名、归档或删除（删除将解散话题群）。"
            : "话题会自动加入父群全员，并归入「话题」分组。可改名、归档或删除（删除将解散话题群）。"}
        </div>
        <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
          <Input
            value={title}
            placeholder="话题名称，如 开发"
            maxLength={20}
            onChange={(v) => this.setState({ title: v })}
          />
          <Button
            theme="solid"
            type="primary"
            loading={loading}
            onClick={async () => {
              const t = title.trim();
              if (!t) {
                Toast.warning("请输入名称");
                return;
              }
              try {
                let created: SubChannelInfo;
                if (isDm) {
                  const peer =
                    shudoOrgManager.resolvePersonPeerUid(parent) ||
                    parent.channelID;
                  created = await shudoOrgManager.createTopicFromPerson(
                    peer,
                    t
                  );
                } else {
                  created = await shudoOrgManager.createSubChannel(parentKey, t);
                }
                Toast.success("已创建话题");
                this.setState({ title: "" });
                await this.reload();
                if (created?.sub_group_no) {
                  WKApp.endpoints.showConversation(
                    new Channel(created.sub_group_no, ChannelTypeGroup)
                  );
                }
              } catch (e: any) {
                Toast.error(e?.msg || e?.message || "创建失败");
              }
            }}
          >
            创建
          </Button>
        </div>
        <div style={{ marginBottom: 12, display: "flex", gap: 8, flexWrap: "wrap" }}>
          <Button
            size="small"
            type={showArchived ? "primary" : "tertiary"}
            onClick={async () => {
              this.setState({ showArchived: !showArchived }, () =>
                this.reload()
              );
            }}
          >
            {showArchived ? "隐藏已归档" : "显示已归档"}
          </Button>
          {!isDm ? (
            <Button
              size="small"
              type="tertiary"
              loading={loading}
              onClick={async () => {
                try {
                  this.setState({ loading: true });
                  await shudoOrgManager.syncSubChannelMembers(parentKey);
                  Toast.success("已同步父群成员到话题");
                } catch (e: any) {
                  Toast.error(e?.msg || e?.message || "同步失败");
                } finally {
                  this.setState({ loading: false });
                }
              }}
            >
              同步成员
            </Button>
          ) : null}
        </div>
        <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
          {list.map((s) => {
            const archived = !!s.archived;
            const editing = renaming === s.sub_group_no;
            return (
              <li
                key={s.sub_group_no}
                style={{
                  padding: "12px 0",
                  borderBottom:
                    "1px solid var(--wk-border-subtle, rgba(0,0,0,0.06))",
                  opacity: archived ? 0.65 : 1,
                }}
              >
                {editing ? (
                  <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                    <Input
                      value={renameValue}
                      maxLength={20}
                      autoFocus
                      onChange={(v) => this.setState({ renameValue: v })}
                      onEnterPress={() => this.onRename(s)}
                    />
                    <Button
                      size="small"
                      theme="solid"
                      onClick={() => this.onRename(s)}
                    >
                      保存
                    </Button>
                    <Button
                      size="small"
                      type="tertiary"
                      onClick={() =>
                        this.setState({ renaming: null, renameValue: "" })
                      }
                    >
                      取消
                    </Button>
                  </div>
                ) : (
                  <>
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: 8,
                        cursor: "pointer",
                      }}
                      onClick={() => {
                        if (!archived) {
                          WKApp.endpoints.showConversation(
                            new Channel(s.sub_group_no, ChannelTypeGroup)
                          );
                        }
                      }}
                    >
                      <div style={{ fontWeight: 600, flex: 1 }}>
                        #{s.title}
                        {archived ? (
                          <span
                            style={{
                              marginLeft: 8,
                              fontSize: 12,
                              fontWeight: 500,
                              color: "var(--wk-color-font-tip, #8A9199)",
                            }}
                          >
                            已归档
                          </span>
                        ) : null}
                      </div>
                    </div>
                    <div
                      style={{
                        display: "flex",
                        gap: 6,
                        marginTop: 8,
                        flexWrap: "wrap",
                      }}
                    >
                      <Button
                        size="small"
                        type="tertiary"
                        onClick={() =>
                          this.setState({
                            renaming: s.sub_group_no,
                            renameValue: s.title,
                          })
                        }
                      >
                        改名
                      </Button>
                      <Button
                        size="small"
                        type="tertiary"
                        onClick={() => this.onArchive(s, !archived)}
                      >
                        {archived ? "恢复" : "归档"}
                      </Button>
                      <Button
                        size="small"
                        type="danger"
                        onClick={() => this.onDelete(s)}
                      >
                        删除
                      </Button>
                    </div>
                  </>
                )}
              </li>
            );
          })}
          {!list.length ? (
            <li
              style={{
                color: "var(--wk-color-font-tip, #8A9199)",
                padding: "8px 0",
              }}
            >
              {showArchived ? "暂无话题" : "暂无活跃话题"}
            </li>
          ) : null}
        </ul>
      </div>
    );
  }
}
