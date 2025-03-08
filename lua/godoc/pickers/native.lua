local M = {}

--- @param adapter GoDocAdapter
--- @param config GoDocConfig
--- @param callback fun(choice: GoDocCallbackData)
function M.show(adapter, config, callback)
	-- Create picker configuration
	local opts = {
		prompt = "Select item",
		format_item = function(item)
			return item
		end,
	}

	if config.picker.native then
		opts = vim.tbl_deep_extend("force", opts, config.picker.native)
	end

	vim.ui.select(adapter.get_items(), opts, function(choice)
		callback({ type = "show_documentation", choice = choice })
	end)
end

M.goto_definition = nil

return M
