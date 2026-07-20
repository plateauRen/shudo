import { Extension, Editor } from "@tiptap/core";
import { Plugin, PluginKey } from "@tiptap/pm/state";
import { sanitizeHtml } from "./sanitize";

/** Tab / multi-line plain text that looks like a spreadsheet paste. */
export function looksLikeTsvTable(text: string): boolean {
  if (!text) return false;
  const normalized = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  if (normalized.includes("\t")) {
    const lines = normalized.split("\n").filter((l) => l.length > 0);
    if (lines.length < 1) return false;
    const cols = lines[0].split("\t").length;
    if (cols < 2) return false;
    let ok = 0;
    for (const line of lines) {
      if (Math.abs(line.split("\t").length - cols) <= 1) ok++;
    }
    return ok >= Math.max(1, Math.ceil(lines.length * 0.5));
  }
  // Markdown pipe table
  if (/\|.+\|/.test(normalized) && normalized.split("\n").length >= 2) {
    const lines = normalized.split("\n").filter((l) => /\|/.test(l));
    return lines.length >= 2;
  }
  return false;
}

function escapeHtml(s: string) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

export function tsvToHtmlTable(text: string): string {
  const lines = text
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n")
    .filter((l) => l.length > 0);
  if (!lines.length) return "";

  let rows: string[][];
  if (lines[0].includes("\t")) {
    rows = lines.map((line) => line.split("\t"));
  } else if (lines.some((l) => /\|/.test(l))) {
    rows = lines
      .filter((l) => !/^\s*\|?\s*:?-+:?\s*\|/.test(l)) // skip markdown separator
      .map((line) =>
        line
          .replace(/^\|/, "")
          .replace(/\|$/, "")
          .split("|")
          .map((c) => c.trim())
      )
      .filter((r) => r.length > 0 && r.some((c) => c.length > 0));
  } else {
    return "";
  }

  if (!rows.length) return "";
  const [header, ...body] = rows;
  const th = header.map((c) => `<th>${escapeHtml(c)}</th>`).join("");
  const trs = (body.length ? body : [header.map(() => "")])
    .map(
      (r) =>
        `<tr>${r.map((c) => `<td>${escapeHtml(c)}</td>`).join("")}</tr>`
    )
    .join("");
  if (body.length) {
    return `<table class="wk-rich-table"><thead><tr>${th}</tr></thead><tbody>${trs}</tbody></table><p></p>`;
  }
  return `<table class="wk-rich-table"><tbody><tr>${header
    .map((c) => `<td>${escapeHtml(c)}</td>`)
    .join("")}</tr></tbody></table><p></p>`;
}

/** Pull a clean <table>…</table> from clipboard HTML (Excel / Sheets / Word / Apple). */
export function extractTableHtml(html: string): string | null {
  if (!html || !/<table[\s>]/i.test(html)) return null;

  // Apple / Office paste often wraps fragments
  let fragment = html;
  const start = html.indexOf("<!--StartFragment-->");
  const end = html.indexOf("<!--EndFragment-->");
  if (start >= 0 && end > start) {
    fragment = html.slice(start + "<!--StartFragment-->".length, end);
  }

  // Prefer DOM parse when available (handles nested junk better)
  if (typeof document !== "undefined") {
    try {
      const doc = new DOMParser().parseFromString(fragment, "text/html");
      const table = doc.querySelector("table");
      if (table) {
        // Normalize: ensure class, drop colgroup widths noise is ok
        table.classList.add("wk-rich-table");
        const cleaned = sanitizeHtml(table.outerHTML);
        if (/<table[\s>]/i.test(cleaned)) return cleaned + "<p></p>";
      }
    } catch {
      /* fall through */
    }
  }

  const cleaned = sanitizeHtml(fragment);
  const m = cleaned.match(/<table[\s\S]*?<\/table>/i);
  return m ? m[0] + "<p></p>" : null;
}

function insertTableHtml(editor: Editor, tableHtml: string): boolean {
  try {
    return editor
      .chain()
      .focus()
      .insertContent(tableHtml, {
        parseOptions: { preserveWhitespace: false },
      })
      .run();
  } catch {
    return false;
  }
}

/**
 * Prefer HTML table from clipboard; fall back to TSV / markdown → HTML table.
 * Always insert ourselves — TipTap default paste often drops tables on iOS WKWebView.
 */
export function handleTablePaste(
  editor: Editor,
  event: ClipboardEvent
): boolean {
  const cd = event.clipboardData;
  if (!cd) return false;

  const html = cd.getData("text/html") || "";
  const text = cd.getData("text/plain") || "";

  const tableOnly = extractTableHtml(html);
  if (tableOnly) {
    event.preventDefault();
    insertTableHtml(editor, tableOnly);
    return true;
  }

  if (looksLikeTsvTable(text)) {
    event.preventDefault();
    insertTableHtml(editor, tsvToHtmlTable(text));
    return true;
  }
  return false;
}

/** Keep HTML table markup when copying a selection that includes a table. */
export function handleTableCopy(
  editor: Editor,
  event: ClipboardEvent
): boolean {
  const { state } = editor;
  if (!state.selection || state.selection.empty) return false;

  let hasTable = editor.isActive("table");
  if (!hasTable) {
    state.doc.nodesBetween(state.selection.from, state.selection.to, (node) => {
      if (node.type.name === "table") hasTable = true;
    });
  }
  if (!hasTable) return false;

  // Prefer serializer HTML for the full table node when caret is inside a table
  let tableHtml = "";
  if (editor.isActive("table")) {
    const { $from } = state.selection;
    for (let d = $from.depth; d > 0; d--) {
      if ($from.node(d).type.name === "table") {
        const pos = $from.before(d);
        const node = $from.node(d);
        const dom = editor.view.nodeDOM(pos);
        if (dom instanceof HTMLElement) {
          tableHtml = sanitizeHtml(dom.outerHTML);
        } else {
          // Fallback: slice JSON → HTML via temporary insert
          const slice = node.type.schema.nodeFromJSON(node.toJSON());
          void slice;
        }
        break;
      }
    }
  }

  const domSel = window.getSelection();
  if (!tableHtml && domSel && domSel.rangeCount > 0) {
    const range = domSel.getRangeAt(0);
    const div = document.createElement("div");
    div.appendChild(range.cloneContents());
    const selHtml = div.innerHTML;
    if (/<table[\s>]/i.test(selHtml)) {
      tableHtml = sanitizeHtml(selHtml);
    }
  }

  if (!tableHtml || !/<table[\s>]/i.test(tableHtml)) return false;

  try {
    event.clipboardData?.setData("text/html", tableHtml);
    event.clipboardData?.setData(
      "text/plain",
      domSel?.toString() || htmlTableToTsv(tableHtml)
    );
    event.preventDefault();
    return true;
  } catch {
    return false;
  }
}

function htmlTableToTsv(html: string): string {
  if (typeof document === "undefined") return "";
  const doc = new DOMParser().parseFromString(html, "text/html");
  const rows = [...doc.querySelectorAll("tr")];
  return rows
    .map((tr) =>
      [...tr.querySelectorAll("th,td")]
        .map((c) => (c.textContent || "").replace(/\t/g, " "))
        .join("\t")
    )
    .join("\n");
}

export const TableClipboard = Extension.create({
  name: "wkTableClipboard",
  addProseMirrorPlugins() {
    const editor = this.editor;
    return [
      new Plugin({
        key: new PluginKey("wkTableClipboard"),
        props: {
          handlePaste(_view, event) {
            return handleTablePaste(editor, event as ClipboardEvent);
          },
          handleDOMEvents: {
            copy(_view, event) {
              return handleTableCopy(editor, event as ClipboardEvent);
            },
            // iOS sometimes uses cut/paste via beforeinput; also catch paste on DOM
            paste(_view, event) {
              return handleTablePaste(editor, event as ClipboardEvent);
            },
          },
          transformPastedHTML(html: string) {
            const table = extractTableHtml(html);
            if (table) return table;
            return sanitizeHtml(html);
          },
        },
      }),
    ];
  },
});
