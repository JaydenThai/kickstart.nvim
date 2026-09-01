-- Rust helpers. Kept out of the plugin spec so `lua/custom/plugins/*.lua`
-- stays a pure list of lazy.nvim specs.
local M = {}

-- The most recent cargo terminal. Reused so repeated runs replace the window
-- instead of stacking up hidden terminals.
local runner = nil

--- Run a cargo subcommand in a horizontal toggleterm below the code.
--- @param subcmd string e.g. 'run', 'test', 'clippy'
function M.cargo(subcmd)
  -- cargo reads the file from disk, not from your buffer
  vim.cmd 'silent! write'

  -- cargo must run from the crate root, which is not necessarily nvim's cwd
  local manifest = vim.fs.find('Cargo.toml', { upward = true, path = vim.fn.expand '%:p:h' })[1]
  if not manifest then
    vim.notify('No Cargo.toml found above ' .. vim.fn.expand '%:p:h', vim.log.levels.WARN)
    return
  end

  if runner then runner:shutdown() end

  -- close_on_exit is off so a failed compile stays on screen long enough to read
  runner = require('toggleterm.terminal').Terminal:new {
    cmd = 'cargo ' .. subcmd,
    dir = vim.fs.dirname(manifest),
    direction = 'horizontal',
    close_on_exit = false,
    on_open = function(term) vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = term.bufnr, desc = 'Close cargo output' }) end,
  }
  runner:open()
end

return M
