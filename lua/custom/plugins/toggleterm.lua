-- Terminal: toggleterm, plus a cargo run/test loop for Rust.
-- Keymaps live under <leader>r ([R]un); <leader>t is TS/toggle maps and
-- <leader>T is neotest.
return {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    opts = {
      -- Horizontal terminals get a fixed height; vertical ones take 40% of the
      -- window, which reads better than a fixed column count on a wide screen.
      size = function(term)
        if term.direction == 'horizontal' then
          return 15
        elseif term.direction == 'vertical' then
          return vim.o.columns * 0.4
        end
      end,
      direction = 'float',
      -- Match the rounded border used by the diagnostic floats
      float_opts = { border = 'rounded' },
      start_in_insert = true,
      -- Remember whether you left the terminal in normal or insert mode
      persist_mode = true,
    },
    keys = {
      -- NOTE: this shadows the <C-\> half of the built-in <C-\><C-n>. Exiting
      -- terminal mode still works via <Esc><Esc> (mapped in init.lua).
      { [[<c-\>]], '<cmd>ToggleTerm<cr>', mode = { 'n', 't' }, desc = 'Toggle terminal' },
      { '<leader>rr', function() require('custom.rust').cargo 'run' end, desc = '[R]ust: cargo [R]un' },
      { '<leader>rt', function() require('custom.rust').cargo 'test' end, desc = '[R]ust: cargo [T]est' },
    },
  },
}
