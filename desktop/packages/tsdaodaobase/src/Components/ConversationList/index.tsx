import WKSDK from "wukongimjssdk";
import { ChannelInfoListener } from "wukongimjssdk";
import { Channel, ChannelInfo, ChannelTypePerson, ChannelTypeGroup } from "wukongimjssdk";
import React, { Component } from "react";
import { ConversationWrap, MessageWrap } from "../../Service/Model";
import { getTimeStringAutoShort2 } from '../../Utils/time'
import classNames from "classnames";

import "./index.css"
import { Badge, Toast } from "@douyinfe/semi-ui";
import WKApp from "../../App";
import { EndpointID } from "../../Service/Const";
import ContextMenus, { ContextMenusContext } from "../ContextMenus";
import { ChannelSettingManager } from "../../Service/ChannelSetting";
import { TypingListener, TypingManager } from "../../Service/TypingManager";
import { BeatLoader } from "react-spinners";
import { RevokeCell } from "../../Messages/Revoke";
import { FlameMessageCell } from "../../Messages/Flame";
import WKAvatar from "../WKAvatar";
import { shudoOrgManager } from "../../Service/ShudoOrgManager";
import SubChannelsPanel from "../SubChannelsPanel";

export interface ConversationListProps {
    conversations: ConversationWrap[]
    select?: Channel
    /** 当前选中的分组 id；空为全部 */
    currentFolderId?: string
    onClick?: (conversation: ConversationWrap) => void
    onClearMessages?: (channel: Channel) => void
}

export interface ConversationListState {
    selectConversationWrap?: ConversationWrap

}

export default class ConversationList extends Component<ConversationListProps, ConversationListState>{
    channelListener!: ChannelInfoListener
    contextMenusContext!: ContextMenusContext
    typingListener!: TypingListener
    constructor(props: ConversationListProps) {
        super(props)

        this.state = {
        }
    }

    componentDidMount() {
        this.channelListener = (channelInfo: ChannelInfo) => {
            this.setState({})
        }
        WKSDK.shared().channelManager.addListener(this.channelListener)

        this.typingListener = (channel: Channel, add: boolean) => {
            this.setState({})
        }
        TypingManager.shared.addTypingListener(this.typingListener)

    }

    componentWillUnmount() {
        WKSDK.shared().channelManager.removeListener(this.channelListener)
        TypingManager.shared.removeTypingListener(this.typingListener)
    }

    _handleScroll() {
        this.contextMenusContext.hide()
    }
    _handleContextMenu(conversationWrap: ConversationWrap, event: React.MouseEvent) {
        // 先写入选中项再弹出菜单，否则菜单项（如「创建话题」）会读到旧状态
        this.setState({
            selectConversationWrap: conversationWrap
        }, () => {
            this.contextMenusContext.show(event)
        })
    }

    _getTypingUI(conversationWrap: ConversationWrap) {
        const typing = TypingManager.shared.getTyping(conversationWrap.channel)
        return <div className="wk-typing"><BeatLoader size={4} margin={3} color="var(--wk-color-theme)" />&nbsp;&nbsp;{conversationWrap.channel.channelType !== ChannelTypePerson ? typing?.fromName : ""}正在输入</div>
    }

    lastContent(conversationWrap: ConversationWrap) {
        if (!conversationWrap.lastMessage) {
            return
        }
        const draft = conversationWrap.remoteExtra.draft
        if(draft && draft!=="") {
            return draft
        }
        const lastMessage = new MessageWrap(conversationWrap.lastMessage)
        if (lastMessage.isDeleted) {
            return ""
        }
        if (lastMessage.revoke) {
            return RevokeCell.tip(lastMessage)
        }
        if(lastMessage.flame) {
            return FlameMessageCell.tip(lastMessage)
        }
        if (lastMessage.channel.channelType === ChannelTypePerson) {
            return lastMessage.content?.conversationDigest
        } else {

            let from = ""
            if (lastMessage.fromUID && lastMessage.fromUID !== "") {
                const fromChannel = new Channel(lastMessage.fromUID, ChannelTypePerson)
                const fromChannelInfo = WKSDK.shared().channelManager.getChannelInfo(fromChannel)
                if (fromChannelInfo) {
                    from = `${fromChannelInfo.title}: `
                } else {
                    WKSDK.shared().channelManager.fetchChannelInfo(fromChannel)
                }
            }


            return `${from}${lastMessage.content?.conversationDigest || ""}`
        }
    }

    getOnlineTip(channelInfo: ChannelInfo) {
        if (channelInfo.online) {
            return undefined
        }
        const nowTime = new Date().getTime() / 1000
        const btwTime = nowTime - channelInfo.lastOffline
        if (btwTime < 60) {
            return "刚刚"
        }
        return `${(btwTime / 60).toFixed(0)}分钟`
    }

    // 是否需要显示在线状态
    needShowOnlineStatus(channelInfo?: ChannelInfo) {
        if (!channelInfo) {
            return false
        }
        if (channelInfo.online) {
            return true
        }
        const nowTime = new Date().getTime() / 1000
        const btwTime = nowTime - channelInfo.lastOffline
        if (btwTime > 0 && btwTime < 60 * 60) { // 小于1小时才显示
            return true
        }
        return false
    }

    conversationItem(conversationWrap: ConversationWrap) {
        

        let channelInfo = conversationWrap.channelInfo
        if (!channelInfo) {
            WKSDK.shared().channelManager.fetchChannelInfo(conversationWrap.channel)
        }

        const avatarKey = WKApp.shared.getChannelAvatarTag(conversationWrap.channel);

        const { select, onClick } = this.props
        const typing = TypingManager.shared.getTyping(conversationWrap.channel)
        const selected = select && select.isEqual(conversationWrap.channel)
        return <div key={conversationWrap.channel.getChannelKey()} onClick={() => {
            if (onClick) {
                onClick(conversationWrap)
            }
        }} className={classNames("wk-conversationlist-item", channelInfo?.top ? "wk-conversationlist-item-top" : undefined)} onContextMenu={(e) => {
            this._handleContextMenu(conversationWrap, e)
        }}>
            <div className={classNames("wk-conversationlist-item-content", selected ? "wk-conversationlist-item-selected" : undefined)}>
                <div className="wk-conversationlist-item-left">
                    <div className="wk-conversationlist-item-avatar-box">
                        <WKAvatar  channel={conversationWrap.channel} key={avatarKey}></WKAvatar>
                        {
                            channelInfo && this.needShowOnlineStatus(channelInfo) ? <OnlineStatusBadge tip={this.getOnlineTip(channelInfo)}></OnlineStatusBadge> : undefined
                        }

                    </div>
                </div>
                <div className="wk-conversationlist-item-right">
                    <div className="wk-conversationlist-item-right-first-line">
                        <div className="wk-conversationlist-item-name">
                            <h3>
                                {(() => {
                                    const sub = shudoOrgManager.getSubChannelMeta(
                                        conversationWrap.channel.channelID
                                    );
                                    if (sub) {
                                        return `#${sub.title}`;
                                    }
                                    return channelInfo?.orgData.displayName;
                                })()}
                            </h3>
                            {
                                channelInfo?.orgData.identityIcon ? <img style={{ "marginLeft": "4px", "width": channelInfo?.orgData?.identitySize.width, "height": channelInfo?.orgData?.identitySize.height }} src={channelInfo?.orgData.identityIcon}></img> : undefined
                            }
                            <div style={{ "width": "14px", height: "14px", "display": "flex", "alignItems": "center", "marginLeft": "5px" }}>
                                {
                                    channelInfo?.mute && <svg className="icon" viewBox="0 0 1131 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="2755" width="14" height="14"><path d="M914.688 892.736L64 236.224l38.784-50.88L271.36 315.648a300.288 300.288 0 0 1 246.976-157.952v-33.28c0-16.64 13.504-30.08 30.08-30.08h2.304c16.576 0 30.08 13.44 30.08 30.08v32.96a299.776 299.776 0 0 1 284.928 299.136v294.272l45.504 58.624 48.768 37.696-45.312 45.632zM234.624 480.384l506.88 391.232H140.416l94.272-121.536-0.064-269.696z" fill="#bfbfbf" p-id="2756"></path></svg>
                                }

                            </div>
                            <div className="wk-conversationlist-item-time">
                                <span>{getTimeStringAutoShort2(conversationWrap.timestamp * 1000, true)}</span>
                            </div>
                        </div>

                    </div>
                    <div className="wk-conversationlist-item-right-second-line">
                        <div className="wk-conversationlist-item-lastmsg">
                            {
                                !typing?<label className="wk-reminder" style={{ display: conversationWrap.remoteExtra.draft  ? undefined : 'none' }}>[草稿]</label>:undefined
                            }
                            {
                                conversationWrap.simpleReminders && !typing &&  conversationWrap.simpleReminders.length>0 ?(
                                    conversationWrap.simpleReminders.filter((r)=>r.done === false).map((r)=>{
                                        return   <label key={r.reminderID} className="wk-reminder">{r.text}</label>
                                    })
                                ):undefined
                            }
                            {
                                typing ? this._getTypingUI(conversationWrap) : this.lastContent(conversationWrap)
                            }

                        </div>
                        <div className="wk-conversationlist-item-reddot">
                            {
                                conversationWrap.unread > 0 ? <Badge style={channelInfo?.mute ? { "border": "none", "backgroundColor": "rgb(200,200,200)" } : { border: "none" }} count={conversationWrap.unread} type='danger'></Badge> : undefined
                            }
                        </div>
                    </div>
                </div>
            </div>
        </div>
    }

    onTop(channelInfo: ChannelInfo) {
        ChannelSettingManager.shared.top(!channelInfo.top, channelInfo.channel)
    }

    onMute(channelInfo: ChannelInfo) {
        ChannelSettingManager.shared.mute(!channelInfo.mute, channelInfo.channel)
    }

    onCloseChat(channel: Channel) { // 关闭聊天
        WKApp.conversationProvider.deleteConversation(channel)
    }

    async onClearMessages(channel: Channel) {
        if(this.props.onClearMessages) {
            this.props.onClearMessages(channel)
        }
    }

    render() {
        const { conversations, select, currentFolderId } = this.props
        const { selectConversationWrap } = this.state
        const ch = selectConversationWrap?.channel
        const isGroup = ch?.channelType === ChannelTypeGroup
        const isSub = ch ? !!shudoOrgManager.getSubChannelMeta(ch.channelID) : false
        const containing = ch
            ? shudoOrgManager.foldersContaining(ch.channelID, ch.channelType)
            : []
        const currentFolder = currentFolderId
            ? shudoOrgManager.folders.find((f) => f.folder_id === currentFolderId)
            : undefined

        const menus: { title: string; onClick: () => void }[] = [
            {
                title: selectConversationWrap?.channelInfo?.top ? "取消置顶" : "置顶",
                onClick: () => {
                    this.onTop(selectConversationWrap?.channelInfo!)
                },
            },
            {
                title: selectConversationWrap?.channelInfo?.mute
                    ? "关闭免打扰"
                    : "开启免打扰",
                onClick: () => {
                    this.onMute(selectConversationWrap?.channelInfo!)
                },
            },
        ]

        // 话题相关：父频道可创建/管理；话题内可回所属群/私聊
        if (ch && shudoOrgManager.canHostTopics(ch)) {
            menus.push({
                title: "创建话题",
                onClick: async () => {
                    const title = window.prompt("话题名称")
                    if (!title || !title.trim()) return
                    try {
                        const created = isGroup
                            ? await shudoOrgManager.createSubChannel(
                                  ch.channelID,
                                  title.trim()
                              )
                            : await shudoOrgManager.createTopicFromPerson(
                                  shudoOrgManager.resolvePersonPeerUid(ch) ||
                                      ch.channelID,
                                  title.trim()
                              )
                        Toast.success("已创建话题")
                        if (created?.sub_group_no) {
                            WKApp.endpoints.showConversation(
                                new Channel(created.sub_group_no, ChannelTypeGroup)
                            )
                        }
                    } catch (e: any) {
                        Toast.error(e?.msg || e?.message || "创建失败")
                    }
                },
            })
            menus.push({
                title: "管理话题",
                onClick: () => {
                    SubChannelsPanel.open(ch)
                },
            })
        } else if (ch && isSub) {
            const meta = shudoOrgManager.getSubChannelMeta(ch.channelID)
            const parentNo = meta?.parent_group_no || ""
            if (parentNo) {
                menus.push({
                    title: parentNo.startsWith("dm:") ? "打开私聊" : "打开所属群",
                    onClick: () => {
                        if (parentNo.startsWith("dm:")) {
                            const peer = parentNo.slice(3)
                            if (peer) {
                                WKApp.endpoints.showConversation(
                                    new Channel(peer, ChannelTypePerson)
                                )
                            }
                        } else {
                            WKApp.endpoints.showConversation(
                                new Channel(parentNo, ChannelTypeGroup)
                            )
                        }
                    },
                })
            }
        }

        for (const f of shudoOrgManager.folders || []) {
            if (!ch) break
            if (shudoOrgManager.folderContains(f, ch.channelID, ch.channelType)) {
                continue
            }
            menus.push({
                title: `移到分组：${f.name}`,
                onClick: async () => {
                    try {
                        await shudoOrgManager.addChannelToFolder(
                            f.folder_id,
                            ch.channelID,
                            ch.channelType
                        )
                        Toast.success(`已加入「${f.name}」`)
                    } catch (e: any) {
                        Toast.error(e?.msg || e?.message || "操作失败")
                    }
                },
            })
        }

        if (currentFolder && ch && shudoOrgManager.folderContains(currentFolder, ch.channelID, ch.channelType)) {
            menus.push({
                title: `从「${currentFolder.name}」移除`,
                onClick: async () => {
                    try {
                        await shudoOrgManager.removeChannelFromFolder(
                            currentFolder.folder_id,
                            ch.channelID,
                            ch.channelType
                        )
                        Toast.success("已从分组移除")
                    } catch (e: any) {
                        Toast.error(e?.msg || e?.message || "操作失败")
                    }
                },
            })
        } else {
            for (const f of containing) {
                if (!ch) break
                menus.push({
                    title: `从「${f.name}」移除`,
                    onClick: async () => {
                        try {
                            await shudoOrgManager.removeChannelFromFolder(
                                f.folder_id,
                                ch.channelID,
                                ch.channelType
                            )
                            Toast.success(`已从「${f.name}」移除`)
                        } catch (e: any) {
                            Toast.error(e?.msg || e?.message || "操作失败")
                        }
                    },
                })
            }
        }

        menus.push(
            {
                title: "关闭聊天窗口",
                onClick: () => {
                    this.onCloseChat(selectConversationWrap?.channel!)
                },
            },
            {
                title: "清空聊天记录",
                onClick: () => {
                    this.onClearMessages(selectConversationWrap?.channel!)
                },
            },
            {
                title: "关闭窗口并清空聊天记录",
                onClick: () => {
                    this.onCloseChat(selectConversationWrap?.channel!)
                    this.onClearMessages(selectConversationWrap?.channel!)
                },
            }
        )

        return <div id="wk-conversationlist" className="wk-conversationlist" onScroll={this._handleScroll.bind(this)}>
            {
                conversations && conversations.map((conversationWrap) => {
                    return this.conversationItem(conversationWrap)
                })
            }

            <ContextMenus
              key={selectConversationWrap?.channel?.getChannelKey?.() || "ctx"}
              onContext={(ctx) => {
                this.contextMenusContext = ctx
              }}
              menus={menus}
            />
        </div>
    }
}


interface OnlineStatusBadgeProps {
    tip?: string
}
export class OnlineStatusBadge extends Component<OnlineStatusBadgeProps> {

    render(): React.ReactNode {
        const { tip } = this.props
        return <div className={classNames("wk-onlinestatusbadge", !tip ? "wk-onlinestatusbadge-empty" : undefined)}>
            <div className="wk-onlinestatusbadge-content">
                <div className="wk-onlinestatusbadge-content-tip">{tip}</div>
            </div>
        </div>
    }
}