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
since PRs merge as merge commits and keep the sha. Never point a version
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
everything changed since the merge-base with `origin/master` (commits, staged, unstaged, untracked), then runs `npm test` (checks `template.tpl` has every required section with valid embedded JSON and that `metadata.yaml`'s newest `versions[]` sha is a real commit, then runs every `___TESTS___` scenario through `scripts/run_template_tests.mjs`: the whole set, about a second) unless the change is prose only. AFFECTED in tests.yml runs the same single job.
It prints `Tests selected: N ...` and what it ran, and on success `PASSED. Put in the commit and the PR description: Tests: local (...)`. The pre-deploy check `Validate template.tpl` is a required hard stop and runs on every ready PR whatever you recorded (one billed minute, it guards the branch Google's Gallery reads), so a recorded local or none choice saves the batch, not that check.

**Trailer placement:** the last paragraph of the commit message AND of the PR description (a squash merge keeps it).
**Batches and nightly:** every `CI_BATCH_SIZE` (10) merges per branch the AFFECTED tests run (since 2026-10-23: `tests.yml` mode AFFECTED measured from the last tested sha, reason `batch-affected`; FULL only when there is no tested sha), counting ONLY `affected` and unmarked
changes (`local` and `skip` are not counted); ONE nightly FULL run (01:41 UTC) stays the full safety net, only when master moved. A red batch **bisects** to the guilty
merge (every failed check re-runs) and says which merges chose not to test on their own. Mechanics: `.github/workflows/tests.yml` header.

## Docs here

Decisions in `docs/decisions/NNNN-title.md` (short, frozen, a newer record supersedes an old one); how the template works now in `docs/SPEC.md` (one page, about 300 lines, updated by the PR that changes the template), with `docs/TESTING.md` and `docs/ENVIRONMENT_SPINUP.md` beside it. Statuses are DRAFT, ACTIVE or SUPERSEDED. The rule is the `docs-rule` skill in loop.

## Backlog Discipline

`docs/BACKLOG.md` is the single living list of every open TODO the user has called out.

- When the user asks for something new, capture it in `docs/BACKLOG.md` *before* starting work, under the right priority (`P0` / `P1` / `P2`).
- When something ships (or is verified), delete its entry in the same PR: the PR and git history keep the record. A request deliberately not shipped moves under `## Dropped` with its rationale.
- Items that exist as code but the user has not yet seen working live in `## P0 — needs verification`.
- Never silently drop a request. If you push back on scope, write the rationale inline next to the entry.
- When the user says "did you do X", search `docs/BACKLOG.md` (open and dropped items) and `git log` (shipped ones).
