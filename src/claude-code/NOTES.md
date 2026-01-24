# Using Claude Code in devcontainers

## Installation

This feature uses the native Claude Code binary installer (`https://claude.ai/install.sh`), which downloads a pre-built binary for your platform. No Node.js is required.

## Persistent Storage

This feature includes volume mounts for persistence across container rebuilds:

- **Config volume**: Mounted at `/claude-config` with `CLAUDE_CONFIG_DIR` set accordingly
- **History volume**: Stores command history at `/commandhistory`

Both volumes are named using the `${devcontainerId}` variable to ensure isolation between different devcontainers. A symlink from `~/.claude` to `/claude-config` is also created for compatibility.

## Credentials

To use Claude Code, you need to authenticate. You have two options:

### Option 1: Authenticate inside the container

Run `claude` in the terminal and follow the authentication flow. Your credentials will be stored in the persistent config volume.

### Option 2: Mount credentials from host (recommended for teams)

Add a bind mount in your `devcontainer.json` to share credentials from your host machine:

```json
{
    "mounts": [
        {
            "source": "${localEnv:HOME}/.claude/.credentials.json",
            "target": "/home/vscode/.claude/.credentials.json",
            "type": "bind"
        }
    ]
}
```

**Note:** Adjust `/home/vscode` to match your `remoteUser` if using a different username.

## Options

### `remoteUser`

The username in the container. Used for setting correct permissions on mounted volumes. Defaults to `vscode`.

```json
"features": {
    "ghcr.io/anthropics/devcontainer-features/claude-code:2": {
        "remoteUser": "node"
    }
}
```

### `persistConfig`

Whether to use a volume for persistent Claude configuration. Defaults to `true`.

### `persistHistory`

Whether to use a volume for persistent command history. Defaults to `true`.

## Example Configuration

```json
{
    "name": "My Project",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/anthropics/devcontainer-features/claude-code:2": {
            "remoteUser": "vscode"
        }
    },
    "mounts": [
        {
            "source": "${localEnv:HOME}/.claude/.credentials.json",
            "target": "/home/vscode/.claude/.credentials.json",
            "type": "bind"
        }
    ]
}
```
