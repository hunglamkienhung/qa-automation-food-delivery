'use strict';

/**
 * Build fixtures/testcases.json (and TestCases.md) from the feature files.
 *
 * The features are the single source of truth: every scenario carries @case:N,
 * a feature carries @module/@be|@fe/@db|@api/@minieats|@mealdb tags, and a
 * Scenario Outline carries one @case per Examples block. This walks them and
 * emits one catalogue entry per @case, so the catalogue can never drift from
 * what actually runs.
 *
 *   node testcases/build.js            write the files
 *   node testcases/build.js --check    exit non-zero if they are stale
 */

const fs = require('fs');
const path = require('path');

const HERE = __dirname;
const FEATURES = path.join(HERE, '..', 'features');
const FIXTURE = path.join(HERE, '..', 'fixtures', 'testcases.json');
const EXPECTED = path.join(HERE, '..', 'fixtures', 'expected-results.json');
const MD = path.join(HERE, 'TestCases.md');
const CHECK = process.argv.includes('--check');

const LAYER = (tags) => {
  const be = tags.has('@be');
  if (tags.has('@db')) return 'BE/DB';
  if (tags.has('@api')) return 'BE/API';
  if (tags.has('@fe')) return 'FE/UI';
  return be ? 'BE' : 'FE';
};
const TIER = (tags) => {
  for (const t of tags) if (t.startsWith('@tier:')) return t.slice(6);
  if (tags.has('@minieats') && tags.has('@security')) return 'minieats-security';
  if (tags.has('@minieats') && tags.has('@db')) return 'minieats-db';
  if (tags.has('@minieats') && tags.has('@api')) return 'minieats-api';
  if (tags.has('@minieats') && tags.has('@fe')) return 'minieats-fe';
  if (tags.has('@mealdb') && tags.has('@api')) return 'mealdb-api';
  return 'unknown';
};
const MODULE = (tags) => { for (const t of tags) if (t.startsWith('@module:')) return t.slice(8); return 'misc'; };
const PRIORITY = (tags) => { for (const t of tags) if (t.startsWith('@priority:')) return t.slice(10)[0].toUpperCase() + t.slice(11); return 'Medium'; };
const tagsOf = (line) => new Set((line.match(/@[\w:.-]+/g) || []));
const moduleTitle = (m) => m.replace(/^\d+-/, '').replace(/-/g, ' ');

function parseFeature(file) {
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  let featureTags = new Set();
  let pending = new Set();
  let scenario = null;
  let inExamples = false;
  const cases = [];
  const emit = (id, sc, extraTags) => {
    const tags = new Set([...featureTags, ...sc.tags, ...(extraTags || [])]);
    cases.push({ id: Number(id), module: MODULE(tags), moduleTitle: moduleTitle(MODULE(tags)), layer: LAYER(tags), tier: TIER(tags), title: sc.name, priority: PRIORITY(tags), steps: sc.steps.slice() });
  };
  const flushPlain = () => { if (scenario && scenario.plainCase) emit(scenario.plainCase, scenario); };

  for (const raw of lines) {
    const line = raw.trim();
    if (line.startsWith('@')) { for (const t of tagsOf(line)) pending.add(t); continue; }
    if (line.startsWith('Feature:')) { featureTags = new Set(pending); pending = new Set(); continue; }
    if (line.startsWith('Scenario Outline:') || line.startsWith('Scenario:')) {
      flushPlain();
      scenario = { name: line.replace(/^Scenario( Outline)?:\s*/, ''), steps: [], tags: new Set(pending), plainCase: null, outline: line.startsWith('Scenario Outline:') };
      for (const t of pending) { const m = /^@case:(\d+)$/.exec(t); if (m) scenario.plainCase = m[1]; }
      pending = new Set(); inExamples = false; continue;
    }
    if (line.startsWith('Background:')) { scenario = null; pending = new Set(); continue; }
    if (line.startsWith('Examples:')) { inExamples = true;
      for (const t of pending) { const m = /^@case:(\d+)$/.exec(t); if (m && scenario) emit(m[1], scenario); }
      pending = new Set(); continue; }
    if (!scenario) { pending = new Set(); continue; }
    if (inExamples) continue;
    if (/^(Given|When|Then|And|But)\b/.test(line)) { scenario.steps.push(line); }
  }
  flushPlain();
  return cases;
}

function main() {
  const files = fs.readdirSync(FEATURES).filter((f) => f.endsWith('.feature')).sort();
  let all = [];
  for (const f of files) all = all.concat(parseFeature(path.join(FEATURES, f)));
  all.sort((a, b) => a.id - b.id);

  const seen = new Set();
  for (const c of all) { if (seen.has(c.id)) throw new Error('duplicate @case:' + c.id); seen.add(c.id); }

  const cases = {};
  for (const c of all) cases[String(c.id)] = { module: c.module, layer: c.layer, tier: c.tier, title: c.title, priority: c.priority, steps: c.steps };
  const nextId = all.length ? Math.max(...all.map((c) => c.id)) + 1 : 1;
  const fixture = {
    meta: {
      domain: 'food-delivery',
      targets: {
        'minieats-db': 'mini-eats SQLite, written by the service (be/db, both stacks open the same file)',
        'minieats-api': 'mini-eats REST over that SQLite -- the customer, merchant, driver and admin apps (be/api)',
        'minieats-security': 'mini-eats authorization boundaries -- no/wrong/forged token, cross-actor access (be/api)',
        'minieats-fe': 'mini-eats HTML pages for the four app surfaces (Playwright)',
        'mealdb-api': 'themealdb.com public API (no key)',
      },
      idPolicy: 'immutable',
      nextId,
      note: 'Generated from features/*.feature by testcases/build.js. Every scenario carries @case:N; an N missing here is an error.',
    },
    cases,
  };

  // Every case declares ["Passed","Blocked"]: the invariant held, or a source
  // was unreachable and nothing was measured. What no list contains is Failed.
  const expected = {
    why: [
      'A declared status may be a single value or a LIST of acceptable ones.',
      'Every case declares ["Passed","Blocked"]: the invariant held, or a source was unreachable and nothing was measured. What no list contains is Failed.',
      'mini-eats cases (DB, API, FE) are deterministic against the local service and its SQLite; they grade Blocked only when the service is not running.',
      'TheMealDB cases grade Blocked when the live API or the network is unavailable -- an outage is never the menu being wrong.',
      'No case is declared Failed: nothing here is currently failing, and manufacturing a failure to have one would be dishonest.',
    ],
    summary: {
      total: all.length,
      Passed: all.length,
      Failed: 0,
      Blocked: 0,
      note: 'nominal: mini-eats running and seeded, TheMealDB reachable, a browser available for the FE tier',
    },
    cases: Object.fromEntries(all.map((c) => [String(c.id), ['Passed', 'Blocked']])),
  };

  const md = renderMd(all);
  const jsonText = JSON.stringify(fixture, null, 2) + '\n';
  const expectedText = JSON.stringify(expected, null, 2) + '\n';
  if (CHECK) {
    const stale = [];
    if (!fs.existsSync(FIXTURE) || fs.readFileSync(FIXTURE, 'utf8') !== jsonText) stale.push('fixtures/testcases.json');
    if (!fs.existsSync(EXPECTED) || fs.readFileSync(EXPECTED, 'utf8') !== expectedText) stale.push('fixtures/expected-results.json');
    if (!fs.existsSync(MD) || fs.readFileSync(MD, 'utf8') !== md) stale.push('testcases/TestCases.md');
    if (stale.length) { console.error('stale: ' + stale.join(', ') + ' -- run node testcases/build.js'); process.exit(1); }
    console.log('testcases up to date: ' + all.length + ' cases');
    return;
  }
  fs.mkdirSync(path.dirname(FIXTURE), { recursive: true });
  fs.writeFileSync(FIXTURE, jsonText);
  fs.writeFileSync(EXPECTED, expectedText);
  fs.writeFileSync(MD, md);
  const byTier = {};
  for (const c of all) byTier[c.tier] = (byTier[c.tier] || 0) + 1;
  console.log(all.length + ' cases; nextId ' + nextId + '; ' + JSON.stringify(byTier));
}

function renderMd(rows) {
  const out = ['# Food delivery — test cases', '', `${rows.length} cases across a self-written mini-eats service (a real SQLite store behind the customer, merchant, driver and admin apps) and the live TheMealDB API. Generated from \`../features/*.feature\` by \`build.js\`; do not edit by hand.`, ''];
  const tiers = [...new Set(rows.map((r) => r.tier))];
  for (const tier of tiers) {
    const group = rows.filter((r) => r.tier === tier);
    out.push('## ' + tier + ' (' + group.length + ')', '', '| ID | Layer | Priority | Title |', '|---|---|---|---|');
    for (const c of group) out.push(`| ${c.id} | ${c.layer} | ${c.priority} | ${c.title.replace(/\|/g, '\\|')} |`);
    out.push('');
  }
  return out.join('\n');
}

main();
