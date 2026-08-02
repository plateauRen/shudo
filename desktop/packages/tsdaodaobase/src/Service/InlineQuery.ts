import WKApp from "../App";

export type InlineGifItem = {
  url: string;
  width: number;
  height: number;
};

export type InlineQueryResult = {
  id?: string;
  type: string;
  inlineQuerySid?: string;
  nextOffset?: string;
  results: InlineGifItem[];
};

/**
 * POST robot/inline_query — aligns with iOS WKConversationView+Robot.
 */
export async function requestInlineQuery(params: {
  username: string;
  query: string;
  offset?: string;
  channelId: string;
  channelType: number;
}): Promise<InlineQueryResult> {
  const data: any = await WKApp.apiClient.post("robot/inline_query", {
    username: params.username,
    query: params.query || "",
    offset: params.offset || "",
    channel_id: params.channelId,
    channel_type: params.channelType,
  });

  const type = String(data?.type || "");
  const resultsRaw = Array.isArray(data?.results) ? data.results : [];
  const results: InlineGifItem[] =
    type === "gif"
      ? resultsRaw.map((r: any) => ({
          url: String(r?.url || ""),
          width: Number(r?.width) || 270,
          height: Number(r?.height) || 270,
        })).filter((r: InlineGifItem) => Boolean(r.url))
      : [];

  return {
    id: data?.id ? String(data.id) : undefined,
    type,
    inlineQuerySid: data?.inline_query_sid
      ? String(data.inline_query_sid)
      : undefined,
    nextOffset: data?.next_offset ? String(data.next_offset) : "",
    results,
  };
}

/** Parse `@username query…` (plain text, not mention markup). */
export function parseInlineBotInput(
  raw: string
): { username: string; query: string } | null {
  const text = (raw || "").trimStart();
  // Ignore react-mentions markup @[name]
  if (!text.startsWith("@") || text.startsWith("@[")) return null;
  const m = text.match(/^@([^\s\[]+)\s+([\s\S]*)$/);
  if (!m) return null;
  return { username: m[1], query: (m[2] || "").trimStart() };
}
