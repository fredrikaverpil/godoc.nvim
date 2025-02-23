--- @class MiniPicker: GoDocPicker
local M = {}

--- @param adapter GoDocAdapter
--- @param config GoDocConfig
--- @param callback fun(choice: string|nil)
function M.show(adapter, config, callback)
	local minipick = require("mini.pick")

	-- Create picker configuration
	local opts = {
		source = {
			items = adapter.get_items(),
			name = "Select item",
			preview = function(buf_id, item)
				vim.notify(vim.inspect(buf_id))
				local content = adapter.get_content(item)
				local syntax_info = adapter.get_syntax_info()
				vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, content)
				vim.api.nvim_set_option_value("filetype", syntax_info.filetype, { buf = buf_id })
			end,
			choose = function(item)
				callback(item)
			end,
		},
	}

	if config.picker.mini then
		opts = vim.tbl_deep_extend("force", opts, config.picker.mini)
	end

	minipick.start(opts)
end

return M
