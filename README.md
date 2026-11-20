# Paper Mono Ligaturized

[Paper Mono](https://github.com/paper-design/paper-mono) patched with
Fira Code ligatures via Ligaturizer.

The slashed zero is the default `0`. Every spacing glyph advances one terminal
cell, including keyboard symbols and arrows. Coding ligatures use the standard
`calt` feature and preserve one cell per character.

![Paper Mono in Ghostty. With Ghostty configuration `adjust-cell-height = 8`. Theme: Dracula+.](documentation/screenshot-ghostty.png)

## Setup

Install with Homebrew:

```bash
brew install --cask nanxstats/tap/font-paper-mono-ligaturized
```

Or install the ligaturized fonts from `fonts/` using your OS font manager.

Paper Mono currently ships eight upright weights and no italic styles, so this
repo generates these variants:

- `LigaPaperMono-Thin.otf`
- `LigaPaperMono-ExtraLight.otf`
- `LigaPaperMono-Light.otf`
- `LigaPaperMono-Regular.otf`
- `LigaPaperMono-Medium.otf`
- `LigaPaperMono-SemiBold.otf`
- `LigaPaperMono-Bold.otf`
- `LigaPaperMono-ExtraBold.otf`

### VS Code

In VS Code, press `Cmd` + `Shift` + `P`, search for
`Preferences: Open User Settings (JSON)`. In the opened `settings.json`,
set font family to `Liga Paper Mono` and enable ligatures:

```json
"editor.fontFamily": "'Liga Paper Mono', monospace",
"editor.fontLigatures": "'calt', 'liga'",
"terminal.integrated.fontFamily": "'Liga Paper Mono', monospace",
"terminal.integrated.fontLigatures.enabled": true,
```

### Ghostty

Open Ghostty settings (`Cmd` + `,`) and set font family to `Liga Paper Mono`:

```ini
font-family = Liga Paper Mono
```

Press `Cmd` + `Shift` + `,` to reload the terminal with the new configuration.

## Build

Run `make build` in the repository root with Git, Python 3.11 or later with
pip, FontForge with Python 3.11 or later, and HarfBuzz. On macOS the Makefile
installs missing font tools with Homebrew. It caches the pinned sources and a
private copy of FontTools in `.build/` and writes the eight OTFs to `fonts/`.

The build pins the Paper Mono v1.000 release (`e6eaece`). Upstream's terminal
PR adds a TTF build and ships the same standard OTFs as v1.000. We apply its
fixed-width rules to those OTFs, removing the duospace and narrow-space
alternates (`ss02`, `ss03`) and scaling wider symbols uniformly to fit one
cell. Combining marks keep their zero advance. See the
[v1.000 release](https://github.com/paper-design/paper-mono/releases/tag/v1.000)
and the [upstream terminal build](https://github.com/paper-design/paper-mono/pull/15).

The build removes Paper Mono's `ss01` coding ligatures and uses the existing
Fira Code repertoire through Ligaturizer's `calt` rules. It then copies
`zero.zero` onto `zero`. Each OTF is checked for fixed-pitch metadata and glyph
widths. HarfBuzz checks default shaping, the exclusions below, and the cell
advances of every supported ligature.

Run `make` to build and remove the source cache. Run `make clean` to remove
the cache and the eight generated fonts.

### Dropped ligatures

These ligatures from Fira Code are intentionally omitted:

`&&`, `~@`, `\/`, `.?`, `?:`, `?=`, `?.`, `??`, `;;`, `/\`
