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

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function hermesTableToHtml(content: {
  title?: string;
  caption?: string;
  columns?: HermesTableColumn[];
  rows?: Record<string, any>[];
}): string {
  const columns = content.columns || [];
  const rows = content.rows || [];
  if (!columns.length) return "";
  const captionParts = [content.title, content.caption].filter(Boolean);
  const caption = captionParts.length
    ? `<caption>${escapeHtml(captionParts.join(" — "))}</caption>`
    : "";
  const th = columns
    .map((c) => `<th>${escapeHtml(c.label || c.id)}</th>`)
    .join("");
  const body = rows
    .map((row) => {
      const tds = columns
        .map((c) => {
          const raw = row?.[c.id];
          const val = raw == null ? "" : String(raw);
          return `<td>${escapeHtml(val)}</td>`;
        })
        .join("");
      return `<tr>${tds}</tr>`;
    })
    .join("");
  return `<table>${caption}<thead><tr>${th}</tr></thead><tbody>${body}</tbody></table>`;
}

export function hermesTableToPlainText(content: HermesTableContent): string {
  const structured = plainTextFromTable(
    content.title || "",
    content.caption || "",
    content.columns || [],
    content.rows || []
  );
  if (structured) return structured;
  return (content.contentText || "").trim();
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

type CellState = { open: boolean; menuOpen: boolean; draftRows: Record<string, any>[]; draftCols: HermesTableColumn[] };

export class HermesTableCell extends MessageCell<any, CellState> {
  state: CellState = {
    open: false,
    menuOpen: false,
    draftRows: [],
    draftCols: [],
  };

  open = () => {
    const content = this.props.message.content as HermesTableContent;
    this.setState({
      open: true,
      menuOpen: false,
      draftRows: (content.rows || []).map((r) => ({ ...r })),
      draftCols: (content.columns || []).map((c) => ({ ...c })),
    });
  };
  close = () => this.setState({ open: false, menuOpen: false });

  toggleMenu = (e?: React.MouseEvent) => {
    e?.stopPropagation();
    this.setState({ menuOpen: !this.state.menuOpen });
  };

  copyAll = async (text: string, html?: string) => {
    try {
      if (html && navigator.clipboard?.write && typeof ClipboardItem !== "undefined") {
        const item = new ClipboardItem({
          "text/plain": new Blob([text || ""], { type: "text/plain" }),
          "text/html": new Blob([html], { type: "text/html" }),
        });
        await navigator.clipboard.write([item]);
      } else if (navigator.clipboard?.writeText) {
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
      this.setState({ menuOpen: false });
    } catch {
      Toast.error("复制失败");
    }
  };

  addRow = (after: boolean) => {
    const { draftCols, draftRows } = this.state;
    const empty: Record<string, any> = {};
    for (const c of draftCols) empty[c.id] = "";
    const next = [...draftRows];
    if (after) next.push(empty);
    else next.unshift(empty);
    this.setState({ draftRows: next, open: true, menuOpen: false });
    Toast.success(after ? "已在下方添加行" : "已在上方添加行");
  };

  addColumn = (after: boolean) => {
    const { draftCols, draftRows } = this.state;
    const id = `col_${Date.now().toString(36)}`;
    const col: HermesTableColumn = {
      id,
      label: `列${draftCols.length + 1}`,
      align: "left",
    };
    const cols = after ? [...draftCols, col] : [col, ...draftCols];
    const rows = draftRows.map((r) => ({ ...r, [id]: "" }));
    this.setState({ draftCols: cols, draftRows: rows, open: true, menuOpen: false });
    Toast.success(after ? "已在右侧添加列" : "已在左侧添加列");
  };

  render() {
    const { message, context } = this.props;
    const content = message.content as HermesTableContent;
    const columns = this.state.open && this.state.draftCols.length
      ? this.state.draftCols
      : content.columns || [];
    const allRows = this.state.open && this.state.draftRows.length
      ? this.state.draftRows
      : content.rows || [];
    const rows = allRows.slice(0, MAX_ROWS);
    const truncated = allRows.length > MAX_ROWS;
    const title = content.title || "表格";
    const plainText =
      plainTextFromTable(
        content.title || "",
        content.caption || "",
        columns,
        allRows
      ) || (content.contentText || "").trim();
    const htmlText = hermesTableToHtml({
      title: content.title,
      caption: content.caption,
      columns,
      rows: allRows,
    });

    return (
      <MessageBase hiddeBubble={true} message={message} context={context}>
        <div className="wk-hermes-table">
          <div className="wk-hermes-table-head">
            <div
              className="wk-hermes-table-title"
              onClick={this.open}
              role="button"
            >
              {title}
            </div>
            <button
              type="button"
              className="wk-hermes-table-morebtn"
              title="表格设置"
              aria-label="表格设置"
              onClick={this.toggleMenu}
            >
              <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden>
                <circle cx="12" cy="5" r="1.8" fill="currentColor" />
                <circle cx="12" cy="12" r="1.8" fill="currentColor" />
                <circle cx="12" cy="19" r="1.8" fill="currentColor" />
              </svg>
            </button>
          </div>
          {this.state.menuOpen ? (
            <div className="wk-hermes-table-menu" role="menu">
              <button type="button" onClick={this.open}>
                查看完整表格
              </button>
              <button type="button" onClick={() => this.copyAll(plainText, htmlText)}>
                复制全部
              </button>
              <div className="wk-hermes-table-menu-sep" />
              <button type="button" onClick={() => this.addRow(false)}>
                在上方添加行
              </button>
              <button type="button" onClick={() => this.addRow(true)}>
                在下方添加行
              </button>
              <button type="button" onClick={() => this.addColumn(false)}>
                在左侧添加列
              </button>
              <button type="button" onClick={() => this.addColumn(true)}>
                在右侧添加列
              </button>
            </div>
          ) : null}
          {content.caption ? (
            <div className="wk-hermes-table-caption">{content.caption}</div>
          ) : null}
          <div className="wk-hermes-table-scroll">
            <TableGrid columns={content.columns || []} rows={(content.rows || []).slice(0, MAX_ROWS)} />
          </div>
          {truncated && !this.state.open ? (
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
                  type="tertiary"
                  onClick={() => this.addRow(true)}
                >
                  加行
                </Button>
                <Button
                  theme="borderless"
                  type="tertiary"
                  onClick={() => this.addColumn(true)}
                >
                  加列
                </Button>
                <Button
                  theme="borderless"
                  type="primary"
                  onClick={() => this.copyAll(plainText, htmlText)}
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
                下方文本可选中复制（加行/加列为本地预览，复制后使用）
              </div>
              <pre className="wk-hermes-table-selectable">{plainText}</pre>
            </div>
          </div>
        </Modal>
      </MessageBase>
    );
  }
}
