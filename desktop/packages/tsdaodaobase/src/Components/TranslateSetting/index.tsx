import React, { useState } from "react";
import { Modal, Switch, Radio, RadioGroup, Toast } from "@douyinfe/semi-ui";
import { translateManager } from "../../Service/TranslateManager";

type Props = {
  visible: boolean;
  onClose: () => void;
};

export function TranslateSettingModal({ visible, onClose }: Props) {
  const [autoOn, setAutoOn] = useState(translateManager.autoTranslateEnabled);
  const [target, setTarget] = useState(translateManager.targetLanguage);

  return (
    <Modal
      title="翻译设置"
      visible={visible}
      onCancel={onClose}
      onOk={() => {
        translateManager.autoTranslateEnabled = autoOn;
        translateManager.targetLanguage = target;
        Toast.success("已保存");
        onClose();
      }}
      okText="保存"
      cancelText="取消"
    >
      <div style={{ marginBottom: 16 }}>
        <div style={{ marginBottom: 8, color: "#666", fontSize: 13 }}>
          开启后，会话中收到的文本消息将自动翻译为目标语言，并显示在原文下方。
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span>自动翻译</span>
          <Switch checked={autoOn} onChange={setAutoOn} />
        </div>
      </div>
      <div>
        <div style={{ marginBottom: 8 }}>目标语言</div>
        <RadioGroup
          direction="vertical"
          value={target}
          onChange={(e) => setTarget(e.target.value)}
        >
          {translateManager.supportedLanguages.map((l) => (
            <Radio key={l.code} value={l.code}>
              {l.name}
            </Radio>
          ))}
        </RadioGroup>
      </div>
    </Modal>
  );
}
