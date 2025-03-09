--- @class Fzflua: GoDocPicker
local M = {}

--- @param adapter GoDocAdapter
--- @param config GoDocConfig
--- @param callback fun(choice: GoDocCallbackData)
function M.show(adapter, config, callback)
	local core = require("fzf-lua.core")
	local opts = {
		prompt = "Select item",
		fn_transform = function() end,
		debug = false,
		actions = {
			["default"] = function(selected, _)
				callback({ type = "show_documentation", choice = table.concat(selected, "") })
			end,
			-- TODO: fzf lua doesn't accept 'gd' as a keymap
			["ctrl-s"] = function(selected, _)
				callback({ type = "goto_definition", choice = table.concat(selected, "") })
			end,
		},
	}

	if config.picker.fzf_lua then
		opts = vim.tbl_deep_extend("force", opts, config.picker.fzf_lua)
	end

	core.fzf_exec(adapter.get_items(), opts)
end

M.goto_definition = function()
	return require("fzf-lua").lsp_definitions()
end

return M
