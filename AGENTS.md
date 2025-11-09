# AGENTS GUIDE

This document captures the conventions and guardrails for maintaining this
project. Please follow these rules whenever you contribute.

## Workflow
- **Always verify with `bin/rake check`** before pushing or opening a PR. It
  runs Rails tests, Playwright tests, and Rubocop in parallel.
- When designing or implementing changes, apply the YAGNI principle—"you ain't
  gonna need it." Do not introduce flexibility or additional abstractions
  unless there is a confirmed requirement. Prioritize simple, direct solutions
  and avoid complexity without a concrete payoff.
- The following tasks are also available when you need finer control:
  - `bin/rake test_rails` – run only the Rails test suite.
  - `bin/rake test_js` – run only the Playwright suite.
  - `bin/rake test` – run both test suites sequentially.
  - `bin/rake format` – run `rubocop -A` (autocorrect).
- Do not rely on Playwright writing artifacts to the repository. Its output is
  directed to an ignored tmp directory; never commit generated files under
  `tmp/playwright-output/`.
- When you need to inspect a remote GitHub repository, always use the `gh`
  command-line tool (e.g., `shadowenv exec -- gh repo view ...`).
- If a command fails because the environment is not initialized, retry it with
  `shadowenv exec -- <command>` so the correct environment is loaded.
- Never ignore command failures. If something keeps failing—especially due to
  authentication—report it immediately instead of silently skipping the step.
- When asked to run dev tooling, invoke `/opt/dev/bin/dev ...` rather than a
  bundled executable.

## Coding Style
- Prefer concise, idiomatic Ruby and Rails; reach for built-in behaviour (e.g.
  `default_url_options`, helpers, ActiveSupport conveniences) instead of
  hand-rolled plumbing unless there is a clear gap to fill.
- Avoid defensive boilerplate that adds no value. Express conditionals with the
  simplest construct that communicates the intent, and let shorter expressions
  (ternaries, guard clauses, memoised hashes) replace multi-line scaffolding.
- Do not code defensively: assume the expected resources exist and let genuine
  failures surface early. Guard clauses are for impossible states, not for
  masking missing files or misconfigured params.
- Eliminate unused methods and dead abstractions promptly—they add noise and
  encourage accidental reuse.
- Before introducing a new helper or service, check whether the framework (or
  an existing layer in the app) already solves the problem; reuse wins over
  reinvention.

## Frontend Interaction Patterns
- The advent console relies on a fetch-and-swap transition (no full reload).
  Whenever you change the markup inside `.advent-console`, ensure the dynamic
  swap still works:
  - Keep buttons annotated with `data-advent-check-in` or
    `data-advent-reset` when applicable so the JS hooks can find them.
  - If you add new interactive elements that rely on JavaScript, expose an
    explicit `data-` attribute instead of selecting by text.
- When altering the headline, remember it animates on initial page load but
  should render fully typed after a dynamic swap. The Playwright tests assert
  that `.advent-title__line` has the `is-complete` class after check-in/reset.

## Testing Expectations
- Extend the Playwright suite for any user-facing interaction changes. The
  existing tests cover:
  - Headline animation completion
  - Tab toggling
  - Countdown ticking
  - Fireworks burst during check-in
  - Reset button behaviour
- If you introduce new behaviour that should be protected, add Playwright
  coverage rather than relying on manual QA.

## Styling Guidelines
- The experience must remain mobile-first. When updating layout or typography,
  verify on narrow viewports and adjust the responsive rules under
  `@media (max-width: 720px)` and `@media (max-width: 480px)` as needed.
- Typing and fireworks effects should respect `prefers-reduced-motion`.

## Miscellaneous
- Stick to ASCII in source files unless Unicode is semantically required (e.g.
  star glyphs).
- Avoid committing generated artefacts or temporary files.

If you need to deviate from any of these guidelines, call it out explicitly in
your PR or discussion so reviewers understand the trade-offs.
