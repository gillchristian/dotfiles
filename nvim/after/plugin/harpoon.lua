require("harpoon").setup({
  menu = { width = 120 },
})

local ui = require("harpoon.ui")
local mark = require("harpoon.mark")

vim.keymap.set("n", "<leader>a", mark.toggle_file)
vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)

vim.keymap.set("n", "<C-g>1", function() ui.nav_file(1) end)
vim.keymap.set("n", "<C-g>2", function() ui.nav_file(2) end)
vim.keymap.set("n", "<C-g>3", function() ui.nav_file(3) end)
vim.keymap.set("n", "<C-g>4", function() ui.nav_file(4) end)
vim.keymap.set("n", "<C-g>5", function() ui.nav_file(5) end)
vim.keymap.set("n", "<C-g>6", function() ui.nav_file(6) end)
vim.keymap.set("n", "<C-g>7", function() ui.nav_file(7) end)
vim.keymap.set("n", "<C-g>8", function() ui.nav_file(8) end)
vim.keymap.set("n", "<C-g>9", function() ui.nav_file(9) end)
