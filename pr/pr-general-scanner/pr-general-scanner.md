# General PR scanner: build a reviewer profile for any repo

Generalized version of the process behind `circuitpython-review.md`. Point it
at any GitHub repo and it produces the same kind of deliverable: who actually
decides whether a PR merges, what they consistently ask for, what gets a PR
closed unmerged, and a pre-flight checklist to run before you submit.

Use it two ways: follow it once by hand to produce `<repo>-review.md`, or hand
the whole file to an agent with a repo name and let it execute the steps and
write the deliverable. It is also the basis for a reusable skill — see
"Turning this into a skill" at the end.

Requires `gh` authenticated against the target host, and `jq`/`python3`.
Everything below is parameterized on:

```bash
export OWNER=owner
export REPO=repo
```

---

## 0. Decide if this approach fits the repo

This method assumes a repo with a real review culture: enough PR/issue volume
that a small number of people leave the comments that actually gate merging.
It degrades gracefully on smaller repos (see step 8), but on a repo with under
~100 closed PRs there usually isn't enough signal to distinguish a pattern
from a one-off. Check first:

```bash
gh api "repos/$OWNER/$REPO" --jq '{stars: .stargazers_count, open_issues: .open_issues_count}'
gh pr list -R "$OWNER/$REPO" --state all --limit 1 --json number | jq .
```

If the repo is small enough that you could read every closed PR yourself in
under an hour, just do that instead of running the pipeline.

---

## 1. Find the moderators — don't assume you already know who they are

The circuitpython version started from two known names. On an unfamiliar repo,
derive them instead of guessing. GitHub's REST comment endpoints return
`author_association` per comment (`OWNER`, `MEMBER`, `COLLABORATOR`,
`CONTRIBUTOR`, `NONE`) — rank by comment volume filtered to the first three,
excluding comments people left on their own threads.

```bash
mkdir -p data && cd data

# All line-level review comments, paged to exhaustion
gh api --paginate "repos/$OWNER/$REPO/pulls/comments" > rc_raw.jsonl.tmp \
  && jq -s '.' rc_raw.jsonl.tmp > review_comments.json

# All issue-thread comments (covers PR conversation comments + issues)
gh api --paginate "repos/$OWNER/$REPO/issues/comments" > ic_raw.jsonl.tmp \
  && jq -s '.' ic_raw.jsonl.tmp > issue_comments.json
```

Then rank:

```bash
python3 - <<'EOF'
import json, collections
rc = json.load(open('review_comments.json'))
ic = json.load(open('issue_comments.json'))
counts = collections.Counter()
for c in rc + ic:
    if c.get('author_association') in ('OWNER', 'MEMBER', 'COLLABORATOR'):
        counts[c['user']['login']] += 1
for who, n in counts.most_common(15):
    print(f"{n:6d}  {who}")
EOF
```

The top 2-4 names by volume, cross-checked against who actually leaves
`APPROVED` / `CHANGES_REQUESTED` reviews (not just comments), are your
moderators. Confirm with:

```bash
gh api --paginate "repos/$OWNER/$REPO/pulls" -f state=all --jq '.[].number' > all_pr_numbers.txt
# sample a few hundred if the repo is huge — see step 8
```

A maintainer who reviews a lot but rarely uses `CHANGES_REQUESTED` may still
be the real gate — some repos merge on a single "comment" review plus a green
check. Don't over-index on the formal verdict field alone; cross-reference
against who is in `CODEOWNERS` (if present) and who actually clicks merge
(`merged_by` on merged PRs).

```bash
gh api "repos/$OWNER/$REPO/contents/CODEOWNERS" 2>/dev/null --jq -r '.content' | base64 -d 2>/dev/null
gh api "repos/$OWNER/$REPO/contents/.github/CODEOWNERS" 2>/dev/null --jq -r '.content' | base64 -d 2>/dev/null
```

---

## 2. Pull PR/issue metadata and join it to the comments

Line comments and issue comments don't carry PR outcome, author, or diff
size. Join against GraphQL metadata, batched (GraphQL doesn't page well for
bulk lookups by number, so batch by number list instead — see
`data/fetch_meta.sh` and `data/worker.sh` in this directory for a working
batching script against `adafruit/circuitpython`; swap the two hardcoded
`owner`/`name` strings and the input number list to reuse it directly).

The query shape:

```
query {
  repository(owner: "OWNER", name: "REPO") {
    a0: issueOrPullRequest(number: N) {
      __typename
      ... on PullRequest {
        number title state merged createdAt
        author { login }
        additions deletions changedFiles
        reviews(first: 60) { nodes { author { login } state body submittedAt } }
      }
      ... on Issue {
        number title state createdAt
        author { login }
      }
    }
  }
}
```

Batch ~40 numbers per query (GraphQL query complexity limits), run batches in
parallel (`xargs -P 6`), and join the results into every comment: PR/issue
number → title, state, merged, author, size, review verdicts. This join is
what lets you filter to "comments on PRs the moderator did not author" and to
compute closure-cause statistics later.

---

## 3. Filter to signal

Exclude comments moderators left on their own PRs/issues — you want what they
ask *of submitters*, not how they narrate their own work.

```python
comments = [x for x in joined
            if x['type'] == 'PullRequest'
            and x['who'] != x['pr_author']
            and x['body']]
```

Compute the per-moderator profile table (mirrors circuitpython-review.md §1):

```python
import statistics, collections
for who in MODERATORS:
    mine = [x for x in comments if x['who'] == who]
    print(who, 'total', len(mine), 'PRs', len({x['pr'] for x in mine}))
    print('  median chars', statistics.median(len(x['body']) for x in mine))
    print('  suggestion blocks', sum('```suggestion' in x['body'] for x in mine))
    print('  ends in ?', sum(x['body'].strip().endswith('?') for x in mine))
verdicts = collections.Counter((x['who'], x['review_state']) for x in reviews)
```

If two or more moderators show up, look for a role split before writing
anything else — circuitpython's split was architecture-vs-correctness, but it
could just as easily be frontend-vs-backend, or design-vs-release-mechanics.
The split usually falls out of which comment themes cluster on which name
(step 4). State the split explicitly in the deliverable: it tells a
submitter whose objection to resolve first.

---

## 4. Theme-tag the comments

Start from this generic theme set (adapted from `data/themes.py`), then add
2-4 domain-specific themes by skimming 50-100 comments first — every repo has
its own hot topics (memory allocation for an embedded C repo, N+1 queries for
a backend repo, bundle size for a frontend repo, migration safety for a repo
with a database).

```python
THEMES = {
 'scope/necessity':      r'\b(why (do|does|is)|do we need|out of scope|separate PR|split (this|the))\b',
 'duplication/reuse':    r'\b(duplicat\w+|already (exists|have)|factor(ed)? out|DRY)\b',
 'testing/verify':       r'\b(did you test|have you tested|please test|verify|reproduce|CI\b)\b',
 'style/formatting':     r'\b(lint|format(ting)?|whitespace|typo|pre-commit|style guide)\b',
 'naming':               r'\b(rename|better name|misleading name|naming)\b',
 'docs/comments':        r'\b(add a comment|docstring|document(ed|ation)?|explain (in|what|why))\b',
 'API/interface design': r'\b(API|interface|signature|breaking change|backwards.compat)\b',
 'performance':          r'\b(performance|slow(er)?|latency|overhead|optimi[sz]e)\b',
 'security':             r'\b(sanitiz\w+|injection|escape|CVE|vulnerab\w+|auth(entication|orization)?)\b',
 'commit hygiene':       r'\b(rebase|squash|force.?push|commit message|unrelated change)\b',
 'simplify':             r'\b(simpl(er|ify)|unnecessary|not needed|remove this|no need)\b',
}
```

Run and rank by count per moderator (see `data/themes.py` for the full loop).
The top 5-8 themes per moderator become the "code rules" section of the
deliverable — but don't stop at the count. Pull 3-5 actual quotes per theme
(the `q.py`/`qi.py` pattern: regex-match, dedupe by first 60 chars, print
`[who|#PR|outcome] snippet`) so the deliverable states the rule in the
moderator's own words with a citation, not a paraphrase. Paraphrased rules
drift from what was actually said; quoted ones don't.

---

## 5. Find what gets a PR closed unmerged

This is usually the highest-value section, because it is asymmetric: a
submitter can read a hundred approved PRs and still miss the two habits that
get PRs killed.

```python
closed = [x for x in joined_prs if x['state'] == 'CLOSED' and not x['merged']
          and x['number'] in reviewed_by_moderators]
```

For each, pull the last 3-5 comments on the thread (closing discussion is
almost always where the real reason surfaces, not the opening description).
Classify by keyword into buckets like:

- submitter went silent (no response for weeks, then a polite close)
- design/API rejected even though the goal was accepted
- superseded by another PR / fixed elsewhere
- wrong base branch, never corrected
- scope too broad, asked to split, never split
- untested or non-building code
- repo-specific killer (circuitpython's was a bad USB VID/PID on board PRs —
  every repo has an equivalent "this one thing blocks merge outright";
  finding it is worth the whole exercise)

Report rough percentages, not false precision — note explicitly that
categories overlap and a keyword classifier is approximate. The value is in
ranking ("silence is bigger than everything else combined") not in a clean
partition.

---

## 6. Check the repo's own stated process

Don't infer what's already written down. Read directly and fold it in rather
than re-deriving it from comments:

```bash
gh api "repos/$OWNER/$REPO/contents/CONTRIBUTING.md" --jq -r '.content' | base64 -d
gh api "repos/$OWNER/$REPO/contents/.github/PULL_REQUEST_TEMPLATE.md" --jq -r '.content' | base64 -d
gh api "repos/$OWNER/$REPO/contents/.github/ISSUE_TEMPLATE" --jq '.[].name'
gh api "repos/$OWNER/$REPO/branches" --jq '.[].name'   # branch model (main + release branches?)
```

Cross-reference against comment volume: if `CONTRIBUTING.md` says "run the
linter" and moderators still leave 80 comments a year about formatting, the
written doc isn't being read — say so, and lead with it more forcefully in
the deliverable than the source doc does.

---

## 7. Find the repo's highest-volume PR category

Not every repo has an equivalent of circuitpython's "new board PR," but most
domain repos have *some* recurring PR shape with its own extra checklist —
a new connector/provider/plugin, a new migration, a new locale. Find it by
grepping which files show up together across moderator-reviewed PRs:

```bash
gh pr list -R "$OWNER/$REPO" --state all --limit 500 --json number,files \
  | jq -r '.[].files[].path' | sort | uniq -c | sort -rn | head -30
```

If one small cluster of paths dominates, treat it as its own subsection with
its own checklist, the way circuitpython splits board PRs (and further splits
zephyr-cp boards, which don't follow the general board-PR rules at all).
Watch for exactly that kind of exception — a category that looks like the
main pattern but silently isn't — and call it out the same way.

---

## 8. Scaling down for smaller repos

Under a few hundred PRs, comment volume alone won't separate signal from
noise the way it does at circuitpython's scale (5,000+ comments). Adjust:

- Don't compute percentages on the closed-PR classification (step 5) below
  ~30 closed-and-reviewed PRs; list the actual cases instead of a table.
- Skip the theme-frequency table (step 4) if any given theme has fewer than
  ~10 hits; quote the handful of comments directly instead.
- If there's really only one moderator, section 1's "two reviewers" framing
  collapses to one profile — don't force a role split that isn't there.
- If GraphQL batching (step 2) is overkill for the PR count, just call
  `gh pr view $N --json ...` in a loop instead.

The goal is always the same regardless of scale: extract what's actually true
about this repo's gatekeeping, not what the framework expects to find.

---

## 9. Write the deliverable

Structure `<repo>-review.md` the way `circuitpython-review.md` is structured
— it's a template, not just an example:

1. **The moderators at a glance** — table from step 3, plus the role split if
   one exists.
2. **Decide what you're opening, before you open it** — repo/library/upstream
   boundary questions if they exist for this repo; design-vs-implementation
   sequencing; split-PR pressure.
3. **Branch / process mechanics** — from step 6, plus any comment-driven
   corrections found in step 4's commit-hygiene theme.
4. **What gets a PR closed unmerged** — step 5, in ranked-cause order.
5. **What to put in the PR/issue description** — synthesize the PR template
   (step 6) with the questions moderators repeatedly ask that the template
   doesn't cover (very common: exact versions, exact repro steps, what was
   NOT tested).
6. **AI-assisted work** — search step 1's comment corpus for `LLM|AI-generat|
   Copilot|ChatGPT|Claude|Cursor` ahead of writing this section; many repos
   now have explicit stated positions worth quoting directly, and getting
   this wrong (assuming a repo is silent on it when it isn't, or inventing a
   policy when it's never been said) undermines the rest of the document.
7. **Code/domain rules** — step 4's themes with quotes.
8. **The repo's highest-volume special category**, if step 7 found one.
9. **Filing an issue** — same treatment as PRs, from the issue-comment corpus.
10. **Reading their language** — a phrase-to-meaning glossary. Build it by
    finding short phrases each moderator repeats verbatim across many threads
    (`grep`-style clustering on the comment corpus works fine), then read
    enough surrounding context on each to state what it actually means in
    practice, distinguishing genuine open questions from rhetorical ones.
11. **Responding to review** — general good practice plus anything
    repo-specific (this repo's stance on force-push, on `suggestion` blocks,
    on splitting review threads into new issues).
12. **Pre-flight checklist** — every `[ ]` item upstream in the document,
    collected into one runnable checklist at the end, grouped the same way
    the document's sections are grouped.

Keep every claim traceable to either a quote or a stated count — that
traceability, not the prose, is what makes the deliverable trustworthy enough
to hand to a subagent as a gate before submission.

---

## 10. Turning this into a skill

Once `<repo>-review.md` exists for a repo you work in regularly, do what this
repo does with `circuitpython-review.md` and the `/tandan` skill: write a
skill whose job is "read `<repo>-review.md`, then audit the current branch's
diff and PR description against every item in its pre-flight checklist,
flagging any unchecked box with the specific quote it violates." The skill
itself stays generic — it's the checklist file, not the skill, that's
repo-specific. That's what makes this reusable across every repo you touch
without rewriting the audit logic each time.
