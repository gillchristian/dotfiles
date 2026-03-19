-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Search selected text
--
-- TODO: not working
--
-- From Vim:
--   vnoremap / "py/\V<c-r>p<cr>
--
-- vim.keymap.set('v', '/', 'y/<C-r>"<cr>')

-- Hide search
vim.keymap.set('n', '<C-h>', ':nohl<cr>', { silent = true })

-- Windows
vim.keymap.set('n', '<leader>wo', ':only<cr>', { silent = true })
vim.keymap.set('n', '<leader>wh', '<c-w>h', { silent = true })
vim.keymap.set('n', '<leader>wj', '<c-w>j', { silent = true })
vim.keymap.set('n', '<leader>wk', '<c-w>k', { silent = true })
vim.keymap.set('n', '<leader>wl', '<c-w>l', { silent = true })
vim.keymap.set('n', '<leader>ww', '<c-w>w', { silent = true })

-- CamelCaseMotion
vim.g.camelcasemotion_key = '<leader>'

-- Open file explorer (ie. Netrw)
vim.keymap.set('n', "<leader>pv", vim.cmd.Ex)

-- Move when highlighted
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- Apped next line to current one but keep the cursor on the current position
-- vim.keymap.set('n', 'J', 'mzJ`z')

-- Vertical navigation with centering
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')

-- Paste without loosing the copied object
vim.keymap.set('x', '<leader>p', "\"_dP")

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)
-- TODO: this conflicts with CamelCaseMotion
-- vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)

vim.keymap.set('n', '<leader>cp', function()
  local path = vim.fn.expand('%:.')
  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path)
end, { desc = 'Copy file path' })

vim.keymap.set('n', '<leader>cP', function()
  local filepath = vim.fn.expand('%:p')
  local git_root = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(vim.fn.expand('%:p:h')) .. ' rev-parse --show-toplevel')[1]
  local rel_path = filepath:sub(#git_root + 2) -- +2 to skip the trailing /
  vim.fn.setreg('+', rel_path)
  vim.notify('Copied: ' .. rel_path)
end, { desc = 'Copy file path (relative to git root)' })
