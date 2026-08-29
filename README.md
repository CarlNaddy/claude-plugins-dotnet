# claude-plugins-dotnet

A personal [Claude Code](https://code.claude.com/docs) plugin marketplace for
.NET work.

Marketplace name: **`mudblazor-agent-skills`**

## Plugins

| Plugin | What it provides |
|---|---|
| `mudblazor` | Consumer-side guidance for building Blazor UI with MudBlazor — setup/wiring, render-mode rules, component patterns, and conventions for app-owned components built on MudBlazor. Complements the `dotnet-blazor` skills; not for contributing to the MudBlazor library itself. |

## Install

```
/plugin marketplace add CarlNaddy/claude-plugins-dotnet
/plugin install mudblazor@mudblazor-agent-skills
```

### Enable per project (committed)

In a project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "mudblazor-agent-skills": {
      "source": { "source": "github", "repo": "CarlNaddy/claude-plugins-dotnet" }
    }
  },
  "enabledPlugins": {
    "mudblazor@mudblazor-agent-skills": true
  }
}
```

Teammates are prompted to trust the marketplace on first use; the plugin then
installs automatically.

## Layout

```
.claude-plugin/marketplace.json      marketplace manifest
plugins/mudblazor/
  .claude-plugin/plugin.json         plugin manifest (bump "version" on every change)
  skills/mudblazor/
    SKILL.md                         loaded when the skill activates
    references/patterns.md           copy-paste code patterns
    references/authoring-components.md  conventions for components built on MudBlazor
```

## Updating

1. Edit files under `plugins/mudblazor/skills/mudblazor/`.
2. Bump `version` in `plugins/mudblazor/.claude-plugin/plugin.json`.
3. Commit and push.
4. Consumers run `/plugin update mudblazor@mudblazor-agent-skills` (or
   `/plugin marketplace update mudblazor-agent-skills`).

## Provenance

The MudBlazor conventions in the `mudblazor` skill are the app-development subset
of MudBlazor's own contributor guide (`github.com/MudBlazor/MudBlazor` →
`AGENTS.md`). Build-system material specific to the MudBlazor repo is
intentionally excluded. Refresh by re-reading that file upstream.
