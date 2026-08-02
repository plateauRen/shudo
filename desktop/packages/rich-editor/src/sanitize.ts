import DOMPurify from "dompurify";

const ALLOWED_TAGS = [
  "p",
  "br",
  "strong",
  "b",
  "em",
  "i",
  "u",
  "s",
  "strike",
  "span",
  "a",
  "ul",
  "ol",
  "li",
  "pre",
  "code",
  "blockquote",
  "h1",
  "h2",
  "h3",
  "table",
  "thead",
  "tbody",
  "tr",
  "th",
  "td",
  "div",
];

const ALLOWED_ATTR = ["href", "target", "rel", "style", "colspan", "rowspan", "class"];

export function sanitizeHtml(html: string): string {
  if (!html) return "";
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS,
    ALLOWED_ATTR,
    ALLOW_DATA_ATTR: false,
  });
}

/** Strip tags for conversation digest / plain fallback. Collapses whitespace. */
export function htmlToPlainText(html: string): string {
  if (!html) return "";
  if (typeof document !== "undefined") {
    const div = document.createElement("div");
    div.innerHTML = sanitizeHtml(html);
    return (div.textContent || div.innerText || "").replace(/\s+/g, " ").trim();
  }
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** Plain text for clipboard: keep table rows/cols as TSV (\t / \\n). */
export function htmlToPlainTextWithTables(html: string): string {
  if (!html) return "";
  if (typeof document === "undefined") {
    return htmlToPlainTextWithTablesFallback(html);
  }
  const root = document.createElement("div");
  root.innerHTML = sanitizeHtml(html);
  root.querySelectorAll("table").forEach((table) => {
    const tsv = [...table.querySelectorAll("tr")]
      .map((tr) =>
        [...tr.querySelectorAll("th,td")]
          .map((c) => (c.textContent || "").replace(/\t/g, " ").trim())
          .join("\t")
      )
      .join("\n");
    const holder = document.createElement("div");
    holder.textContent = tsv;
    table.replaceWith(holder);
  });
  root.querySelectorAll("br").forEach((br) => {
    br.replaceWith(document.createTextNode("\n"));
  });
  ["p", "div", "li", "h1", "h2", "h3", "blockquote", "pre"].forEach((tag) => {
    root.querySelectorAll(tag).forEach((el) => {
      el.appendChild(document.createTextNode("\n"));
    });
  });
  return (root.textContent || "").replace(/\n{3,}/g, "\n\n").trim();
}

function htmlToPlainTextWithTablesFallback(html: string): string {
  let s = html;
  s = s.replace(/<\/tr\s*>/gi, "\n");
  s = s.replace(/<\/(td|th)\s*>\s*<(td|th)\b/gi, "\t<$2");
  s = s.replace(/<br\s*\/?>/gi, "\n");
  s = s.replace(/<\/p>/gi, "\n");
  s = s.replace(/<[^>]+>/g, "");
  return s.replace(/\n{3,}/g, "\n\n").trim();
}

export function isEmptyHtml(html: string): boolean {
  const text = htmlToPlainText(html);
  return !text;
}
