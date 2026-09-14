#!/usr/bin/env bash
# Verify the invariant that makes `qlab install <name>` fetch what we think:
#
#   plugin.conf version  ==  registry/index.json version  ==  git tag v<version>
#   and that tag must be at HEAD and pushed.
#
# install_plugin() checks out v${version} using the version from the registry,
# so a bumped plugin.conf without a matching pushed tag silently installs the
# old code.
#
#   tools/check-versions.sh [plugins-parent-dir]

set -uo pipefail
QLAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${1:-$(cd "$QLAB_DIR/.." && pwd)}"
REG="$QLAB_DIR/registry/index.json"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YEL=$'\033[1;33m'; RESET=$'\033[0m'
problems=0

printf "%-20s %-9s %-9s %-9s %-8s %-8s %s\n" PLUGIN CONF REGISTRY TAG AT-HEAD PUSHED NOTE
for d in "$ROOT"/qlab-plugin-*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d"); name=${name#qlab-plugin-}
    conf=$(python3 -c "import json;print(json.load(open('$d/plugin.conf'))['version'])" 2>/dev/null || echo "?")
    reg=$(python3 -c "
import json
d=json.load(open('$REG'))
e=[x for x in d if x['name']=='$name']
print(e[0]['version'] if e else '-')" 2>/dev/null || echo "?")
    tag=$(git -C "$d" tag -l --sort=-v:refname 2>/dev/null | head -1)
    tag=${tag:--}
    athead="-"; pushed="-"; note=""
    if [ "$tag" != "-" ]; then
        [ "$(git -C "$d" rev-parse "$tag^{commit}" 2>/dev/null)" = "$(git -C "$d" rev-parse HEAD 2>/dev/null)" ] \
            && athead="yes" || athead="NO"
        git -C "$d" ls-remote --tags origin "$tag" 2>/dev/null | grep -q . && pushed="yes" || pushed="NO"
    fi
    [ "$conf" != "$reg" ] && note+="conf!=registry "
    [ "v$conf" != "$tag" ] && note+="no tag v$conf "
    [ "$athead" = "NO" ] && note+="tag behind HEAD "
    [ "$pushed" = "NO" ] && note+="tag not pushed "
    dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
    [ "$dirty" -gt 0 ] && note+="${dirty} uncommitted "
    col=$GREEN; [ -n "$note" ] && { col=$RED; problems=$((problems+1)); }
    printf "%s%-20s %-9s %-9s %-9s %-8s %-8s %s%s\n" "$col" "$name" "$conf" "$reg" "$tag" "$athead" "$pushed" "$note" "$RESET"
done

echo
if [ "$problems" -eq 0 ]; then
    printf "%sAll plugins consistent.%s\n" "$GREEN" "$RESET"
else
    printf "%s%d plugin(s) need attention.%s\n" "$YEL" "$problems" "$RESET"
fi
exit $(( problems > 0 ))
