# tools/

## web_smoke.js

Drives the exported web build in a real browser with real keystrokes: title,
type a name, through the sprite editor, instrument, element, and into the
field. Screenshots each step and reports any console or page errors.

    node tools/web_smoke.js

Needs Playwright and a Chromium build; on this machine:

    /usr/local/lib/node_modules/playwright
    ~/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome

This exists because a synthetic in-engine input test turned out to be the wrong
tool. Driving `Input.action_press()` from a test's `_process` races with the
game's own `_process` inside the same frame, so `is_action_just_pressed` was
missed about half the time. The test was flaky in a way that would eventually
have been "fixed" by loosening it until it always passed, which is worse than
having no test. A real browser pressing real keys against the real build has
none of that ambiguity.

## Two things about the web build that are easy to lose

**It must be served over HTTPS.** Godot web exports refuse to start without a
secure context and fail with "Secure Context - Check web server configuration".
Plain `http://host:4000/...` loads the page and then stops. The HTTPS route
through the proxy on hunter works.

**Threads are off** in `export_presets.cfg` (`variant/thread_support=false`).
The threaded build needs COOP/COEP headers that the static Python server does
not send. Turning threads on will produce a build that silently refuses to run.
