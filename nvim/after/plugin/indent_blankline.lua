-- See `:help indent_blankline.txt`
require('ibl').setup {
  indent = { char = "┊" },
  whitespace = { remove_blankline_trail = true },
  exclude = { filetypes = { "text", "help", "dashboard" } },
}
