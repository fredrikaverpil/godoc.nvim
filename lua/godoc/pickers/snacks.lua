--- @class SnacksPicker: GoDocPicker
local M = {}

--- @param adapter GoDocAdapter
--- @param config GoDocConfig
--- @param callback fun(choice: string|nil)
function M.show(adapter, config, callback)
	local snacks = require("snacks")

	local function create_items()
		local items = {}
		for _, item_name in ipairs(adapter.get_items()) do
			table.insert(items, {
				text = item_name,
				item_name = item_name,
			})
		end
		return items
	end

	local syntax_info = adapter.get_syntax_info()

	-- Create picker configuration
	--- @type snacks.picker.Config
	local opts = {
		finder = create_items,
		format = "text",
		title = "Select item",
		preview = function(ctx)
			if ctx.item then
				local content = adapter.get_content(ctx.item.item_name)
				ctx.preview:set_lines(content)
				ctx.preview:highlight({ ft = syntax_info.filetype })
			else
				ctx.preview:reset()
			end
		end or nil,
		actions = {
			confirm = function(picker, item)
				if item then
					snacks.picker.actions.close(picker)
					callback(item.item_name)
				end
			end,
		},
	}

	-- Merge with global picker config if it exists
	if config.picker.snacks then
		opts = vim.tbl_deep_extend("force", opts, config.picker.snacks)
	end

	snacks.picker.pick(opts)
end

return M
