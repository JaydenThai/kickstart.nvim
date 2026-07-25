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
