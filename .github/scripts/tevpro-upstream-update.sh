#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY}"
: "${GH_TOKEN:?Set GH_TOKEN}"
if [[ "$GITHUB_REPOSITORY" != 'Tevpro/open-seo' ]]; then
  printf 'Refusing to update unexpected repository: %s\n' "$GITHUB_REPOSITORY" >&2
  exit 1
fi

release=$(gh api repos/every-app/open-seo/releases/latest --jq .tag_name)
if [[ ! "$release" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9.-]+)?$ ]]; then
  printf 'Unexpected upstream release tag: %s\n' "$release" >&2
  exit 1
fi

git remote add openseo-upstream https://github.com/every-app/open-seo.git 2>/dev/null || \
  git remote set-url openseo-upstream https://github.com/every-app/open-seo.git
git fetch --no-tags openseo-upstream "refs/tags/$release:refs/tags/$release"
git fetch origin main

if git merge-base --is-ancestor "$release" origin/main; then
  printf 'Upstream %s is already incorporated in main.\n' "$release"
  exit 0
fi

branch="chore/openseo-$release"
# A release branch is rebuilt from main, rather than force-pushing over an
# existing review branch. If an open PR exists, leave it for human resolution.
if gh pr list --repo "$GITHUB_REPOSITORY" --head "$branch" --state open --json number --jq 'length' | grep -qx '1'; then
  printf 'Existing update PR for %s; leave its review branch untouched.\n' "$release"
  exit 0
fi

git config user.name 'Tevpro OpenSEO updater'
git config user.email 'rick@tevpro.com'
git switch -c "$branch" origin/main
if ! git merge --no-ff --no-edit "$release"; then
  git merge --abort || true
  printf 'Upstream %s conflicts with Tevpro changes; resolve manually.\n' "$release" >&2
  exit 1
fi

git push origin "HEAD:refs/heads/$branch"
gh pr create --repo "$GITHUB_REPOSITORY" --base main --head "$branch" \
  --title "chore: update OpenSEO to $release" \
  --body "Upstream release: https://github.com/every-app/open-seo/releases/tag/$release

Review database migrations, Alchemy resources, Cloudflare Access/auth changes and any workflow edits. CI runs without production credentials. Merging this PR does not deploy; production has a separate manual, guarded workflow."

# A PR created by GITHUB_TOKEN does not recursively trigger pull_request CI.
# workflow_dispatch is the explicit, allowed exception; it checks this branch.
gh workflow run ci.yml --repo "$GITHUB_REPOSITORY" --ref "$branch"
