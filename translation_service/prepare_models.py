"""Download the default models used by the JHenTai translation workflow."""

import asyncio

from manga_translator.config import Detector, Inpainter, Ocr
from manga_translator.detection import prepare as prepare_detection
from manga_translator.inpainting import prepare as prepare_inpainting
from manga_translator.ocr import prepare as prepare_ocr


async def main() -> None:
    await prepare_detection(Detector.default)
    await prepare_ocr(Ocr.ocr48px, "cpu")
    await prepare_inpainting(Inpainter.default, "cpu")


if __name__ == "__main__":
    asyncio.run(main())
