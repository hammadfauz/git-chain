#!/bin/bash

current_branch=$(git rev-parse --abbrev-ref HEAD)
target_branch="$1"

if [ -z "$target_branch" ]; then
  echo "Usage: git safe-merge <target-branch>"
  exit 1
fi

# Check if the current branch has a parent
parent=$(git notes show "$(git rev-list --max-parents=0 HEAD)" 2>/dev/null | jq -r --arg branch "$current_branch" '.[$branch] | .[0]')
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
git for-each-ref --format="%(refname:short)" refs/heads/ | while read -r branch; do
  # Read the JSON notes
  json=$(git notes show "$(git rev-list --max-parents=0 HEAD)" 2>/dev/null || echo "{}")

  # Check if the current branch is the parent of the child branch
  is_child=$(echo "$json" | jq -e --arg child "$branch" --arg parent "$current_branch" '
    .[$parent] and (.[$parent] | index($child)) != null
  ' >/dev/null 2>&1)

  if [ "$is_child" ]; then
    # Update the parent of the child branch to the target branch
    json=$(echo "$json" | jq -c --arg child "$branch" --arg old_parent "$current_branch" --arg new_parent "$target_branch" '
      .[$old_parent] -= [$child] | .[$new_parent] += [$child] | .[$child] //= []
    ')
    git notes add -f "$(git rev-list --max-parents=0 HEAD)" -m "$json"
    echo "Updated parent of '$branch' to '$target_branch'."
  fi
done

