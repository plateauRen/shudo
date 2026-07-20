import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Editor } from "@tiptap/react";

type Props = {
  editor: Editor | null;
};

type Pos = { top: number; left: number; place: "above" | "below" };

function findTableEl(editor: Editor): HTMLElement | null {
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

export function TableBubble({ editor }: Props) {
  const [tick, setTick] = useState(0);
  const [pos, setPos] = useState<Pos | null>(null);
  const [open, setOpen] = useState(false);
  const bubbleRef = useRef<HTMLDivElement>(null);
  const inTable = !!editor?.isActive("table");

  useEffect(() => {
    if (!editor) return;
    const bump = () => setTick((n) => n + 1);
    editor.on("selectionUpdate", bump);
    editor.on("transaction", bump);
    editor.on("focus", bump);
    editor.on("blur", bump);
    return () => {
      editor.off("selectionUpdate", bump);
      editor.off("transaction", bump);
      editor.off("focus", bump);
      editor.off("blur", bump);
    };
  }, [editor]);

  useEffect(() => {
    if (!inTable) setOpen(false);
  }, [inTable]);

  useLayoutEffect(() => {
    if (!editor || !inTable) {
      setPos((p) => (p ? null : p));
      return;
    }
    const tableEl = findTableEl(editor);
    const root = editor.view.dom.closest(
      ".wk-rich-editor-main"
    ) as HTMLElement | null;
    if (!tableEl || !root) {
      setPos((p) => (p ? null : p));
      return;
    }
    const t = tableEl.getBoundingClientRect();
    const r = root.getBoundingClientRect();
    const h = bubbleRef.current?.offsetHeight || (open ? 72 : 34);
    const gap = 6;
    const spaceBelow = r.bottom - t.bottom;
    const place: "above" | "below" =
      spaceBelow >= h + gap || spaceBelow >= t.top - r.top ? "below" : "above";
    const top =
      place === "below"
        ? t.bottom - r.top + gap + root.scrollTop
        : Math.max(4, t.top - r.top - h - gap + root.scrollTop);
    const next: Pos = {
      top,
      left: Math.max(4, t.left - r.left + root.scrollLeft),
      place,
    };
    setPos((prev) =>
      prev &&
      prev.top === next.top &&
      prev.left === next.left &&
      prev.place === next.place
        ? prev
        : next
    );
  }, [editor, inTable, tick, open]);

  if (!editor || !inTable || !pos) return null;

  return (
    <div
      ref={bubbleRef}
      className={`wk-rich-table-bubble${open ? " is-open" : " is-collapsed"}`}
      style={{ top: pos.top, left: pos.left }}
      onMouseDown={(e) => e.preventDefault()}
    >
      <button
        type="button"
        className="wk-rich-table-toggle"
        title={open ? "收起表格工具" : "表格工具"}
        onClick={() => setOpen((v) => !v)}
      >
        表{open ? "▴" : "▾"}
      </button>
      {open ? (
        <div className="wk-rich-table-actions">
          <button
            type="button"
            title="上方插入行"
            onClick={() => editor.chain().focus().addRowBefore().run()}
          >
            ↑行
          </button>
          <button
            type="button"
            title="下方插入行"
            onClick={() => editor.chain().focus().addRowAfter().run()}
          >
            ↓行
          </button>
          <button
            type="button"
            title="删除当前行"
            onClick={() => editor.chain().focus().deleteRow().run()}
          >
            ×行
          </button>
          <span className="wk-rich-tb-sep" />
          <button
            type="button"
            title="左侧插入列"
            onClick={() => editor.chain().focus().addColumnBefore().run()}
          >
            ←列
          </button>
          <button
            type="button"
            title="右侧插入列"
            onClick={() => editor.chain().focus().addColumnAfter().run()}
          >
            →列
          </button>
          <button
            type="button"
            title="删除当前列"
            onClick={() => editor.chain().focus().deleteColumn().run()}
          >
            ×列
          </button>
          <span className="wk-rich-tb-sep" />
          <button
            type="button"
            title="删除表格"
            className="danger"
            onClick={() => {
              if (!window.confirm("删除整个表格？")) return;
              editor.chain().focus().deleteTable().run();
            }}
          >
            ×表
          </button>
        </div>
      ) : null}
    </div>
  );
}
