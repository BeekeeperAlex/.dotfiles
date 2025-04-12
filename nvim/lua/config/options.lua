-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.root_spec = { ".git", "compose.yml", "cwd" }
vim.g.lazyvim_prettier_needs_config = true
vim.g.rust_recommended_style = "0"

vim.opt.linebreak = true
vim.opt.expandtab = false
vim.opt.formatoptions:remove({ "r", "o" })
vim.opt.tabstop = 3
vim.opt.shiftwidth = 3
vim.opt.scrolloff = 10
vim.opt.jumpoptions = "stack,view"
vim.opt.relativenumber = false
vim.opt.showbreak = "↪ "
vim.opt.listchars = {
	tab = " ➞ ",
	multispace = "·",
	trail = "·",
	extends = "»",
	precedes = "«",
}

-- vim.opt.guifont = "ComicShannsMono Nerd Font:h12"

if vim.fn.has("wsl") == 1 then
	local w32y = vim.fs.joinpath(vim.fn.getenv("HOME"), ".dotfiles", "bin", "win32yank.exe")
	vim.g.clipboard = {
		name = "WslClipboard",
		copy = {
			["+"] = w32y .. " -i --crlf",
			["*"] = w32y .. " -i --crlf",
		},
		paste = {
			["+"] = w32y .. " -o --lf",
			["*"] = w32y .. " -o --lf",
		},
		cache_enabled = false,
	}
	-- vim.g.clipboard = {
	-- 	name = "WslClipboard",
	-- 	copy = {
	-- 		["+"] = "clip.exe",
	-- 		["*"] = "clip.exe",
	-- 	},
	-- 	paste = {
	-- 		["+"] = 'powershell.exe -NoLogo -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
	-- 		["*"] = 'powershell.exe -NoLogo -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
	-- 	},
	-- 	cache_enabled = 0,
	-- }
end
