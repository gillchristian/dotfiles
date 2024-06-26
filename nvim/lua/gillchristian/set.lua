-- See `:help vim.o`

-- Disable netrw in favor for nvim-tree
-- vim.g.loaded_netrw = 1
-- vim.g.loaded_netrwPlugin = 1

-- Set <space> as the leader key
-- See `:help mapleader`
--
-- IMPORTANT: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.o.encoding='utf-8'

-- Up to three signs in the sign column on the left
vim.o.signcolumn='auto:3'

-- Disable netrw in favor for nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set highlight on search
vim.o.hlsearch = true
vim.o.incsearch = true

-- Make relative line numbers default
vim.wo.number = true
vim.wo.relativenumber = true

-- Enable mouse mode
vim.o.mouse = 'a'

-- Enable break indent
vim.o.breakindent = true
vim.o.expandtab = true
vim.o.shiftround = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.softtabstop = 2

vim.o.backupcopy = 'yes'

-- Confirm operations that would fail when there are unsaved changes
vim.o.confirm = true

-- Use the system keyboard
-- TODO: use a different command to copy on the system keyboard?
vim.o.clipboard = 'unnamedplus'

-- Padding to keep above the cursor when scrolling
vim.o.scrolloff = 3

-- When splitting, open windows to the right
vim.o.splitright = true

-- No backups when overwritting a file
vim.o.writebackup = false

-- Height of the command line
vim.o.cmdheight = 2

-- Save undo history
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Decrease update time
vim.o.updatetime = 100

-- Set colorscheme
vim.o.termguicolors = true
vim.o.background = 'dark'
vim.cmd [[colorscheme onedark]]

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- Show matching brackets when inserted
vim.o.showmatch = true
vim.o.showcmd = true
vim.o.textwidth = 80
vim.o.colorcolumn = "40,80,120"
vim.o.showtabline = 2
