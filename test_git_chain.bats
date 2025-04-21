# Load the git-chain.sh script
source ./git-chain.sh

# Setup a temporary Git repository for testing
setup() {
  mkdir test_repo
  cd test_repo
  git init > /dev/null
  git config user.name "Test user"
  git config user.email "test@test.test"
  touch file
  git add file
  git commit -m "Initial commit"
}

# Cleanup after tests
teardown() {
  cd ..
  rm -rf test_repo
}

@test "get_trunk_branch returns the default branch" {
  git branch -m main
  result="$(get_trunk_branch)"
  [ "$result" = "main" ]
}

@test "first_commit returns the first commit hash" {
  result="$(first_commit)"
  first_commit_hash="$(git rev-list --max-parents=0 HEAD)"
  [ "$result" = "$first_commit_hash" ]
}

@test "initialize_chain creates a valid JSON note" {
  initialize_chain
  note="$(git notes show "$(first_commit)")"
  [ "$note" = "{}" ]
}

@test "read_chains retrieves the JSON note" {
  initialize_chain
  result="$(read_chains)"
  [ "$result" = "{}" ]
}

@test "write_chains updates the JSON note" {
  initialize_chain
  write_chains '{"key":"value"}'
  result="$(read_chains)"
  [ "$result" = '{"key":"value"}' ]
}

@test "set_chain updates the parent-child relationship" {
  git checkout -b feature
  set_chain main
  result="$(read_chains)"
  expected='{"main":["feature"],"feature":[]}'
  [ "$result" = "$expected" ]
}

@test "show_chain displays the correct chain" {
  git checkout -b feature
  set_chain main
  result="$(show_chain)"
  [ "$result" = $'Branch chain for \'feature\':\nmain -> feature' ]
}

@test "show_all_chains displays all chains" {
  git checkout -b feature
  set_chain main
  result="$(show_all_chains)"
  [ "$result" = $'All branch chains:\nmain -> feature' ]
}

@test "clear_chain removes the parent relationship" {
  git checkout -b feature
  set_chain main
  clear_chain
  result="$(read_chains)"
  expected='{"main":[]}'
  [ "$result" = "$expected" ]
}

