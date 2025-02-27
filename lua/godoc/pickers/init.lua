local M = {}

--- @type table<string, GoDocPicker>
local pickers = {
	native = require("godoc.pickers.native"),
	telescope = require("godoc.pickers.telescope"),
	snacks = require("godoc.pickers.snacks"),
	mini = require("godoc.pickers.mini"),
	fzf_lua = require("godoc.pickers.fzf_lua"),
}

--- Get a picker implementation
--- @param picker_type string
--- @return GoDocPicker?
function M.get_picker(picker_type)
	return pickers[picker_type]
end

return M
