"""
Shudo (叙叨) translation microservice.

POST /v1/common/translate
Body: { "text": "...", "target": "zh-CN", "source": "auto" }
Resp: { "text": "...", "translated": "...", "target": "zh-CN", "source": "en" }

Provider via TRANSLATE_PROVIDER:
  - google  (deep-translator / Google, default for local)
  - deepl   (requires DEEPL_API_KEY)
  - libre   (requires LIBRETRANSLATE_URL)
"""

from __future__ import annotations

import os
import re
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Shudo Translate", version="1.0.0")

PROVIDER = os.getenv("TRANSLATE_PROVIDER", "google").lower()
DEEPL_API_KEY = os.getenv("DEEPL_API_KEY", "")
LIBRETRANSLATE_URL = os.getenv("LIBRETRANSLATE_URL", "").rstrip("/")

# Map common BCP-47 / UI codes to provider codes.
LANG_MAP = {
    "zh": "zh-CN",
    "zh-cn": "zh-CN",
    "zh-hans": "zh-CN",
    "zh-tw": "zh-TW",
    "zh-hant": "zh-TW",
    "en": "en",
    "ja": "ja",
    "ko": "ko",
    "fr": "fr",
    "de": "de",
    "es": "es",
    "ru": "ru",
    "auto": "auto",
}


class TranslateRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=8000)
    target: str = Field(default="zh-CN")
    source: str = Field(default="auto")


class TranslateResponse(BaseModel):
    text: str
    translated: str
    target: str
    source: str


def normalize_lang(code: str) -> str:
    if not code:
        return "auto"
    key = code.strip().replace("_", "-")
    lower = key.lower()
    return LANG_MAP.get(lower, key)


def looks_mostly_target(text: str, target: str) -> bool:
    """Cheap skip: Chinese target + CJK-heavy text."""
    t = target.lower()
    if t.startswith("zh"):
        cjk = len(re.findall(r"[\u4e00-\u9fff]", text))
        return cjk >= max(1, int(len(text) * 0.35))
    if t.startswith("en"):
        letters = len(re.findall(r"[A-Za-z]", text))
        return letters >= max(1, int(len(text) * 0.5)) and not re.search(r"[\u4e00-\u9fff]", text)
    return False


def translate_google(text: str, target: str, source: str) -> tuple[str, str]:
    from deep_translator import GoogleTranslator

    tgt = "zh-CN" if target.lower() in ("zh", "zh-cn", "zh-hans") else target
    src = "auto" if source == "auto" else source
    translator = GoogleTranslator(source=src, target=tgt)
    out = translator.translate(text)
    return out or text, src


def translate_deepl(text: str, target: str, source: str) -> tuple[str, str]:
    if not DEEPL_API_KEY:
        raise HTTPException(status_code=500, detail="DEEPL_API_KEY not configured")
    import httpx

    tgt = target.upper().replace("ZH-CN", "ZH").replace("ZH-TW", "ZH")
    if tgt == "ZH-HANS":
        tgt = "ZH"
    payload = {"text": [text], "target_lang": tgt}
    if source and source != "auto":
        payload["source_lang"] = source.upper()
    headers = {"Authorization": f"DeepL-Auth-Key {DEEPL_API_KEY}"}
    url = "https://api-free.deepl.com/v2/translate"
    if os.getenv("DEEPL_API_URL"):
        url = os.getenv("DEEPL_API_URL").rstrip("/") + "/v2/translate"
    with httpx.Client(timeout=30.0) as client:
        r = client.post(url, headers=headers, json=payload)
        if r.status_code >= 400:
            raise HTTPException(status_code=502, detail=f"DeepL error: {r.text}")
        data = r.json()
        item = data["translations"][0]
        return item["text"], item.get("detected_source_language", source)


def translate_libre(text: str, target: str, source: str) -> tuple[str, str]:
    if not LIBRETRANSLATE_URL:
        raise HTTPException(status_code=500, detail="LIBRETRANSLATE_URL not configured")
    import httpx

    tgt = "zh" if target.lower().startswith("zh") else target.split("-")[0]
    src = "auto" if source == "auto" else source.split("-")[0]
    with httpx.Client(timeout=30.0) as client:
        r = client.post(
            f"{LIBRETRANSLATE_URL}/translate",
            json={"q": text, "source": src, "target": tgt, "format": "text"},
        )
        if r.status_code >= 400:
            raise HTTPException(status_code=502, detail=f"LibreTranslate error: {r.text}")
        data = r.json()
        return data.get("translatedText") or text, src


@app.get("/health")
def health():
    return {"ok": True, "provider": PROVIDER}


@app.post("/v1/common/translate", response_model=TranslateResponse)
def translate(req: TranslateRequest):
    text = (req.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is empty")

    target = normalize_lang(req.target)
    source = normalize_lang(req.source)

    if looks_mostly_target(text, target):
        return TranslateResponse(text=text, translated=text, target=target, source=source)

    try:
        if PROVIDER == "deepl":
            translated, detected = translate_deepl(text, target, source)
        elif PROVIDER == "libre":
            translated, detected = translate_libre(text, target, source)
        else:
            translated, detected = translate_google(text, target, source)
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"translate failed: {exc}") from exc

    return TranslateResponse(
        text=text,
        translated=translated,
        target=target,
        source=detected or source,
    )
