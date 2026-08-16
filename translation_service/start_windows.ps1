$ErrorActionPreference = "Stop"

if (-not (Test-Path ".venv")) {
    if ($env:JHENTAI_PYTHON) {
        & $env:JHENTAI_PYTHON -m venv .venv
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        py -3.11 -m venv .venv
    } else {
        throw "Python 3.11 was not found. Set JHENTAI_PYTHON to its python.exe path."
    }
}

& .\.venv\Scripts\python.exe -m pip install -r requirements.txt
& .\.venv\Scripts\python.exe -m uvicorn app:app --host 127.0.0.1 --port 5100
