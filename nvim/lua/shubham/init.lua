-- Set <Space> as the leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Load core setting, plugins and keymaps
require('shubham.options')
require('shubham.packer')
require('shubham.keymaps')
