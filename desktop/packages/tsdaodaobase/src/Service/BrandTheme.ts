/** 叙叨品牌主题：石青 / 玄青 / 松烟 / 雾蓝 */

export type BrandThemeId = "shiqing" | "xuanqing" | "songyan" | "wulan";

export type BrandThemePalette = {
  id: BrandThemeId;
  name: string;
  light: string;
  dark: string;
  softLight: string;
  softDark: string;
  mutedLight: string;
  mutedDark: string;
  focusLight: string;
  focusDark: string;
  bubbleLight: string;
  bubbleDark: string;
  hoverLight: string;
  hoverDark: string;
};

export const BRAND_THEMES: Record<BrandThemeId, BrandThemePalette> = {
  shiqing: {
    id: "shiqing",
    name: "石青",
    light: "#0E7490",
    dark: "#38BDF8",
    softLight: "rgba(14, 116, 144, 0.12)",
    softDark: "rgba(56, 189, 248, 0.18)",
    mutedLight: "rgba(14, 116, 144, 0.08)",
    mutedDark: "rgba(56, 189, 248, 0.12)",
    focusLight: "rgba(14, 116, 144, 0.35)",
    focusDark: "rgba(56, 189, 248, 0.4)",
    bubbleLight: "#D0EAF2",
    bubbleDark: "#0C4A5C",
    hoverLight: "#0F8AAB",
    hoverDark: "#7DD3FC",
  },
  xuanqing: {
    id: "xuanqing",
    name: "玄青",
    light: "#1B4D5C",
    dark: "#5FA8B8",
    softLight: "rgba(27, 77, 92, 0.12)",
    softDark: "rgba(95, 168, 184, 0.18)",
    mutedLight: "rgba(27, 77, 92, 0.08)",
    mutedDark: "rgba(95, 168, 184, 0.12)",
    focusLight: "rgba(27, 77, 92, 0.35)",
    focusDark: "rgba(95, 168, 184, 0.4)",
    bubbleLight: "#D9E8EC",
    bubbleDark: "#122F38",
    hoverLight: "#256A7E",
    hoverDark: "#7EBFCC",
  },
  songyan: {
    id: "songyan",
    name: "松烟",
    light: "#1F7A4D",
    dark: "#4ADE80",
    softLight: "rgba(31, 122, 77, 0.12)",
    softDark: "rgba(74, 222, 128, 0.18)",
    mutedLight: "rgba(31, 122, 77, 0.08)",
    mutedDark: "rgba(74, 222, 128, 0.12)",
    focusLight: "rgba(31, 122, 77, 0.35)",
    focusDark: "rgba(74, 222, 128, 0.4)",
    bubbleLight: "#DDF5E8",
    bubbleDark: "#143D28",
    hoverLight: "#25965E",
    hoverDark: "#86EFAC",
  },
  wulan: {
    id: "wulan",
    name: "雾蓝",
    light: "#3B6D9A",
    dark: "#7EB0D9",
    softLight: "rgba(59, 109, 154, 0.12)",
    softDark: "rgba(126, 176, 217, 0.18)",
    mutedLight: "rgba(59, 109, 154, 0.08)",
    mutedDark: "rgba(126, 176, 217, 0.12)",
    focusLight: "rgba(59, 109, 154, 0.35)",
    focusDark: "rgba(126, 176, 217, 0.4)",
    bubbleLight: "#E2ECF5",
    bubbleDark: "#243A52",
    hoverLight: "#4A82B5",
    hoverDark: "#A5C9E8",
  },
};

export const DEFAULT_BRAND_THEME: BrandThemeId = "shiqing";

/** Migrate legacy storage keys */
export function normalizeBrandThemeId(raw?: string | null): BrandThemeId {
  if (!raw) return DEFAULT_BRAND_THEME;
  if (raw === "orange" || raw === "teal" || raw === "lanqing") return "shiqing";
  if (raw === "blue") return "wulan";
  if (raw in BRAND_THEMES) return raw as BrandThemeId;
  return DEFAULT_BRAND_THEME;
}

export function applyBrandThemeToDocument(id: BrandThemeId, isDark: boolean): string {
  const p = BRAND_THEMES[id] || BRAND_THEMES[DEFAULT_BRAND_THEME];
  document.body.setAttribute("data-brand-theme", p.id);
  const root = document.documentElement;
  const theme = isDark ? p.dark : p.light;
  root.style.setProperty("--wk-color-theme", theme);
  root.style.setProperty("--wk-color-theme-soft", isDark ? p.softDark : p.softLight);
  root.style.setProperty("--wk-color-theme-muted", isDark ? p.mutedDark : p.mutedLight);
  root.style.setProperty("--wk-focus-ring", isDark ? p.focusDark : p.focusLight);
  root.style.setProperty("--wk-color-message-send", isDark ? p.bubbleDark : p.bubbleLight);
  root.style.setProperty("--semi-color-primary", theme);
  root.style.setProperty("--semi-color-primary-hover", isDark ? p.hoverDark : p.hoverLight);
  return theme;
}

/** Circle + white glyph avatar as data URI (file helper / system notify / default). */
export function brandCircleAvatarDataUri(
  kind: "fileHelper" | "system" | "defaultPerson",
  color: string,
  size = 96
): string {
  let glyph: string;
  if (kind === "fileHelper") {
    glyph =
      '<path fill="#fff" d="M30 28h36c2.2 0 4 1.8 4 4v8H26v-8c0-2.2 1.8-4 4-4zm-4 16h44v30c0 2.2-1.8 4-4 4H30c-2.2 0-4-1.8-4-4V44z"/>';
  } else if (kind === "system") {
    glyph =
      '<path fill="#fff" d="M48 22c-7.7 0-14 6.3-14 14v8h-2c-2.2 0-4 1.8-4 4v22c0 2.2 1.8 4 4 4h32c2.2 0 4-1.8 4-4V48c0-2.2-1.8-4-4-4h-2v-8c0-7.7-6.3-14-14-14zm0 8c3.3 0 6 2.7 6 6v8H42v-8c0-3.3 2.7-6 6-6zm0 36a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"/>';
  } else {
    glyph =
      '<path fill="#fff" d="M48 26c8.3 0 15 6.7 15 15s-6.7 15-15 15-15-6.7-15-15 6.7-15 15-15zm0 36c14 0 26 7 26 16v6H22v-6c0-9 12-16 26-16z"/>';
  }
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 96 96"><circle cx="48" cy="48" r="48" fill="${color}"/>${glyph}</svg>`;
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
}

/** Theme mark logo (flame swirl) for login / branding surfaces. */
export function brandMarkDataUri(color: string, size = 128): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 128 128"><circle cx="64" cy="64" r="64" fill="${color}"/><path d="M64 22c18 8 26 28 14 48-6 10-18 14-26 8-10-8-6-22 6-28 10-5 16 2 10 10-4 6-12 6-14 0-2-6 4-12 10-10" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round"/><circle cx="64" cy="64" r="8" fill="#fff"/><circle cx="64" cy="64" r="4" fill="${color}"/></svg>`;
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
}

/** White contact-header glyphs (pair with solid theme background). */
export function brandContactIconDataUri(
  kind: "newFriend" | "savedGroup" | "blacklist",
  size = 48
): string {
  let glyph: string;
  if (kind === "newFriend") {
    glyph =
      '<path fill="#fff" d="M20 14a8 8 0 1 1 0 16 8 8 0 0 1 0-16zm0 20c9 0 16 4 16 10v4H4v-4c0-6 7-10 16-10zm18-18v-4h4v4h4v4h-4v4h-4v-4h-4v-4h4z"/>';
  } else if (kind === "savedGroup") {
    glyph =
      '<path fill="#fff" d="M16 18a6 6 0 1 1 0 12 6 6 0 0 1 0-12zm16 2a5 5 0 1 1 0 10 5 5 0 0 1 0-10zM16 32c7 0 12 3 12 8v4H4v-4c0-5 5-8 12-8zm16 2c5 0 10 2 10 6v4H30v-4c0-2 1-4 2-6z"/>';
  } else {
    glyph =
      '<path fill="#fff" d="M24 8c-7 0-12 5-12 12v4H8c-2 0-4 2-4 4v16c0 2 2 4 4 4h32c2 0 4-2 4-4V28c0-2-2-4-4-4h-4v-4c0-7-5-12-12-12zm0 6c4 0 6 2 6 6v4H18v-4c0-4 2-6 6-6zm0 22a3 3 0 1 0 0-6 3 3 0 0 0 0 6z"/>';
  }
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 48 48">${glyph}</svg>`;
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
}
