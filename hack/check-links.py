#!/usr/bin/env python3
"""Fails when a link inside the built site points to something that is not there.

Usage: hack/check-links.py [public]
"""
import pathlib
import re
import sys
import urllib.parse

LINK = re.compile(r'(?:href|src)="(/[^"]*)"')


def targets(root: pathlib.Path, url: str):
    """Every file that would satisfy the url."""
    path = urllib.parse.urlparse(url).path
    base = root / path.lstrip("/")
    return [base, base / "index.html"]


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "public")
    if not root.is_dir():
        print(f"{root} does not exist, run make build first")
        return 2

    broken = []
    for page in sorted(root.rglob("*.html")):
        html = page.read_text(encoding="utf-8", errors="ignore")
        for match in LINK.finditer(html):
            url = match.group(1)
            if url.startswith("//"):
                continue
            if not any(candidate.is_file() for candidate in targets(root, url)):
                broken.append((page.relative_to(root), url))

    if not broken:
        print(f"every internal link resolves in {root}")
        return 0

    for page, url in broken:
        print(f"{page}: {url}")
    print(f"\n{len(broken)} broken links")
    return 1


if __name__ == "__main__":
    sys.exit(main())
