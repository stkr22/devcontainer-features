# uv (uv)

Installs uv, the fast Python package manager from Astral.

## Example Usage

```json
"features": {
    "ghcr.io/stkr22/devcontainer-features/uv:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of uv to install (e.g., '0.4.0' or 'latest') | string | latest |

## Environment Variables

This feature sets the following environment variables in the container:

| Variable | Value | Description |
|----------|-------|-------------|
| `VIRTUAL_ENV` | `/workspaces/.venv` | Path to the Python virtual environment |
| `UV_PROJECT_ENVIRONMENT` | `/workspaces/.venv` | uv project environment path |

## About uv

[uv](https://github.com/astral-sh/uv) is an extremely fast Python package and project manager, written in Rust. It can replace pip, pip-tools, pipx, poetry, pyenv, virtualenv, and more.

## Version Pinning

To install a specific version of uv:

```json
"features": {
    "ghcr.io/stkr22/devcontainer-features/uv:1": {
        "version": "0.4.0"
    }
}
```
