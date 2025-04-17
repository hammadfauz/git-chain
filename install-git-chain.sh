#!/bin/bash

# Define installation paths
BIN_DIR="$HOME/.local/bin"
CHAIN_SCRIPT="$BIN_DIR/git-chain"
SAFE_MERGE_SCRIPT="$BIN_DIR/git-safe-merge"

# Ensure the bin directory exists
mkdir -p "$BIN_DIR"

# Install the git-chain script
cat > "$CHAIN_SCRIPT" << 'EOF'
#!/bin/bash

get_trunk_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
}

# Add a parent to the current branch
set_chain() {
  local parent="$1"
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  if [ -z "$parent" ]; then
    echo "Usage: git chain <parent>"
    exit 1
  fi

  # Add a note to the HEAD commit
  git notes add -m "parent:$parent"
  echo "Set parent of '$current_branch' to '$parent'."
}

# Show the current branch's chain
show_chain() {
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  local trunk_branch
  trunk_branch=$(get_trunk_branch)

  echo "Branch chain for '$current_branch':"
  local branch="$current_branch"
  while true; do
    local parent
    parent=$(git notes show HEAD 2>/dev/null | grep "parent:" | cut -d':' -f2)
    if [ -z "$parent" ]; then
      parent="$trunk_branch"
      echo "$branch -> $parent (default)"
      break
    fi
    echo "$branch -> $parent"
    branch="$parent"
    git checkout "$parent" >/dev/null 2>&1
  done
  git checkout "$current_branch" >/dev/null 2>&1
}

# Show all branch chains
show_all_chains() {
  echo "All branch chains:"
  git log --all --notes --pretty=format:"%h %d" | grep "parent:" | while read -r line; do
    local commit
    commit=$(echo "$line" | awk '{print $1}')
    local parent
    parent=$(echo "$line" | grep "parent:" | cut -d':' -f2)
    echo "$commit -> $parent"
  done
}

# Sync notes with the remote
sync_chain() {
  local action="$1"
  if [ "$action" == "push" ]; then
    git push origin refs/notes/commits
  elif [ "$action" == "pull" ]; then
    git fetch origin refs/notes/*:refs/notes/*
  else
    echo "Usage: git $action --chain"
    exit 1
  fi
}

# Main command handler
case "$1" in
  "")
    echo "Usage: git chain <parent> | --show | --show-all | --push | --pull"
    ;;
  --show)
    show_chain
    ;;
  --show-all)
    show_all_chains
    ;;
  --push)
    sync_chain "push"
    ;;
  --pull)
    sync_chain "pull"
    ;;
  *)
    set_chain "$1"
    ;;
esac
EOF

# Make the git-chain script executable
chmod +x "$CHAIN_SCRIPT"

# Install the git-safe-merge script
cat > "$SAFE_MERGE_SCRIPT" << 'EOF'
#!/bin/bash

current_branch=$(git rev-parse --abbrev-ref HEAD)
target_branch="$1"

if [ -z "$target_branch" ]; then
  echo "Usage: git safe-merge <target-branch>"
  exit 1
fi

# Check if the current branch has a parent
parent=$(git notes show HEAD 2>/dev/null | grep "parent:" | cut -d':' -f2)
if [ -n "$parent" ] && [ "$parent" != "$target_branch" ]; then
  echo "Warning: '$current_branch' is not a direct child of '$target_branch'."
  echo "Are you sure you want to merge? (y/N)"
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Perform the merge
git merge "$target_branch"

# Update parent branches of all children
echo "Updating parent branches of children..."
git for-each-ref --format="%(refname:short)" refs/heads/ | while read -r branch; do
  child_parent=$(git notes show "refs/heads/$branch" 2>/dev/null | grep "parent:" | cut -d':' -f2)
  if [ "$child_parent" == "$current_branch" ]; then
    # Update the parent of the child branch to the target branch
    git notes add -f -m "parent:$target_branch" "refs/heads/$branch"
    echo "Updated parent of '$branch' to '$target_branch'."
  fi
done

EOF

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
