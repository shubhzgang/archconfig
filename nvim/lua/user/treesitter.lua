require('nvim-treesitter.configs').setup({
  ensure_installed = { 'java', 'lua', 'vim' }, -- Make sure parsers are installed
  highlight = {
    enable = true,
  },
  indent = { enable = true },
})
