return {
    -- https://github.com/catppuccin/nvim/discussions/323#discussioncomment-3952454
    {
        "catppuccin/nvim",
        lazy = false,
        name = "catppuccin",
        opts = {
            -- flavour = "frappe",
            -- flavour = "macchiato",
            flavour = "mocha",
            transparent_background = true,
        },
    },
    {
        "ellisonleao/gruvbox.nvim",
        lazy = false,
        opts = {
            contrast = "hard",
            invert_tabline = false,
            inverse = false,
            transparent_mode = true,
        },
    },
    {
        "folke/tokyonight.nvim",
        lazy = false,
        opts = {
            -- style = "storm",
            -- style = "moon",
            style = "night",
            transparent = true,
        },
    },
    { "LazyVim/LazyVim", opts = { colorscheme = "gruvbox" } },
}
