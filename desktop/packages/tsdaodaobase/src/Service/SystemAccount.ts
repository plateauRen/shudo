/** Built-in system account UIDs / display names (align with iOS WKAppConfig). */
export const FILE_HELPER_UID = "fileHelper";
export const SYSTEM_NOTIFY_UID = "u_10000";

export function isSystemAccount(uid?: string): boolean {
  if (!uid) return false;
  return uid === FILE_HELPER_UID || uid === SYSTEM_NOTIFY_UID;
}

export function systemAccountDisplayName(uid?: string): string | undefined {
  if (!uid) return undefined;
  if (uid === FILE_HELPER_UID) return "文件传输助手";
  if (uid === SYSTEM_NOTIFY_UID) return "系统通知";
  return undefined;
}
