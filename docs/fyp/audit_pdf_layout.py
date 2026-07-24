from __future__ import annotations

import argparse
import math
from pathlib import Path

import fitz
from PIL import Image, ImageDraw, ImageFont


def render_contact_sheet(pdf_path: Path, output_path: Path) -> None:
    pdf = fitz.open(pdf_path)
    columns = 7
    thumb_width = 180
    thumb_height = round(thumb_width * 841.9 / 595.3)
    label_height = 24
    rows = math.ceil(pdf.page_count / columns)
    sheet = Image.new(
        "RGB",
        (columns * thumb_width, rows * (thumb_height + label_height)),
        "white",
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(r"C:\Windows\Fonts\timesbd.ttf", 16)

    matrix = fitz.Matrix(thumb_width / 595.3, thumb_width / 595.3)
    for index, page in enumerate(pdf):
        pixmap = page.get_pixmap(matrix=matrix, alpha=False)
        image = Image.frombytes("RGB", (pixmap.width, pixmap.height), pixmap.samples)
        x = (index % columns) * thumb_width
        y = (index // columns) * (thumb_height + label_height)
        sheet.paste(image, (x, y))
        draw.rectangle(
            (x, y, x + thumb_width - 1, y + thumb_height - 1),
            outline="#B0B7BE",
            width=1,
        )
        label = str(index + 1)
        label_width = draw.textbbox((0, 0), label, font=font)[2]
        draw.text(
            (x + (thumb_width - label_width) / 2, y + thumb_height + 2),
            label,
            fill="#1A2630",
            font=font,
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, optimize=True)
    print(f"Pages: {pdf.page_count}")
    print(f"Contact sheet: {output_path.resolve()}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    render_contact_sheet(args.pdf, args.output)


if __name__ == "__main__":
    main()
