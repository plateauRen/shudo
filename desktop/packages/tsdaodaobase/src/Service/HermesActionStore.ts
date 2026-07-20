const STORE_KEY = "wk.hermes.action.store.v1";
const MAX_ENTRIES = 200;

type ActedInfo = { action: string; label: string; ts: number };

function loadStore(): Record<string, ActedInfo> {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function saveStore(store: Record<string, ActedInfo>) {
  localStorage.setItem(STORE_KEY, JSON.stringify(store));
}

export class HermesActionStore {
  static markActed(cardId: string, action: string, label: string) {
    if (!cardId || !action) return;
    const store = loadStore();
    store[cardId] = {
      action,
      label: label || action,
      ts: Date.now() / 1000,
    };
    const keys = Object.keys(store);
    if (keys.length > MAX_ENTRIES) {
      keys
        .sort((a, b) => (store[a].ts || 0) - (store[b].ts || 0))
        .slice(0, keys.length - MAX_ENTRIES)
        .forEach((k) => delete store[k]);
    }
    saveStore(store);
  }

  static infoForCardId(cardId?: string | null): ActedInfo | undefined {
    if (!cardId) return undefined;
    return loadStore()[cardId];
  }

  static isActed(cardId?: string | null): boolean {
    return !!this.infoForCardId(cardId);
  }
}
