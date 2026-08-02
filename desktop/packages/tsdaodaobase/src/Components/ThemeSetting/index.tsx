import React, { useEffect, useState } from "react";
import { Modal, Radio, RadioGroup, Toast } from "@douyinfe/semi-ui";
import WKApp, { ThemeMode } from "../../App";
import {
  BrandThemeId,
  BRAND_THEMES,
  DEFAULT_BRAND_THEME,
} from "../../Service/BrandTheme";

type Props = {
  visible: boolean;
  onClose: () => void;
};

const BRAND_ORDER: BrandThemeId[] = ["shiqing", "xuanqing", "songyan", "wulan"];

export function ThemeSettingModal({ visible, onClose }: Props) {
  const [mode, setMode] = useState<ThemeMode>(WKApp.config.themeMode);
  const [brand, setBrand] = useState<BrandThemeId>(WKApp.config.brandTheme);

  useEffect(() => {
    if (visible) {
      setMode(WKApp.config.themeMode);
      setBrand(WKApp.config.brandTheme || DEFAULT_BRAND_THEME);
    }
  }, [visible]);

  return (
    <Modal
      title="主题设置"
      visible={visible}
      onCancel={onClose}
      onOk={() => {
        WKApp.config.brandTheme = brand;
        WKApp.config.themeMode = mode;
        const name = BRAND_THEMES[brand]?.name ?? "石青";
        Toast.success(
          `已切换为${name} · ${mode === ThemeMode.dark ? "深色" : "浅色"}`
        );
        onClose();
      }}
      okText="保存"
      cancelText="取消"
    >
      <div style={{ marginBottom: 8, color: "var(--wk-text-secondary, #666)", fontSize: 13 }}>
        选择品牌主题色与界面外观。主题色将应用于按钮、链接、气泡、Logo 与默认头像。
      </div>
      <div style={{ marginBottom: 6, fontWeight: 500 }}>品牌色</div>
      <RadioGroup
        direction="vertical"
        value={brand}
        onChange={(e) => setBrand(e.target.value as BrandThemeId)}
        style={{ marginBottom: 16 }}
      >
        {BRAND_ORDER.map((id) => {
          const p = BRAND_THEMES[id];
          return (
            <Radio key={id} value={id}>
              <span style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
                <span
                  style={{
                    width: 14,
                    height: 14,
                    borderRadius: "50%",
                    background: p.light,
                    display: "inline-block",
                    boxShadow: `0 0 0 2px ${p.softLight}`,
                  }}
                />
                {p.name}
              </span>
            </Radio>
          );
        })}
      </RadioGroup>
      <div style={{ marginBottom: 6, fontWeight: 500 }}>外观</div>
      <RadioGroup
        direction="vertical"
        value={mode}
        onChange={(e) => setMode(Number(e.target.value) as ThemeMode)}
      >
        <Radio value={ThemeMode.light}>浅色</Radio>
        <Radio value={ThemeMode.dark}>深色</Radio>
      </RadioGroup>
    </Modal>
  );
}
