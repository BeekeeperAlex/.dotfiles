return {
	-- https://github.com/petertriho/nvim-scrollbar
	-- {
	-- 	"petertriho/nvim-scrollbar",
	-- 	dependencies = {
	-- 		{ "kevinhwang91/nvim-hlslens" },
	-- 		{
	-- 			"lewis6991/gitsigns.nvim",
	-- 			opts = {
	-- 				current_line_blame = true,
	-- 			},
	-- 		},
	-- 	},
	-- 	event = "VeryLazy",
	-- 	opts = {
	-- 		handlers = {
	-- 			cursor = true,
	-- 			diagnostic = true,
	-- 			gitsigns = true,
	-- 			handle = true,
	-- 			search = true,
	-- 		},
	-- 	},
	-- },
	-- {
	-- 	"lewis6991/satellite.nvim",
	-- 	event = "VeryLazy",
	-- 	config = true,
	-- },
	{
		"folke/which-key.nvim",
		optional = true,
		opts = {
			disable = {
				ft = { "minimap" },
				bt = { "minimap" },
			},
		},
	},
	{
		"wfxr/minimap.vim",
		build = "cargo install --locked code-minimap",
		event = "BufEnter",
		-- lazy = false,
		cmd = {
			"Minimap",
			"MinimapClose",
			"MinimapToggle",
			"MinimapRefresh",
			"MinimapUpdateHighlight",
		},
		init = function()
			vim.cmd("let g:minimap_block_filetypes = ['snacks_dashboard']")
			vim.cmd("let g:minimap_block_buftypes = ['snacks_dashboard']")
			vim.cmd("let g:minimap_width = 5")
			vim.cmd("let g:minimap_auto_start_win_enter = 1")
			vim.cmd("let g:minimap_auto_start = 1")
		end,
	},
}
