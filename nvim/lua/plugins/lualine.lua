return {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
        return vim.tbl_deep_extend("force", opts, {
            sections = {
                lualine_z = {
                    {
                        "datetime",
                        style = "  %I:%M %p",
                    },
                },
            },
        })
    end,
}
