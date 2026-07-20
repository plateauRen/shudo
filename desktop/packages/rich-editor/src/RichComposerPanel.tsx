import React, { useRef } from "react";
import { RichEditor, RichEditorHandle } from "./RichEditor";
import { isEmptyHtml } from "./sanitize";
import "./editor.css";

export type RichComposerPanelProps = {
  visible: boolean;
  initialHTML?: string;
  onClose: () => void;
  onSend: (html: string) => void;
  title?: string;
};

/**
 * Expanded rich composer anchored to a parent (message pane).
 * Parent should be position:relative; panel uses absolute fill.
 */
export function RichComposerPanel(props: RichComposerPanelProps) {
  const { visible, initialHTML, onClose, onSend, title = "富文本编辑" } =
    props;
  const ref = useRef<RichEditorHandle>(null);

  if (!visible) return null;

  const send = () => {
    const html = ref.current?.getHTML() || "";
    if (isEmptyHtml(html)) return;
    onSend(html);
  };

  return (
    <div className="wk-rich-composer-panel">
      <div className="wk-rich-composer-head">
        <div className="wk-rich-composer-title">{title}</div>
        <div className="wk-rich-composer-actions">
          <button type="button" className="wk-rich-composer-btn" onClick={onClose}>
            关闭
          </button>
          <button
            type="button"
            className="wk-rich-composer-btn primary"
            onClick={send}
          >
            发送
          </button>
        </div>
      </div>
      <div className="wk-rich-composer-body">
        <RichEditor
          ref={ref}
          initialHTML={initialHTML}
          autoFocus
          placeholder="支持字体、链接、代码块、表格…"
        />
      </div>
    </div>
  );
}
