import React, { useEffect, useState } from "react";
import { Editor } from "@tiptap/react";

type Props = {
  editor: Editor | null;
};

function Btn(props: {
  active?: boolean;
  disabled?: boolean;
  title: string;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      className={`wk-rich-tb-btn${props.active ? " active" : ""}`}
      title={props.title}
      disabled={props.disabled}
      onMouseDown={(e) => e.preventDefault()}
      onClick={props.onClick}
    >
      {props.children}
    </button>
  );
}

export function RichToolbar({ editor }: Props) {
  const [, setTick] = useState(0);
  useEffect(() => {
    if (!editor) return;
    const bump = () => setTick((n) => n + 1);
    editor.on("selectionUpdate", bump);
    editor.on("transaction", bump);
    return () => {
      editor.off("selectionUpdate", bump);
      editor.off("transaction", bump);
    };
  }, [editor]);

  if (!editor) return null;

  const setLink = () => {
    const prev = editor.getAttributes("link").href as string | undefined;
    const url = window.prompt("输入链接地址", prev || "https://");
    if (url === null) return;
    if (url === "") {
      editor.chain().focus().extendMarkRange("link").unsetLink().run();
      return;
    }
    editor
      .chain()
      .focus()
      .extendMarkRange("link")
      .setLink({ href: url })
      .run();
  };

  const insertTable = () => {
    const raw = window.prompt("表格大小（行数×列数）", "3×3");
    if (raw === null) return;
    const m = String(raw)
      .trim()
      .match(/^(\d+)\s*[xX×*]\s*(\d+)$/);
    let rows = 3;
    let cols = 3;
    if (m) {
      rows = Number(m[1]);
      cols = Number(m[2]);
    } else {
      const n = Number(raw);
      if (Number.isFinite(n) && n >= 2) {
        rows = n;
        cols = n;
      }
    }
    rows = Math.min(20, Math.max(2, rows || 3));
    cols = Math.min(10, Math.max(2, cols || 3));
    editor
      .chain()
      .focus()
      .insertTable({ rows, cols, withHeaderRow: true })
      .run();
  };

  return (
    <div className="wk-rich-toolbar">
      <Btn
        title="加粗"
        active={editor.isActive("bold")}
        onClick={() => editor.chain().focus().toggleBold().run()}
      >
        B
      </Btn>
      <Btn
        title="斜体"
        active={editor.isActive("italic")}
        onClick={() => editor.chain().focus().toggleItalic().run()}
      >
        I
      </Btn>
      <Btn
        title="下划线"
        active={editor.isActive("underline")}
        onClick={() => editor.chain().focus().toggleUnderline().run()}
      >
        U
      </Btn>
      <Btn
        title="删除线"
        active={editor.isActive("strike")}
        onClick={() => editor.chain().focus().toggleStrike().run()}
      >
        S
      </Btn>
      <span className="wk-rich-tb-sep" />
      <select
        className="wk-rich-tb-select"
        title="字号"
        defaultValue=""
        onChange={(e) => {
          const v = e.target.value;
          if (!v) editor.chain().focus().unsetFontSize().run();
          else editor.chain().focus().setFontSize(v).run();
        }}
      >
        <option value="">字号</option>
        <option value="12px">12</option>
        <option value="14px">14</option>
        <option value="16px">16</option>
        <option value="18px">18</option>
        <option value="20px">20</option>
        <option value="24px">24</option>
      </select>
      <input
        type="color"
        className="wk-rich-tb-color"
        title="文字颜色"
        defaultValue="#333333"
        onChange={(e) =>
          editor.chain().focus().setColor(e.target.value).run()
        }
      />
      <span className="wk-rich-tb-sep" />
      <Btn title="链接" active={editor.isActive("link")} onClick={setLink}>
        链
      </Btn>
      <Btn
        title="代码块"
        active={editor.isActive("codeBlock")}
        onClick={() => editor.chain().focus().toggleCodeBlock().run()}
      >
        {"</>"}
      </Btn>
      <span className="wk-rich-tb-sep" />
      <Btn title="插入表格" onClick={insertTable}>
        +表
      </Btn>
      <span className="wk-rich-tb-sep" />
      <Btn
        title="无序列表"
        active={editor.isActive("bulletList")}
        onClick={() => editor.chain().focus().toggleBulletList().run()}
      >
        •
      </Btn>
      <Btn
        title="有序列表"
        active={editor.isActive("orderedList")}
        onClick={() => editor.chain().focus().toggleOrderedList().run()}
      >
        1.
      </Btn>
      <span className="wk-rich-tb-sep" />
      <Btn
        title="撤销"
        onClick={() => editor.chain().focus().undo().run()}
        disabled={!editor.can().undo()}
      >
        ↶
      </Btn>
      <Btn
        title="重做"
        onClick={() => editor.chain().focus().redo().run()}
        disabled={!editor.can().redo()}
      >
        ↷
      </Btn>
    </div>
  );
}
