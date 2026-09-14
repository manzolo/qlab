#!/usr/bin/env bash
# Publish a plugin's walkthrough: bump, document, commit, tag, push.
#
#   tools/publish-docs.sh <plugin-name> <new-version> [commit-message-file]
#
# Keeps the invariant tools/check-versions.sh enforces: plugin.conf and the
# registry agree, and a tag v<version> exists at HEAD and is pushed. Without
# that, `qlab install <name>` checks out an older tag and the docs are not there.

set -euo pipefail
name="${1:?usage: publish-docs.sh <plugin-name> <version> [msgfile]}"
ver="${2:?missing version}"
msgfile="${3:-}"

QLAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$(cd "$QLAB_DIR/../qlab-plugin-$name" && pwd)"
REG="$QLAB_DIR/registry/index.json"

[ -f "$DIR/docs/walkthrough-en.pdf" ] || { echo "no docs/walkthrough-en.pdf in $DIR" >&2; exit 1; }
[ -f "$DIR/docs/walkthrough-it.pdf" ] || { echo "no docs/walkthrough-it.pdf in $DIR" >&2; exit 1; }

python3 - "$DIR" "$name" "$ver" "$REG" <<'PY'
import json, sys
d, name, ver, reg = sys.argv[1:5]

c = json.load(open(f"{d}/plugin.conf"))
old = c["version"]; c["version"] = ver
json.dump(c, open(f"{d}/plugin.conf", "w"), indent=2, ensure_ascii=False)
open(f"{d}/plugin.conf", "a").write("\n")

s = open(f"{d}/README.md").read()
if "## Walkthrough" not in s:
    add = f"""## Walkthrough

`docs/` holds an illustrated account of a real run — every block of output in it
was captured while the lab was running, not written by hand.

| English | Italiano |
|---|---|
| [`docs/walkthrough-en.pdf`](docs/walkthrough-en.pdf) | [`docs/walkthrough-it.pdf`](docs/walkthrough-it.pdf) |

```bash
# from the qlab checkout
python3 tools/walkthrough/build.py ../qlab-plugin-{name}        # English
python3 tools/walkthrough/build.py ../qlab-plugin-{name} -it    # Italian
python3 tools/walkthrough/build.py ../qlab-plugin-{name} --live # re-capture first
```

"""
    for anchor in ("## Usage", "## Objectives", "## Architecture", "## Exercises", "## License"):
        if anchor in s:
            s = s.replace(anchor, add + anchor, 1); break
    else:
        s = s.rstrip() + "\n\n" + add
    open(f"{d}/README.md", "w").write(s)

r = json.load(open(reg))
hit = False
for x in r:
    if x["name"] == name:
        x["version"] = ver; hit = True
if not hit:
    raise SystemExit(f"{name} is not in the registry")
json.dump(r, open(reg, "w"), indent=2, ensure_ascii=False); open(reg, "a").write("\n")
print(f"{name}: {old} -> {ver}  (plugin.conf, README, registry)")
PY

cd "$DIR"
git add -A
if [ -n "$msgfile" ] && [ -f "$msgfile" ]; then
    git -c user.email="a.manzi@ifac.cnr.it" -c user.name="manzolo" commit -q -F "$msgfile"
else
    git -c user.email="a.manzi@ifac.cnr.it" -c user.name="manzolo" commit -q -m "docs: illustrated walkthrough from a real run, English and Italian

Every block of output in docs/ was captured while the lab was running and is
committed under docs/evidence/, so the PDFs rebuild with no lab up. Built by the
shared generator in the qlab repo, tools/walkthrough/build.py: English by
default, Italian with -it.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YPXgCe1WpNuh6GeV2o86xf"
fi
git tag -a "v$ver" -m "$name $ver"
git push -q origin HEAD
git push -q origin "v$ver"
echo "$name v$ver published"
