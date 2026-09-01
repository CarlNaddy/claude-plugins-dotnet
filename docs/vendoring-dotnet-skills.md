# Vendoring `dotnet/skills` into `CarlNaddy/claude-plugins-dotnet`

This repo's AI tooling is pinned to **one marketplace** — `dotnet-agent-skills`
→ `github.com/CarlNaddy/claude-plugins-dotnet`. That marketplace is a **frozen,
verbatim copy** of Microsoft's [`dotnet/skills`](https://github.com/dotnet/skills)
(every plugin, at a known commit) plus the app-maintained `mudblazor` plugin.

Why: skill text is prompt context. When upstream reworks a `SKILL.md`, agent
behavior shifts. Freezing gives deterministic behavior across machines and over
time; the marketplace only moves when the resync script below is re-run and
pushed. See also `CLAUDE.md` → "Claude Code plugins & skills".

This guide is the procedure for building and maintaining that marketplace repo.
It is **not** run from this template — it operates on `claude-plugins-dotnet`.

---

## 0. Prerequisites

- `git`, `bash`, `python3` (stdlib `json` only — no `pip` packages)
- Push access to `CarlNaddy/claude-plugins-dotnet`
- `claude` CLI (for `claude plugin validate`) — recommended

> On Windows, run from **Git Bash**. If `python3` resolves to the Microsoft
> Store alias stub, the script falls back to `python` / `py` automatically.

## 1. Get the target repo

```bash
git clone git@github.com:CarlNaddy/claude-plugins-dotnet.git
cd claude-plugins-dotnet
```

Starting layout:

```
.claude-plugin/marketplace.json   # name: "mudblazor-agent-skills", 1 plugin
plugins/mudblazor/
README.md  .gitattributes  .gitignore
```

## 2. Add the "local plugins" seed

Entries that are **yours**, not vendored — the script re-adds them on every
resync.

`.claude-plugin/local-plugins.json`:

```json
[
  {
    "name": "mudblazor",
    "source": "./plugins/mudblazor",
    "description": "Consumer-side guidance for building Blazor UI with MudBlazor: setup and wiring, render-mode rules, component selection and code patterns, and conventions for app-owned components built on top of MudBlazor."
  }
]
```

## 3. Add the vendor script

`scripts/vendor-dotnet-skills.sh`:

```bash
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
```

```bash
chmod +x scripts/vendor-dotnet-skills.sh
```

## 4. Run it

Pin to an exact commit for a reproducible freeze:

```bash
bash scripts/vendor-dotnet-skills.sh <dotnet/skills-commit-sha>
# or, for latest upstream:
bash scripts/vendor-dotnet-skills.sh main
```

Resulting layout:

```
.claude-plugin/
  marketplace.json          # name: "dotnet-agent-skills", mudblazor + all dotnet plugins
  local-plugins.json
plugins/
  mudblazor/                # yours, untouched
  dotnet/  dotnet-advanced/  dotnet-ai/  dotnet-aspnetcore/  dotnet-blazor/
  dotnet-data/  dotnet-diag/  dotnet-experimental/  dotnet-maui/  dotnet-msbuild/
  dotnet-nuget/  dotnet-template-engine/  dotnet-test/  dotnet-test-migration/
  dotnet-upgrade/  dotnet11/
vendor/dotnet-skills/
  LICENSE
  UPSTREAM.md               # source URL + pinned commit + date
scripts/vendor-dotnet-skills.sh
```

`dotnet-experimental` is copied to disk but is not in upstream's manifest, so it
is not listed (matches upstream). Add it to `local-plugins.json` if you want it
selectable.

## 5. Validate

```bash
python -m json.tool .claude-plugin/marketplace.json >/dev/null && echo "manifest OK"
claude plugin validate .
```

`claude plugin validate` checks the marketplace manifest plus each plugin's
`plugin.json`, skills, and agents.

## 6. Update the repo's README

```markdown
## Contents

- `plugins/mudblazor/` - app-maintained MudBlazor consumer skill.
- `plugins/dotnet*` - a **frozen, verbatim copy** of Microsoft's
  [dotnet/skills](https://github.com/dotnet/skills), MIT-licensed
  (c) .NET Foundation and Contributors. Pinned commit and license text:
  `vendor/dotnet-skills/`. Resync with `scripts/vendor-dotnet-skills.sh <ref>`.
```

MIT permits redistribution as long as the `LICENSE` and copyright notice travel
with the copy — the script places both under `vendor/dotnet-skills/`.

## 7. Commit, tag, push

```bash
git add -A
git commit -m "Vendor dotnet/skills @ <sha>; rename marketplace to dotnet-agent-skills"
git tag dotnet-skills-$(date +%Y%m%d)
git push --follow-tags
```

The marketplace `name` is now `dotnet-agent-skills` (was `mudblazor-agent-skills`).

## 8. Point consumers at it

A consuming project's `.claude/settings.json` (this template already has this
staged):

```json
{
  "enabledPlugins": {
    "dotnet@dotnet-agent-skills": true,
    "dotnet-aspnetcore@dotnet-agent-skills": true,
    "dotnet-blazor@dotnet-agent-skills": true,
    "dotnet-data@dotnet-agent-skills": true,
    "dotnet-test@dotnet-agent-skills": true,
    "dotnet11@dotnet-agent-skills": true,
    "mudblazor@dotnet-agent-skills": true
  },
  "extraKnownMarketplaces": {
    "dotnet-agent-skills": {
      "source": { "source": "github", "repo": "CarlNaddy/claude-plugins-dotnet" }
    }
  }
}
```

The 10 non-enabled upstream plugins (`dotnet-advanced`, `dotnet-ai`,
`dotnet-diag`, `dotnet-maui`, `dotnet-msbuild`, `dotnet-nuget`,
`dotnet-template-engine`, `dotnet-test-migration`, `dotnet-upgrade`,
`dotnet-experimental`) are available in the marketplace — add any to
`enabledPlugins` per project as needed.

On each machine:

```bash
claude plugin marketplace update dotnet-agent-skills
bash scripts/check-plugins.sh          # in this repo - verifies all enabled plugins
```

## 9. Resync later

```bash
cd claude-plugins-dotnet
git pull
bash scripts/vendor-dotnet-skills.sh main       # or a specific tag/sha
git diff --stat                                  # review what upstream changed
claude plugin validate .
git commit -am "Resync dotnet/skills @ <sha>"
git tag dotnet-skills-$(date +%Y%m%d)
git push --follow-tags
```

Treat it like a vendored dependency — periodically (e.g. quarterly), review the
diff, commit, tag. The freeze holds because your repo's `main` only moves when
this is run.

## Notes

- **Determinism.** Even after vendoring, the marketplace `source` has no `ref`
  pin, so Claude Code pulls your repo's `main` HEAD. The guarantee is that `main`
  only advances when you run the script and push. Tags (`dotnet-skills-YYYYMMDD`)
  are rollback points.
- **`git subtree` alternative.** Keeps upstream history but tracks the remote's
  *root* prefix, not a subdir — you would need `git subtree split` on
  `dotnet/skills` first. The plain copy + script gives cleaner, reviewable diffs
  for what is essentially a mirror.
- **Line endings.** Skill files are Markdown; Claude reads them regardless of
  CRLF/LF. No `.gitattributes` handling is needed for the vendored tree.
