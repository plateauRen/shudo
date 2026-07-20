import React from "react";
import { MessageContent } from "wukongimjssdk";
import MessageBase from "../Base";
import MessageTrail from "../Base/tail";
import { MessageCell } from "../MessageCell";
import { MessageContentTypeConst } from "../../Service/Const";
import { HermesActionStore } from "../../Service/HermesActionStore";
import { displayLabelForAction } from "../../Service/HermesPayload";
import "./index.css";

export type HermesButton = {
  id: string;
  label: string;
  style?: "primary" | "secondary" | "danger" | string;
};

export class HermesCardContent extends MessageContent {
  v = 1;
  kind = "hermes.approval";
  approvalId?: string;
  confirmId?: string;
  clarifyId?: string;
  title = "";
  body = "";
  descText = "";
  contentText = "";
  buttons: HermesButton[] = [];
  meta?: any;
  acted = false;
  actedAction?: string;
  actedLabel?: string;

  get cardId(): string | undefined {
    return this.approvalId || this.confirmId || this.clarifyId;
  }

  applyLocalActedState() {
    const info = HermesActionStore.infoForCardId(this.cardId);
    if (!info) return;
    this.acted = true;
    this.actedAction = info.action;
    this.actedLabel = info.label;
  }

  markActed(action: string, label: string) {
    this.acted = true;
    this.actedAction = action;
    this.actedLabel = label;
    HermesActionStore.markActed(this.cardId || "", action, label);
  }

  decodeJSON(content: any) {
    this.v = content?.v || 1;
    this.kind = content?.kind || "hermes.approval";
    this.approvalId = content?.approval_id;
    this.confirmId = content?.confirm_id;
    this.clarifyId = content?.clarify_id;
    this.title = content?.title || "";
    this.body = content?.body || "";
    this.descText = content?.description || "";
    this.contentText = content?.content || this.title || "";
    this.buttons = Array.isArray(content?.buttons) ? content.buttons : [];
    this.meta = content?.meta;
    this.applyLocalActedState();
  }

  encodeJSON() {
    return {
      v: this.v || 1,
      kind: this.kind || "hermes.approval",
      approval_id: this.approvalId,
      confirm_id: this.confirmId,
      clarify_id: this.clarifyId,
      title: this.title || "",
      body: this.body || undefined,
      description: this.descText || undefined,
      content: this.contentText || "",
      buttons: this.buttons || [],
      meta: this.meta,
    };
  }

  get contentType() {
    return MessageContentTypeConst.hermesCard;
  }

  get conversationDigest() {
    if (this.acted && this.actedLabel) return `[已选] ${this.actedLabel}`;
    return this.title ? `[Hermes] ${this.title}` : "[Hermes]";
  }
}

export class HermesActionContent extends MessageContent {
  v = 1;
  kind = "hermes.action";
  action = "";
  label = "";
  approvalId?: string;
  confirmId?: string;
  clarifyId?: string;
  sourceMessageId?: string;
  contentText = "";

  static create(
    action: string,
    label: string,
    opts: {
      approvalId?: string;
      confirmId?: string;
      clarifyId?: string;
      sourceMessageId?: string;
    } = {}
  ) {
    const c = new HermesActionContent();
    c.action = action;
    c.label = displayLabelForAction(action, label);
    c.approvalId = opts.approvalId;
    c.confirmId = opts.confirmId;
    c.clarifyId = opts.clarifyId;
    c.sourceMessageId = opts.sourceMessageId;
    const cardId = c.approvalId || c.confirmId || c.clarifyId || "";
    c.contentText = `::hermes_action::${c.action}:${cardId}`;
    return c;
  }

  decodeJSON(content: any) {
    this.v = content?.v || 1;
    this.kind = content?.kind || "hermes.action";
    this.action = content?.action || "";
    this.label =
      content?.label ||
      displayLabelForAction(
        this.action,
        typeof content?.content === "string" &&
          !String(content.content).startsWith("::hermes_action::")
          ? content.content
          : undefined
      );
    this.approvalId = content?.approval_id;
    this.confirmId = content?.confirm_id;
    this.clarifyId = content?.clarify_id;
    this.sourceMessageId = content?.source_message_id;
    this.contentText = content?.content || this.label;
  }

  encodeJSON() {
    return {
      v: this.v || 1,
      kind: "hermes.action",
      action: this.action || "",
      label: this.label || undefined,
      approval_id: this.approvalId,
      confirm_id: this.confirmId,
      clarify_id: this.clarifyId,
      source_message_id: this.sourceMessageId,
      content: this.label || this.contentText || "",
    };
  }

  get contentType() {
    return MessageContentTypeConst.hermesAction;
  }

  get conversationDigest() {
    return this.label || this.action || "[Hermes]";
  }
}

interface HermesCardCellState {
  acted: boolean;
  actedLabel: string;
  actedAction: string;
}

export class HermesCardCell extends MessageCell<any, HermesCardCellState> {
  constructor(props: any) {
    super(props);
    const content = props.message.content as HermesCardContent;
    content.applyLocalActedState();
    this.state = {
      acted: !!content.acted,
      actedLabel: content.actedLabel || "",
      actedAction: content.actedAction || "",
    };
  }

  onClickButton = (btn: HermesButton) => {
    const { message, context } = this.props;
    const content = message.content as HermesCardContent;
    content.applyLocalActedState();
    if (content.acted || this.state.acted) return;

    const action = btn.id || "";
    if (!action) return;
    const label = displayLabelForAction(action, btn.label);
    content.markActed(action, label);
    this.setState({ acted: true, actedLabel: label, actedAction: action });

    const actionContent = HermesActionContent.create(action, label, {
      approvalId: content.approvalId,
      confirmId: content.confirmId,
      clarifyId: content.clarifyId,
      sourceMessageId: message.clientMsgNo,
    });
    // Silent callback: still send over IM; list filters HERMES_ACTION
    context.sendMessage(actionContent);
  };

  render() {
    const { message, context } = this.props;
    const content = message.content as HermesCardContent;
    const acted = this.state.acted || content.acted;
    const actedLabel = this.state.actedLabel || content.actedLabel || "";
    const actedAction = this.state.actedAction || content.actedAction || "";
    const buttons = content.buttons || [];
    const deny = (actedAction || "").toLowerCase() === "deny";

    return (
      <MessageBase hiddeBubble={true} message={message} context={context}>
        <div className="wk-hermes-card">
          <div className="wk-hermes-card-title">
            {content.title || "Hermes"}
          </div>
          {content.body ? (
            <div className="wk-hermes-card-body">{content.body}</div>
          ) : null}
          {content.descText ? (
            <div className="wk-hermes-card-desc">{content.descText}</div>
          ) : null}

          {acted ? (
            <div className={`wk-hermes-card-status${deny ? " deny" : ""}`}>
              已选择：{actedLabel || "OK"}
            </div>
          ) : (
            <div className="wk-hermes-card-buttons">
              {buttons.map((btn, i) => {
                const style = btn.style || "secondary";
                const full = i === buttons.length - 1 && buttons.length % 2 === 1;
                return (
                  <button
                    key={`${btn.id}-${i}`}
                    type="button"
                    className={`wk-hermes-card-btn ${style}${
                      full ? " full" : ""
                    }`}
                    onClick={() => this.onClickButton(btn)}
                  >
                    {btn.label || btn.id}
                  </button>
                );
              })}
            </div>
          )}

          <div className="wk-hermes-card-foot">
            <MessageTrail message={message} timeStyle={{ color: "#999" }} />
          </div>
        </div>
      </MessageBase>
    );
  }
}

/** Hidden / unused visually; kept for type registration. */
export class HermesActionCell extends MessageCell {
  render() {
    return <div style={{ display: "none" }} />;
  }
}
