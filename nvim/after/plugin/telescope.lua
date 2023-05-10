-- See `:help telescope` and `:help telescope.setup()`
require('telescope').setup {
  defaults = {
    mappings = {
      i = {
        ['<C-u>'] = false,
        ['<C-d>'] = false,
      },
    },
  },
}

-- Enable telescope fzf native, if installed
pcall(require('telescope').load_extension, 'fzf')

local builtin = require('telescope.builtin')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require("telescope.config").values
local make_entry = require('telescope.make_entry')

local function get_project_root()
  local cwd = vim.fn.getcwd()
  local resolved_cwd = vim.fn.resolve(cwd)
  return vim.fn.fnamemodify(resolved_cwd, ':p:h')
end

local function global_marks_in_current_directory()
  local items = {}

  local global_marks = {
    items = vim.fn.getmarklist(),
  }

  local project_root = get_project_root()

  local function global_mark_name(mark)
    local mark_path = vim.fn.expand(vim.api.nvim_get_mark(mark, {})[4])
    -- Start in the next character after the project root (+1)
    -- And skip the first character of the path, which is a slash (+1)
    local project_root_length = project_root:len() + 1 + 1
    return mark_path:sub(project_root_length)
  end

  for _, mark in ipairs(global_marks.items) do
    local mark_name = string.sub(mark.mark, 2, 3)
    local _, lnum, col, _ = unpack(mark.pos)
    local line = string.format("%s %6d %4d %s", mark_name, lnum, col - 1, global_mark_name(mark_name))
    local row = {
      line = line,
      lnum = lnum,
      col = col,
      filename = mark.file,
    }

    local is_in_project = vim.fn.expand(mark.file):find(project_root, 1, true) == 1
    local is_global_mark = mark_name:match("%u")

    if is_in_project and is_global_mark then
      table.insert(items, row)
    end

  end

  pickers.new({}, {
    prompt_title = "Global Marks in Current Project",
    finder = finders.new_table {
      results = items,
      entry_maker = make_entry.gen_from_marks({}),
    },
    previewer = conf.grep_previewer({}),
    sorter = conf.generic_sorter({}),
    push_cursor_on_edit = true,
    push_tagstack_on_edit = true,
  }):find()
end

-- See `:help telescope.builtin`
vim.keymap.set('n', '<leader>?', builtin.oldfiles, { desc = '[?] Find recently opened files' })
vim.keymap.set('n', '<leader><space>', builtin.buffers, { desc = '[ ] Find existing buffers' })
vim.keymap.set('n', '<leader>/', function()
  -- You can pass additional configuration to telescope to change theme, layout, etc.
  builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer]' })

vim.keymap.set('n', '<leader><C-p>', builtin.git_files, { desc = 'Search Files in the Repo' })
vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sm', builtin.marks, { desc = '[S]earch All [M]arks' })
vim.keymap.set('n', '<leader>sl', global_marks_in_current_directory, { desc = '[S]earch [L]ocal Marks' })
