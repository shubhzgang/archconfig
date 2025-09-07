-- Set <space> as the leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Load core settings, plugins, and keymaps
require('user.options')
require('user.packer')
require('user.keymaps')
require('user.theme')
require('user.lsp')
require('user.treesitter')
