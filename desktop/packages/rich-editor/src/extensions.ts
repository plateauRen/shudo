import StarterKit from "@tiptap/starter-kit";
import Underline from "@tiptap/extension-underline";
import Link from "@tiptap/extension-link";
import { Placeholder } from "@tiptap/extensions";
import { TextStyle, Color, FontSize } from "@tiptap/extension-text-style";
import { Table, TableRow, TableCell, TableHeader } from "@tiptap/extension-table";
import { TableClipboard } from "./tablePaste";

export function createEditorExtensions(placeholder = "输入富文本消息…") {
  return [
    StarterKit.configure({
      codeBlock: {
        HTMLAttributes: { class: "wk-rich-codeblock" },
      },
    }),
    Underline,
    TextStyle,
    Color,
    FontSize,
    Link.configure({
      openOnClick: false,
      HTMLAttributes: { rel: "noopener noreferrer", target: "_blank" },
    }),
    Placeholder.configure({ placeholder }),
    Table.configure({
      resizable: false,
      HTMLAttributes: { class: "wk-rich-table" },
    }),
    TableRow,
    TableHeader,
    TableCell,
    TableClipboard,
  ];
}
