import React from "react";
import { Button, Modal, Toast } from "@douyinfe/semi-ui";
import { MessageContent } from "wukongimjssdk";
import MessageBase from "../Base";
import MessageTrail from "../Base/tail";
import { MessageCell } from "../MessageCell";
import { MessageContentTypeConst } from "../../Service/Const";
import "./table.css";

const MAX_ROWS = 30;

export type HermesTableColumn = {
  id: string;
  label: string;
  align?: "left" | "center" | "right" | string;
  format?: "text" | "pct_color" | string;
};

export class HermesTableContent extends MessageContent {
  v = 1;
  kind = "hermes.table";
  title = "";
  caption = "";
  contentText = "";
  columns: HermesTableColumn[] = [];
  rows: Record<string, any>[] = [];
  meta?: any;

  decodeJSON(content: any) {
    this.v = content?.v || 1;
    this.kind = content?.kind || "hermes.table";
    this.title = content?.title || "";
    this.caption = content?.caption || "";
    this.contentText = content?.content || this.title || "";
    this.columns = Array.isArray(content?.columns) ? content.columns : [];
    this.rows = Array.isArray(content?.rows) ? content.rows : [];
    this.meta = content?.meta;
  }

  encodeJSON() {
    return {
      v: this.v || 1,
      kind: "hermes.table",
      title: this.title || "",
      caption: this.caption || undefined,
      content: this.contentText || "",
      columns: this.columns || [],
      rows: this.rows || [],
      meta: this.meta,
    };
  }

  get contentType() {
    return MessageContentTypeConst.hermesTable;
  }

  get conversationDigest() {
    return this.title ? `[表格] ${this.title}` : "[表格]";
  }
}

function cellColor(value: string, format?: string): string | undefined {
  if (format !== "pct_color" || !value) return undefined;
  const c = value[0];
  if (c === "+" || c === "＋") return "#ff3b30";
  if (c === "-" || c === "－" || c === "−") return "#34c759";
  return undefined;
}

function alignClass(align?: string): string {
  if (align === "right") return "right";
  if (align === "center") return "center";
  return "left";
}

function plainTextFromTable(
  title: string,
  caption: string,
  columns: HermesTableColumn[],
  rows: Record<string, any>[]
): string {
  const lines: string[] = [];
  if (title) lines.push(title);
  if (caption) lines.push(caption);
  if (title || caption) lines.push("");
  if (columns.length) {
    lines.push(columns.map((c) => c.label || c.id).join("\t"));
    for (const row of rows) {
      lines.push(
        columns
          .map((c) => {
            const raw = row?.[c.id];
            return raw == null ? "" : String(raw);
          })
          .join("\t")
      );
    }
  }
  return lines.join("\n").trim();
}

function TableGrid(props: {
  columns: HermesTableColumn[];
  rows: Record<string, any>[];
}) {
  const { columns, rows } = props;
  return (
    <div className="wk-hermes-table-grid">
      <table>
        <thead>
          <tr>
            {columns.map((col) => (
              <th key={col.id} className={alignClass(col.align)}>
                {col.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <tr key={ri} className={ri % 2 ? "alt" : undefined}>
              {columns.map((col) => {
                const raw = row?.[col.id];
                const val =
                  raw == null
                    ? ""
                    : typeof raw === "string"
                    ? raw
                    : String(raw);
                const color = cellColor(val, col.format);
                return (
                  <td
                    key={col.id}
                    className={alignClass(col.align)}
                    style={color ? { color } : undefined}
                  >
                    {val}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

type CellState = { open: boolean };

export class HermesTableCell extends MessageCell<any, CellState> {
  state: CellState = { open: false };

  open = () => this.setState({ open: true });
  close = () => this.setState({ open: false });

  copyAll = async (text: string) => {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        const ta = document.createElement("textarea");
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        document.body.removeChild(ta);
      }
      Toast.success("已复制");
    } catch {
      Toast.error("复制失败");
    }
  };

  render() {
    const { message, context } = this.props;
    const content = message.content as HermesTableContent;
    const columns = content.columns || [];
    const allRows = content.rows || [];
    const rows = allRows.slice(0, MAX_ROWS);
    const truncated = allRows.length > MAX_ROWS;
    const title = content.title || "表格";
    const plainText = plainTextFromTable(
      content.title || "",
      content.caption || "",
      columns,
      allRows
    );

    return (
      <MessageBase hiddeBubble={true} message={message} context={context}>
        <div className="wk-hermes-table">
          <div
            className="wk-hermes-table-title"
            onClick={this.open}
            role="button"
          >
            {title}
          </div>
          {content.caption ? (
            <div className="wk-hermes-table-caption">{content.caption}</div>
          ) : null}
          <div className="wk-hermes-table-scroll">
            <TableGrid columns={columns} rows={rows} />
          </div>
          {truncated ? (
            <div className="wk-hermes-table-more">
              仅显示前 {MAX_ROWS} 行
            </div>
          ) : null}
          <button
            type="button"
            className="wk-hermes-table-open"
            onClick={this.open}
          >
            查看完整表格
          </button>
          <div className="wk-hermes-table-foot">
            <MessageTrail message={message} timeStyle={{ color: "#999" }} />
          </div>
        </div>

        <Modal
          className="wk-base-modal wk-hermes-table-modal"
          visible={this.state.open}
          footer={null}
          width="92%"
          centered
          maskClosable
          // Anchor over the message pane only — leave the conversation list uncovered.
          getPopupContainer={() =>
            (document.querySelector(
              ".wk-chat-content-right"
            ) as HTMLElement) || document.body
          }
          onCancel={this.close}
        >
          <div className="wk-hermes-table-modal-inner">
            <div className="wk-hermes-table-modal-head">
              <div className="wk-hermes-table-modal-title">{title}</div>
              <div className="wk-hermes-table-modal-actions">
                <Button
                  theme="borderless"
                  type="primary"
                  onClick={() => this.copyAll(plainText)}
                >
                  复制全部
                </Button>
                <Button theme="borderless" type="tertiary" onClick={this.close}>
                  关闭
                </Button>
              </div>
            </div>
            <div className="wk-hermes-table-modal-body">
              {content.caption ? (
                <div className="wk-hermes-table-caption">{content.caption}</div>
              ) : null}
              <div className="wk-hermes-table-modal-scroll">
                <TableGrid columns={columns} rows={allRows} />
              </div>
              <div className="wk-hermes-table-select-hint">
                下方文本可选中复制
              </div>
              <pre className="wk-hermes-table-selectable">{plainText}</pre>
            </div>
          </div>
        </Modal>
      </MessageBase>
    );
  }
}
