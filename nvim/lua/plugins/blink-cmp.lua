return {
	"saghen/blink.cmp",
	optional = true,
	dependencies = {
		"moyiz/blink-emoji.nvim",
		"Kaiser-Yang/blink-cmp-dictionary",
	},
	opts = function(_, opts)
		opts.enabled = function()
			return not vim.tbl_contains({ "copilot-chat" }, vim.bo.filetype)
				and vim.bo.buftype ~= "prompt"
				and vim.b.completion ~= false
		end

		opts.sources.providers.emoji = {
			module = "blink-emoji",
			name = "Emoji",
			score_offset = 15,
			opts = { insert = true },
		}
		table.insert(opts.sources.default, "emoji")

		-- opts.sources.providers.dictionary = {
		-- 	module = "blink-cmp-dictionary",
		-- 	name = "Dict",
		-- 	score_offset = 20,
		-- 	max_items = 8,
		-- 	min_keyword_length = 3,
		-- 	opts = {
		-- 		dictionary_files = nil,
		-- 		dictionary_directories = nil,
		-- 		get_command = "rg",
		-- 		get_command_args = function(prefix, _)
		-- 			return {
		-- 				"rg",
		-- 				"--color=never",
		-- 				"--no-line-number",
		-- 				"--no-messages",
		-- 				"--no-filename",
		-- 				"--ignore-case",
		-- 				"--",
		-- 				prefix,
		-- 				vim.fn.expand("~/.dotfiles/words.txt"),
		-- 			}
		-- 		end,
		-- 	},
		-- }
		-- table.insert(opts.sources.default, "dictionary")
		return opts
	end,
}
