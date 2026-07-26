# Using Claude Code in devcontainers

## Installation

This feature uses the native Claude Code binary installer (`https://claude.ai/install.sh`), which downloads a pre-built binary for your platform. No Node.js is required.

## Persistent Storage

This feature includes volume mounts for persistence across container rebuilds:

- **Config volume**: Mounted at `/claude-config` with `CLAUDE_CONFIG_DIR` set accordingly
- **Memory volume**: Mounted at `/claude-memory`. The default `settings.json` sets `autoMemoryDirectory` to this path, so Claude Code's auto-memory files land on the volume and survive rebuilds.

All volumes are named using the `${devcontainerId}` variable to ensure isolation between different devcontainers. A symlink from `~/.claude` to `/claude-config` is also created for compatibility.

To share memory across all your devcontainers instead of per-project, override the mount in your `devcontainer.json` with a statically named volume (e.g. `"source": "claude-memory-shared"`).

## Authentication

To use Claude Code, you need to authenticate. You have two options:

### Option 1: Long-lived OAuth token (recommended)

Generate a long-lived token once on your host machine with `claude setup-token` (valid for one year, requires a Claude subscription), then export it in your shell profile:

```bash
export CLAUDE_CODE_OAUTH_TOKEN=<your-token>
```

Pass it into the container by adding this to your `devcontainer.json`:

```json
{
    "remoteEnv": {
        "CLAUDE_CODE_OAUTH_TOKEN": "${localEnv:CLAUDE_CODE_OAUTH_TOKEN}"
    }
}
```

Claude Code picks up the token automatically at startup. `remoteEnv` is applied at attach time, so the token is never baked into an image layer. If the variable is unset on the host, it resolves to an empty string and Claude Code simply falls back to interactive login. In GitHub Codespaces, set `CLAUDE_CODE_OAUTH_TOKEN` as a Codespaces secret instead.

**Note:** `ANTHROPIC_API_KEY` takes precedence over the OAuth token — make sure it is not also set in the container, or you will be billed via the API key instead of your subscription. See the [authentication docs](https://code.claude.com/docs/en/authentication) for details.

**Known issue — Fable 5 appears credit-gated even on a Max plan.** Fable 5 became a standard part of Max/Team-Premium plans on 2026-07-20; that rollout shipped with several open, unfixed entitlement bugs that all surface as "Fable 5 requires usage credits" for accounts that actually have access:

- [anthropics/claude-code#79441](https://github.com/anthropics/claude-code/issues/79441) — the **VS Code extension panel** specifically holds stale entitlement data from before the transition. Restarting VS Code or reloading the window does not clear it.
- [anthropics/claude-code#79337](https://github.com/anthropics/claude-code/issues/79337) — the `[1m]` model alias (`claude-fable-5[1m]`) is checked against entitlements as a literal string instead of being resolved first, so it never matches and falls back to the credits prompt.
- [anthropics/claude-code#79597](https://github.com/anthropics/claude-code/issues/79597) — with `setup-token`/`CLAUDE_CODE_OAUTH_TOKEN` auth specifically, the account profile omits `subscriptionType`, so the interactive picker's plan check fails closed.

None have a confirmed fix as of this writing. Setting `ANTHROPIC_MODEL=fable` or typing `/model fable` does **not** route around any of these — the failing check runs before model selection. The one thing confirmed to work around #79441: use the **integrated terminal's `claude` CLI** rather than the VS Code extension's chat panel — the CLI on the same Max account is unaffected. If the CLI also shows the credits dialog, it's #79337 or #79597 instead; check whether you're using the `[1m]` alias or token auth, respectively.

If none of the workarounds apply, "Switch to the default model and continue" in the dialog falls back to Opus for that session — this is the only option until Anthropic ships a fix. Track the linked issues for resolution.

### Option 2: Authenticate inside the container

Run `claude` in the terminal and follow the authentication flow. Your credentials are stored in the persistent config volume, so they survive container rebuilds (but the volume is per-devcontainer, so each project authenticates separately).

## Example Configuration

```json
{
    "name": "My Project",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/stkr22/devcontainer-features/claude-code:4": {}
    },
    "remoteEnv": {
        "CLAUDE_CODE_OAUTH_TOKEN": "${localEnv:CLAUDE_CODE_OAUTH_TOKEN}"
    }
}
```

The container user is picked up automatically from your devcontainer's `remoteUser`/`containerUser` config — there's no separate option to set.
