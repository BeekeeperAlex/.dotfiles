return {
    "snacks.nvim",
    optional = true,
    opts = function(_, opts)
        opts.indent.indent = {
            -- char = "│",
            char = "░",
            -- char = "▏",
            -- char = "┋",
            -- char = "┊",
        }
        opts.indent.scope = {
            -- char = "░",
            char = "▓",
        }
        return opts
    end,
}
