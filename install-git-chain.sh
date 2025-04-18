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

    # Get the first commit
    local first_commit
    first_commit=$(git rev-list --max-parents=0 HEAD)

    # Fetch the JSON note
    local json
    json=$(git notes show "$first_commit" 2>/dev/null || echo "{}")

    # Update the JSON tree
    json=$(echo "$json" | jq --arg parent "$parent" --arg child "$current_branch" '
        .[$parent] += [$child] | .[$child] //= []
    ')

    # Save the updated JSON back to the note
    echo "$json"
    git notes add -f "$first_commit" -m "$json"
    echo "Set parent of '$current_branch' to '$parent'."
}

# Show the current branch's chain
show_chain() {
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    if [ -z "$current_branch" ]; then
        echo "You are not on a branch."
        return
    fi

    # Get the first commit
    local first_commit
    first_commit=$(git rev-list --max-parents=0 HEAD)

    # Fetch the JSON note from the first commit
    local json
    json=$(git notes show "$first_commit" 2>/dev/null || echo "{}")

    # Collect the chain in an array
    declare -a chain
    local branch="$current_branch"
    while true; do
        chain+=("$branch")

        local parent
        parent=$(echo "$json" | jq -r --arg child "$branch" '
            to_entries[] | select(.value[] == $child) | .key
        ')

        if [ -z "$parent" ]; then
            break
        fi

        branch="$parent"
    done

    # Reverse the chain for proper parent -> child order
    echo "Branch chain for '$current_branch':"
    for (( i=${#chain[@]}-1; i>=0; i-- )); do
        if [ $i -eq 0 ]; then
            echo -n "${chain[i]}"
        else
            echo -n "${chain[i]} -> "
        fi
    done
    echo
}

# Show all branch chains
show_all_chains() {
    # Get the first commit
    local first_commit
    first_commit=$(git rev-list --max-parents=0 HEAD)

    # Fetch the JSON note
    local json
    json=$(git notes show "$first_commit" 2>/dev/null || echo "{}")

    echo "All branch chains:"
    echo "$json" | jq -r 'to_entries[] | .key as $parent | .value[] | "\($parent) -> \(.)"'
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
