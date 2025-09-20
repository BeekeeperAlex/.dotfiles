return {
	"nvim-mini/mini.hipatterns",
	optional = true,
	opts = function(_, opts)
		table.insert(opts.tailwind.ft, "copilot-chat")
		return opts
	end,
}
