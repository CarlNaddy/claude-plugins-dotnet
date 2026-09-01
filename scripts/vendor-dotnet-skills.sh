#!/usr/bin/env bash
# Freeze Microsoft's dotnet/skills plugins into this marketplace repo.
#
#   scripts/vendor-dotnet-skills.sh [<ref>]
#
# <ref> = branch, tag, or commit of github.com/dotnet/skills (default: main).
# Re-run to resync to a newer upstream; review the diff, then commit + tag.
#
# Needs: git, bash, and python3 (stdlib json only).

set -euo pipefail
UPSTREAM="https://github.com/dotnet/skills.git"
REF="${1:-main}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"

# find a python that actually runs (skip the Windows Store alias stub)
PY=""
for c in python py python3; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || { echo "need a working python 3 on PATH" >&2; exit 1; }
[ -f .claude-plugin/local-plugins.json ] || { echo "missing .claude-plugin/local-plugins.json" >&2; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "==> cloning dotnet/skills @ $REF"
git clone -q --depth 1 --branch "$REF" "$UPSTREAM" "$tmp/s" 2>/dev/null \
  || { git clone -q "$UPSTREAM" "$tmp/s"; git -C "$tmp/s" checkout -q "$REF"; }
sha="$(git -C "$tmp/s" rev-parse HEAD)"
when="$(git -C "$tmp/s" log -1 --format=%cI HEAD)"
echo "    resolved $sha ($when)"

echo "==> replacing vendored plugin trees (keeping local dirs)"
# dir names declared in local-plugins.json — these are NOT wiped
keep="$("$PY" - <<'PY'
import json
for e in json.load(open(".claude-plugin/local-plugins.json")):
    s = e["source"]
    print(s[len("./plugins/"):] if s.startswith("./plugins/") else s)
PY
)"
for d in plugins/*/; do
    [ -d "$d" ] || continue
    n="$(basename "$d")"
    grep -qxF "$n" <<<"$keep" || rm -rf "$d"
done
mkdir -p plugins
cp -R "$tmp/s/plugins/." plugins/

echo "==> license + provenance"
mkdir -p vendor/dotnet-skills
cp "$tmp/s/LICENSE" vendor/dotnet-skills/LICENSE
cat > vendor/dotnet-skills/UPSTREAM.md <<EOF
# Vendored from dotnet/skills

- Source:  https://github.com/dotnet/skills
- Commit:  $sha
- Date:    $when
- License: MIT - (c) .NET Foundation and Contributors (see ./LICENSE)

Everything under \`plugins/\` except the dirs listed in
\`.claude-plugin/local-plugins.json\` is a verbatim copy of that commit's
\`plugins/\` tree. Resync: \`scripts/vendor-dotnet-skills.sh <ref>\`.
EOF

echo "==> regenerating .claude-plugin/marketplace.json"
"$PY" - "$tmp/s/.claude-plugin/marketplace.json" <<'PY'
import json, sys
up   = json.load(open(sys.argv[1]))
seed = json.load(open(".claude-plugin/local-plugins.json"))
out = {
    "name": "dotnet-agent-skills",
    "owner": {"name": "CarlNaddy"},
    "metadata": {
        "description": "MudBlazor consumer skill + a frozen copy of Microsoft dotnet/skills "
                       "(see vendor/dotnet-skills/UPSTREAM.md)."
    },
    "plugins": seed + up["plugins"],
}
with open(".claude-plugin/marketplace.json", "w", encoding="utf-8", newline="\n") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
PY

echo
echo "Frozen at dotnet/skills@$sha"
echo "Next:"
echo "  $PY -m json.tool .claude-plugin/marketplace.json >/dev/null && echo 'manifest OK'"
echo "  claude plugin validate ."
echo "  git add -A && git commit -m \"Vendor dotnet/skills @ ${sha:0:12}\""
echo "  git tag dotnet-skills-\$(date +%Y%m%d) && git push --follow-tags"
