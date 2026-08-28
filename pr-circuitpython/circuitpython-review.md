# Submitting to adafruit/circuitpython: what tannewt and dhalbert require

Pre-submission reference for PRs and issues on `adafruit/circuitpython`.
Built from every review comment tannewt and dhalbert left on other people's PRs
and issues in this repo (5,016 PR comments across 1,388 distinct PRs, plus 2,418
issue comments across 1,008 issues, and 4,266 formal review verdicts).

Use it two ways: read the checklist before you open anything, and hand the
"Pre-flight check" section to a subagent to audit a branch before submission.

---

## 1. The two reviewers at a glance

|                          | tannewt (Scott)                | dhalbert (Dan)                  |
|--------------------------|--------------------------------|---------------------------------|
| Comments on others' PRs  | 2,402 across 777 PRs           | 2,614 across 756 PRs            |
| Approve / Changes / Comment | 649 / 632 / 636             | 592 / 465 / 417                 |
| Median comment length    | 93 chars                       | 100 chars                       |
| Inline `suggestion` blocks | 348 (14%)                    | 424 (16%)                       |
| Comments ending in a question | 384 (16%)                 | 393 (15%)                       |

They split roles consistently:

**tannewt owns architecture and the long-term shape of the API.** He asks whether
the thing should exist, whether the interface is the one CircuitPython wants in
two years, and whether it allocates memory it does not need. His top themes by
volume: API/interface design (181 comments), simplification and removal (163),
necessity and scope (94), memory and allocation (88).

**dhalbert owns correctness, release mechanics, and polish.** He handles branch
targeting, upstream MicroPython coordination, build failures, formatting, docs
wording, and board file hygiene. His top themes: board and hardware specifics
(316), simplification (128), upstream/MicroPython (99), API (99), style and
formatting (78).

Consequence: a change can pass dhalbert's correctness bar and still be blocked by
tannewt on "do we want this at all." Answer tannewt's question in the PR
description before he has to ask it.

---

## 2. Decide what you are opening, before you open it

Their most expensive redirect is telling you the work belongs somewhere else.

**Does it belong in the core at all?** They push work out to libraries often
(57 dhalbert comments, 34 tannewt comments on 69 PRs). If it can be a
CircuitPython library or a community bundle entry, that is where it goes.
> "I don't see it as a core issue, but as a library issue." (dhalbert, #10572)

**Does it belong upstream in MicroPython?** Anything under `py/`, `extmod/`,
`lib/`, or a `tests/` file that came from MicroPython should go to
micropython/micropython first (99 dhalbert comments across 76 PRs).
> "This code comes from MicroPython, so it would be appropriate to submit this
> upstream ... submit there first. If they accept it, then we'll take their
> change as it is merged there, so the sources match." (dhalbert, #10297)

**Is it a design change?** Open an issue and get agreement on the API before
writing the implementation. Design arguments in a PR diff cost you the PR.
> "It is our policy not to change the semantics of APIs during a minor revision.
> ... if you'd like to propose a new API and its semantics, that is great."
> (dhalbert, #10023)

**Is it one change or several?** Split it. They will ask.
> "Could you split this into two PR's ... Then we can discuss the PDM stuff
> separately." (dhalbert, #10623)
> "Please change the files to minimize the diff. There is a lot of extraneous
> changes that are unnecessary." (tannewt, #10503)

---

## 3. Branch targeting (55 comments across 47 PRs, the single most common process correction)

Get this right at branch-creation time. Changing the base on an open PR does not
work: it drags in hundreds of commits and they will make you redo it.

| Change type | Base branch |
|---|---|
| New feature, API change, behavior change | `main` |
| Bug fix you want in the next patch release | current `X.Y.x` branch |
| New board definition | `main` (unless a maintainer asks otherwise) |

Rules they state repeatedly:
- Fixes on `X.Y.x` get merged forward into `main` automatically. Do not open two PRs.
  > "We don't need two PRs. Just the one to 10.2.x is enough. We regularly merge
  > fixes from that branch into main." (tannewt, #11012)
- New features never go on a stable branch.
  > "9.2.x should only be new board defs and bug fixes." (tannewt, #10158)
- If you targeted wrong: branch fresh off the right base and `git cherry-pick`
  your commits, then open a new PR and close the old one.
- Your branch must be current with the base, otherwise `locale/circuitpython.pot`
  shows spurious diffs. If you changed or added an error message, run
  `make translate` at the top level and commit the result.

---

## 4. What gets a PR closed unmerged

Of the 181 PRs in this set that they reviewed and that were closed without
merging, keyword classification of the closing discussion gives roughly:

| Share of closed PRs | Cause |
|---|---|
| ~12% | Submitter stopped responding |
| ~9%  | Design or API rejected, even when the goal was accepted |
| ~9%  | USB VID/PID problem on a board PR |
| ~5%  | Superseded by another PR, or fixed upstream |
| ~4%  | Wrong base branch and the rebase never happened |
| ~2%  | Scope too broad, asked to split, never split |
| ~1%  | Untested or non-building code |

(Categories overlap and the rest are one-offs, so this is a rough shape, not a
partition.) What it means in practice:

1. **Silence closes PRs.** They wait weeks to months, then close politely: "I'm
   going to close this for now ... We can always reopen it." If you are still
   working, say so in the thread. This is the single cheapest failure to avoid.
2. **tannewt will accept your goal and reject your interface.** Getting the API
   agreed in an issue before you write the implementation is the difference
   between a merge and a rewrite.
3. **A generic or reused USB VID/PID blocks a board PR outright.** See section 8.
4. **Search first.** A meaningful share of closures are "in favor of #NNNN" or
   "fixed by upstream MicroPython".
5. **Untested or non-building code draws real annoyance**, even though it closes
   few PRs outright:
   > "Submitting untested, uncompiled code isn't helpful and wastes time."
   > (tannewt, #10503)
   > "We don't merge PR's with broken builds, in general." (dhalbert, #11093)
6. **Symptom fixes get rejected on principle.**
   > "I pinged @hathach internally to look at the root cause. I'd rather fix the
   > root issue than use 15k more RAM." (tannewt, #10964)

---

## 5. What to put in the PR description

They ask for the same handful of things. Include them up front and you skip a round trip.

```markdown
## What
One or two sentences. What behavior changes.

## Why
The problem, and why it belongs in the core rather than a library or upstream
MicroPython. Link the issue or forum thread if there is one.

## Hardware tested
Exact board names, chip revision if relevant, CircuitPython version, and host OS
if USB or filesystem behavior is involved. List what you did NOT test.

## How I tested it
The actual `code.py` you ran, and the serial output. Paste both. If it is a
timing or bus issue, attach the analyzer or sniffer capture, not a description
of one.

## Scope
What is deliberately left out and why. Link the follow-up issue if you filed one.

## AI assistance
State it if you used one, and say what you verified yourself.
```

Evidence for each of those:
- Hardware and version: dhalbert's most common issue-triage question by a wide
  margin. Which board, which version, what does `boot_out.txt` say, which host OS.
- Real measurement, not narrative:
  > "Please use a Beagle or other USB sniffer to prove the behavior from the host
  > OS ... I don't trust your benchmark numbers because they appear to be from an
  > LLM and your benchmarking setup isn't clear to me." (tannewt, #10967)
- Repeat measurements: dhalbert will not accept 3 trials on anything noisy.
  > "The variance on these is pretty high, so I think 5 or 10 trials would give us
  > more confidence." (dhalbert, #11071)
- Smoke test beyond your one case:
  > "Did you try running something like Fruit Jam OS to smoke test general
  > operation?" (dhalbert, #11130)
  > "It would be good to test on Windows as well, and also on boards that are not
  > RP2xxx, such as a PyPortal, and a Metro ESP32-S3." (dhalbert, #10967)

---

## 6. AI-assisted work: their explicit rules

This repo's maintainers use LLMs themselves and are fine with you doing so. They
have precise conditions, and they have already flagged AI-shaped output.

- **Disclose up front.**
  > "Given the size and style of this PR I suspect it was done via LLM agent. In
  > principle that is ok but I'd like you to say so upfront. Please also state
  > 1) What prompts you did and 2) how you tested it." (tannewt, #10793)
- **Review the output yourself before asking them to.**
  > "(Please review LLM changes thoroughly before asking me to.)" (tannewt, #10844)
- **Do not paste model output as evidence.** Measurements must come from
  instruments. See #10967 above.
- **Watch the two things LLMs reliably get wrong here:**
  > "Please don't add new translations unless you really really need to. (claude
  > loves to add new ones)" (tannewt, #10976)
  > "Yes, please try to reduce code elsewhere. LLMs love to add. They are less good
  > at refactoring." (tannewt, #11090)
- **Strip the tells.** Unnecessary casts, dead defines, stale comments, defensive
  NULL checks that cannot fire, verbose comments restating the code.
  > "Then I removed the unneeded `(uint32_t)` casts (maybe an LLM put those in?)"
  > (dhalbert, #11013)
  > "Don't leave dead or stale stuff in." (dhalbert, #11093)

---

## 7. Code rules they enforce

### Memory and allocation (tannewt's sharpest area)
- Anything that must survive a VM restart uses `port_malloc()`, not `m_malloc()`.
  > "Use `port_malloc()` to allocate this when you need it. Those allocations also
  > outlive the VM." (tannewt, #11102)
- Do not add RAM to work around a bug. Fix the bug.
- Prefer stricter argument types over flexible ones when flexibility costs an
  allocation.
  > "I'd just be stricter here. The docs say it's a tuple or single Biquad. Don't
  > support any sequence to save yourself the allocation." (tannewt, #11196)
- Free on failure, and put the cleanup where the allocation is.
- Watch flash size. Adding a feature that pushes small boards over the storage
  limit is your problem to solve, usually by turning the feature off per board.

### Layering
- `shared-bindings/` is the Python API and the docstrings. `shared-module/` is
  portable implementation. `common-hal/` is port-specific only.
- Anything not port-specific must move to `shared-module/` so other ports get it.
- Duplicated logic gets factored out, not copied.
  > "The same code is here. Please factor it out into a shared location in
  > shared-module." (tannewt, #10990)
- Do not put examples in `shared-bindings/` source. Inline docstrings, `docs/*.rst`,
  or a Learn Guide.

### Error messages and translations
- Reuse an existing message before adding one. Use `%q` to adapt an existing
  string rather than writing a new one.
- Strings cost flash. tannewt will tell you to drop messages on rarely hit paths.
- Prefer readable strings and Exception subclasses over error numbers, unless
  matching a CPython API.
  > "Error strings are better than error numbers because they are human readable
  > and therefore human actionable. I only want to avoid similar error messages
  > that could be combined." (tannewt, #10611)

### Conditionals and config
- Use `#if FLAG`, never `#ifdef FLAG`. Undefined macros are an error on purpose.
  Define the default in `py/circuitpy_mpconfig.h` in alphabetical order.
- Board settings belong in `mpconfigboard.mk`, not `mpconfigboard.h`, unless the
  option is header-only.
- On Espressif, prefer CircuitPython's settings over hand-written `sdkconfig`
  entries. An empty board `sdkconfig` is normal and preferred.

### Docs
- Every new or changed Python-visible API needs its `shared-bindings` docstring
  updated in the same PR, including the type signature line.
- New `settings.toml` variables get documented in `docs/environment.rst`, written
  out in full so they are searchable.
- Add a comment explaining any non-obvious mechanism. "Please add a comment about
  how this works" is one of tannewt's most repeated requests.

### Naming our hardware

Use one name for the board everywhere, in PR text, commit messages, review
replies and issues. Inconsistency reads as sloppiness and invites the reviewer
to wonder whether two boards are involved.

- **`SiWx917-DK2605A`** in prose. This is the name to use by default.
- **`siwx917_dk2605a`** when naming the Zephyr board, so a maintainer can go
  straight from the text to `west build -b siwx917_dk2605a`. Worth including
  once in any PR that touches the port.
- **`SiWG917M111MGTBA`** for the SoC part, when the specific silicon matters.
- **`BRD2605A`** only when quoting runtime output. The firmware banner prints
  the radio board number, so a description saying DK2605A next to a banner
  saying BRD2605A looks like a mismatch unless the quote explains itself.

Do not write "SiWx917 DK2605A" with a space, "SiWx917 Dev Kit", or
"DK2605A Rev A00". They are all the same board and the variety is the problem.

### Style
- Install and run `pre-commit` locally. Formatting failures in CI read as
  carelessness.
- Alphabetize lists of anything.
- Newline at end of file.
- Delete dead code rather than commenting it out.
- No unrelated whitespace or reformatting in the diff.

---

## 8. New board PRs (their highest-volume review category)

Most reviewed files: `mpconfigboard.mk`, `pins.c`, `mpconfigboard.h`,
`sdkconfig`, `board.c`.

- **USB VID/PID must be unique and real.** 172 comments across 128 PRs. Generic
  vendor PIDs and reused PIDs block the merge. Espressif boards:
  https://github.com/espressif/usb-pids . Others: https://pid.codes .
  RP2040/RP2350: https://github.com/raspberrypi/usb-pid . Do not swap VID and PID.
- **Manufacturer must be accurate.** If you did not make the board, do not name a
  vendor who did not. "unknown" is acceptable.
  > "I just want it to be clear who made, and (theoretically) supports the board."
  > (tannewt, #10959)
- **`pins.c` carries board-specific names only**, meaning silkscreen labels and
  on-board connections. Every MCU pin is already exposed via `microcontroller.pin`.
  > "Don't include every MCU pin in `board`." (tannewt, #10674)
- Use current pin naming conventions:
  https://learn.adafruit.com/how-to-add-a-new-board-to-circuitpython/pin-and-device-names
- Do not duplicate modules already frozen. Check `.gitmodules`.
- No per-board `README.md`. Board documentation goes to circuitpython-org after merge.
- Use the current `board.c` header, and delete `MP_WEAK` overrides you did not change.
- CI must be green before you ask for review.

### zephyr-cp boards are a different shape

The list above does not transfer. A zephyr-cp board has no `mpconfigboard.h`,
`mpconfigboard.mk`, `pins.c`, `sdkconfig` or USB IDs of its own. It has
`boards/<board>.conf`, `boards/<board>.overlay`, and a generated
`boards/<vendor>/<board>/autogen_board_info.toml`.

- **The board `.conf` must not restate what the port already sets.** Same rule as
  "an empty board `sdkconfig` is normal and preferred", applied to
  `ports/zephyr-cp/Kconfig` and `prj.conf`.
  > "I believe these settings have been factored out. Maybe into Kconfig. I don't
  > think you need them here." (tannewt, #11218)

  Run `scripts/zephyr_conf_dupes.py` against the `.conf`. On #11218 it found 23
  redundant settings; review had flagged one block of them.
- **Nothing the devicetree already implies.** `config BT` defaults from
  `dt_chosen_enabled(zephyr,bt-hci)`, so a board with that chosen node must not
  set `CONFIG_BT=y`.
- **`autogen_board_info.toml` is generated.** It must be byte-identical to what a
  build produces. Build it and diff before filing. Its own header says not to edit
  it, and hand-editing it hides generator bugs: the wrong vendor name in #11218
  was a real defect in `zephyr2cp.py`, fixed separately in #11220.
- **Do not enable devicetree nodes whose supporting code is not in the PR.**
  Measure the effect rather than assuming one. On #11218 enabling `&psram` left
  the Python heap at 7936 bytes either way, because nothing yet builds the heap in
  the largest region, so the node was dropped.
- **Comments carry the reason, not the investigation.** Long narratives of what was
  tried and what the root cause turned out to be belong in the PR body or an
  issue, not in a `.conf` or `.overlay`.
  > "No need for this. The addition is self explanatory." (tannewt, #11223)
- **Verify a `.conf` edit against the generated `.config`, not the diff.** The
  source diff does not show what the edit did, and both failure modes build
  clean: an unknown `CONFIG_` name is silently ignored, and deleting a line falls
  back to the Kconfig default rather than the value you measured with. On #11218
  removing `CONFIG_NET_MAX_CONTEXTS=10` landed on Zephyr's default of 6, under
  the `CONFIG_NET_MAX_CONN=12` it has to cover. Use
  `scripts/zephyr_config_effect.py`. The same check proves the safe removals:
  `CONFIG_SPI_SILABS_SIWX91X_GSPI` and `CONFIG_BT` both stayed `y` once deleted,
  because the devicetree implies them.

---

## 9. Filing an issue

dhalbert does most triage. What he asks for, in rough frequency order:

1. Exact CircuitPython version, and the full `boot_out.txt` contents.
2. Exact board, including variant, flash and PSRAM size, and revision or date code
   if the hardware changed over time.
3. Host OS and version, for anything touching USB, MSC, or the filesystem.
4. A minimal `code.py` that reproduces it, and the full serial output including
   the traceback.
5. Whether it reproduces on the latest alpha or beta, and on a different board.
6. For timing, display, or bus problems: a photo, video, or analyzer capture.
7. Whether the code involved was AI-generated. He checks generated code against
   the docs before debugging it.

If you found it by bisecting, say which commit. dhalbert bisects himself and
will thank you for skipping it.

---

## 10. Reading their language

**tannewt** writes short and direct. Question marks are real questions with an
implied objection behind them.

| He writes | He means |
|---|---|
| "Why does this need to change?" | Justify it or remove it from the diff |
| "I don't think we'll want this long term" | The API is wrong; propose a different one |
| "No need for this" / "Delete all of these" | Remove it, not negotiable |
| "I'd rather ..." | Do it his way |
| "I wonder if ..." / "What do you think about ..." | Genuine design discussion, engage |
| "Please add a comment about how this works" | Blocking, do it |
| "Do you want to close this then?" | He is done with this approach |
| "Is this ready for another review?" | He is waiting on you |

**dhalbert** writes longer, explains the background, and often gives you the exact
command or the exact code. He hedges genuinely ("I may be wrong, but this is my
understanding"), and he means it. He is easy to push back on with evidence.

| He writes | He means |
|---|---|
| A `suggestion` block | Apply it, it is his most common review action |
| "Not optional" / "Add new header" / "Alphabetize" | Mechanical fix, just do it |
| "Did you mean to ...?" | You probably left something in by accident |
| "Could you ...?" | Blocking request phrased politely |
| "I'm going to close this for now" | Stale, reopenable, respond if still alive |
| "This is not a problem, just a question" | Genuinely not blocking |

Neither of them is harsh, and both thank people readily. When tannewt does get
blunt, it is about wasted reviewer time: untested code, unverified claims, or
pasted model output presented as evidence.

---

## 11. Responding to review

- Answer every comment, even if the answer is "done in <sha>".
- Apply `suggestion` blocks rather than reimplementing them by hand. Check they
  actually landed; suggestions sometimes silently fail to apply.
- If you disagree, say so with data. Both of them change their minds in the record.
- Do not fix unrelated things in the same PR. Open a follow-up issue and link it.
- Push fixes as new commits. Do not force-push over a review in progress.
- If the discussion outgrows the PR, move it to an issue and say so in the thread.
- If you are stalled, post that you are still on it. Silence gets the PR closed.

---

## 12. Pre-flight check

Run this against the branch before opening the PR.

**Scope**
- [ ] Belongs in the core, not a library and not upstream MicroPython
- [ ] One logical change, no drive-by fixes, no reformatting noise
- [ ] Any design or API change already agreed in an issue
- [ ] Searched open PRs and issues for an existing fix

**Branch**
- [ ] Correct base: `main` for features, `X.Y.x` for a patch-release bugfix
- [ ] Only one PR, not one per branch
- [ ] Branch current with base
- [ ] `locale/circuitpython.pot` diff is either empty or a real consequence of a
      message change, after running `make translate`

**Code**
- [ ] Builds clean locally, and CI is green
- [ ] `pre-commit` run and clean
- [ ] Right layer: `shared-bindings` / `shared-module` / `common-hal`
- [ ] No duplicated logic that could be factored out
- [ ] Long-lived allocations use `port_malloc()`; nothing allocated that could be avoided
- [ ] Flash size impact checked; no small board pushed over its limit
- [ ] No new translatable strings unless unavoidable; reused existing ones with `%q`
- [ ] `#if`, not `#ifdef`; defaults defined in `circuitpy_mpconfig.h`, alphabetized
- [ ] Docstrings and type signatures updated in `shared-bindings`
- [ ] New `settings.toml` options documented in `docs/environment.rst`
- [ ] Comments explain any non-obvious mechanism
- [ ] No dead code, stale comments, unnecessary casts, or unreachable NULL checks
- [ ] Alphabetized lists, newline at EOF

**Board PRs**
- [ ] Unique registered USB VID/PID, correct order, correct registry
- [ ] Accurate manufacturer
- [ ] `pins.c` has board-specific names only, current naming conventions
- [ ] No per-board README
- [ ] No modules duplicated against `.gitmodules`

**zephyr-cp board PRs** (the checks above do not apply)
- [ ] `scripts/zephyr_conf_dupes.py` clean: no board `.conf` setting restates a
      `Kconfig` default or `prj.conf` entry
- [ ] Nothing set that the devicetree already implies (e.g. `CONFIG_BT` with a
      `zephyr,bt-hci` chosen node)
- [ ] `autogen_board_info.toml` byte-identical to a fresh build, never hand-edited
- [ ] No devicetree node enabled whose supporting code is not in this PR, verified
      by measuring the effect
- [ ] `.conf` and `.overlay` comments give the reason only, no investigation log
- [ ] Built `.config` checked after every `.conf` edit: each setting landed, and
      nothing changed that was not intended

**Description**
- [ ] What, why, and why it belongs in the core
- [ ] Boards, CP version, and host OS tested, plus what was not tested
- [ ] The actual `code.py` and the actual serial output pasted
- [ ] Instrument capture for any timing, bus, or performance claim
- [ ] Multiple trials for any noisy measurement
- [ ] AI assistance disclosed, with what you verified yourself
- [ ] Deliberate omissions stated, follow-up issues linked
