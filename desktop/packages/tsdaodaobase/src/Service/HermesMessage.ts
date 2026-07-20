import { Message, MessageContentType, MessageText, WKSDK } from "wukongimjssdk";
import { MessageContentTypeConst } from "./Const";
import { Convert } from "./Convert";
import { unwrapHermesPayload } from "./HermesPayload";

/**
 * If a realtime/synced message is a Hermes text envelope, replace its content
 * with HermesCardContent / HermesActionContent.
 */
export function rehydrateHermesMessage(message: Message): void {
  if (!message?.content) return;

  // Already typed
  if (
    message.contentType === MessageContentTypeConst.hermesCard ||
    message.contentType === MessageContentTypeConst.hermesAction
  ) {
    return;
  }

  const payload: any = { type: message.contentType };
  const content: any = message.content;

  if (typeof content.encodeJSON === "function") {
    Object.assign(payload, content.encodeJSON() || {});
  }

  if (message.contentType === MessageContentType.text || payload.type === 1) {
    const text =
      (content as MessageText)?.text ??
      content?.content ??
      payload.content ??
      "";
    payload.type = 1;
    payload.content = typeof text === "string" ? text : "";
  }

  if (!unwrapHermesPayload(payload)) return;

  const next = WKSDK.shared().getMessageContent(Number(payload.type));
  next.decode(Convert.stringToUint8Array(JSON.stringify(payload)));
  (message as any).content = next;
}

export function shouldHideHermesMessage(message: Message): boolean {
  if (message.contentType === MessageContentTypeConst.hermesAction) {
    return true;
  }
  if (message.contentType === MessageContentType.text) {
    const text = (message.content as MessageText)?.text || "";
    if (typeof text === "string" && text.includes("::hermes_action::")) {
      return true;
    }
  }
  return false;
}
