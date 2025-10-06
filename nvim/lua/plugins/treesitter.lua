return {
	{
		"nvim-treesitter/nvim-treesitter",
		opts = function(_, opts)
			opts = opts or {}
			if #vim.api.nvim_list_uis() == 0 then
				opts.sync_install = true
			end
			return opts
		end,
	},
}
