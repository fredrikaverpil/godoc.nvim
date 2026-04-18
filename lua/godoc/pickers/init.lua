local M = {}

--- Get a picker implementation
--- @param picker_type string
--- @return GoDocPicker?
function M.get_picker(picker_type)
	local ok, result = pcall(require, "godoc.pickers." .. picker_type)
	if ok then
		return result
	end
	-- Only silence "module not found" errors; surface real errors in picker code.
	if not result:find("module 'godoc.pickers." .. picker_type .. "' not found", 1, true) then
		error(result)
	end
end

return M
