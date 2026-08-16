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
TRANSLATOR = os.getenv("JHENTAI_MT_TRANSLATOR", "deepseek")
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


def _engine_config(
    target_language: str,
    translation_provider: str,
    api_base_url: str,
    api_key: str,
    api_model: str,
    disable_thinking: bool,
) -> dict:
    try:
        config = json.loads(os.getenv("JHENTAI_MT_CONFIG_JSON", "{}"))
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail=f"Invalid JHENTAI_MT_CONFIG_JSON: {exc}") from exc

    translator = config.setdefault("translator", {})
    provider = translation_provider or TRANSLATOR
    translator["translator"] = "deepseek" if provider == "openai_compatible" else provider
    translator["target_lang"] = LANGUAGE_MAP.get(target_language.lower(), target_language.upper())
    if provider == "openai_compatible":
        translator["api_base_url"] = api_base_url.rstrip("/")
        translator["api_key"] = api_key
        translator["api_model"] = api_model or "deepseek-v4-flash"
        translator["disable_thinking"] = disable_thinking
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


@app.post("/v1/test")
async def test_configuration(
    translation_provider: Annotated[str, Form()] = "openai_compatible",
    api_base_url: Annotated[str, Form()] = "https://api.deepseek.com",
    api_key: Annotated[str, Form()] = "",
    api_model: Annotated[str, Form()] = "deepseek-v4-flash",
    disable_thinking: Annotated[bool, Form()] = True,
) -> dict:
    await health()
    if translation_provider != "openai_compatible":
        return {"status": "ok", "provider": translation_provider}
    payload = {
        "model": api_model,
        "messages": [{"role": "user", "content": "Reply only with OK"}],
        "max_tokens": 4,
    }
    if disable_thinking:
        payload["thinking"] = {"type": "disabled"}
    headers = {"Authorization": f"Bearer {api_key.strip()}"} if api_key.strip() else {}
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                f"{api_base_url.rstrip('/')}/chat/completions",
                json=payload,
                headers=headers,
            )
            response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Translation API rejected the configuration (HTTP {exc.response.status_code})",
        ) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail=f"Translation API unavailable: {exc}") from exc
    return {"status": "ok", "provider": translation_provider, "model": api_model}


@app.post("/v1/translate")
async def translate(
    image: Annotated[UploadFile, File()],
    gallery_id: Annotated[str, Form()],
    page_index: Annotated[int, Form()],
    source_language: Annotated[str, Form()] = "auto",
    target_language: Annotated[str, Form()] = "zh-CN",
    translation_provider: Annotated[str, Form()] = "openai_compatible",
    api_base_url: Annotated[str, Form()] = "https://api.deepseek.com",
    api_key: Annotated[str, Form()] = "",
    api_model: Annotated[str, Form()] = "deepseek-v4-flash",
    disable_thinking: Annotated[bool, Form()] = True,
    authorization: Annotated[str | None, Header()] = None,
) -> Response:
    del gallery_id, page_index, source_language
    _check_token(authorization)
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image")

    files = {"image": (image.filename or "page.jpg", image_bytes, image.content_type or "application/octet-stream")}
    data = {
        "config": json.dumps(
            _engine_config(
                target_language,
                translation_provider,
                api_base_url,
                api_key,
                api_model,
                disable_thinking,
            ),
            ensure_ascii=False,
        )
    }
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
