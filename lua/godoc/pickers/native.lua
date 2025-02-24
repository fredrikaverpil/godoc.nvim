local M = {}

--- @param adapter GoDocAdapter
--- @param config GoDocConfig
--- @param callback fun(choice: string|nil)
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

	vim.ui.select(adapter.get_items(), opts, callback)
end

return M
