import React, { useEffect, useState } from "react";
import { Toast } from "@douyinfe/semi-ui";
import { MessageContent } from "wukongimjssdk";
import MessageBase from "../Base";
import MessageTrail from "../Base/tail";
import { MessageCell } from "../MessageCell";
import { MessageContentTypeConst } from "../../Service/Const";
import {
  hermesAudioPlayer,
  HermesAudioPlayerState,
} from "../../Service/HermesAudioPlayer";
import "./Audio.css";

export class HermesAudioContent extends MessageContent {
  v = 1;
  kind = "hermes.audio";
  title = "";
  contentText = "";
  url = "";
  durationMs = 0;
  mime = "";
  meta?: any;

  decodeJSON(content: any) {
    this.v = content?.v || 1;
    this.kind = content?.kind || "hermes.audio";
    this.title = content?.title || "";
    this.contentText = content?.content || this.title || "";
    this.url = content?.url || "";
    this.durationMs = Number(content?.duration_ms) || 0;
    this.mime = content?.mime || "";
    this.meta = content?.meta;
  }

  encodeJSON() {
    return {
      v: this.v || 1,
      kind: "hermes.audio",
      title: this.title || "",
      content: this.contentText || "",
      url: this.url || "",
      duration_ms: this.durationMs || undefined,
      mime: this.mime || undefined,
      meta: this.meta,
    };
  }

  get contentType() {
    return MessageContentTypeConst.hermesAudio;
  }

  get conversationDigest() {
    return this.title ? `[音频] ${this.title}` : "[音频]";
  }
}

function fmtTime(ms: number): string {
  if (!ms || ms <= 0) return "";
  const s = Math.round(ms / 1000);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r.toString().padStart(2, "0")}`;
}

function fmtCurrent(t: number): string {
  if (!Number.isFinite(t) || t < 0) return "0:00";
  const m = Math.floor(t / 60);
  const r = Math.floor(t % 60);
  return `${m}:${r.toString().padStart(2, "0")}`;
}

interface AudioCardProps {
  content: HermesAudioContent;
}

function AudioCard({ content }: AudioCardProps) {
  const [player, setPlayer] = useState<HermesAudioPlayerState>(
    hermesAudioPlayer.getSnapshot()
  );

  useEffect(() => hermesAudioPlayer.subscribe(setPlayer), []);

  const canPlay = Boolean(content?.url);
  const isActive = player.visible && player.url === content.url;
  const isPlaying = isActive && player.playing;
  const title = content.title || content.contentText || "Hermes 音频";
  const totalDur = fmtTime(content.durationMs);
  const currentLabel = isActive ? fmtCurrent(player.current) : "";
  const durationLabel =
    isActive && player.duration > 0
      ? fmtCurrent(player.duration)
      : totalDur;

  const progress =
    isActive && player.duration > 0
      ? Math.min((player.current / player.duration) * 100, 100)
      : 0;

  const handleClick = () => {
    if (!canPlay) {
      Toast.warning("无音频地址");
      return;
    }
    if (isActive) {
      hermesAudioPlayer.toggle();
    } else {
      hermesAudioPlayer.play({
        url: content.url,
        title,
        durationMs: content.durationMs,
      });
    }
  };

  return (
    <div
      className={
        "wk-hermes-audio" +
        (!canPlay ? " wk-hermes-audio-disabled" : "") +
        (isPlaying ? " wk-hermes-audio-playing" : "")
      }
      onClick={canPlay ? handleClick : undefined}
      role={canPlay ? "button" : undefined}
      aria-label={isPlaying ? `暂停 ${title}` : `播放 ${title}`}
    >
      <button
        type="button"
        className="wk-hermes-audio-btn"
        disabled={!canPlay}
        onClick={(e) => {
          e.stopPropagation();
          handleClick();
        }}
        aria-label={isPlaying ? "暂停" : "播放"}
      >
        {isPlaying ? (
          <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
            <rect x="2" y="2" width="4" height="12" rx="1" />
            <rect x="10" y="2" width="4" height="12" rx="1" />
          </svg>
        ) : (
          <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
            <path d="M4 2.5v11l10-5.5z" />
          </svg>
        )}
      </button>

      <div className="wk-hermes-audio-body">
        <div className="wk-hermes-audio-top">
          <span className="wk-hermes-audio-title">{title}</span>
          <span className="wk-hermes-audio-dur">
            {isActive ? `${currentLabel} / ${durationLabel}` : totalDur}
          </span>
        </div>

        {isActive && (
          <div className="wk-hermes-audio-track">
            <div
              className="wk-hermes-audio-fill"
              style={{ width: `${progress}%` }}
            />
          </div>
        )}
      </div>
    </div>
  );
}

export class HermesAudioCell extends MessageCell<any, {}> {
  render() {
    const { message, context } = this.props;
    const content = message.content as HermesAudioContent;

    return (
      <MessageBase hiddeBubble={true} message={message} context={context}>
        <AudioCard content={content} />
        <MessageTrail message={message} />
      </MessageBase>
    );
  }
}
