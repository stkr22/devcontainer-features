# Dev Container Features

This repository contains [Dev Container Features](https://containers.dev/implementors/features/) for use with VS Code Dev Containers and GitHub Codespaces.

## Available Features

| Feature | Description |
|---------|-------------|
| [claude-code](src/claude-code) | Installs Claude Code CLI using the native binary installer |

## Usage

Add features to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/OWNER/devcontainer-features/claude-code:2": {}
    }
}
```

Replace `OWNER` with your GitHub username or organization.

## Repository Structure

```
├── .github/workflows/    # CI/CD workflows
├── src/                  # Feature source code
│   └── feature-name/
│       ├── devcontainer-feature.json
│       ├── install.sh
│       ├── README.md
│       └── NOTES.md
└── test/                 # Feature tests
    └── feature-name/
        ├── scenarios.json
        └── test.sh
```

## Adding a New Feature

1. Create a new directory under `src/` with your feature name
2. Add required files:
   - `devcontainer-feature.json` - Feature metadata and options
   - `install.sh` - Installation script
   - `README.md` - Documentation (auto-generated on release)
   - `NOTES.md` - Additional documentation (appended to README)
3. Create tests under `test/feature-name/`
4. Push to main to publish

## Development

### Testing locally

```bash
# Install devcontainer CLI
npm install -g @devcontainers/cli

# Test a specific feature
devcontainer features test -f claude-code .

# Test all features
devcontainer features test .
```

### Publishing

Features are automatically published to GitHub Container Registry on push to `main`.

## License

MIT License - see [LICENSE](LICENSE) for details.
