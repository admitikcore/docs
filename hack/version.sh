#!/usr/bin/env bash
# Archives what is published today and moves the root to the next version.
#
#   hack/version.sh <version that goes to the archive> [<version that goes live>]
#
# The newest content lives at the root, so this has to run BEFORE the pages are
# edited for the next release: it copies the root into /<version>/ and records it
# in hugo.toml. With the second argument it also points the site at the new one.
set -euo pipefail

version="${1:?usage: hack/version.sh 2.1.0 [2.1.1]}"
next="${2:-}"
target="content/en/${version}"

if [[ -d "$target" ]]; then
  echo "$target already exists. Delete it first if you want to redo it." >&2
  exit 1
fi

mkdir -p "$target"
cp -r content/en/docs content/en/use-cases "$target"/

python3 - "$version" "$next" <<'PY'
import pathlib
import re
import sys

frozen, upcoming = sys.argv[1], sys.argv[2]
config = pathlib.Path("hugo.toml")
text = config.read_text()

# The first entry of params.versions is the one served from the root.
entry = re.compile(r"  \[\[params\.versions\]\]\n(?:    [^\n]*\n)+")
match = entry.search(text)
if match is None:
    sys.exit("no params.versions entry found in hugo.toml")

block = match.group(0)
live = re.search(r'version = "v([^"]+)"', block).group(1)
if upcoming and live != frozen:
    print(f"warning: the live entry says v{live}, not v{frozen}")

archived = (
    f'  [[params.versions]]\n'
    f'    version = "v{frozen}"\n'
    f'    url = "https://admitik.dev/{frozen}"\n'
    f'\n'
)

if upcoming:
    fresh = (
        f'  [[params.versions]]\n'
        f'    version = "v{upcoming}"\n'
        f'    url = "https://admitik.dev/"\n'
        f'    githubbranch = "master"\n'
        f'\n'
    )
    text = text.replace(block, fresh + archived, 1)
    text = re.sub(r'version_menu = "v[^"]+"', f'version_menu = "v{upcoming}"', text, count=1)
    print(f"root -> v{upcoming}, v{frozen} -> /{frozen}/")
else:
    text = text.replace(block, archived + block, 1)
    print(f"v{frozen} -> /{frozen}/, root unchanged")

config.write_text(text)
PY

cat <<MESSAGE

Content copied to $target.

Next:
  1. Edit content/en/docs and content/en/use-cases with what the new version changes.
  2. Run make check.
  3. Open a pull request. Merging deploys.

The pages under /$version/ are frozen: do not edit them.
MESSAGE
