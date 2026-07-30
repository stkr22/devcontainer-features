#!/bin/bash

set -e

source dev-container-features-test-lib

# This scenario pins remoteUser to root, which is what plain debian/ubuntu images
# resolve to. Claude Code refuses bypass-permissions mode as uid 0 unless
# IS_SANDBOX=1 is set, and the VS Code extension always requests that mode — so
# without the variable the extension cannot spawn Claude at all.
check "running as root" test "$(id -u)" -eq 0

check "claude cli installed" command -v claude
check "IS_SANDBOX set" bash -c 'test "$IS_SANDBOX" = "1"'

# The refusal is printed before any auth or network work, so it shows up even
# without credentials. Any other failure mode is fine here.
check "no root bypass refusal" bash -c \
    '! timeout 60 claude --dangerously-skip-permissions -p hi </dev/null 2>&1 | grep -q "cannot be used with root/sudo"'

# Config wiring should follow root's home rather than /home/vscode
check "claude dir is symlink" test -L /root/.claude
check "settings.json exists" test -f /claude-config/settings.json
check "memory dir writable" touch /claude-memory/.write-test

reportResults
