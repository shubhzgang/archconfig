local opt = vim.opt -- for conciseness

-- Line Numbers
opt.relativenumber = true -- show relative line numbers
opt.number = true -- shows absolute line number on cursor line

-- Tabs & Indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true -- use spaces instead of tabs
opt.autoindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true

-- Appearance
opt.termguicolors = true
opt.background = 'dark'
opt.signcolumn = 'yes' -- always show the sign column

-- Behavior
opt.clipboard = 'unnamedplus' -- use system clipboard
opt.mouse = 'a' -- enable mouse support
opt.splitright = true -- split vertical windows to the right
opt.splitbelow = true -- split horizontal windows to the bottom
