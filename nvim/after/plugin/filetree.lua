require('nvim-tree').setup()

vim.keymap.set('n', '<leader>nf', ':Fern .<cr>', { silent = true })
vim.keymap.set('n', '<leader>nt', ':NvimTreeToggle<cr>', { silent = true })
