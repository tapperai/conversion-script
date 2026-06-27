#!/usr/bin/env node
/*
 * Environment-independent validation gate for the GTM Community Template.
 *
 * No secrets, no network, no third-party packages — safe to run as a
 * pre-deploy gate. It fails (exit 1) on the kinds of breakage that would
 * make the Community Template Gallery reject the submission:
 *
 *   1. metadata.yaml: parseable, has versions[0].sha, and that sha is a real
 *      commit reachable in this checkout (when run inside a git repo).
 *   2. template.tpl: contains every required GTM section.
 *   3. template.tpl: the embedded JSON blocks (___INFO___,
 *      ___TEMPLATE_PARAMETERS___, ___WEB_PERMISSIONS___) are valid JSON.
 *
 * NOTE: this intentionally does NOT execute the ___TESTS___ sandbox scenarios.
 * Google does not publish a standalone test runner for that, and gating on a
 * non-existent/unstable runner would block legitimate deploys. The scenarios
 * are run in the GTM template editor "Tests" tab before publishing.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '..');
let failures = 0;
const fail = (msg) => { console.error('FAIL: ' + msg); failures++; };
const ok = (msg) => console.log('ok: ' + msg);

// --- metadata.yaml ---------------------------------------------------------
const metaPath = path.join(repoRoot, 'metadata.yaml');
const metaRaw = fs.readFileSync(metaPath, 'utf8');

// Minimal extraction (avoids a YAML dep): pull the first versions[].sha value.
const shaMatch = metaRaw.match(/^\s*-\s*sha:\s*["']?([0-9a-f]{7,40})["']?\s*$/m);
if (!shaMatch) {
  fail('metadata.yaml: could not find versions[0].sha');
} else {
  const sha = shaMatch[1];
  ok('metadata.yaml: found versions[0].sha = ' + sha);
  // Verify the sha is a real commit when we have a git checkout.
  let inGit = true;
  try {
    execFileSync('git', ['rev-parse', '--is-inside-work-tree'], { cwd: repoRoot, stdio: 'ignore' });
  } catch (_) { inGit = false; }
  if (inGit) {
    try {
      const type = execFileSync('git', ['cat-file', '-t', sha], { cwd: repoRoot })
        .toString().trim();
      if (type !== 'commit') fail('metadata.yaml: sha ' + sha + ' is a ' + type + ', not a commit');
      else ok('metadata.yaml: sha resolves to a real commit');
    } catch (_) {
      fail('metadata.yaml: sha ' + sha + ' does not exist in this repo');
    }
  } else {
    console.log('skip: not a git checkout, cannot verify sha reachability');
  }
}

// --- template.tpl ----------------------------------------------------------
const tplPath = path.join(repoRoot, 'template.tpl');
const tpl = fs.readFileSync(tplPath, 'utf8');

const requiredSections = [
  '___TERMS_OF_SERVICE___',
  '___INFO___',
  '___TEMPLATE_PARAMETERS___',
  '___SANDBOXED_JS_FOR_WEB_TEMPLATE___',
  '___WEB_PERMISSIONS___',
  '___TESTS___',
];
for (const s of requiredSections) {
  if (tpl.indexOf(s) === -1) fail('template.tpl: missing section ' + s);
}
if (requiredSections.every((s) => tpl.indexOf(s) !== -1)) {
  ok('template.tpl: all required sections present');
}

// Validate the JSON-bearing blocks.
function sectionBody(name) {
  const start = tpl.indexOf(name);
  if (start === -1) return null;
  const after = start + name.length;
  // body runs until the next ___SECTION___ marker or EOF
  const next = tpl.slice(after).search(/\n___[A-Z_]+___/);
  return next === -1 ? tpl.slice(after) : tpl.slice(after, after + next);
}

for (const jsonSection of ['___INFO___', '___TEMPLATE_PARAMETERS___', '___WEB_PERMISSIONS___']) {
  const body = sectionBody(jsonSection);
  if (body == null) continue; // already reported missing above
  try {
    JSON.parse(body.trim());
    ok('template.tpl: ' + jsonSection + ' is valid JSON');
  } catch (e) {
    fail('template.tpl: ' + jsonSection + ' is not valid JSON — ' + e.message);
  }
}

// --- result ----------------------------------------------------------------
if (failures > 0) {
  console.error('\n' + failures + ' check(s) failed.');
  process.exit(1);
}
console.log('\nAll template checks passed.');
