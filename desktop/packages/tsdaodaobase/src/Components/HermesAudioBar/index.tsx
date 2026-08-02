import React, { useEffect, useState } from "react";
import {
  hermesAudioPlayer,
  HermesAudioPlayerState,
} from "../../Service/HermesAudioPlayer";
import "./HermesAudioBar.css";

function fmt(t: number): string {
  if (!Number.isFinite(t) || t < 0) t = 0;
  const s = Math.floor(t);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r.toString().padStart(2, "0")}`;
}

export function HermesAudioBar() {
  const [state, setState] = useState<HermesAudioPlayerState>(
    hermesAudioPlayer.getSnapshot()
  );

  useEffect(() => hermesAudioPlayer.subscribe(setState), []);

  if (!state.visible) return null;

  const max = Math.max(state.duration || 0, 0.1);

  return (
    <div className="wk-hermes-audio-bar" role="region" aria-label="音频播报">
      <div className="wk-hermes-audio-bar-chrome">
        <button
          type="button"
          className="wk-hermes-audio-bar-play"
          aria-label={state.playing ? "暂停" : "播放"}
          onClick={() => hermesAudioPlayer.toggle()}
        >
          {state.playing ? "❚❚" : "▶"}
        </button>
        <div className="wk-hermes-audio-bar-body">
          <div className="wk-hermes-audio-bar-title">{state.title}</div>
          <input
            className="wk-hermes-audio-bar-slider"
            type="range"
            min={0}
            max={max}
            step={0.1}
            value={Math.min(state.current, max)}
            onChange={(e) => hermesAudioPlayer.seek(Number(e.target.value))}
          />
        </div>
        <div className="wk-hermes-audio-bar-time">
          {fmt(state.current)}
          {state.duration > 0 ? ` / ${fmt(state.duration)}` : ""}
        </div>
        <button
          type="button"
          className="wk-hermes-audio-bar-close"
          aria-label="关闭"
          onClick={() => hermesAudioPlayer.stopAndHide()}
        >
          ×
        </button>
      </div>
    </div>
  );
}
