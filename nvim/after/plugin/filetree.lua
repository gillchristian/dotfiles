require('nvim-tree').setup()

vim.keymap.set('n', '<leader>nt', ':NvimTreeFindFileToggle<cr>', { silent = true })
