'use strict';

// Wire the shared Cucumber harness to this domain. The World is the core
// Recorder plus the slots this domain's steps fill: the mini-eats DB, an HTTP
// response, and the screen for one of the four app surfaces.
require('@portfolio/core/harness/cucumber').install({
  browserTag: '@fe',
  viewport: { width: 1440, height: 900 },
  extendWorld(world) {
    world.store = null;   // rows read from the mini-eats SQLite
    world.api = null;     // an HTTP response (mini-eats or the live TheMealDB)
    world.screen = {};    // values read off an app page
  },
});
