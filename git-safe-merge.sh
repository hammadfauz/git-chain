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


