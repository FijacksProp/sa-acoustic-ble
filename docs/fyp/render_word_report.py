from __future__ import annotations

import argparse
from pathlib import Path

import win32com.client


def update_story_fields(document) -> None:
    for story_type in range(1, 18):
        try:
            story = document.StoryRanges(story_type)
        except Exception:
            continue
        while story is not None:
            try:
                story.Fields.Update()
            except Exception:
                pass
            try:
                story = story.NextStoryRange
            except Exception:
                story = None


def render(document_path: Path, pdf_path: Path) -> None:
    document_path = document_path.resolve()
    pdf_path = pdf_path.resolve()
    word = win32com.client.DispatchEx("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    document = None
    try:
        document = word.Documents.Open(str(document_path), ReadOnly=False)
        document.Fields.Update()
        update_story_fields(document)
        document.Repaginate()
        document.Save()
        document.ExportAsFixedFormat(
            OutputFileName=str(pdf_path),
            ExportFormat=17,
            OpenAfterExport=False,
            OptimizeFor=0,
            Range=0,
            Item=0,
            IncludeDocProps=True,
            KeepIRM=True,
            CreateBookmarks=1,
            DocStructureTags=True,
            BitmapMissingFonts=True,
            UseISO19005_1=False,
        )
    finally:
        if document is not None:
            document.Close(SaveChanges=False)
        word.Quit()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("document", type=Path)
    parser.add_argument("pdf", type=Path)
    args = parser.parse_args()
    render(args.document, args.pdf)
    print(f"Updated: {args.document.resolve()}")
    print(f"Rendered: {args.pdf.resolve()}")


if __name__ == "__main__":
    main()
