from __future__ import annotations

import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CHAPTERS = sorted(ROOT.glob("CHAPTER_*.md"))
REFERENCES = ROOT / "REFERENCES.md"


def reference_keys(text: str) -> set[tuple[str, str]]:
    keys: set[tuple[str, str]] = set()
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        author = line.split(",", 1)[0].split(".", 1)[0].strip()
        year_match = re.search(r"\((\d{4}|n\.d\.)\)", line)
        if author and year_match:
            keys.add((author.lower(), year_match.group(1)))
    return keys


def citation_keys(text: str) -> Counter[tuple[str, str]]:
    citations: Counter[tuple[str, str]] = Counter()
    pattern = re.compile(
        r"\b([A-Z][A-Za-z-]+)"
        r"(?:\s+(?:and|&)\s+[A-Z][A-Za-z-]+|\s+et al\.)?"
        r"\s*\((\d{4}|n\.d\.)\)"
        r"|\(([A-Z][A-Za-z-]+)"
        r"(?:\s+(?:and|&)\s+[A-Z][A-Za-z-]+|\s+et al\.)?,\s*"
        r"(\d{4}|n\.d\.)\)"
    )
    for match in pattern.finditer(text):
        author = match.group(1) or match.group(3)
        year = match.group(2) or match.group(4)
        citations[(author.lower(), year)] += 1

    multi_parenthetical = re.compile(r"\(([^()]+)\)")
    item_pattern = re.compile(
        r"^\s*([A-Z][A-Za-z-]+)"
        r"(?:\s+(?:and|&)\s+[A-Z][A-Za-z-]+|\s+et al\.)?,\s*"
        r"(\d{4}|n\.d\.)\s*$"
    )
    for group in multi_parenthetical.findall(text):
        if ";" not in group:
            continue
        for item in group.split(";"):
            match = item_pattern.match(item)
            if match:
                citations[(match.group(1).lower(), match.group(2))] += 1
    android_count = text.count("Android Developers (n.d.)")
    android_count += text.count("(Android Developers, n.d.)")
    if android_count:
        citations[("android developers", "n.d.")] += android_count
    return citations


def main() -> None:
    refs = reference_keys(REFERENCES.read_text(encoding="utf-8"))
    chapter_text = "\n".join(
        path.read_text(encoding="utf-8") for path in CHAPTERS
    )
    citations = citation_keys(chapter_text)
    missing = sorted(key for key in citations if key not in refs)
    unused = sorted(key for key in refs if key not in citations)

    print(f"Chapters: {len(CHAPTERS)}")
    print(f"Reference entries: {len(refs)}")
    print(f"Distinct detected citations: {len(citations)}")
    print(f"Detected citation occurrences: {sum(citations.values())}")
    print(f"Citations missing from references: {missing}")
    print(f"References not detected in chapter citations: {unused}")
    print("Citation counts:")
    for (author, year), count in sorted(citations.items()):
        print(f"  {author.title()} ({year}): {count}")


if __name__ == "__main__":
    main()
