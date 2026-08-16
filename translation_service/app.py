"""Thin JHenTai adapter for a manga-image-translator API server."""

from __future__ import annotations

import json
import os
from typing import Annotated

import httpx
from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import Response

app = FastAPI(title="JHenTai Translation Adapter", version="0.1.0")

ENGINE_URL = os.getenv("JHENTAI_MT_URL", "http://127.0.0.1:8000").rstrip("/")
API_TOKEN = os.getenv("JHENTAI_TRANSLATION_TOKEN", "")
TRANSLATOR = os.getenv("JHENTAI_MT_TRANSLATOR", "sugoi")
REQUEST_TIMEOUT_SECONDS = float(os.getenv("JHENTAI_MT_TIMEOUT", "300"))

LANGUAGE_MAP = {
    "zh": "CHS",
    "zh-cn": "CHS",
    "zh-hans": "CHS",
    "zh-tw": "CHT",
    "zh-hant": "CHT",
    "en": "ENG",
    "en-us": "ENG",
    "ja": "JPN",
    "ja-jp": "JPN",
    "ko": "KOR",
    "ko-kr": "KOR",
}


def _check_token(authorization: str | None) -> None:
    if not API_TOKEN:
        return
    if authorization != f"Bearer {API_TOKEN}":
        raise HTTPException(status_code=401, detail="Invalid translation service token")


def _engine_config(target_language: str) -> dict:
    try:
        config = json.loads(os.getenv("JHENTAI_MT_CONFIG_JSON", "{}"))
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail=f"Invalid JHENTAI_MT_CONFIG_JSON: {exc}") from exc

    translator = config.setdefault("translator", {})
    translator.setdefault("translator", TRANSLATOR)
    translator["target_lang"] = LANGUAGE_MAP.get(target_language.lower(), target_language.upper())
    return config


@app.get("/health")
async def health() -> dict:
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(f"{ENGINE_URL}/openapi.json")
            response.raise_for_status()
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail=f"Translation engine unavailable: {exc}") from exc
    return {"status": "ok", "engine": ENGINE_URL}


@app.post("/v1/translate")
async def translate(
    image: Annotated[UploadFile, File()],
    gallery_id: Annotated[str, Form()],
    page_index: Annotated[int, Form()],
    source_language: Annotated[str, Form()] = "auto",
    target_language: Annotated[str, Form()] = "zh-CN",
    authorization: Annotated[str | None, Header()] = None,
) -> Response:
    del gallery_id, page_index, source_language
    _check_token(authorization)
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image")

    files = {"image": (image.filename or "page.jpg", image_bytes, image.content_type or "application/octet-stream")}
    data = {"config": json.dumps(_engine_config(target_language), ensure_ascii=False)}
    try:
        timeout = httpx.Timeout(REQUEST_TIMEOUT_SECONDS, connect=10)
        async with httpx.AsyncClient(timeout=timeout) as client:
            result = await client.post(f"{ENGINE_URL}/translate/with-form/image", files=files, data=data)
            result.raise_for_status()
    except httpx.HTTPStatusError as exc:
        detail = exc.response.text[:1000]
        raise HTTPException(status_code=502, detail=f"Translation engine error: {detail}") from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail=f"Translation engine unavailable: {exc}") from exc

    return Response(content=result.content, media_type=result.headers.get("content-type", "image/png"))
