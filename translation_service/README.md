# JHenTai local translation adapter

This directory implements the small HTTP contract used by JHenTai. It proxies
page images to the headless API from
[`manga-image-translator`](https://github.com/zyddnys/manga-image-translator),
which performs detection, OCR, translation, inpainting, and typesetting.

Comic Translate was considered first, but its current processing pipeline is
coupled to Qt application state and does not expose a supported headless API.
Keeping this adapter boundary means a Comic Translate backend can be added
later without changing the Flutter client.

## Windows development setup

1. Clone `manga-image-translator`, then apply the compatibility patch shipped
   in this directory:

   ```powershell
   git apply --unidiff-zero ..\JHenTai\translation_service\manga-image-translator.patch
   ```

   Install its dependencies and start it in API/web mode on
   `http://127.0.0.1:8000`. From its repository root, the CPU command is
   `python server/main.py`; add `--use-gpu` when its CUDA dependencies are
   installed.
2. Open PowerShell in this directory and run:

   ```powershell
   .\start_windows.ps1
   ```

3. In JHenTai, open **Settings > Image translation**, keep the default URL
   `http://127.0.0.1:5100`, then use **Test connection**.

The first translation can take much longer because the engine downloads and
loads its models. JHenTai's default request timeout is five minutes.

## Engine configuration

The adapter uses the following environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `JHENTAI_MT_URL` | `http://127.0.0.1:8000` | Upstream engine URL |
| `JHENTAI_MT_TRANSLATOR` | `sugoi` | Upstream translator backend |
| `JHENTAI_MT_CONFIG_JSON` | `{}` | Extra manga-image-translator config JSON |
| `JHENTAI_MT_TIMEOUT` | `300` | Upstream timeout in seconds |
| `JHENTAI_TRANSLATION_TOKEN` | empty | Optional bearer token required from JHenTai |

The current test client supports DeepSeek directly. The API key and model are
configured in JHenTai and sent only to the local adapter/engine for each
request. Thinking mode is explicitly disabled. Do not expose either local
HTTP service to the public internet.

## HTTP contract

- `GET /health` checks that the upstream engine is reachable.
- `POST /v1/translate` accepts multipart fields `image`, `gallery_id`,
  `page_index`, `source_language`, and `target_language`, and returns the final
  translated image bytes.
