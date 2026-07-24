# Python Dev Optimisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Python editing in this kickstart.nvim config to parity with the existing Svelte/TS setup: treesitter highlighting, ruff LSP + formatting, import organisation keymaps, debugpy debugging, and neotest/pytest.

**Architecture:** All changes stay within the kickstart structure. `init.lua` gains treesitter parsers, the ruff LSP server, conform formatters, and Python keymaps; `lua/kickstart/plugins/debug.lua` is converted from Go to Python; a new `lua/custom/plugins/neotest.lua` adds the test runner. Spec: `docs/superpowers/specs/2026-07-24-python-dev-optimisation-design.md`.

**Tech Stack:** Neovim 0.11+ (`vim.lsp.config`/`vim.lsp.enable`), lazy.nvim, mason, nvim-lspconfig, conform.nvim, nvim-lint, nvim-dap + nvim-dap-python (debugpy), neotest + neotest-python (pytest), nvim-treesitter (main branch API).

## Global Constraints

- Follow existing Lua style: 2-space indent, single quotes, kickstart comment tone.
- Commit style (user's global preference): imperative subject + explanatory body + trailing `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Verification is headless: `nvim --headless ... +qa` commands with expected output. Neovim config has no unit-test framework; each task's "failing test" is the headless check run before the edit.
- Scratch fixture directory (session scratchpad, safe to write): `/private/tmp/claude-501/-Users-jaydenthai--config-nvim/8bcf1462-bdfb-4e0e-9d54-2fd29d313f94/scratchpad` — referred to as `$SCRATCH` below; export it at the top of each shell block.
- All file paths below are relative to `/Users/jaydenthai/.config/nvim` unless absolute.

---

### Task 1: Treesitter parsers for python and toml

**Files:**
- Modify: `init.lua` (treesitter `install` list, ~line 940)

**Interfaces:**
- Produces: installed `python` and `toml` parsers. Task 6 (neotest) depends on the `python` parser for test discovery.

- [ ] **Step 1: Verify parsers are currently missing (failing check)**

Run:
```bash
nvim --headless "+lua print('python:', pcall(vim.treesitter.language.add, 'python')); print('toml:', pcall(vim.treesitter.language.add, 'toml'))" +qa
```
Expected: `python: false ...` and `toml: false ...` (second value is the "no parser" error).

- [ ] **Step 2: Add parsers to the install list**

In `init.lua`, replace:
```lua
      require('nvim-treesitter.install').install({
        'bash', 'c', 'css', 'diff', 'html', 'javascript', 'json',
        'lua', 'luadoc', 'markdown', 'markdown_inline', 'query',
        'svelte', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml',
      })
```
with:
```lua
      require('nvim-treesitter.install').install({
        'bash', 'c', 'css', 'diff', 'html', 'javascript', 'json',
        'lua', 'luadoc', 'markdown', 'markdown_inline', 'python', 'query',
        'svelte', 'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml',
      })
```

- [ ] **Step 3: Install the parsers synchronously**

Run:
```bash
nvim --headless "+lua local t = require('nvim-treesitter.install').install({'python','toml'}) if t and t.wait then t:wait(300000) end" +qa
```
Expected: exits without error (compilation output is fine). If `t.wait` doesn't exist on this nvim-treesitter version, instead run `nvim --headless "+lua vim.defer_fn(function() vim.cmd 'qa!' end, 60000)"` to let the config's own install run for 60s.

- [ ] **Step 4: Re-run the check from Step 1**

Expected: `python: true` and `toml: true`.

- [ ] **Step 5: Commit**

```bash
git add init.lua
git commit -m "Add python and toml treesitter parsers

Python files were falling back to legacy regex highlighting because no
treesitter parser was installed; toml covers pyproject.toml. Also a
prerequisite for neotest test discovery.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Ruff LSP server beside pyright

**Files:**
- Modify: `init.lua` (servers table ~line 628, `vim.list_extend` ~line 688, LspAttach callback ~line 582)
- Create (fixture): `$SCRATCH/pydemo/pyproject.toml`, `$SCRATCH/pydemo/main.py`

**Interfaces:**
- Produces: `ruff` LSP attached to Python buffers, exposing code-action kinds `source.fixAll.ruff` and `source.organizeImports.ruff` (consumed by Task 4's keymaps).

- [ ] **Step 1: Create the scratch Python project**

```bash
SCRATCH=/private/tmp/claude-501/-Users-jaydenthai--config-nvim/8bcf1462-bdfb-4e0e-9d54-2fd29d313f94/scratchpad
mkdir -p $SCRATCH/pydemo && cd $SCRATCH/pydemo
printf '[project]\nname = "pydemo"\nversion = "0.1.0"\n' > pyproject.toml
cat > main.py <<'EOF'
import sys
import os


def greet(name):
    return f"hello {name}"
EOF
```

- [ ] **Step 2: Baseline check — ruff not attached (failing check)**

```bash
SCRATCH=/private/tmp/claude-501/-Users-jaydenthai--config-nvim/8bcf1462-bdfb-4e0e-9d54-2fd29d313f94/scratchpad
cd $SCRATCH/pydemo && nvim --headless main.py "+lua vim.defer_fn(function() local names = {} for _, c in ipairs(vim.lsp.get_clients()) do names[#names + 1] = c.name end table.sort(names) print('clients: ' .. table.concat(names, ',')) vim.cmd 'qa!' end, 8000)"
```
Expected: `clients: pyright` (no ruff). If pyright is missing too, run `nvim --headless "+MasonInstall pyright" +qa` first — mason installs synchronously in headless mode.

- [ ] **Step 3: Add ruff to the servers table and defer import organisation to it**

In `init.lua`, replace:
```lua
        pyright = {
          before_init = function(_, config)
            local venv_path = vim.fs.find('.venv', { path = config.root_dir, upward = true, type = 'directory' })[1]
            if venv_path then
              config.settings.python.pythonPath = venv_path .. '/bin/python'
            end
          end,
          settings = {
            python = {
              pythonPath = '.venv/bin/python',
            },
          },
        },
```
with:
```lua
        pyright = {
          before_init = function(_, config)
            local venv_path = vim.fs.find('.venv', { path = config.root_dir, upward = true, type = 'directory' })[1]
            if venv_path then
              config.settings.python.pythonPath = venv_path .. '/bin/python'
            end
          end,
          settings = {
            pyright = {
              -- Ruff owns import organisation (see the ruff server below)
              disableOrganizeImports = true,
            },
            python = {
              pythonPath = '.venv/bin/python',
            },
          },
        },
        -- Ruff runs as a second LSP beside pyright: live lint diagnostics plus
        -- fix-all and organize-imports code actions. Pyright keeps types/hover.
        ruff = {},
```

- [ ] **Step 4: Remove the now-redundant manual mason entry**

`ruff` is now a key in `servers`, so `vim.tbl_keys(servers)` feeds it to mason automatically ('ruff' is also the mason package name). In `init.lua`, replace:
```lua
      vim.list_extend(ensure_installed, {
        'lua-language-server', -- Lua Language server
        'stylua', -- Used to format Lua code
        'ruff', -- Python linter and formatter
        'prettierd', -- Fast Prettier daemon for formatting JS/TS/CSS/HTML
      })
```
with:
```lua
      vim.list_extend(ensure_installed, {
        'lua-language-server', -- Lua Language server
        'stylua', -- Used to format Lua code
        'prettierd', -- Fast Prettier daemon for formatting JS/TS/CSS/HTML
      })
```

- [ ] **Step 5: Let pyright own hover**

In `init.lua`, inside the `kickstart-lsp-attach` LspAttach callback, replace:
```lua
          local client = vim.lsp.get_client_by_id(event.data.client_id)
```
with:
```lua
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          -- Ruff runs alongside pyright for Python; let pyright own hover
          if client and client.name == 'ruff' then client.server_capabilities.hoverProvider = false end
```
(This line is unique in `init.lua` — it sits inside the `kickstart-lsp-attach` LspAttach callback, directly above the `documentHighlight` block.)

- [ ] **Step 6: Re-run the check from Step 2**

Expected: `clients: pyright,ruff`.

- [ ] **Step 7: Commit**

```bash
git add init.lua
git commit -m "Run ruff as an LSP server beside pyright

Ruff's language server provides live lint diagnostics plus fix-all and
organize-imports code actions, replacing the save-time-only nvim-lint
pipeline. Pyright defers import organisation to ruff and keeps hover,
types, and completion. The manual mason entry for ruff is dropped since
the servers table now supplies it.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Format on save via ruff; retire nvim-lint for Python

**Files:**
- Modify: `init.lua` (conform `formatters_by_ft`, ~line 760)
- Modify: `lua/kickstart/plugins/lint.lua` (linters_by_ft, ~line 8)
- Create (fixture): `$SCRATCH/pydemo/fmt_test.py`

**Interfaces:**
- Consumes: ruff binary installed by mason (Task 2).
- Produces: saving/formatting a Python buffer runs `ruff_organize_imports` then `ruff_format`.

- [ ] **Step 1: Create a badly formatted fixture**

```bash
SCRATCH=/private/tmp/claude-501/-Users-jaydenthai--config-nvim/8bcf1462-bdfb-4e0e-9d54-2fd29d313f94/scratchpad
cat > $SCRATCH/pydemo/fmt_test.py <<'EOF'
import sys
import os
def add(a,b):
        return a+b
print(add(1,2), os.sep, sys.platform)
EOF
```

- [ ] **Step 2: Baseline check — formatting is a no-op (failing check)**

```bash
SCRATCH=/private/tmp/claude-501/-Users-jaydenthai--config-nvim/8bcf1462-bdfb-4e0e-9d54-2fd29d313f94/scratchpad
cd $SCRATCH/pydemo && nvim --headless fmt_test.py "+lua require('conform').format { bufnr = 0, timeout_ms = 10000 }" +w +qa && cat fmt_test.py
```
Expected: file content unchanged (no formatter configured for python).

- [ ] **Step 3: Wire ruff into conform**

In `init.lua`, replace:
```lua
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
```
with:
```lua
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        python = { 'ruff_organize_imports', 'ruff_format' },
        --
```

- [ ] **Step 4: Remove the redundant nvim-lint entry**

In `lua/kickstart/plugins/lint.lua`, replace:
```lua
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
        python = { 'ruff' },
      }
```
with:
```lua
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
      }
```

- [ ] **Step 5: Re-run the check from Step 2**

Expected output of `cat fmt_test.py` — imports sorted, spacing normalised:
```python
import os
import sys


def add(a, b):
    return a + b


print(add(1, 2), os.sep, sys.platform)
```

- [ ] **Step 6: Commit**

```bash
git add init.lua lua/kickstart/plugins/lint.lua
git commit -m "Format Python on save with ruff via conform

ruff_organize_imports then ruff_format run through conform's existing
format-on-save hook, so saving a .py file sorts imports and formats it.
The nvim-lint ruff entry is removed: the ruff LSP server added in the
previous commit already provides live diagnostics, making the CLI
lint-on-save pass redundant.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Buffer-local Ruff keymaps in Python files

**Files:**
- Modify: `init.lua` (after the TS keybindings block, ~line 224)

**Interfaces:**
- Consumes: code-action kinds `source.fixAll.ruff` and `source.organizeImports.ruff` from the ruff LSP (Task 2).
- Produces: `<leader>tf` / `<leader>to` buffer-local maps in Python buffers, shadowing the global TS maps.

- [ ] **Step 1: Baseline check — no Ruff maps in Python buffers (failing check)**

```bash
SCRATCH=/private/tmp/claude-501/-Users-jaydenthai--config-nvim/8bcf1462-bdfb-4e0e-9d54-2fd29d313f94/scratchpad
cd $SCRATCH/pydemo && nvim --headless main.py "+lua local found = 0 for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do if (m.desc or ''):match 'Ruff' then found = found + 1 end end print('ruff maps: ' .. found)" +qa
```
Expected: `ruff maps: 0`.

- [ ] **Step 2: Add the FileType autocmd**

In `init.lua`, directly after this existing line:
```lua
vim.keymap.set('n', '<leader>tr', '<cmd>TSToolsRenameFile<cr>', { desc = '[T]S [R]ename file (updates imports)' })
```
insert:
```lua

-- Python / Ruff keybindings (buffer-local; shadow the TS maps above in Python files)
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  group = vim.api.nvim_create_augroup('python-ruff-keymaps', { clear = true }),
  callback = function(event)
    local function ruff_action(kind)
      return function() vim.lsp.buf.code_action { context = { only = { kind } }, apply = true } end
    end
    vim.keymap.set('n', '<leader>tf', ruff_action 'source.fixAll.ruff', { buffer = event.buf, desc = 'Ruff [F]ix all' })
    vim.keymap.set('n', '<leader>to', ruff_action 'source.organizeImports.ruff', { buffer = event.buf, desc = 'Ruff [O]rganize imports' })
  end,
})
```

- [ ] **Step 3: Re-run the check from Step 1**

Expected: `ruff maps: 2`.

- [ ] **Step 4: Commit**

```bash
git add init.lua
git commit -m "Add buffer-local Ruff fix-all and organize-imports keymaps

<leader>tf and <leader>to in Python buffers trigger ruff's
source.fixAll and source.organizeImports code actions, mirroring the
muscle memory of the global TypeScript maps they shadow.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Python debugging via debugpy

**Files:**
- Rewrite: `lua/kickstart/plugins/debug.lua`
- Modify: `init.lua` (uncomment the debug require, ~line 966)

**Interfaces:**
- Produces: `require('dap').configurations.python` populated by nvim-dap-python; DAP strategy consumed by Task 6's `<leader>Td`. Keymaps: `F5` continue, `F1/F2/F3` step into/over/out, `<leader>b` / `<leader>B` breakpoints, `F7` DAP UI.

- [ ] **Step 1: Baseline check — no DAP (failing check)**

```bash
nvim --headless "+lua print('dap-python ok:', (pcall(require, 'dap-python')))" +qa
```
Expected: `dap-python ok: false`.

- [ ] **Step 2: Rewrite debug.lua for Python**

Replace the entire content of `lua/kickstart/plugins/debug.lua` with:
```lua
-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
-- Configured for Python via debugpy (installed through mason).

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Python debugging via debugpy
    'mfussenegger/nvim-dap-python',
  },
  keys = {
    {
      '<F5>',
      function() require('dap').continue() end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function() require('dap').step_into() end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function() require('dap').step_over() end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function() require('dap').step_out() end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function() require('dap').toggle_breakpoint() end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<F7>',
      function() require('dapui').toggle() end,
      desc = 'Debug: See last session result.',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      ensure_installed = {
        'debugpy',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Python: the adapter runs from mason's debugpy install; the program being
    -- debugged still uses the project's own interpreter/.venv.
    require('dap-python').setup(vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python')
  end,
}
```

- [ ] **Step 3: Enable the plugin in init.lua**

Replace:
```lua
  -- require 'kickstart.plugins.debug',
```
with:
```lua
  require 'kickstart.plugins.debug',
```

- [ ] **Step 4: Install plugins and debugpy**

```bash
nvim --headless "+Lazy! install" +qa
nvim --headless "+MasonInstall debugpy" +qa
```
Expected: lazy installs nvim-dap, nvim-dap-ui, nvim-nio, mason-nvim-dap, nvim-dap-python without errors; mason prints a debugpy success line (mason installs synchronously when headless).

- [ ] **Step 5: Verify DAP configurations are registered**

```bash
nvim --headless "+lua require 'dap' print('py configs: ' .. #(require('dap').configurations.python or {}))" +qa
ls ~/.local/share/nvim/mason/packages/debugpy/venv/bin/python
```
Expected: `py configs: 3` (or more — launch-file, launch-with-args, attach) and the debugpy interpreter path exists.

- [ ] **Step 6: Commit**

```bash
git add init.lua lua/kickstart/plugins/debug.lua
git commit -m "Enable DAP debugging for Python via debugpy

Converts kickstart's Go-focused debug.lua to Python: nvim-dap-go and
delve are replaced by nvim-dap-python and debugpy (installed through
mason). The adapter runs from mason's debugpy venv while the debugged
program uses the project's own interpreter. Kickstart's stock keymaps
(F5 continue, F1-F3 step, <leader>b breakpoints, F7 UI) are unchanged.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Test running via neotest + pytest

**Files:**
- Create: `lua/custom/plugins/neotest.lua`
- Modify: `init.lua` (which-key spec, ~line 338)

**Interfaces:**
- Consumes: treesitter `python` parser (Task 1); DAP python configurations (Task 5) for the `dap` strategy.
- Produces: `<leader>T*` test keymaps.

- [ ] **Step 1: Baseline check — neotest absent (failing check)**

```bash
nvim --headless "+lua print('neotest ok:', (pcall(require, 'neotest')))" +qa
```
Expected: `neotest ok: false`.

- [ ] **Step 2: Create the plugin file**

Create `lua/custom/plugins/neotest.lua` with:
```lua
-- Test runner: neotest with pytest for Python.
-- Keymaps live under <leader>T ([T]est); <leader>t is taken by TS/toggle maps.
return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/neotest-python',
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require 'neotest-python' {
            runner = 'pytest',
            -- Step into library code while debugging tests if you need to
            dap = { justMyCode = false },
          },
        },
      }
    end,
    keys = {
      { '<leader>Tt', function() require('neotest').run.run() end, desc = '[T]est: run nearest' },
      { '<leader>Tf', function() require('neotest').run.run(vim.fn.expand '%') end, desc = '[T]est: run [F]ile' },
      { '<leader>Td', function() require('neotest').run.run { strategy = 'dap' } end, desc = '[T]est: [D]ebug nearest' },
      { '<leader>Ts', function() require('neotest').summary.toggle() end, desc = '[T]est: toggle [S]ummary' },
      { '<leader>To', function() require('neotest').output.open { enter = true, auto_close = true } end, desc = '[T]est: show [O]utput' },
    },
  },
}
```

- [ ] **Step 3: Register the which-key group**

In `init.lua`, replace:
```lua
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      },
```
with:
```lua
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>T', group = '[T]est' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      },
```

- [ ] **Step 4: Install and verify**

```bash
nvim --headless "+Lazy! install" +qa
nvim --headless "+lua require 'neotest' print 'neotest ok: true'" +qa
```
Expected: plugins install cleanly; second command prints `neotest ok: true` with no error output (requiring the module lazy-loads the plugin and runs `setup`, which would error on a broken adapter config).

- [ ] **Step 5: Commit**

```bash
git add init.lua lua/custom/plugins/neotest.lua
git commit -m "Add neotest with pytest for in-editor test running

neotest-python discovers and runs pytest tests from the editor.
Keymaps sit under a new <leader>T ([T]est) which-key group since
<leader>t is occupied by TS/toggle maps: Tt nearest, Tf file, Td debug
via DAP (uses the debugpy setup), Ts summary sidebar, To output.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Indent guides

**Files:**
- Modify: `init.lua` (uncomment the indent_line require, ~line 967)

**Interfaces:**
- Produces: indent-blankline (`ibl`) active in all buffers.

- [ ] **Step 1: Baseline check (failing check)**

```bash
nvim --headless "+lua print('ibl ok:', (pcall(require, 'ibl')))" +qa
```
Expected: `ibl ok: false`.

- [ ] **Step 2: Enable the kickstart module**

In `init.lua`, replace:
```lua
  -- require 'kickstart.plugins.indent_line',
```
with:
```lua
  require 'kickstart.plugins.indent_line',
```

- [ ] **Step 3: Install and verify**

```bash
nvim --headless "+Lazy! install" +qa
nvim --headless "+lua print('ibl ok:', (pcall(require, 'ibl')))" +qa
```
Expected: `ibl ok: true`.

- [ ] **Step 4: Commit**

```bash
git add init.lua
git commit -m "Enable indent guides via kickstart's indent_line module

indent-blankline makes Python's whitespace-delimited blocks easier to
scan; it applies to all filetypes.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: End-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Full headless regression sweep**

```bash
SCRATCH=/private/tmp/claude-501/-Users-jaydenthai--config-nvim/8bcf1462-bdfb-4e0e-9d54-2fd29d313f94/scratchpad
nvim --headless "+lua print('python parser:', pcall(vim.treesitter.language.add, 'python'))" +qa
cd $SCRATCH/pydemo && nvim --headless main.py "+lua vim.defer_fn(function() local names = {} for _, c in ipairs(vim.lsp.get_clients()) do names[#names + 1] = c.name end table.sort(names) print('clients: ' .. table.concat(names, ',')) print('diagnostics: ' .. #vim.diagnostic.get(0)) vim.cmd 'qa!' end, 8000)"
nvim --headless "+lua require 'dap' print('py configs: ' .. #(require('dap').configurations.python or {}))" +qa
nvim --headless "+lua require 'neotest' print 'neotest: ok'" +qa
```
Expected: `python parser: true`; `clients: pyright,ruff`; `diagnostics:` ≥ 2 (two unused imports in main.py); `py configs: 3` or more; `neotest: ok`. Also confirm lazy-lock.json changed (new plugins pinned) and commit it if not yet committed:
```bash
git status --short
# if lazy-lock.json is dirty:
git add lazy-lock.json
git commit -m "Pin new Python tooling plugins in lazy-lock

Locks nvim-dap, nvim-dap-ui, nvim-nio, mason-nvim-dap, nvim-dap-python,
neotest, neotest-python, and indent-blankline versions added by the
Python dev optimisation.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 2: Manual smoke checklist (report to user, don't block)**

Interactive checks for the user next time they open Neovim in a Python project:
- `:checkhealth` — no new errors; `:LspInfo` in a `.py` buffer shows pyright + ruff.
- Save a messy `.py` file → imports sorted + formatted.
- `<leader>tf` / `<leader>to` in a `.py` buffer run ruff actions; still TS actions in `.ts` buffers.
- `<leader>b` on a line, `F5`, pick "file" config → debugger stops; `F7` toggles UI.
- In a pytest repo: `<leader>Tt` runs nearest test, `<leader>Ts` opens the summary tree.
