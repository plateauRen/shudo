import React, { useEffect, useImperativeHandle, forwardRef } from "react";
import { EditorContent, useEditor } from "@tiptap/react";
import { createEditorExtensions } from "./extensions";
import { RichToolbar } from "./Toolbar";
import { TableBubble } from "./TableBubble";
import { sanitizeHtml, htmlToPlainText, isEmptyHtml } from "./sanitize";
import "./editor.css";

export type RichEditorHandle = {
  getHTML: () => string;
  getText: () => string;
  setHTML: (html: string) => void;
  focus: () => void;
  isEmpty: () => boolean;
};

export type RichEditorProps = {
  initialHTML?: string;
  placeholder?: string;
  autoFocus?: boolean;
  showToolbar?: boolean;
  className?: string;
  onChange?: (html: string) => void;
};

export const RichEditor = forwardRef<RichEditorHandle, RichEditorProps>(
  function RichEditor(props, ref) {
    const {
      initialHTML = "",
      placeholder,
      autoFocus,
      showToolbar = true,
      className,
      onChange,
    } = props;

    const editor = useEditor({
      extensions: createEditorExtensions(placeholder),
      content: initialHTML || "",
      autofocus: autoFocus ? "end" : false,
      immediatelyRender: false,
      onUpdate: ({ editor: ed }) => {
        onChange?.(ed.getHTML());
      },
    });

    useImperativeHandle(
      ref,
      () => ({
        getHTML: () => sanitizeHtml(editor?.getHTML() || ""),
        getText: () => htmlToPlainText(editor?.getHTML() || ""),
        setHTML: (html: string) => {
          editor?.commands.setContent(sanitizeHtml(html || ""), {
            emitUpdate: false,
          });
        },
        focus: () => editor?.commands.focus(),
        isEmpty: () => isEmptyHtml(editor?.getHTML() || ""),
      }),
      [editor]
    );

    return (
      <div className={`wk-rich-editor${className ? ` ${className}` : ""}`}>
        {showToolbar ? <RichToolbar editor={editor} /> : null}
        <div className="wk-rich-editor-main">
          <EditorContent editor={editor} className="wk-rich-editor-body" />
          <TableBubble editor={editor} />
        </div>
      </div>
    );
  }
);
