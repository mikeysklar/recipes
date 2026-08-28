# Submitting to adafruit/Adafruit_Wippersnapper_Arduino: what brentru and tyeth require

Pre-submission reference for PRs and issues on `adafruit/Adafruit_Wippersnapper_Arduino`.
Built from every review comment brentru and tyeth left on PR and issue threads in
this repo (1,509 comments across 369 distinct threads they did not author
themselves, out of 3,297 total joined comments; 892 formal PR review verdicts),
plus the repo's own written process docs: `.github/ISSUE_TEMPLATE/`, and the
`.agents/skills/add-sensor-component-v1/SKILL.md` the maintainers wrote to guide
AI coding agents through the single highest-volume PR shape in this repo.

Produced with the general pipeline in `general-pr-scanner.md`. Repo scale is
moderate (607 PRs total, 113 open issues) — meaningfully smaller than the
circuitpython corpus this method was first built on, so percentages below are
reported only where the underlying sample is large enough to mean something,
and are marked as rough where it isn't.

Use it two ways: read the checklist before you open anything, and hand the
"Pre-flight check" section to a subagent to audit a branch before submission.

---

## 1. The two reviewers at a glance

|                              | brentru (Brent)        | tyeth (Tyeth)           |
|------------------------------|-------------------------|--------------------------|
| Comments on others' threads  | 1,112 across 299 threads | 397 across 92 threads   |
| Approve / Changes / Comment  | 134 / 88 / 292           | 40 / 18 / 318            |
| Median comment length        | 86 chars                | 152 chars                |
| Comments ending in a question | 288 (26%)               | 43 (11%)                 |
| Inline `suggestion` blocks   | 0                        | 2                        |

Unlike a repo with a clean architecture-vs-correctness split, brentru and
tyeth cover mostly the same ground — both weigh in on driver design, board
compatibility, and network reliability. The difference is volume and register,
not topic:

**brentru is the default, high-volume reviewer.** He comments on nearly 3x as
many threads as tyeth, asks far more clarifying questions (26% of his comments
end in `?` vs 11%), writes tersely, and does almost all of the stale-issue
triage (14 "closing this stale issue" comments vs tyeth's 4 in the themed
sample). If only one of them responds to your PR, it is almost always him.

**tyeth writes fewer comments but goes deeper, and owns two things by
volume-adjusted share rather than raw count:** protobuf/wire-schema design
(12 comments across 8 PRs vs brentru's 8 across 8, despite a third of the
total volume) and driver duplication/factoring (7 vs brentru's 2). He also
does the bulk of hands-on multi-board hardware bring-up testing described in
his own comments (UF2/bootloader behavior, I2C bus scanning edge cases,
HIL — hardware-in-the-loop — test runs), and hedges genuinely ("not certain
what happens in error situations", "no idea", "I'd be tempted to") rather
than asserting.

Consequence: brentru is more likely to send back a quick, decisive "why do we
need this" or a mechanical fix request; tyeth is more likely to dig into
whether a driver actually behaves correctly on real hardware, and to ask
open-ended design questions you're expected to engage with, not just resolve.

Both routinely review each other's PRs too — a large share of this repo's own
development happens as brentru/tyeth PRs against `main` (see §4), so the
standards below are enforced on their own code, not just on contributors'.

---

## 2. Decide what you are opening, before you open it

**Which repository?** A driver or firmware change belongs in
`Adafruit_Wippersnapper_Arduino`. A new sensor also needs a matching entry in
the separate `Wippersnapper_Components` repo (JSON definition + product
image) — see §8. These are always two PRs, one per repo, cross-referenced.

**`.proto` files are off-limits to non-staff.** Wire-format schema lives in
`Wippersnapper_Protobuf` and only Adafruit staff modify it, per the
maintainers' own written skill doc:
> "Proto files are off-limits. Only Adafruit staff modify `.proto` files."
> (`.agents/skills/add-sensor-component-v1/SKILL.md`)

If your change needs a new field on the wire, open an issue and propose it —
don't touch `.proto` in your PR.

**Is it a design change?** Park it explicitly rather than pushing an
unresolved design question through review.
> "edit: holding while we decide a path ... noting that this will be fixed
> in production on server-side, not in firmware" (brentru, #287)

Driver-level design disagreements get resolved in the thread, in the open —
tyeth and brentru negotiate with each other in public on shared PRs (e.g.
#644, #693), so expect the same back-and-forth on yours.

**Should this go through the AI-agent skill instead of hand-writing it?** For
the single most common PR shape here — adding a new I2C sensor driver — the
maintainers have written and iterated on a structured skill
(`add-sensor-component-v1`) specifically because ad hoc attempts (by both
humans and agents) kept making the same mistakes: guessing library names from
repo names, skipping the datasheet/learn-guide, and skipping `library.properties`.
Read §8 before starting a driver PR by hand.

---

## 3. Branch targeting

Unlike circuitpython's fixed `main` + `X.Y.x` release-branch model, this repo
normally targets `main` directly — there is no dedicated stable/release
branch. But **check current open PRs before you branch**, because the
maintainers regularly run large migrations on long-lived integration
branches that are not `main`. At the time this was written, multiple open
PRs targeted `migrate-api-v2`, `migrate-api-v2-backport-components`,
`api-v2-pins-as-strings`, and feature branches like
`claude/telemetry-protobuf-components-...` instead of `main`:

```
971  main                                  add(component): Add SCD43 ...
964  migrate-api-v2                        Fix [Pico W] ...
956  migrate-api-v2                        Dfrobot firebeetle2 esp32c5
946  migrate-api-v2-backport-components    feat(telemetry): RSSI + boot reason ...
933  migrate-api-v2                        Backport 22 missing I2C sensor drivers to API v2
```

If your change overlaps an active migration (currently the v2 API rewrite),
check the most recent PRs touching the same files to see what they target,
or ask, before opening against `main`. Getting this wrong on a smaller repo
like this one is cheap to fix (rebase onto the right base and re-open) but
avoidable.

---

## 4. What gets a PR closed unmerged

78 closed-unmerged PRs are in this dataset. The framing here differs sharply
from a typical external-contribution repo: **the large majority are brentru's
and tyeth's own experimental or scratch branches**, not community submissions
getting rejected. Roughly:

- ~24 (31%) are the auto-generated `.proto file wrappers updated` bot PRs
  (author `adafruitio`) or other internally-authored PRs explicitly closed
  "in favor of" / "superseded by" / "folded into" a follow-up PR number.
- ~40 (51%) are brentru/tyeth's own exploratory or WIP branches, closed with
  reasoning like "superseded by #NNN," a hardware bring-up failure
  ("Feels like ... can't get my titano to boot correctly (red light of
  doom)" — tyeth, #538), "no longer needed thanks to #446" (tyeth, #357), or
  (twice) an explicit note that the branch was itself a test of an AI coding
  agent's ability (see §6).
- Only ~8 (10%) were opened by someone outside the two maintainers. This is
  the small-but-real sample worth reading closely if you are an external
  contributor:

  - **CI-breaking dependency/naming mismatches kill driver PRs.** Two
    external driver PRs stalled specifically on this:
    > "@borotaman Ok, the library is not named this so Arduino is not
    > picking it up. Please change `Adafruit HTU31D` to
    > `Adafruit HTU31D Library`." (brentru, #302)
    > "This one hasn't gone into library.properties" (tyeth, #803)
  - **Unresolved `clang-format` CI failures stall a PR indefinitely.**
    > "Hi @afp316 - this pull request is still failing on clang-format ...
    > we have a guide on this here:
    > https://learn.adafruit.com/the-well-automated-arduino-library/formatting-with-clang-format"
    > (brentru, #291)
  - **A good external driver often gets absorbed into an internal rewrite
    rather than merged as-is**, when the maintainers need it tested and
    finished on a timeline:
    > "Closing this PR in favor of #296 which provides tested support for
    > SHT4x. Will be released in next version." (brentru, #266, closing a
    > community-submitted SHT4x driver)
  - **A device that misbehaves under the generic I2C bus scan is a hard
    blocker**, independent of whether the driver code itself is correct:
    > "This is not planned for support, due to failing to initialise after
    > being i2c scanned. Hotplugging the device after scanning was deemed
    > unacceptable." (brentru, #565, on the MCP9601)
  - **Contributors going quiet is handled gently, not punitively** — the
    PR gets closed but the door stays open:
    > "I kind of lost track on this one, I probably won't be finishing." /
    > "Ok - no problem!" (afp316 / brentru, #289)

The practical read: your driver code being correct is necessary but not
sufficient. CI must be green (clang-format, build, Doxygen), the dependency
must be named exactly as `library.properties` declares it, and the physical
device must survive being probed by the generic I2C scan before your PR is
safe from being quietly superseded by an internal rewrite.

---

## 5. What to put in the PR description

There is no `.github/PULL_REQUEST_TEMPLATE.md` in this repo, so nothing is
enforced by GitHub's UI — these expectations come entirely from the
maintainers' own written skill doc and from what they repeatedly ask for in
review.

```markdown
## What
One or two sentences. What this adds or fixes, and which repo(s) — a new
I2C sensor driver needs a matching PR in Wippersnapper_Components too.

## Model used
If any part of this PR was AI-assisted, say which model/tool. This is an
explicit, written instruction from the maintainers' own agent-facing docs,
not an inferred norm — see §6.

## Testing
How you tested it: which board, and whether you exercised the actual
Adafruit IO device page flow (New Component → "Show Dev" → configure →
confirm readings appear), not just that it compiles. If you don't have
hardware, say so explicitly.

## Related PR
For a sensor driver, link the companion Wippersnapper_Components PR (JSON
definition + product image) in the other direction.
```

Evidence for each of those:
- "Mention the model used for the PRs in the description" is a direct
  instruction to submitters (human or AI-agent), not paraphrased:
  `.agents/skills/add-sensor-component-v1/SKILL.md`, Step 8.
- The two-repo linkage is explicit in the same doc: "PR 2 ... Reference the
  components PR in the description," and points to #228 as "a good example
  PR" worth reading before writing your own description.
- The real hardware-testing bar is the Adafruit IO device page flow, not
  just a compile: `.agents/skills/add-sensor-component-v1/SKILL.md`, Step 9
  ("Go to Adafruit IO device page → New Component → check 'Show Dev' ...
  Verify sensor readings appear on the device page").
- Board name is the first thing asked in the bug-report template
  (`.github/ISSUE_TEMPLATE/bug_report.md`) and shows up the same way in PR
  review when a fix's applicability is in question.

---

## 6. AI-assisted work: an unusually AI-forward repo, with real caution baked in

This repo is far more AI-integrated than a typical Adafruit repo. It carries
`agents.md`, `claude.md`, `gemini.md`, and `opencode.md` at the root (all
pointing at `.agents/skills/`), a real skill (`add-sensor-component-v1`) the
maintainers actively maintain and iterate for driving AI coding agents through
driver PRs, and a bot account, `tyeth-ai-assisted`, that posts PR updates with
a `_🤖 Addressed by [Claude Code]_` footer. tyeth also actively directs GitHub
Copilot's coding agent in review threads (`@copilot resolve the merge
conflicts`, `@copilot reduce this millis call duplication`, #896/#910).

That openness comes with sharp, explicit caution, not blanket acceptance:

- **Disclose the model, per the written skill instructions** — see §5.
- **Agent output that skips the research step is called out and rejected,**
  not silently fixed:
  > "cheated, used a memory rather than finding the driver" (tyeth, #889)
  > "Closing as was a test of the lowest model's capabilities (generally
  > poor without prescriptive guidance)." (tyeth, #886)
- **Unverified externally-suggested AI fixes are refused outright:**
  > "no thanks, don't infect us with your chatgpt/codex bug 😬" (tyeth, #921)
- **Strip agent artifacts before submitting**, the same way circuitpython's
  maintainers flag LLM tells:
  > "Rm Claude plan file from commit" (brentru, #875)
  > "I'd remove the claude readme and .claude folder from ignore. Instead
  > ignore the settings file inside claude folder along with the worktrees
  > subfolder." (tyeth, #917)
- **The skill doc itself codifies the exact failure modes seen in review**,
  which is worth reading as maintainer intent even though it's phrased as
  agent instructions rather than a human policy statement:
  > "These rules exist because agents have previously skipped the learn
  > guide, guessed GitHub URLs for libraries, silently ignored 404s, and
  > constructed library names from repo names instead of looking them up.
  > Each of these produced drivers that either called non-existent APIs or
  > failed to compile." (`add-sensor-component-v1/SKILL.md`, "Hard Gates")

Net effect: using an AI agent to write your PR is normal here and even
tooled-for, but the bar is that the output is verified against the real
library/datasheet, not that it merely compiles or looks plausible.

---

## 7. Code rules they enforce

### Driver architecture (their most consistently enforced area)
- Every I2C driver subclasses the shared `drvBase` base class. Reviewers
  push back hard when a driver reaches for the wrong base or duplicates
  logic `drvBase` already owns:
  > "We aren't going to change the base type of the `i2c_driver` vector.
  > Instead of `auto` use the base class `drvBase`." (brentru, #748)
  > "Why is this and other drivers using the Output base header, `out`
  > prefix, and the rest use the `dispDrvBase.h`?" (brentru, #875)
- Match the existing `getEvent*()` naming pattern used by sibling drivers
  rather than inventing your own:
  > "Maybe should be getEventProximity(sensors_event_t *proximityEvent)
  > instead of getEventRaw, matching the ToF VL53x sensors" (tyeth, #787)
- **Never block the main loop.** WipperSnapper runs many components
  concurrently in one loop; an infinite `while (!sensor.dataReady())
  delay(10);` hangs the whole firmware if one sensor stalls. Use a bounded
  check-and-retry instead (`add-sensor-component-v1/SKILL.md`, "Key
  decisions").
- If the sensor's datasheet requires a minimum polling cadence to keep an
  internal algorithm running (e.g. a gas sensor's IAQ estimation), implement
  `fastTick()` with a `millis()`-based non-blocking guard and cache the
  reading, rather than trying to poll at the requested publish interval.

### Naming and dependencies
- **The Arduino/PlatformIO library name comes from that library's own
  `library.properties`, never guessed from its GitHub repo name.** This is
  called out as the single most common agent/contributor mistake:
  > "Library names come from `library.properties`, not from the repo name.
  > ... An agent once guessed `adafruit/Adafruit AS7331` ... and got
  > `UnknownPackageError`." (`add-sensor-component-v1/SKILL.md`)
  In review, the same mistake surfaces as a naming-mismatch build failure:
  > "the library is not named this so Arduino is not picking it up. Please
  > change `Adafruit HTU31D` to `Adafruit HTU31D Library`." (brentru, #302)
- Add every new dependency to both `library.properties` (`depends=`) and
  `platformio.ini` (`lib_deps`), using that exact registered name.
- PascalCase for C++ identifiers (`WipperSnapper_I2C_Driver_TMP119`),
  lowercase for the component folder and internal `strcmp` string
  (`tmp119`). Pick the canonical name once and use it everywhere.

### Formatting, docs, and headers
- `clang-format` must pass in CI before review continues — a failing check
  stalls the PR (§4). Run it locally first.
- Every public/protected method needs a Doxygen `/*! @brief ... */` block;
  CI enforces this.
- New driver files need the standard Adafruit file header with your name
  and the current year — reviewers flag this by hand when it's missing:
  > "Add the default file header including license and your name."
  > (brentru, #748)
  > "Add your name and current year here" (brentru, #565)
  > "Missing copyright" (brentru, #765)

### Scope and duplication
- Factor out logic that already exists elsewhere in a driver rather than
  reimplementing it:
  > "Handling this within the drvBase rather than the driver configuration
  > func call itself" (brentru, #925)
- Unnecessary or unreferenced code gets removed on sight:
  > "If we aren't utilizing these lines, delete them. Otherwise, comment
  > why they may be needed in the future." (brentru, #590)

---

## 8. Adding a new I2C sensor driver (their highest-volume PR category)

File-path clustering across reviewed PRs confirms this directly: 153 of 365
PRs with file data (42%) touch a driver-shaped path, and
`src/components/i2c/drivers` is the single most-touched directory outside
`src/` itself (273 file-touches, ahead of every other directory).

This is also the one category where the maintainers have written down the
full process, in `.agents/skills/add-sensor-component-v1/SKILL.md` — read it
before starting, it is the closest thing this repo has to a CONTRIBUTING
guide. Summary of what it requires, cross-checked against real review
comments above:

1. **Research before writing code — this is a hard gate, not a suggestion.**
   Find the Adafruit product page, follow it to the learn guide, and read
   the `## Arduino` section to get the real library name. A 404 anywhere in
   this chain is a stop-and-ask signal, not something to route around.
2. **Two PRs, cross-referenced:** the firmware PR (driver + registration +
   dependency entries) in this repo, and a `definition.json` + product image
   PR in `Wippersnapper_Components`.
3. **Read the library's actual example sketch and header before writing the
   driver.** Use the closest existing driver as a template — `SCD30` for
   read-caching and default-setting style, `SGP30` for the `fastTick()`
   pattern.
4. **Never block** — see §7.
5. **CI must pass**: `clang-format -i`, Doxygen comment blocks on every
   public/protected method, and a successful build across the boards in
   `platformio.ini`.
6. **Test through the real Adafruit IO device page flow** if hardware is
   available (§5), and say so — or say explicitly that you couldn't.
7. **PR titles follow a fixed convention:** `Add <SENSOR> component
   definition` for the Components repo, `Add <SENSOR> I2C driver` for the
   firmware repo.

`.proto` changes are never part of this — see §2.

---

## 9. Filing an issue

There's no dedicated maintainer-triage pattern the way dhalbert triages
circuitpython issues — brentru does most of the stale-issue closing, but
issue volume in the reviewed sample is small enough that this section leans
on the repo's own bug-report template rather than inferred frequency. From
`.github/ISSUE_TEMPLATE/bug_report.md`, in the order it asks for them:

1. Exact Arduino board name/type.
2. Steps to reproduce.
3. Expected vs. actual behavior.
4. Which components are configured on the WipperSnapper device page for that
   board.
5. Screenshots, if applicable.
6. Host OS/browser/version, if the issue involves the Adafruit IO web UI
   (desktop and mobile fields are both present in the template).

In review threads, board identity and exact firmware/library version are the
recurring follow-up questions when a bug report is ambiguous, the same as
circuitpython's dhalbert pattern — just without the volume to quantify it
reliably here.

---

## 10. Reading their language

**brentru** is short, direct, and reviews at high volume. A question is
almost always a real, answerable question rather than pure rhetoric — he
asks more of them than tyeth by a wide margin.

| He writes | He means |
|---|---|
| "Why do we want X instead of Y?" / "Why is this needed?" | Justify it in the thread or drop it |
| "Could you ...?" | A concrete, expected change |
| "Closing in favor of #NNN" | Not a rejection of the goal — the work continues elsewhere, follow that PR |
| "Closing this stale issue due to inactivity ... I'll re-open" | Not final — comment if you're still working it |
| "Add your name and current year here" / "Missing copyright" | Mechanical, just do it |
| "Nice catch!" / "Thanks for the work!" | Genuine, he thanks contributors readily |

**tyeth** writes longer, hedges honestly ("not certain", "no idea", "I'd be
tempted to"), and is the one most likely to go hands-on with real hardware
before responding.

| He writes | He means |
|---|---|
| "Superseded by #NNN" / "Superceded by #NNN" | Same as brentru's "in favor of" — track the successor |
| "I'd be tempted to ..." | A real design opinion, open to pushback with evidence |
| "cheated, used a memory rather than finding the driver" | Blocking — the implementation wasn't actually verified against the source |
| "no thanks, don't infect us with your chatgpt/codex bug" | A hard no on an unverified suggested fix |
| "Looks good @brentru, just some minor things" | Approval in substance, minor items still expected to land |

---

## 11. Responding to review

- Apply naming/formatting fixes without pushback — these are the most common
  mechanical asks and are never negotiable in this dataset.
- If a PR's fate is genuinely undecided, park it explicitly rather than
  letting it go silent: "holding while we decide a path" (brentru, #287) is
  the model to follow.
- When asked whether a stalled PR should stay open, answer directly:
  > "@tyeth Ok! In that case, this PR still active or do you want to close
  > it?" / "Happy to close it. I perused it again and can refer when
  > necessary." (brentru / tyeth, #658)
- Tag the reviewer explicitly when you want another look:
  > "@tyeth Okay, please tag me for re-review before merging" (brentru, #765)
- If you used an AI agent and it hit a blocker (couldn't push, couldn't find
  a library), say so plainly rather than papering over it — this repo's own
  skill doc treats a silent workaround as worse than reporting the failure.

---

## 12. Pre-flight check

Run this against the branch before opening the PR.

**Scope**
- [ ] Correct repo: firmware change here, sensor definition/image in
      `Wippersnapper_Components`, both PRs cross-referenced if it's a new
      sensor
- [ ] No `.proto` file changes — those are staff-only
- [ ] Any open design question resolved or explicitly parked in the thread,
      not left implicit

**Branch**
- [ ] Checked recent open PRs on the same files to confirm the right base
      (`main`, or an active migration branch like `migrate-api-v2`)

**Driver code** (if adding/changing an I2C sensor)
- [ ] Subclasses `drvBase`; `getEvent*()` naming matches sibling drivers
- [ ] No blocking `while(...) delay(...)` loop; bounded check-and-retry
      instead
- [ ] `fastTick()` implemented if the datasheet requires a minimum polling
      cadence, otherwise omitted
- [ ] Library name in `library.properties` and `platformio.ini` matches the
      dependency's own `library.properties`, not its GitHub repo name
- [ ] File header present with your name and the current year
- [ ] Doxygen `/*! @brief ... */` blocks on every public/protected method
- [ ] `clang-format -i` run and clean
- [ ] Builds for the relevant boards in `platformio.ini`

**Description**
- [ ] What, and which repo(s)
- [ ] AI model used, disclosed, if any part was AI-assisted
- [ ] How it was tested — real board via the Adafruit IO device page flow,
      or an explicit statement that hardware wasn't available
- [ ] Companion `Wippersnapper_Components` PR linked, for a new sensor
- [ ] No stray AI-agent artifacts (plan files, `.claude`/`.agents` config,
      unreviewed generated code) left in the diff
