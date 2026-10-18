## Document First Development

**Every new feature or significant change must have a spec in `docs/` before implementation begins.** Skip steps 1-5 only if the user explicitly asks to write code directly (e.g., "just fix this", "skip the spec").

**Docs here:** decisions in `docs/decisions/NNNN-title.md` (short, frozen, a newer record supersedes an old one); how each area works now in `docs/<area>.md` (one page per area, about 300 lines, updated by the PR that changes the area). The rule is the `docs-rule` skill in loop.

1. **Before implementing any feature or significant change**, read the rules:
   - Read `docs/DOCUMENT_FIRST.md` for spec rules, structure, and conventions
2. Before writing code, check if a spec exists at `docs/{domain}/SPEC.md`
3. If no spec exists, create one from `docs/_templates/SPEC.md` first
4. **After writing the spec, open the file, record the decisions it locks in (what you measured, what would have made the answer no), and implement straight away.** No confirmation wait: agents decide from evidence and record the decision in the spec.
5. Implement from the spec and follow it exactly. Break the spec into independent work streams and **spawn parallel agents** (one per work stream) to maximize speed. Sequence dependent work — implement dependencies first, then parallelize everything that follows
6. After implementing, update the spec to match what was built — keep specs and code in sync at all times. Mark `Implemented in:` with the current repo name. Move completed items out of Remaining Work. Mark any sections that are designed but not yet coded as `PLANNED`
7. **For doc commands** (e.g., `Check spec drift`, full rerun, setup) — read `docs/DOCUMENT_FIRST.md` and follow its rules

## Backlog Discipline

`docs/BACKLOG.md` is the single living list of every TODO the user has called out, **including ones that have already been shipped**.

- When the user asks for something new, capture it in `docs/BACKLOG.md` *before* starting work — under the right priority (`P0` / `P1` / `P2`).
- When something ships, **don't delete it** — move it under `## Done` with a one-line note + the date so we can audit what landed and when.
- Items that exist as code but the user has not yet seen working live in `## P0 — needs verification`.
- Never silently drop a request. If you push back on scope, write the rationale inline next to the entry.
- Treat `docs/BACKLOG.md` as authoritative when the user says "did you do X" — search there first before re-reading code or git log.

---

# conversion-script

Single-file GTM Community Template (`template.tpl`) that records Tapper
conversions client-side via `tapper.push`. There is no server or build in this
repo: the sandboxed JS lives inside `template.tpl` itself, validated by
`scripts/validate-template.js` (run it locally with `npm test`) and CI (CI standard 2026-10-17: `.github/workflows/tests.yml`, job `Validate template.tpl (pre-deploy gate)`, about 10 seconds, on every ready PR in every gate mode; drafts run nothing, no push run). It stays a hard stop: ruleset `required-checks` on `master` requires it next to `CI gate`, which follows the Actions variable `CI_GATE_MODE` (`NONE` today: skipped, which counts as passing). Labels `ci:skip-tests` / `ci:run-tests` switch the mode per PR; `test-batch.yml` runs the set every `CI_BATCH_SIZE` merges, nightly and on demand (`gh workflow run tests.yml -R tapperai/conversion-script --ref master -f sha=<sha> -f reason=on-demand`) and bisects a red run to the guilty merge. Merges are direct merge commits (`gh pr merge <n> --merge`; no merge queue).

**This repo is PUBLIC** (the GTM Community Template Gallery publishes from it), so everything here is world-readable: every file (including `template.tpl` code comments, `README.md`, `docs/SPEC.md` and `docs/BACKLOG.md`), every commit message and branch name, and every PR, issue and comment. Write the technical change only: no customer names or customer domains, no workspace or protection-script ids, no rates, counts or internal table names, no operator quotes. The Backlog Discipline above still applies, but entries stay technical: the customer evidence and the why go in a private tapperai repo (its `docs/BACKLOG.md` or a private twin PR). Editing does not erase: PR edit history, the PR timeline and git history keep the old text, so get it right the first time.

**A new `metadata.yaml` version on `master` IS the release.** The GTM
Community Template Gallery serves the commit named by the FIRST `versions[]`
entry (newest first); a merge that adds no entry releases nothing. Each `sha`
must be a real commit: commit the `template.tpl` change, read its sha with
`git rev-parse HEAD`, then commit a new first `versions[]` entry pointing at
it (see README.md, "Releasing (maintainers)"). Both commits can ride in one PR,
since queue merges are merge commits and keep the sha. Never point a version
entry at a sha that does not exist yet. You push and merge your own work here
(operator, 2026-09-12).

## Testing a change (policy 2026-10-18)

The author of each change chooses ONE of three, per change, and records it:
1. **Local** (default for code): run the tests for your change on your machine; if they pass, merge with no GitHub test run.
   Trailer `Tests: local (<the exact command you ran>)`.
2. **Affected on GitHub**: GitHub runs only the tests the change can reach (`tests.yml` mode AFFECTED), for that PR only.
   Label `ci:run-affected`, or the line `Tests: affected` in the PR description; on a commit that lands with no PR-time run,
   the trailer `Tests: affected` makes the batch trigger dispatch it at merge.
3. **None** (trivial: docs, copy, a style value): trailer `Tests: skip (<reason>)`, or label `ci:skip-tests`.
`ci:run-tests` / `Tests: run` still starts the FULL suite on request.

**The ONE local command:** `npm run test:changed` (`scripts/test-changed.*`; `-- --list` prints the selection only, `-- --base <ref>`). It takes
everything changed since the merge-base with `origin/master` (commits, staged, unstaged, untracked), then runs `npm test` (validates `template.tpl`, its permission grants and `metadata.yaml`: the whole set, about a second) unless the change is prose only. AFFECTED in tests.yml runs the same single job.
It prints `Tests selected: N ...` and what it ran, and on success `PASSED. Put in the commit and the PR description: Tests: local (...)`. The pre-deploy check `Validate template.tpl` is a required hard stop and runs on every ready PR whatever you recorded (one billed minute, it guards the branch Google's Gallery reads), so a recorded local or none choice saves the batch, not that check.

**Trailer placement:** the last paragraph of the commit message AND of the PR description (a squash merge keeps it).
**Batches and nightly:** every `CI_BATCH_SIZE` (10) merges per branch the FULL suite runs, counting ONLY `affected` and unmarked
changes (`local` and `skip` are not counted); ONE nightly FULL run (01:41 UTC) as the safety net, only when master moved. A red batch **bisects** to the guilty
merge (every failed check re-runs) and says which merges chose not to test on their own. Mechanics: `.github/workflows/tests.yml` header.
