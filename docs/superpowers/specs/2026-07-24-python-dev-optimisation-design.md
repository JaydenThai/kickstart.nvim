# Python Dev Optimisation — Design

**Date:** 2026-07-24
**Status:** Approved

## Goal

Bring the Python editing experience in this kickstart.nvim config up to parity
with the existing Svelte/TypeScript setup: proper highlighting, format on save,
import organisation, live lint diagnostics, breakpoint debugging, and in-editor
test running. Target use: web backends/APIs (FastAPI-style) and scripts/tooling.

## Current state

- pyright LSP configured with upward `.venv` detection — kept as-is.
- ruff installed via mason, running as a CLI linter through nvim-lint.
- No Python treesitter parser (legacy regex highlighting).
- No Python formatter in conform; format-on-save is a no-op for `.py`.
- No fix-all / organize-imports actions for Python (TS has these).
- Debugging disabled (`kickstart/plugins/debug.lua` commented out, Go-specific).
- No test runner integration.

## Design

### 1. Treesitter

Add `python` and `toml` to the parser install list in `init.lua`.

### 2. LSP: ruff server beside pyright

- Add `ruff = {}` to the `servers` table (binary already in mason
  `ensure_installed`; runs as `ruff server`).
- pyright: set `settings.pyright.disableOrganizeImports = true` — imports are
  ruff's job.
- ruff: disable `hoverProvider` on attach — pyright's hover is better.
- Existing pyright `.venv` detection unchanged.

### 3. Formatting & linting

- conform: `python = { 'ruff_organize_imports', 'ruff_format' }`. Global
  format-on-save (500 ms timeout) already applies.
- nvim-lint: remove the `python = { 'ruff' }` entry — the ruff LSP replaces it
  with live diagnostics.

### 4. Keymaps (buffer-local in Python buffers)

Shadow the global TS maps with Python equivalents via a FileType autocmd:

| Map | Action |
| --- | --- |
| `<leader>tf` | ruff fix-all code action (`source.fixAll.ruff`) |
| `<leader>to` | organize imports (`source.organizeImports.ruff`) |

### 5. Debugger

Enable `kickstart/plugins/debug.lua` in `init.lua` and convert it from Go to
Python:

- Remove `leoluz/nvim-dap-go` dependency and its `dap-go` setup; drop `delve`
  from `ensure_installed`.
- Add `mfussenegger/nvim-dap-python`; ensure `debugpy` via mason-nvim-dap.
- `require('dap-python').setup()` pointed at mason's debugpy interpreter
  (`stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'`).
  nvim-dap-python auto-detects the project `.venv` for the debuggee.
- Existing kickstart keymaps kept: `F5` continue, `F1/F2/F3` step into/over/out,
  `<leader>b` toggle breakpoint, `<leader>B` conditional breakpoint, `F7` DAP UI.

### 6. Tests: neotest + pytest

New file `lua/custom/plugins/neotest.lua`:

- `nvim-neotest/neotest` with `neotest-python` adapter (`runner = 'pytest'`),
  deps: nvim-nio, plenary, treesitter.
- which-key group `<leader>T` = **[T]est** (capital T; `<leader>t` is taken):

| Map | Action |
| --- | --- |
| `<leader>Tt` | run nearest test |
| `<leader>Tf` | run current file |
| `<leader>Td` | debug nearest test (DAP strategy) |
| `<leader>Ts` | toggle summary sidebar |
| `<leader>To` | open test output |

### 7. Indent guides

Enable `kickstart.plugins.indent_line` (indent-blankline.nvim) in `init.lua`.

## Out of scope

- Notebook/REPL integration (molten, iron.nvim) — not needed per user.
- basedpyright migration, venv-selector — existing pyright + `.venv` detection
  suffices.
- Coverage display, extra Python plugins.

## Error handling / risks

- ruff LSP + pyright overlap is handled by the two tweaks in §2.
- If a project has no `.venv`, pyright falls back to its default interpreter
  resolution; debugpy launches still work (mason's own venv runs the adapter).
- neotest requires the treesitter python parser — installed in §1.

## Testing the change

- `:checkhealth` clean; `:Lazy` installs without errors.
- Open a `.py` file in a uv/venv project: treesitter highlighting active
  (`:InspectTree`), pyright + ruff both attached (`:LspInfo`).
- Save a badly formatted file with unsorted imports → formatted + sorted.
- `<leader>tf` / `<leader>to` work in a Python buffer; TS maps still work in
  `.ts` buffers.
- Set a breakpoint in a script, `F5`, select a debug config → stops on line.
- In a pytest project: `<leader>Tt` runs nearest test, `<leader>Ts` shows tree.
