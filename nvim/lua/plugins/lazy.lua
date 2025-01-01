return {
	"folke/lazy.nvim",
	optional = true,
	init = function()
		-- Run script on LazySync event.
		vim.api.nvim_create_autocmd("User", {
			pattern = "LazySync",
			callback = function()
				local handle = io.popen("bun $HOME/.dotfiles/update-readme.ts")
				if handle then
					local result = handle:read("*a")
					handle:close()
					if result then
						vim.notify(result, vim.log.levels.INFO)
					else
						vim.notify("Failed to read output from command", vim.log.levels.ERROR)
					end
				else
					vim.notify("Failed to execute command", vim.log.levels.ERROR)
				end
			end,
		})
	end,
}
