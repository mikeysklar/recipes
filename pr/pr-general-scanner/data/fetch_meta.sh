#!/bin/bash
# Batch-fetches PR/issue GraphQL metadata for pr-general-scanner.md's Step 2.
#
# Usage:
#   export OWNER=owner REPO=repo
#   cd data && ../data/fetch_meta.sh
#
# Expects a `nums.txt` file in the current directory, one PR/issue number
# per line (e.g. from `gh api --paginate "repos/$OWNER/$REPO/pulls" -f
# state=all --jq '.[].number' > nums.txt`). Writes `meta/chunk_*.json`,
# one GraphQL response per 40-number batch, run 6 at a time.
set -euo pipefail

: "${OWNER:?set OWNER, e.g. export OWNER=owner}"
: "${REPO:?set REPO, e.g. export REPO=repo}"

mkdir -p meta
split -l 40 nums.txt meta/chunk_
ls meta/chunk_* | xargs -P 6 -I{} bash -c '
f="{}"; out="${f}.json"
[ -s "$out" ] && exit 0
q="query{repository(owner:\"'"$OWNER"'\",name:\"'"$REPO"'\"){"
i=0
while read n; do
  q="$q a$i: issueOrPullRequest(number:$n){ __typename ... on PullRequest{ number title state merged createdAt author{login} additions deletions changedFiles reviews(first:60){nodes{author{login} state body submittedAt}} } ... on Issue{ number title state createdAt author{login} } } "
  i=$((i+1))
done < "$f"
q="$q}}"
gh api graphql -f query="$q" > "$out" 2>"${f}.err"
'
