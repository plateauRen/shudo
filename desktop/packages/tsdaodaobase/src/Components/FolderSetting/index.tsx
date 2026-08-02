import React, { useEffect, useState } from "react";
import { Button, Input, Modal, Toast } from "@douyinfe/semi-ui";
import {
  shudoOrgManager,
  ShudoFolder,
  TOPICS_GROUP_NAME,
} from "../../Service/ShudoOrgManager";

type Props = {
  visible: boolean;
  onClose: () => void;
  /** 打开时若传入初始名称，自动填入创建框 */
  initialCreateName?: string;
};

export function FolderSettingModal({
  visible,
  onClose,
  initialCreateName,
}: Props) {
  const [folders, setFolders] = useState<ShudoFolder[]>([]);
  const [name, setName] = useState("");
  const [loading, setLoading] = useState(false);

  const reload = async () => {
    setLoading(true);
    try {
      const list = await shudoOrgManager.refreshFolders();
      setFolders(list);
    } catch (e: any) {
      Toast.error(e?.msg || e?.message || "加载失败");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (visible) {
      shudoOrgManager.loadCache();
      setFolders(shudoOrgManager.folders);
      setName(initialCreateName || "");
      reload();
    }
  }, [visible, initialCreateName]);

  return (
    <Modal
      title="管理分组"
      visible={visible}
      onCancel={onClose}
      footer={null}
      width={420}
    >
      <div
        style={{
          marginBottom: 12,
          color: "var(--wk-text-secondary, #666)",
          fontSize: 13,
        }}
      >
        用分组整理会话列表。系统默认提供「{TOPICS_GROUP_NAME}」分组，新建话题会自动归入。
      </div>
      <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        <Input
          value={name}
          placeholder="新分组名称"
          maxLength={20}
          onChange={setName}
        />
        <Button
          theme="solid"
          type="primary"
          loading={loading}
          onClick={async () => {
            const n = name.trim();
            if (!n) {
              Toast.warning("请输入名称");
              return;
            }
            try {
              await shudoOrgManager.createFolder(n);
              setName("");
              Toast.success("已创建分组");
              await reload();
            } catch (e: any) {
              Toast.error(e?.msg || e?.message || "创建失败");
            }
          }}
        >
          创建
        </Button>
      </div>
      <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
        {folders.map((f) => {
          const isTopics = f.name === TOPICS_GROUP_NAME;
          return (
            <li
              key={f.folder_id}
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                padding: "10px 0",
                borderBottom: "1px solid var(--wk-border-subtle, #eee)",
              }}
            >
              <div>
                <div style={{ fontWeight: 600 }}>
                  {f.name}
                  {isTopics ? (
                    <span
                      style={{
                        marginLeft: 8,
                        fontSize: 12,
                        color: "var(--wk-color-theme, #0E7490)",
                        fontWeight: 500,
                      }}
                    >
                      默认
                    </span>
                  ) : null}
                </div>
                <div style={{ fontSize: 12, color: "#8A9199" }}>
                  {f.items?.length || 0} 个会话
                </div>
              </div>
              <div style={{ display: "flex", gap: 8 }}>
                <Button
                  size="small"
                  disabled={isTopics}
                  onClick={async () => {
                    const next = window.prompt("重命名分组", f.name);
                    if (!next || !next.trim()) return;
                    try {
                      await shudoOrgManager.renameFolder(
                        f.folder_id,
                        next.trim()
                      );
                      await reload();
                    } catch (e: any) {
                      Toast.error(e?.msg || e?.message || "失败");
                    }
                  }}
                >
                  重命名
                </Button>
                <Button
                  size="small"
                  type="danger"
                  disabled={isTopics}
                  onClick={async () => {
                    if (!window.confirm(`删除分组「${f.name}」？`)) return;
                    try {
                      await shudoOrgManager.deleteFolder(f.folder_id);
                      await reload();
                    } catch (e: any) {
                      Toast.error(e?.msg || e?.message || "失败");
                    }
                  }}
                >
                  删除
                </Button>
              </div>
            </li>
          );
        })}
        {!folders.length ? (
          <li style={{ color: "#8A9199", padding: "12px 0" }}>暂无分组</li>
        ) : null}
      </ul>
    </Modal>
  );
}
