#!/usr/bin/env bash
#
# Start work on an issue.
#
#   scripts/start-issue.sh 46
#
# Creates a branch through `gh issue develop`, which is what links the branch
# to the issue on GitHub. The link is the point: a pull request from a linked
# branch closes its issue on merge with nothing written in the description.
#
# Branch names are <prefix>/<issue>-<slug>, so the issue number is always in
# front of you and `git branch` sorts into fixes and features on its own.

set -euo pipefail

die() {
  printf 'start-issue: %s\n' "$1" >&2
  exit 1
}

[ $# -eq 1 ] || die "usage: scripts/start-issue.sh <issue-number>"

issue="${1#\#}"
case "$issue" in
  ''|*[!0-9]*) die "'$1' is not an issue number." ;;
esac

command -v gh >/dev/null 2>&1 || die "gh is not installed. brew install gh"
git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository."

# Switching branches carries uncommitted tracked changes across, which is how
# work on one issue ends up in the pull request for another. Untracked files
# are left alone: build output is gitignored and harmless.
git diff-index --quiet HEAD -- \
  || die "you have uncommitted changes. Commit or stash them first."

# One call for all three fields. A missing issue, a pull request number, or an
# unauthenticated gh all land here.
info=$(gh issue view "$issue" --json state,labels,title \
  --jq '[.state, ([.labels[].name] | join(",")), .title] | @tsv') \
  || die "cannot read issue #$issue. Check the number, and that gh is logged in."

IFS=$'\t' read -r state labels title <<< "$info"

[ "$state" = "OPEN" ] || die "issue #$issue is $state. Reopen it, or pick another."

# Already started, most likely on another machine or before a reset. Take the
# branch that exists rather than opening a second one against the same issue.
existing=$(gh issue develop --list "$issue" | head -1 | cut -f1)
if [ -n "$existing" ]; then
  printf 'start-issue: #%s already has a branch. Checking out %s.\n' "$issue" "$existing"
  git fetch --quiet origin
  git switch "$existing"
  exit 0
fi

# Defect labels first: an issue carrying both is a defect that also wants a
# feature, and the fix is what ships.
case ",$labels," in
  *,dead-setting,*|*,unreachable,*|*,partial,*|*,wrong-behaviour,*|*,data-loss,*|*,polish,*|*,bug,*|*,accessibility,*)
    prefix=fix ;;
  *,enhancement,*|*,groundwork,*)
    prefix=feat ;;
  *,documentation,*)
    prefix=docs ;;
  *)
    prefix=chore ;;
esac

slug=$(printf '%s' "$title" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' \
  | cut -c1-40 \
  | sed 's/-$//')
[ -n "$slug" ] || slug=issue

branch="$prefix/$issue-$slug"

# No --base. `gh issue develop` branches from the repository's default branch
# on the remote, so a stale local main does not matter here.
gh issue develop "$issue" --name "$branch" --checkout

cat <<EOF

On $branch for #$issue: $title

  1. Commit as you like. Only the pull request title has to be a Conventional
     Commit, and it is what decides the next version number.
  2. gh pr create --fill
  3. CI runs. Merge when it is green, and #$issue closes itself.
EOF
