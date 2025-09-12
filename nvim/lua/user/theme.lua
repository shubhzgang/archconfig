-- Load the colorscheme
vim.cmd('colorscheme tokyonight-storm')

-- Lualine (Status Line)
require('lualine').setup({
  options = {
    theme = 'tokyonight',
    icons_enabled = true,
  },
})

-- NvimTree (File Explorer)
require('nvim-tree').setup({
  view = {
    width = 30,
  },
})
