/** Shared Hermes audio player (conversation top bar). Aligns with iOS WKHermesAudioBar. */

export type HermesAudioPlayRequest = {
  url: string;
  title?: string;
  durationMs?: number;
};

export type HermesAudioPlayerState = {
  visible: boolean;
  playing: boolean;
  title: string;
  url: string;
  current: number; // seconds
  duration: number; // seconds
};

type Listener = (s: HermesAudioPlayerState) => void;

class HermesAudioPlayer {
  private audio = new Audio();
  private listeners = new Set<Listener>();
  private state: HermesAudioPlayerState = {
    visible: false,
    playing: false,
    title: "",
    url: "",
    current: 0,
    duration: 0,
  };

  constructor() {
    this.audio.preload = "metadata";
    this.audio.addEventListener("timeupdate", () => {
      this.patch({
        current: this.audio.currentTime || 0,
        duration: this.effectiveDuration(),
      });
    });
    this.audio.addEventListener("loadedmetadata", () => {
      this.patch({ duration: this.effectiveDuration() });
    });
    this.audio.addEventListener("play", () => this.patch({ playing: true }));
    this.audio.addEventListener("pause", () => this.patch({ playing: false }));
    this.audio.addEventListener("ended", () => {
      this.patch({ playing: false, current: 0 });
      try {
        this.audio.currentTime = 0;
      } catch {
        /* ignore */
      }
    });
    this.audio.addEventListener("error", () => {
      this.patch({ playing: false });
    });
  }

  getSnapshot(): HermesAudioPlayerState {
    return { ...this.state };
  }

  subscribe(fn: Listener): () => void {
    this.listeners.add(fn);
    fn(this.getSnapshot());
    return () => this.listeners.delete(fn);
  }

  private emit() {
    const snap = this.getSnapshot();
    this.listeners.forEach((fn) => fn(snap));
  }

  private patch(partial: Partial<HermesAudioPlayerState>) {
    this.state = { ...this.state, ...partial };
    this.emit();
  }

  private effectiveDuration(): number {
    const d = this.audio.duration;
    if (Number.isFinite(d) && d > 0) return d;
    return this.state.duration || 0;
  }

  play(req: HermesAudioPlayRequest) {
    const url = (req.url || "").trim();
    if (!url) return;
    const title = (req.title || "").trim() || "Hermes 音频";
    const hintDur =
      req.durationMs && req.durationMs > 0 ? req.durationMs / 1000 : 0;

    this.audio.pause();
    this.audio.src = url;
    this.patch({
      visible: true,
      playing: false,
      title,
      url,
      current: 0,
      duration: hintDur,
    });
    const p = this.audio.play();
    if (p && typeof p.catch === "function") {
      p.catch(() => this.patch({ playing: false }));
    }
  }

  toggle() {
    if (!this.state.visible || !this.state.url) return;
    if (this.audio.paused) {
      const p = this.audio.play();
      if (p && typeof p.catch === "function") p.catch(() => undefined);
    } else {
      this.audio.pause();
    }
  }

  seek(seconds: number) {
    if (!Number.isFinite(seconds)) return;
    try {
      this.audio.currentTime = Math.max(0, seconds);
      this.patch({ current: this.audio.currentTime });
    } catch {
      /* ignore */
    }
  }

  stopAndHide() {
    this.audio.pause();
    try {
      this.audio.removeAttribute("src");
      this.audio.load();
    } catch {
      /* ignore */
    }
    this.patch({
      visible: false,
      playing: false,
      title: "",
      url: "",
      current: 0,
      duration: 0,
    });
  }
}

export const hermesAudioPlayer = new HermesAudioPlayer();
