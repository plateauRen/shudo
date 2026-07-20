import { MessageContent, MessageContentType } from "wukongimjssdk";
import { htmlToPlainText } from "@tsdaodao/rich-editor";

/**
 * Text message with format=html (WYSIWYG composer).
 * Extends wire payload beyond stock MessageText which only encodes `content`.
 */
export class HtmlMessageText extends MessageContent {
  text: string = "";
  format: string = "html";

  constructor(html?: string) {
    super();
    if (html) this.text = html;
  }

  decodeJSON(content: any) {
    this.text = content?.content || "";
    this.format = content?.format || "";
  }

  encodeJSON() {
    return {
      content: this.text || "",
      format: this.format || "html",
    };
  }

  get contentType() {
    return MessageContentType.text;
  }

  get conversationDigest() {
    if (this.format === "html") {
      return htmlToPlainText(this.text || "") || "[富文本]";
    }
    return (this.text || "").replace(/\n/g, " ");
  }
}

/** Patch decode helper: read format from payload when using stock MessageText. */
export function getMessageTextFormat(content: any): string {
  if (!content) return "";
  if (typeof content.format === "string") return content.format;
  // Some SDK builds store only via encodeJSON fields on custom content
  try {
    const enc =
      typeof content.encodeJSON === "function" ? content.encodeJSON() : null;
    if (enc && typeof enc.format === "string") return enc.format;
  } catch {
    /* ignore */
  }
  return "";
}

export function getMessageTextHtml(content: any): string {
  if (!content) return "";
  if (typeof content.text === "string") return content.text;
  if (typeof content.content === "string") return content.content;
  return "";
}
