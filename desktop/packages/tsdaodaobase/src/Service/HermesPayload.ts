/**
 * Unwrap TangSeng robot text envelopes into Hermes payloads.
 *   ::hermes_card::{json}  → 21000
 *   ::hermes_action::a:id → 21001
 *   ::hermes_table::{json} → 21002
 */

export const HERMES_CARD_MARKER = "::hermes_card::";
export const HERMES_ACTION_MARKER = "::hermes_action::";
export const HERMES_TABLE_MARKER = "::hermes_table::";
export const HERMES_CARD_TYPE = 21000;
export const HERMES_ACTION_TYPE = 21001;
export const HERMES_TABLE_TYPE = 21002;

function displayLabelForAction(action: string, preferred?: string): string {
  if (preferred && preferred.trim()) return preferred.trim();
  const a = (action || "").toLowerCase();
  if (a === "once") return "✅ Allow Once";
  if (a === "session") return "✅ Session";
  if (a === "always") return "✅ Always";
  if (a === "deny") return "❌ Deny";
  if (a === "other") return "✏️ Other";
  if (a.startsWith("choice_")) return `选项 ${a.slice("choice_".length)}`;
  return action || "[Hermes]";
}

function unwrapJsonMarker(
  payload: any,
  text: string,
  marker: string,
  forceType: number,
  fallback: string
): boolean {
  const idx = text.indexOf(marker);
  if (idx < 0) return false;
  const jsonStr = text.slice(idx + marker.length).trim();
  try {
    const parsed = JSON.parse(jsonStr);
    if (!parsed || typeof parsed !== "object") return false;
    Object.keys(payload).forEach((k) => delete payload[k]);
    Object.assign(payload, parsed);
    payload.type = forceType;
    if (!payload.content) {
      const readable = text.slice(0, idx).trim();
      payload.content = readable || fallback;
    }
    return true;
  } catch {
    return false;
  }
}

/**
 * If payload is a type-1 text envelope, rewrite it in-place.
 * Returns true when rewritten.
 */
export function unwrapHermesPayload(payload: any): boolean {
  if (!payload || typeof payload !== "object") return false;
  const typeVal = Number(payload.type ?? 0);
  if (typeVal !== 0 && typeVal !== 1) return false;
  const text = typeof payload.content === "string" ? payload.content : "";
  if (!text) return false;

  if (
    unwrapJsonMarker(payload, text, HERMES_CARD_MARKER, HERMES_CARD_TYPE, "[Hermes]")
  ) {
    return true;
  }
  if (
    unwrapJsonMarker(payload, text, HERMES_TABLE_MARKER, HERMES_TABLE_TYPE, "[表格]")
  ) {
    return true;
  }

  const actionIdx = text.indexOf(HERMES_ACTION_MARKER);
  if (actionIdx >= 0) {
    const tail = text.slice(actionIdx + HERMES_ACTION_MARKER.length).trim();
    const colon = tail.indexOf(":");
    if (colon <= 0) return false;
    const action = tail.slice(0, colon).trim();
    let cardId = tail.slice(colon + 1).trim();
    cardId = cardId.split(/\s/)[0] || "";
    if (!action || !cardId) return false;
    const readable = text.slice(0, actionIdx).trim();
    const label = displayLabelForAction(action, readable);
    Object.keys(payload).forEach((k) => delete payload[k]);
    Object.assign(payload, {
      type: HERMES_ACTION_TYPE,
      v: 1,
      kind: "hermes.action",
      action,
      label,
      content: label,
      approval_id: cardId,
    });
    return true;
  }

  return false;
}

export function isHermesActionPayload(payloadOrType: any): boolean {
  if (typeof payloadOrType === "number") {
    return payloadOrType === HERMES_ACTION_TYPE;
  }
  if (payloadOrType && typeof payloadOrType === "object") {
    return Number(payloadOrType.type) === HERMES_ACTION_TYPE;
  }
  return false;
}

export { displayLabelForAction };
