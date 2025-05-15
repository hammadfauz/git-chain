#!/bin/bash

get_trunk_branch() {
  git symbolic-ref --short HEAD 2>/dev/null
}

first_commit() {
    git rev-list --max-parents=0 HEAD
}

# initialize an empty value if needed
initialize_chain() {
    # Fetch the JSON note
    local json
    json=$(git notes show "$(first_commit)" 2>/dev/null || echo "{}")

    # If no note exists, create one with an empty JSON object
    if [ "$json" = "{}" ]; then
        git notes add -f "$(first_commit)" -m "$json"
    fi

    # Check if the JSON is valid
    if ! echo "$json" | jq -c empty >/dev/null 2>&1; then
        # Initialize to an empty JSON object if invalid
        json="{}"
        git notes add -f "$first_commit" -m "$json"
    fi
}

# read chains state from notes
read_chains() {
    # Ensure the chain is initialized
    initialize_chain

    # Fetch and return the JSON note
    git notes show "$(first_commit)"
}

# update chains state in notes
write_chains() {
    local json="$1"

    # Validate the JSON string
    if ! echo "$json" | jq -c empty >/dev/null 2>&1; then
        echo "Error: Invalid JSON provided to write_chains."
        return 1
    fi

    # Get the first commit
    local first_commit
    first_commit=$(git rev-list --max-parents=0 HEAD)

    # Overwrite the note with the provided JSON string
    git notes add -f "$(first_commit)" -m "$json"
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

    # Check if the parent branch exists
    if ! git show-ref --verify --quiet "refs/heads/$parent"; then
        echo "Error: Parent branch '$parent' does not exist."
        exit 1
    fi

    # Read the JSON notes
    local json
    json=$(read_chains)

    # Update the JSON tree
    json=$(echo "$json" | jq -c --arg parent "$parent" --arg child "$current_branch" '
        .[$parent] += [$child] | .[$child] //= []
    ')

    # Write the updated JSON back to the notes
    write_chains "$json" || return 1
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

    # Read the JSON notes
    local json
    json=$(read_chains)

    # Collect the chain in an array
    declare -a chain
    local branch="$current_branch"
    while true; do
        chain+=("$branch")

        local parent
        parent=$(echo "$json" | jq -c -r --arg child "$branch" '
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
    # Read the JSON notes
    local json
    json=$(read_chains)

    echo "All branch chains:"
    echo "$json" | jq -c -r 'to_entries[] | .key as $parent | .value[] | "\($parent) -> \(.)"'
}

# Sync notes with the remote
sync_chain() {
  local action="$1"
  if [ "$action" == "push" ]; then
    git push origin refs/notes/commits
  elif [ "$action" == "pull" ]; then
    git fetch origin refs/notes/*:refs/notes/origin/*
    git notes merge -v origin/commits
  else
    echo "Usage: git $action --chain"
    exit 1
  fi
}

# Clear the current branch's parent
clear_chain() {
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    if [ -z "$current_branch" ]; then
        echo "You are not on a branch."
        return
    fi

    # Read the JSON notes
    local json
    json=$(read_chains)

    # Remove the current branch from the JSON tree
    json=$(echo "$json" | jq -c --arg branch "$current_branch" '
        del(.[$branch]) |
        with_entries(.value |= map(select(. != $branch)))
    ')

    # Write the updated JSON back to the note
    write_chains "$json" || return 1
    echo "Cleared parent of '$current_branch'."
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
  --clear)
    clear_chain
    ;;
  *)
    set_chain "$1"
    ;;
esac

