# Git Chain

**Supercharge your Git workflow with `git-chain` and `git-safe-merge`!**

They say you should keep your code changes small and easy to reason about. They say branches should be short-lived. All branches should [merge to trunk](https://trunkbaseddevelopment.com/). Never break the build on trunk. 

Yet you often need to develop features based on other features that are not yet merged. You could wait until they are merged. ⏳💀

Or, you could use *Git Chain*.

Git Chain is designed to make managing branch dependencies and merges in Git easier and safer.

## Features

### `git-chain`
- **Set Parent Branches**: Easily define parent-child relationships between branches.
- **Visualize Branch Chains**: View the chain of parent branches for the current branch or all branches in your repository.
- **Sync Notes**: Push or pull branch chain metadata to/from your remote repository.

### `git-safe-merge` (aliased to `git merge`)
- **Safe Merging**: Warns you if you're merging a branch that isn't a direct parent, helping you avoid accidental merges.
- **Automatic Parent Updates**: Automatically updates parent metadata for child branches after a merge.

### GitHub Workflow Integration

To automate and enhance your Git Chain workflow, a GitHub Actions workflow template is included in the repository. This workflow helps manage parent-child branch relationships and ensures smooth integration with pull requests.

##### Features of the Workflow

1. **Parent Branch Validation**:
   - Automatically checks if the base branch of a pull request matches the parent branch defined in Git notes.
   - Issues a warning if the base branch differs from the parent branch.

2. **Rebasing Child Pull Requests**:
   - When a pull request is merged, the workflow identifies child branches and rebases their pull requests to the new base branch.

3. **Parent-Child Relationship Updates**:
   - Updates relationships to reflect new parent-child relationships after a pull request is merged.

## Example Dev Workflow

Let's say you have two features to build. Feature A and Feature B.

1. You start by creating a branch for feature A from main
```bash
git checkout -b feature-a main
```

2. You work on your feature, push the branch to remote and open up a pull request. On to feature B.

3. Wait, feature B depends on code in feature A. You need to branch from the Feature A branch. You can now specify `feature-a` as a parent of `feature-b`
```bash
git checkout -b feature-b feature-a
git chain feature-a
```
Doing this can enable git to warn you when you try to merge `feature-b` into `main`.

4. Once `feature-a` is ready to be merged, you merge it
```bash
git checkout main
git merge feature-a
```
This will update the parent for all child branches of `feature-a` to `main`. This tells git that it is now safe to merge `feature-b` to `main`.

5. You can also sync the relationships to/from remote
```bash
git chain --push
git chain --pull
```

6. With Github workflow, this enables Github to recognize the branch chains and act on them:

    1. **Pull Request Validation**:
       - When a pull request is opened or edited, the workflow checks the parent branch defined and compares it with the base branch of the pull request.

    2. **Rebasing Child Pull Requests**:
       - After merging a pull request, the workflow identifies child branches and rebases their pull requests to the new base branch.

    3. **Updating Chains**:
       - The workflow updates chains to reflect the new parent-child relationships on server.

## Installation

Run the following command to install `git-chain` and `git-safe-merge`:

```bash
bash install-git-chain.sh
```

The script will:
1. Install `git-chain` and `git-safe-merge` to your local bin directory (`~/.local/bin`).
2. Add `git-safe-merge` as an alias for `git merge`.
3. Update your `PATH` to include the bin directory (if not already included).

Additionally you need to
1. Ensure the workflow file `.github/workflows/git-chain.yml` is present in your repository.
2. The workflow triggers automatically on the following events:
   - **Pull Request Opened/Edited**: Validates the parent branch.
   - **Pull Request Merged**: Rebases child pull requests and updates parent-child relationships.


## Usage

### `git-chain`
- Set a parent branch:
  ```bash
  git chain <parent-branch>
  ```
- Show the chain for the current branch:
  ```bash
  git chain --show
  ```
- Show all branch chains:
  ```bash
  git chain --show-all
  ```
- Sync chain metadata:
  ```bash
  git chain --push   # Push notes to remote
  git chain --pull   # Pull notes from remote
  ```


