import { Editor } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import Underline from "@tiptap/extension-underline";
import Link from "@tiptap/extension-link";
import { Placeholder } from "@tiptap/extensions";
import { TextStyle, Color, FontSize } from "@tiptap/extension-text-style";
import {
  Table,
  TableRow,
  TableCell,
  TableHeader,
} from "@tiptap/extension-table";
import DOMPurify from "dompurify";
import {
  TableClipboard,
  extractTableHtml,
  looksLikeTsvTable,
  tsvToHtmlTable,
} from "../src/tablePaste";
import { promptText, promptTableSize, confirmDialog } from "./dialog";

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

function sanitize(html: string) {
  return DOMPurify.sanitize(html || "", {
    ALLOWED_TAGS,
    ALLOWED_ATTR: [
      "href",
      "target",
      "rel",
      "style",
      "colspan",
      "rowspan",
      "class",
    ],
    ALLOW_DATA_ATTR: false,
  });
}

function post(type: string, payload?: any) {
  const msg = JSON.stringify({ type, payload });
  (window as any).webkit?.messageHandlers?.richEditor?.postMessage?.(msg);
}

let editor: Editor;
let bubbleEl: HTMLDivElement | null = null;
let actionsEl: HTMLDivElement | null = null;
let toggleBtn: HTMLButtonElement | null = null;
let mainEl: HTMLDivElement | null = null;
let bubbleOpen = false;

function findTableEl(): HTMLElement | null {
  const { view, state } = editor;
  const { $from } = state.selection;
  for (let d = $from.depth; d > 0; d--) {
    if ($from.node(d).type.name === "table") {
      const pos = $from.before(d);
      const dom = view.nodeDOM(pos);
      return dom instanceof HTMLElement ? dom : null;
    }
  }
  return null;
}

function setBubbleOpen(open: boolean) {
  bubbleOpen = open;
  if (actionsEl) actionsEl.hidden = !open;
  if (toggleBtn) {
    toggleBtn.textContent = open ? "表▴" : "表▾";
    toggleBtn.title = open ? "收起表格工具" : "表格工具";
  }
  if (bubbleEl) {
    bubbleEl.classList.toggle("is-open", open);
    bubbleEl.classList.toggle("is-collapsed", !open);
  }
  syncTableBubble();
}

function syncTableBubble() {
  if (!bubbleEl || !mainEl) return;
  const inTable = editor.isActive("table");
  if (!inTable) {
    bubbleEl.hidden = true;
    if (bubbleOpen) {
      bubbleOpen = false;
      if (actionsEl) actionsEl.hidden = true;
      if (toggleBtn) {
        toggleBtn.textContent = "表▾";
        toggleBtn.title = "表格工具";
      }
      bubbleEl.classList.add("is-collapsed");
      bubbleEl.classList.remove("is-open");
    }
    return;
  }
  const tableEl = findTableEl();
  if (!tableEl) {
    bubbleEl.hidden = true;
    return;
  }
  const t = tableEl.getBoundingClientRect();
  const r = mainEl.getBoundingClientRect();
  const h = bubbleEl.offsetHeight || (bubbleOpen ? 72 : 34);
  const gap = 6;
  const spaceBelow = r.bottom - t.bottom;
  const placeBelow = spaceBelow >= h + gap || spaceBelow >= t.top - r.top;
  const top = placeBelow
    ? t.bottom - r.top + gap + mainEl.scrollTop
    : Math.max(4, t.top - r.top - h - gap + mainEl.scrollTop);
  bubbleEl.hidden = false;
  bubbleEl.style.top = `${top}px`;
  bubbleEl.style.left = `${Math.max(4, t.left - r.left + mainEl.scrollLeft)}px`;
}

function buildTableBubble(host: HTMLElement) {
  const bubble = document.createElement("div");
  bubble.className = "wk-rich-table-bubble is-collapsed";
  bubble.hidden = true;
  bubble.onmousedown = (e) => e.preventDefault();

  const toggle = document.createElement("button");
  toggle.type = "button";
  toggle.className = "wk-rich-table-toggle";
  toggle.textContent = "表▾";
  toggle.title = "表格工具";
  toggle.onclick = () => setBubbleOpen(!bubbleOpen);
  bubble.appendChild(toggle);
  toggleBtn = toggle;

  const actions = document.createElement("div");
  actions.className = "wk-rich-table-actions";
  actions.hidden = true;

  const mk = (label: string, title: string, fn: () => void, danger?: boolean) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    b.title = title;
    if (danger) b.className = "danger";
    b.onclick = fn;
    actions.appendChild(b);
  };
  const sep = () => {
    const s = document.createElement("span");
    s.className = "wk-rich-tb-sep";
    actions.appendChild(s);
  };

  mk("↑行", "上方插入行", () => editor.chain().focus().addRowBefore().run());
  mk("↓行", "下方插入行", () => editor.chain().focus().addRowAfter().run());
  mk("×行", "删除当前行", () => editor.chain().focus().deleteRow().run());
  sep();
  mk("←列", "左侧插入列", () =>
    editor.chain().focus().addColumnBefore().run()
  );
  mk("→列", "右侧插入列", () =>
    editor.chain().focus().addColumnAfter().run()
  );
  mk("×列", "删除当前列", () => editor.chain().focus().deleteColumn().run());
  sep();
  mk(
    "×表",
    "删除表格",
    () => {
      void confirmDialog("删除表格", "确定删除整个表格？").then((ok) => {
        if (!ok) return;
        editor.chain().focus().deleteTable().run();
      });
    },
    true
  );

  bubble.appendChild(actions);
  actionsEl = actions;
  host.appendChild(bubble);
  return bubble;
}

function buildToolbar(host: HTMLElement) {
  const wrap = document.createElement("div");
  wrap.className = "wk-rich-toolbar-wrap";

  const scroll = document.createElement("div");
  scroll.className = "wk-rich-toolbar-scroll";

  const mk = (label: string, title: string, fn: () => void) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "wk-rich-tb-btn";
    b.textContent = label;
    b.title = title;
    b.onmousedown = (e) => e.preventDefault();
    b.onclick = fn;
    scroll.appendChild(b);
    return b;
  };
  mk("B", "加粗", () => editor.chain().focus().toggleBold().run());
  mk("I", "斜体", () => editor.chain().focus().toggleItalic().run());
  mk("U", "下划线", () => editor.chain().focus().toggleUnderline().run());
  mk("S", "删除线", () => editor.chain().focus().toggleStrike().run());

  const size = document.createElement("select");
  size.className = "wk-rich-tb-select";
  size.innerHTML =
    '<option value="">字号</option><option value="12px">12</option><option value="14px">14</option><option value="16px">16</option><option value="18px">18</option><option value="20px">20</option><option value="24px">24</option>';
  size.onchange = () => {
    const v = size.value;
    if (!v) editor.chain().focus().unsetFontSize().run();
    else editor.chain().focus().setFontSize(v).run();
  };
  scroll.appendChild(size);

  // Fast 18-swatch palette (no system <input type="color"> — slow in WKWebView)
  const PALETTE_18 = [
    "#1F2329", "#646A73", "#8F959E", "#C9CDD4",
    "#3370FF", "#4E83FD", "#00A0E9", "#14C0C0",
    "#34C759", "#8BC34A", "#FFC107", "#FF9800",
    "#DE645C", "#E91E8C", "#9B59B6", "#795548",
    "#000000", "#FFFFFF",
  ];
  const colorWrap = document.createElement("div");
  colorWrap.className = "wk-rich-color-wrap";
  const colorBtn = document.createElement("button");
  colorBtn.type = "button";
  colorBtn.className = "wk-rich-tb-btn wk-rich-color-btn";
  colorBtn.title = "文字颜色";
  colorBtn.textContent = "A";
  colorBtn.onmousedown = (e) => e.preventDefault();
  const palette = document.createElement("div");
  palette.className = "wk-rich-color-palette";
  palette.hidden = true;
  for (const hex of PALETTE_18) {
    const sw = document.createElement("button");
    sw.type = "button";
    sw.className = "wk-rich-color-swatch";
    sw.style.background = hex;
    if (hex === "#FFFFFF") sw.classList.add("is-light");
    sw.title = hex;
    sw.onmousedown = (e) => e.preventDefault();
    sw.onclick = () => {
      editor.chain().focus().setColor(hex).run();
      palette.hidden = true;
      colorBtn.style.color = hex === "#FFFFFF" ? "var(--re-fg)" : hex;
    };
    palette.appendChild(sw);
  }
  colorBtn.onclick = () => {
    palette.hidden = !palette.hidden;
  };
  document.addEventListener(
    "click",
    (e) => {
      if (!colorWrap.contains(e.target as Node)) palette.hidden = true;
    },
    true
  );
  colorWrap.appendChild(colorBtn);
  colorWrap.appendChild(palette);
  scroll.appendChild(colorWrap);

  mk("链", "链接", () => {
    const prev = editor.getAttributes("link").href || "https://";
    void promptText("输入链接地址", prev, "https://").then((url) => {
      if (url === null) return;
      if (!url)
        editor.chain().focus().extendMarkRange("link").unsetLink().run();
      else
        editor
          .chain()
          .focus()
          .extendMarkRange("link")
          .setLink({ href: url })
          .run();
    });
  });
  mk("</>", "代码块", () => editor.chain().focus().toggleCodeBlock().run());
  mk("+表", "插入表格", () => {
    void promptTableSize(3, 3).then((sz) => {
      if (!sz) return;
      editor
        .chain()
        .focus()
        .insertTable({
          rows: sz.rows,
          cols: sz.cols,
          withHeaderRow: true,
        })
        .run();
    });
  });
  mk("•", "无序列表", () => editor.chain().focus().toggleBulletList().run());
  mk("1.", "有序列表", () => editor.chain().focus().toggleOrderedList().run());

  // Fixed paper-plane send on the right of the same row
  const send = document.createElement("button");
  send.type = "button";
  send.className = "wk-rich-send";
  send.title = "发送";
  send.setAttribute("aria-label", "发送");
  send.innerHTML =
    '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M3.4 20.4 21 12 3.4 3.6 3 10.2l11.1 1.8L3 13.8z"/></svg>';
  send.onmousedown = (e) => e.preventDefault();
  send.onclick = () => post("send");

  wrap.appendChild(scroll);
  wrap.appendChild(send);
  host.appendChild(wrap);
  return wrap;
}

function boot() {
  const root = document.getElementById("app")!;
  mainEl = document.createElement("div");
  mainEl.className = "wk-rich-editor-main";
  const mount = document.createElement("div");
  mount.className = "wk-rich-editor-body";
  mainEl.appendChild(mount);

  editor = new Editor({
    element: mount,
    extensions: [
      StarterKit,
      Underline,
      TextStyle,
      Color,
      FontSize,
      Link.configure({ openOnClick: false }),
      Placeholder.configure({
        placeholder: "支持字体、链接、代码块、表格…",
      }),
      Table.configure({
        resizable: false,
        HTMLAttributes: { class: "wk-rich-table" },
      }),
      TableRow,
      TableHeader,
      TableCell,
      TableClipboard,
    ],
    content: "",
    onSelectionUpdate: () => syncTableBubble(),
    onTransaction: () => syncTableBubble(),
  });

  // Editor first (top), toolbar last (bottom, above keyboard).
  root.appendChild(mainEl);
  buildToolbar(root);
  bubbleEl = buildTableBubble(mainEl);
  syncTableBubble();

  (window as any).RichEditorBridge = {
    getHTML: () => sanitize(editor.getHTML()),
    getText: () => editor.getText(),
    setTheme: (mode: string) => {
      const theme = mode === "dark" ? "dark" : "light";
      document.documentElement.setAttribute("data-theme", theme);
      document.documentElement.style.colorScheme = theme;
      document.body.style.background = "";
      document.body.style.color = "";
    },
    setHTML: (html: string) => {
      editor.commands.setContent(sanitize(html || ""), { emitUpdate: false });
    },
    /** Native iOS pasteboard inject (HTML, preferably containing <table>). */
    insertHTML: (html: string) => {
      const table = extractTableHtml(html || "");
      const content = table || sanitize(html || "");
      if (!content) return false;
      return editor
        .chain()
        .focus()
        .insertContent(content, { parseOptions: { preserveWhitespace: false } })
        .run();
    },
    /** Native iOS pasteboard inject (TSV / markdown table plain text). */
    insertPlain: (text: string) => {
      if (looksLikeTsvTable(text || "")) {
        return editor
          .chain()
          .focus()
          .insertContent(tsvToHtmlTable(text || ""), {
            parseOptions: { preserveWhitespace: false },
          })
          .run();
      }
      return editor.chain().focus().insertContent(text || "").run();
    },
    focus: () => editor.commands.focus(),
    isEmpty: () => !editor.getText().trim(),
    exec: (action: string, payload?: any) => {
      switch (action) {
        case "bold":
          editor.chain().focus().toggleBold().run();
          break;
        case "italic":
          editor.chain().focus().toggleItalic().run();
          break;
        case "underline":
          editor.chain().focus().toggleUnderline().run();
          break;
        case "strike":
          editor.chain().focus().toggleStrike().run();
          break;
        case "codeBlock":
          editor.chain().focus().toggleCodeBlock().run();
          break;
        case "link":
          if (payload?.href)
            editor.chain().focus().setLink({ href: payload.href }).run();
          break;
        case "table":
          editor
            .chain()
            .focus()
            .insertTable({
              rows: payload?.rows || 3,
              cols: payload?.cols || 3,
              withHeaderRow: true,
            })
            .run();
          break;
        case "deleteTable":
          editor.chain().focus().deleteTable().run();
          break;
        case "addRowBefore":
          editor.chain().focus().addRowBefore().run();
          break;
        case "addRowAfter":
          editor.chain().focus().addRowAfter().run();
          break;
        case "deleteRow":
          editor.chain().focus().deleteRow().run();
          break;
        case "addColumnBefore":
          editor.chain().focus().addColumnBefore().run();
          break;
        case "addColumnAfter":
          editor.chain().focus().addColumnAfter().run();
          break;
        case "deleteColumn":
          editor.chain().focus().deleteColumn().run();
          break;
        case "fontSize":
          if (payload?.size)
            editor.chain().focus().setFontSize(payload.size).run();
          break;
        case "color":
          if (payload?.color)
            editor.chain().focus().setColor(payload.color).run();
          break;
        default:
          break;
      }
    },
  };

  post("ready");
}

boot();
