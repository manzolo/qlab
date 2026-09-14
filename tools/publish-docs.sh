#!/usr/bin/env bash
# Publish a plugin's walkthrough: bump, commit, tag, push.
#
#   tools/publish-docs.sh <plugin-name> <new-version> [commit-message-file]
#
# Keeps the invariant tools/check-versions.sh enforces: plugin.conf and the
# registry agree, and a tag v<version> exists at HEAD and is pushed. Without
# that, `qlab install <name>` checks out an older tag and the docs are not there.
#
# The README is NOT rewritten here. Every plugin README carries a "Learn more"
# section that already links the illustrated walkthrough PDFs; this script only
# checks that link is present and warns if it is missing, so the curated README
# structure is never clobbered.

set -euo pipefail
name="${1:?usage: publish-docs.sh <plugin-name> <version> [msgfile]}"
ver="${2:?missing version}"
msgfile="${3:-}"

QLAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$(cd "$QLAB_DIR/../qlab-plugin-$name" && pwd)"
REG="$QLAB_DIR/registry/index.json"

# Pre-flight: at least one English and one Italian walkthrough PDF must exist.
# Accepts both the standard name (docs/walkthrough-en.pdf) and per-topic names
# (e.g. docs/debian-en.pdf, docs/windows-en.pdf for pxe-lab).
shopt -s nullglob
en=("$DIR"/docs/*-en.pdf); it=("$DIR"/docs/*-it.pdf)
shopt -u nullglob
[ "${#en[@]}" -gt 0 ] || { echo "no English walkthrough PDF (docs/*-en.pdf) in $DIR" >&2; exit 1; }
[ "${#it[@]}" -gt 0 ] || { echo "no Italian walkthrough PDF (docs/*-it.pdf) in $DIR" >&2; exit 1; }

# The README should already point at a walkthrough PDF (in "Learn more").
if ! grep -qE '\(docs/[A-Za-z0-9_.-]+\.pdf\)' "$DIR/README.md"; then
    echo "WARNING: README.md does not link any docs/*.pdf — add it to the 'Learn more' section." >&2
fi

python3 - "$DIR" "$name" "$ver" "$REG" <<'PY'
import json, sys
d, name, ver, reg = sys.argv[1:5]

c = json.load(open(f"{d}/plugin.conf"))
old = c["version"]; c["version"] = ver
json.dump(c, open(f"{d}/plugin.conf", "w"), indent=2, ensure_ascii=False)
open(f"{d}/plugin.conf", "a").write("\n")

r = json.load(open(reg))
if not any(x["name"] == name and x.__setitem__("version", ver) is None for x in r):
    raise SystemExit(f"{name} is not in the registry")
json.dump(r, open(reg, "w"), indent=2, ensure_ascii=False); open(reg, "a").write("\n")
print(f"{name}: {old} -> {ver}  (plugin.conf, registry)")
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

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YPXgCe1WpNuh6GeV2o86xf"
fi
git tag -a "v$ver" -m "$name $ver"
git push -q origin HEAD
git push -q origin "v$ver"
echo "$name v$ver published"
