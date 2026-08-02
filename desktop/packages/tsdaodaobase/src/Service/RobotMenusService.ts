import WKApp from "../App";

export type RobotMenuItem = {
  cmd: string;
  remark: string;
  robotID: string;
  type?: string;
};

export type RobotInfo = {
  robotID: string;
  version: number;
  menus: RobotMenuItem[];
  username?: string;
  inlineOn?: boolean;
};

type RobotCacheEntry = RobotInfo;

/**
 * Sync robot menus via POST robot/sync (same as iOS WKRobotManager).
 */
class RobotMenusService {
  private cache = new Map<string, RobotCacheEntry>(); // by robot_id
  private byUsername = new Map<string, string>(); // username -> robot_id

  private ingestRow(row: any) {
    const robotID = String(row?.robot_id || "");
    if (!robotID) return;
    const menusRaw = Array.isArray(row?.menus) ? row.menus : [];
    const menus: RobotMenuItem[] = menusRaw
      .map((m: any) => {
        let cmd = String(m?.cmd || "").trim();
        if (!cmd) return null;
        if (!cmd.startsWith("/")) cmd = `/${cmd}`;
        return {
          cmd,
          remark: String(m?.remark || ""),
          robotID,
          type: m?.type ? String(m.type) : undefined,
        } as RobotMenuItem;
      })
      .filter(Boolean) as RobotMenuItem[];

    const username = row?.username ? String(row.username) : undefined;
    const entry: RobotCacheEntry = {
      robotID,
      version: Number(row?.version) || 0,
      menus,
      username,
      inlineOn: Boolean(row?.inline_on),
    };
    this.cache.set(robotID, entry);
    if (username) {
      this.byUsername.set(username.toLowerCase(), robotID);
    }
  }

  getMenus(robotIDs: string[]): RobotMenuItem[] {
    const out: RobotMenuItem[] = [];
    for (const id of robotIDs) {
      const entry = this.cache.get(id);
      if (entry?.menus?.length) out.push(...entry.menus);
    }
    return out;
  }

  preferredRobotID(robotIDs: string[]): string | undefined {
    for (const id of robotIDs) {
      const entry = this.cache.get(id);
      if (entry?.menus?.length) return id;
    }
    return robotIDs[0];
  }

  getByUsername(username: string): RobotInfo | undefined {
    const id = this.byUsername.get((username || "").toLowerCase());
    if (!id) return undefined;
    return this.cache.get(id);
  }

  async sync(robotIDs: string[]): Promise<RobotMenuItem[]> {
    const ids = Array.from(new Set((robotIDs || []).filter(Boolean)));
    if (ids.length === 0) return [];

    const body = ids.map((robot_id) => ({
      robot_id,
      version: this.cache.get(robot_id)?.version ?? 0,
    }));

    try {
      const results: any[] = await WKApp.apiClient.post("robot/sync", body);
      if (Array.isArray(results)) {
        for (const row of results) this.ingestRow(row);
      }
    } catch (err) {
      console.warn("[RobotMenusService] sync failed", err);
    }

    return this.getMenus(ids);
  }

  /** Sync by username (iOS syncWithUsernames). */
  async syncByUsername(username: string): Promise<RobotInfo | undefined> {
    const u = (username || "").trim();
    if (!u) return undefined;
    const cached = this.getByUsername(u);
    const body = [
      {
        username: u,
        version: cached?.version ?? 0,
      },
    ];
    try {
      const results: any[] = await WKApp.apiClient.post("robot/sync", body);
      if (Array.isArray(results)) {
        for (const row of results) this.ingestRow(row);
      }
    } catch (err) {
      console.warn("[RobotMenusService] syncByUsername failed", err);
    }
    return this.getByUsername(u);
  }
}

export const robotMenusService = new RobotMenusService();
