local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- File Explorer
map('n', '<leader>e', ':NvimTreeToggle<CR>', opts)

-- Telescope (Fuzzy Finder)
local telescope = require('telescope.builtin')
map('n', '<leader>ff', telescope.find_files, opts)
map('n', '<leader>fg', telescope.live_grep, opts)
map('n', '<leader>fb', telescope.buffers, opts)
map('n', '<leader>fh', telescope.help_tags, opts)

-- Buffer management
map('n', '<leader>bn', ':bnext<CR>', opts)
map('n', '<leader>bp', ':bprevious<CR>', opts)
map('n', '<leader>bd', ':bdelete<CR>', opts)
