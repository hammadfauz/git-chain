#!/bin/bash

# Define installation paths
BIN_DIR="$HOME/.local/bin"
CHAIN_SCRIPT="$BIN_DIR/git-chain"
SAFE_MERGE_SCRIPT="$BIN_DIR/git-safe-merge"

# Ensure the bin directory exists
mkdir -p "$BIN_DIR"

# Install the git-chain script
CHAIN_SOURCE_FILE="./git-chain.sh"
if [ -f "$CHAIN_SOURCE_FILE" ]; then
  cp "$CHAIN_SOURCE_FILE" "$CHAIN_SCRIPT"
else
  echo "Error: $CHAIN_SOURCE_FILE not found."
  exit 1
fi

# Make the git-chain script executable
chmod +x "$CHAIN_SCRIPT"

# Install the git-safe-merge script
SAFE_MERGE_SOURCE_FILE="./git-safe-merge.sh"
if [ -f "$SAFE_MERGE_SOURCE_FILE" ]; then
  cp "$SAFE_MERGE_SOURCE_FILE" "$SAFE_MERGE_SCRIPT"
else
  echo "Error: $SAFE_MERGE_SOURCE_FILE not found."
  exit 1
fi

# Make the git-safe-merge script executable
chmod +x "$SAFE_MERGE_SCRIPT"

# Add git-safe-merge as an alias for git merge
git config --global alias.merge '!git-safe-merge'

# Add the bin directory to PATH if not already present
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
  echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
  echo "Added $BIN_DIR to PATH. Restart your shell or run 'source ~/.bashrc' to apply changes."
fi

echo "Installation complete! You can now use 'git chain' and 'git merge' with parent checks."
