import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Editor } from "@tiptap/react";

type Props = {
  editor: Editor | null;
};

type Pos = { top: number; left: number };

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

/**
 * Telegram-style table control: floating ⋯ on the table corner,
 * menu for insert/delete row & column.
 */
export function TableBubble({ editor }: Props) {
  const [tick, setTick] = useState(0);
  const [pos, setPos] = useState<Pos | null>(null);
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
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

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, [open]);

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
    const next: Pos = {
      top: Math.max(4, t.top - r.top + root.scrollTop - 4),
      left: Math.max(4, t.right - r.left + root.scrollLeft - 36),
    };
    setPos((prev) =>
      prev && prev.top === next.top && prev.left === next.left ? prev : next
    );
  }, [editor, inTable, tick, open]);

  if (!editor || !inTable || !pos) return null;

  const run = (fn: () => void) => {
    fn();
    setOpen(false);
  };

  const items: Array<
    | { type: "item"; label: string; danger?: boolean; action: () => void }
    | { type: "sep" }
  > = [
    {
      type: "item",
      label: "在上方添加行",
      action: () => editor.chain().focus().addRowBefore().run(),
    },
    {
      type: "item",
      label: "在下方添加行",
      action: () => editor.chain().focus().addRowAfter().run(),
    },
    {
      type: "item",
      label: "删除当前行",
      danger: true,
      action: () => editor.chain().focus().deleteRow().run(),
    },
    { type: "sep" },
    {
      type: "item",
      label: "在左侧添加列",
      action: () => editor.chain().focus().addColumnBefore().run(),
    },
    {
      type: "item",
      label: "在右侧添加列",
      action: () => editor.chain().focus().addColumnAfter().run(),
    },
    {
      type: "item",
      label: "删除当前列",
      danger: true,
      action: () => editor.chain().focus().deleteColumn().run(),
    },
    { type: "sep" },
    {
      type: "item",
      label: "删除整个表格",
      danger: true,
      action: () => {
        if (!window.confirm("删除整个表格？")) return;
        editor.chain().focus().deleteTable().run();
      },
    },
  ];

  return (
    <div
      ref={rootRef}
      className={`wk-rich-table-corner${open ? " is-open" : ""}`}
      style={{ top: pos.top, left: pos.left }}
      onMouseDown={(e) => e.preventDefault()}
    >
      <button
        type="button"
        className="wk-rich-table-more"
        title="表格设置"
        aria-label="表格设置"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
      >
        <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden>
          <circle cx="12" cy="5" r="1.8" fill="currentColor" />
          <circle cx="12" cy="12" r="1.8" fill="currentColor" />
          <circle cx="12" cy="19" r="1.8" fill="currentColor" />
        </svg>
      </button>
      {open ? (
        <div className="wk-rich-table-menu" role="menu">
          {items.map((it, i) =>
            it.type === "sep" ? (
              <div key={`s-${i}`} className="wk-rich-table-menu-sep" />
            ) : (
              <button
                key={it.label}
                type="button"
                role="menuitem"
                className={
                  it.danger
                    ? "wk-rich-table-menu-item is-danger"
                    : "wk-rich-table-menu-item"
                }
                onClick={() => run(it.action)}
              >
                {it.label}
              </button>
            )
          )}
        </div>
      ) : null}
    </div>
  );
}
