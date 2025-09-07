-- This file is automatically sourced by `init.lua`

-- Auto-install packer if not found
local fn = vim.fn
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
  vim.cmd [[packadd packer.nvim]]
end

-- Autocommand that reloads neovim whenever you save this file
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost packer.lua source <afile> | PackerSync
  augroup end
]])


local status, packer = pcall(require, 'packer')
if not status then
  return
end

-- Define plugins
return packer.startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- Theme and UI ---------------------------------------------------
  use 'folke/tokyonight.nvim' -- A clean, dark theme
  use 'nvim-lualine/lualine.nvim' -- Status line
  use 'nvim-tree/nvim-web-devicons' -- File icons
  use 'nvim-tree/nvim-tree.lua' -- File explorer

  -- Core Functionality ---------------------------------------------
  -- Fuzzy Finder (files, buffers, etc.)
  use { 'nvim-telescope/telescope.nvim', tag = '0.1.x', requires = { { 'nvim-lua/plenary.nvim' } } }

  -- Syntax Highlighting
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }

  -- LSP, Autocomplete, and Java Support ------------------------------
  -- java stuff
  use { 
  'nvim-java/nvim-java',
   }
 
-- LSP framework
  use 'neovim/nvim-lspconfig'
   require('lspconfig').jdtls.setup({})

   -- Mason: Installer for LSPs, formatters, linters
  use 'williamboman/mason.nvim'
  use 'williamboman/mason-lspconfig.nvim'

  -- Autocompletion engine
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-nvim-lsp' -- source for lsp
  use 'hrsh7th/cmp-buffer'   -- source for buffer words
  use 'hrsh7th/cmp-path'     -- source for file paths

  -- Snippets
  use 'L3MON4D3/LuaSnip'
  use 'saadparwaiz1/cmp_luasnip'

 -- Java-specific plugins
  use 'nvim-java/nvim-java-core'
 use 'mfussenegger/nvim-dap' -- Debug Adapter Protocol
 end)
