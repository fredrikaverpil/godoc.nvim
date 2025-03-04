local M = {}

-- Available adapters and their default options
--- @type table<string, fun(opts: table): GoDocAdapter>
M.available_adapters = {
	go = require("godoc.adapters.go").setup,
}

--- Get list of available built-in adapter names
--- @return string[]
function M.get_available_adapter_names()
	return vim.tbl_keys(M.available_adapters)
end

--- Check if an adapter name exists in built-in adapters
--- @param name string
--- @return boolean
function M.has_adapter(name)
	return M.available_adapters[name] ~= nil
end

--- Get a built-in adapter by name
--- @param name string
--- @param opts? GoDocAdapterOpts
--- @return GoDocAdapter|nil
function M.get_adapter(name, opts)
	local setup_fn = M.available_adapters[name]
	if setup_fn then
		return setup_fn(opts or {})
	end
	return nil
end

--- Validate if a table matches the DocAdapter interface
--- @param adapter any
--- @return boolean, string?
function M.validate_adapter(adapter)
	if type(adapter) ~= "table" then
		return false, "Adapter must be a table"
	end

	local required_fields = {
		{ name = "command", type = "string" },
		{ name = "get_items", type = "function" },
		{ name = "get_content", type = "function" },
		{ name = "get_definition", type = "function" },
		{ name = "get_syntax_info", type = "function" },
	}

	for _, field in ipairs(required_fields) do
		if type(adapter[field.name]) ~= field.type then
			return false, string.format("Adapter must have a '%s' field of type '%s'", field.name, field.type)
		end
	end

	return true
end

--- Override a default adapter by merging default implementation with user overrides
--- @param default_adapter GoDocAdapter
--- @param user_opts? GoDocAdapterOpts
--- @return GoDocAdapter
function M.override_adapter(default_adapter, user_opts)
	if not user_opts then
		return default_adapter
	end

	-- Merge user options with default adapter
	return {
		command = user_opts.command or default_adapter.command,
		get_items = user_opts.get_items or default_adapter.get_items,
		get_content = user_opts.get_content or default_adapter.get_content,
		get_definition = user_opts.get_definition or default_adapter.get_definition,
		get_syntax_info = user_opts.get_syntax_info or default_adapter.get_syntax_info,
		health = user_opts.health or default_adapter.health,
	}
end

return M
