local core = require("fzf-lua.core")
local builtin = require("fzf-lua.previewer.builtin")

--- @class Fzflua: GoDocPicker
local M = {}

local documentation_previewer = builtin.base:extend()

function documentation_previewer:new(o, opts, fzf_win)
  documentation_previewer.super.new(self, o, opts, fzf_win)
  setmetatable(self, documentation_previewer)
  return self
end

---@param entry_str string
function documentation_previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    vim.api.nvim_set_option_value("filetype", "godoc", { buf = tmpbuf })
    vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, self.opts.adapter.get_content(entry_str))
    self:set_preview_buf(tmpbuf)
end

--- @param adapter GoDocAdapter
--- @param config GoDocConfig
--- @param callback fun(choice: GoDocCallbackData)
function M.show(adapter, config, callback)
	local opts = {
		prompt = "Select item: ",
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
        adapter = adapter, -- Allow previewer to access adapter
        previewer = documentation_previewer
	}

	if config.picker.fzf_lua then
		opts = vim.tbl_deep_extend("force", opts, config.picker.fzf_lua)
	end

	core.fzf_exec(adapter.get_items(), opts)
end

--- @return nil
M.goto_definition = function()
	require("fzf-lua").lsp_definitions()
end

return M
