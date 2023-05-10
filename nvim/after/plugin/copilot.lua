-- See how to configure here to work together with the LSP !!!
-- https://www.reddit.com/r/neovim/comments/qsfvki/how_to_remap_copilotvim_accept_method_in_lua/
--
--

vim.g.copilot_no_tab_map = true

vim.keymap.set(
    'i',
    '<C-a>',
    function()
        vim.cmd [[call copilot#Accept("")]]
    end,
    { expr = true }
)
