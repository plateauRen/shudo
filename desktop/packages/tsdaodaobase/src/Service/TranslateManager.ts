import WKApp from "../App";
import StorageService from "./StorageService";
import { MessageWrap } from "./Model";
import { Message, MessageContentType } from "wukongimjssdk";
import {
  getMessageTextFormat,
  getMessageTextHtml,
} from "../Messages/HtmlText";
import { htmlToPlainText } from "@tsdaodao/rich-editor";

const AUTO_KEY = "lim_auto_translate_on";
const TARGET_KEY = "lim_translate_target_lang";
const SERVICE_URL_KEY = "lim_translate_service_url";

type Listener = (clientMsgNo: string) => void;
type AttachedState = {
  text?: string;
  hidden?: boolean;
  loading?: boolean;
};

/**
 * Server-backed message translation (auto + manual). Aligns with iOS WKTranslateManager.
 */
class TranslateManager {
  private memoryCache = new Map<string, string>();
  private inflight = new Set<string>();
  private attached = new Map<string, AttachedState>();
  private listeners = new Set<Listener>();

  subscribe(fn: Listener): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  private emit(clientMsgNo: string) {
    this.listeners.forEach((fn) => fn(clientMsgNo));
  }

  private syncWrap(message: MessageWrap) {
    const s = this.attached.get(message.clientMsgNo);
    if (!s) return;
    message.wkTranslation = s.text;
    message.wkTranslationHidden = s.hidden;
    message.wkTranslationLoading = s.loading;
  }

  private saveAttached(clientMsgNo: string, patch: AttachedState) {
    const prev = this.attached.get(clientMsgNo) || {};
    this.attached.set(clientMsgNo, { ...prev, ...patch });
  }

  wrapFromMessage(message: Message | MessageWrap): MessageWrap {
    if ((message as MessageWrap).message && (message as MessageWrap).clientMsgNo !== undefined && (message as any).order !== undefined) {
      const wrap = message as MessageWrap;
      this.syncWrap(wrap);
      return wrap;
    }
    const wrap = new MessageWrap(message as Message);
    this.syncWrap(wrap);
    return wrap;
  }

  get autoTranslateEnabled(): boolean {
    return StorageService.shared.getItem(AUTO_KEY) === "1";
  }

  set autoTranslateEnabled(v: boolean) {
    StorageService.shared.setItem(AUTO_KEY, v ? "1" : "");
  }

  get targetLanguage(): string {
    return StorageService.shared.getItem(TARGET_KEY) || "zh-CN";
  }

  set targetLanguage(code: string) {
    StorageService.shared.setItem(TARGET_KEY, code || "zh-CN");
  }

  get serviceBaseUrl(): string {
    return StorageService.shared.getItem(SERVICE_URL_KEY) || "";
  }

  set serviceBaseUrl(url: string) {
    if (url) StorageService.shared.setItem(SERVICE_URL_KEY, url);
    else StorageService.shared.removeItem(SERVICE_URL_KEY);
  }

  get supportedLanguages(): Array<{ code: string; name: string }> {
    return [
      { code: "zh-CN", name: "简体中文" },
      { code: "zh-TW", name: "繁體中文" },
      { code: "en", name: "English" },
      { code: "ja", name: "日本語" },
      { code: "ko", name: "한국어" },
      { code: "fr", name: "Français" },
      { code: "de", name: "Deutsch" },
      { code: "es", name: "Español" },
      { code: "ru", name: "Русский" },
    ];
  }

  displayNameForLanguage(code: string): string {
    return this.supportedLanguages.find((l) => l.code === code)?.name || code;
  }

  plainTextFromMessage(message: Message | MessageWrap): string {
    const wrap = this.wrapFromMessage(message as any);
    const content: any = wrap?.remoteExtra?.contentEdit || wrap?.content;
    if (!content) return "";
    if (wrap.contentType !== MessageContentType.text) return "";

    const format = getMessageTextFormat(content);
    let text = "";
    if (format === "html") {
      text = htmlToPlainText(getMessageTextHtml(content) || "");
    } else if (typeof content.text === "string") {
      text = content.text;
    } else if (typeof content.content === "string") {
      text = content.content;
    } else if (typeof content.encodeJSON === "function") {
      const enc = content.encodeJSON() || {};
      text = enc.content || "";
    }
    return (text || "").trim();
  }

  private cacheKey(text: string, target: string): string {
    return `${target}|${text}`;
  }

  cachedTranslationForText(text: string, target: string): string | undefined {
    if (!text) return undefined;
    return this.memoryCache.get(this.cacheKey(text, target));
  }

  private storeTranslation(translated: string, text: string, target: string) {
    if (!translated || !text) return;
    this.memoryCache.set(this.cacheKey(text, target), translated);
  }

  translationAttachedToMessage(
    message: Message | MessageWrap
  ): string | undefined {
    const wrap = this.wrapFromMessage(message as any);
    const attached = this.attached.get(wrap.clientMsgNo)?.text;
    if (attached) return attached;
    if (wrap.wkTranslation) return wrap.wkTranslation;
    const text = this.plainTextFromMessage(wrap);
    return this.cachedTranslationForText(text, this.targetLanguage);
  }

  isTranslationHiddenForMessage(message: Message | MessageWrap): boolean {
    const wrap = this.wrapFromMessage(message as any);
    return Boolean(
      this.attached.get(wrap.clientMsgNo)?.hidden ?? wrap.wkTranslationHidden
    );
  }

  isTranslationLoading(message: Message | MessageWrap): boolean {
    const wrap = this.wrapFromMessage(message as any);
    return Boolean(
      this.attached.get(wrap.clientMsgNo)?.loading ?? wrap.wkTranslationLoading
    );
  }

  setTranslationHidden(hidden: boolean, message: Message | MessageWrap) {
    const wrap = this.wrapFromMessage(message as any);
    wrap.wkTranslationHidden = hidden;
    this.saveAttached(wrap.clientMsgNo, { hidden });
    this.emit(wrap.clientMsgNo);
  }

  shouldAutoTranslateMessage(message: MessageWrap): boolean {
    if (!this.autoTranslateEnabled) return false;
    if (!message || message.send) return false;
    if (message.contentType !== MessageContentType.text) return false;
    if (this.isTranslationHiddenForMessage(message)) return false;
    return this.plainTextFromMessage(message).length > 0;
  }

  private translateURL(): string {
    const override = this.serviceBaseUrl?.trim();
    if (override) {
      const base = override.endsWith("/") ? override : `${override}/`;
      return `${base}common/translate`;
    }
    try {
      const api = WKApp.apiClient.config.apiURL || "";
      const u = new URL(api, window.location.origin);
      return `${u.protocol}//${u.hostname}:8091/v1/common/translate`;
    } catch {
      return "http://127.0.0.1:8091/v1/common/translate";
    }
  }

  async translateMessage(
    message: Message | MessageWrap,
    force = false
  ): Promise<string> {
    const wrap = this.wrapFromMessage(message as any);
    const text = this.plainTextFromMessage(wrap);
    if (!text) throw new Error("empty text");

    const target = this.targetLanguage;
    const cached = this.cachedTranslationForText(text, target);
    if (cached && !force) {
      wrap.wkTranslation = cached;
      wrap.wkTranslationHidden = false;
      this.saveAttached(wrap.clientMsgNo, {
        text: cached,
        hidden: false,
        loading: false,
      });
      this.emit(wrap.clientMsgNo);
      return cached;
    }

    const inflightKey = `${wrap.clientMsgNo}|${target}`;
    if (this.inflight.has(inflightKey)) {
      return this.translationAttachedToMessage(wrap) || "";
    }
    this.inflight.add(inflightKey);
    wrap.wkTranslationLoading = true;
    this.saveAttached(wrap.clientMsgNo, { loading: true });
    this.emit(wrap.clientMsgNo);

    try {
      const token = WKApp.loginInfo.token || "";
      const resp = await fetch(this.translateURL(), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { token, Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          text,
          target: target || "zh-CN",
          source: "auto",
        }),
      });
      const json = await resp.json().catch(() => ({}));
      if (!resp.ok) {
        throw new Error(json?.detail || json?.msg || "翻译失败");
      }
      const translated = String(json?.translated || json?.text || "");
      if (!translated) throw new Error("空译文");
      this.storeTranslation(translated, text, target);
      wrap.wkTranslation = translated;
      wrap.wkTranslationHidden = false;
      this.saveAttached(wrap.clientMsgNo, {
        text: translated,
        hidden: false,
        loading: false,
      });
      this.emit(wrap.clientMsgNo);
      return translated;
    } finally {
      this.inflight.delete(inflightKey);
      wrap.wkTranslationLoading = false;
      this.saveAttached(wrap.clientMsgNo, { loading: false });
      this.emit(wrap.clientMsgNo);
    }
  }
}

export const translateManager = new TranslateManager();
