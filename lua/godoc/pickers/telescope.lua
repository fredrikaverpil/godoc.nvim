--- @class TelescopePicker: GoDocPicker
local M = {}

--- @param adapter GoDocAdapter
--- @param config GoDocConfig
--- @param callback fun(choice: string|nil)
function M.show(adapter, config, callback)
	local action_state = require("telescope.actions.state")
	local finders = require("telescope.finders")
	local pickers = require("telescope.pickers")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values

	-- Create custom previewer
	local package_previewer = previewers.new_buffer_previewer({
		title = "Contents",
		get_buffer_by_name = function(_, entry)
			return entry.value
		end,
		define_preview = function(self, entry)
			local docs = adapter.get_content(entry.value)
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, docs)
			local syntax_info = adapter.get_syntax_info()
			vim.api.nvim_set_option_value("filetype", syntax_info.filetype, { buf = self.state.bufnr })
		end,
	})

	local function on_package_select(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if selection then
			callback(selection.value)
		end
	end

	-- Get items from adapter
	local items = adapter.get_items()
	local formatted_items = {}
	for _, item in ipairs(items) do
		table.insert(formatted_items, {
			value = item,
			display = item,
			ordinal = item,
		})
	end

	-- Create picker configuration
	local opts = {
		finder = finders.new_table({
			results = formatted_items,
			entry_maker = function(entry)
				return {
					display = entry.display,
					value = entry.value,
					ordinal = entry.ordinal,
				}
			end,
		}),
		sorter = conf.generic_sorter(),
		previewer = package_previewer,
		attach_mappings = function(_, map)
			map("i", "<CR>", function(prompt_bufnr)
				vim.cmd("stopinsert")
				on_package_select(prompt_bufnr)
			end)
			map("n", "<CR>", function(prompt_bufnr)
				on_package_select(prompt_bufnr)
			end)
			return true
		end,
	}

	-- Merge with global picker config if it exists
	if config.picker.telescope then
		opts = vim.tbl_deep_extend("force", opts, config.picker.telescope)
	end

	pickers.new(opts, {}):find()
end

return M
