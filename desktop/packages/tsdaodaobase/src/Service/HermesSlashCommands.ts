/** Hermes / 机器人斜杠指令（中文说明） */

export type SlashCommandItem = {
  cmd: string;
  remark: string;
  robotID?: string;
};

export const HERMES_SLASH_COMMANDS: SlashCommandItem[] = [
  { cmd: "/new", remark: "开始新对话" },
  { cmd: "/reset", remark: "重置会话（同 /new）" },
  { cmd: "/model", remark: "切换 AI 模型" },
  { cmd: "/personality", remark: "设置人格" },
  { cmd: "/retry", remark: "重试上一轮回复" },
  { cmd: "/undo", remark: "撤销上一轮" },
  { cmd: "/compress", remark: "压缩上下文" },
  { cmd: "/usage", remark: "查看用量" },
  { cmd: "/insights", remark: "用量洞察" },
  { cmd: "/skills", remark: "浏览技能列表" },
  { cmd: "/stop", remark: "中断当前任务" },
  { cmd: "/status", remark: "查看平台状态" },
  { cmd: "/help", remark: "显示帮助" },
  { cmd: "/approve", remark: "批准待确认操作" },
  { cmd: "/deny", remark: "拒绝待确认操作" },
];

const hasCJK = (s: string) => /[\u4e00-\u9fff]/.test(s);

/** 合并服务端 menus（若有）与本地中文兜底，并按当前 /token 过滤 */
export function filterSlashCommands(
  token: string,
  serverMenus?: Array<{ cmd?: string; remark?: string; robotID?: string }>,
  preferredRobotID?: string
): SlashCommandItem[] {
  const seen = new Set<string>();
  const items: SlashCommandItem[] = [];
  const zh = new Map(
    HERMES_SLASH_COMMANDS.map((c) => [c.cmd.toLowerCase(), c.remark])
  );

  const push = (rawCmd: string, rawRemark?: string, robotID?: string) => {
    let cmd = (rawCmd || "").trim();
    if (!cmd) return;
    if (!cmd.startsWith("/")) cmd = `/${cmd}`;
    const key = cmd.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    let remark = (rawRemark || "").trim();
    if (!remark || !hasCJK(remark)) {
      remark = zh.get(key) || "执行指令";
    }
    items.push({
      cmd,
      remark,
      robotID: robotID || preferredRobotID,
    });
  };

  if (serverMenus?.length) {
    for (const m of serverMenus) {
      push(m.cmd || "", m.remark, m.robotID || preferredRobotID);
    }
  }
  for (const c of HERMES_SLASH_COMMANDS) {
    push(c.cmd, c.remark, preferredRobotID);
  }

  const t = (token || "").trim().toLowerCase();
  if (!t.startsWith("/")) return [];

  let matched = items.filter((i) => i.cmd.toLowerCase().startsWith(t));
  if (matched.length === 0 && t.length > 1) {
    const q = t.slice(1);
    matched = items.filter(
      (i) => i.remark.includes(q) || i.cmd.toLowerCase().includes(q)
    );
  }
  return matched;
}
