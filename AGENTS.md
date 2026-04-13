# Agent guidelines

- This repo builds ligaturized Paper Mono.
- Source fonts come from `paper-mono/fonts/otf/` and there are 8 upright
  weights only; do not assume italic variants exist.
- Expected outputs land in `fonts/` as `LigaPaperMono-*.otf`.
- Generated fonts should use the slashed zero by default by copying
  `zero.zero` onto the base `zero` glyph during the final post-processing step.
- Keep the existing ligature exclusions: `&&`, `~@`, `\/`, `.?`, `?:`, `?=`,
  `?.`, `??`, `;;`, `/\`.
- Respect existing changes; never reset or revert unless explicitly told.
- Prefer fast read/search tools (`rg`, `rg --files`); avoid destructive commands.
- Use `apply_patch` for edits; keep ASCII; add comments only when clarifying
  non-obvious logic.
- Follow sandbox/approval rules; request escalation when network or restricted
  paths are required.
- No heavy formatting in replies; reference files with clickable code paths
  (e.g., `fonts/LigaPaperMono-Regular.otf`).
- When automating, include validation or assertions where practical; summarize
  key outcomes succinctly.
