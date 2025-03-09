require("godoc.types")
local pickers = require("godoc.pickers")
local adapters = require("godoc.adapters")

local M = {}

-- Default configuration.
--- @type GoDocConfig
M.defaults = {
	adapters = {
		{
			name = "go",
			opts = { command = "GoDoc" },
		},
	},
	window = {
		type = "split", -- split, vsplit
	},
	picker = {
		type = "native", -- native | telescope | snacks | mini | fzf_lua

		-- see respective picker in lua/godoc/pickers for available options
		native = {},
		telescope = {},
		snacks = {},
		mini = {},
		fzf_lua = {},
	},
}

-- Final configuration (defaults + user-provided) after setup.
--- @type GoDocConfig
M.config = nil

-- The configured adapters, after having set them up.
--- @type GoDocAdapter[]
M.configured_adapters = {}

--- @param config? GoDocConfig
--- @return GoDocAdapter[]
local function configure_adapters(config)
	if not config or not config.adapters or type(config.adapters) ~= "table" then
		vim.notify("Invalid configuration: adapters must be a list", vim.log.levels.ERROR)
		return {}
	end

	local configured_adapters = {}

	for _, adapter_config in ipairs(config.adapters) do
		if type(adapter_config) == "table" then
			if adapter_config.setup and type(adapter_config.setup) == "function" then
				-- Handle third-party adapter
				local default_adapter = adapter_config.setup() -- Get default adapter implementation
				local final_adapter = adapters.override_adapter(default_adapter, adapter_config.opts)
				local is_valid, error_message = adapters.validate_adapter(final_adapter)
				if is_valid then
					table.insert(configured_adapters, final_adapter)
				else
					vim.notify(string.format("Invalid third-party adapter: %s", error_message), vim.log.levels.WARN)
				end
			elseif adapter_config.name and adapters.has_adapter(adapter_config.name) then
				-- Handle built-in adapter
				local default_adapter = adapters.get_adapter(adapter_config.name)
				if default_adapter ~= nil then
					local final_adapter = adapters.override_adapter(default_adapter, adapter_config.opts)
					table.insert(configured_adapters, final_adapter)
				else
					vim.notify(string.format("Adapter %s not found", adapter_config.name), vim.log.levels.WARN)
				end
			else
				-- Handle user-defined adapter
				local is_valid, error_message = adapters.validate_adapter(adapter_config)
				if is_valid then
					table.insert(configured_adapters, adapter_config)
				else
					vim.notify(string.format("Invalid user-defined adapter: %s", error_message), vim.log.levels.WARN)
				end
			end
		end
	end

	return configured_adapters
end

-- Set up the plugin with user config
--- @param opts? GoDocConfig
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
	M.configured_adapters = configure_adapters(M.config)

	for _, adapter in ipairs(M.configured_adapters) do
		-- Set up syntax highlighting
		vim.treesitter.language.register(adapter.get_syntax_info().language, { adapter.get_syntax_info().filetype })

		-- Create user command
		vim.api.nvim_create_user_command(adapter.command, function(args)
			-- if args were passed, show documentation directly
			if args.args ~= nil and args.args ~= "" then
				M.show_documentation(adapter, args.args)
				return
			end

			-- Show picker
			local picker = pickers.get_picker(M.config.picker.type)
			if picker then
				---@type GoDocPicker
				picker.show(adapter, M.config, function(data)
					if data.choice then
						if data.type == "show_documentation" then
							M.show_documentation(adapter, data.choice)
						elseif data.type == "goto_definition" then
							M.goto_definition(adapter, data.choice, picker.goto_definition)
						end
					end
				end)
			else
				vim.notify("Picker not implemented: " .. M.config.picker.type, vim.log.levels.ERROR)
			end
		end, { nargs = "?" })
	end
end

--- Open window based on split type
--- @param type 'split' | 'vsplit'
local function open_window(type)
	if type == "split" or type == "vsplit" then
		vim.cmd(type)
	else
		vim.notify("Invalid window type: " .. type, vim.log.levels.ERROR)
	end
end

-- Show documentation in new buffer
--- @param adapter GoDocAdapter
--- @param item string
function M.show_documentation(adapter, item)
	local content = adapter.get_content(item)

	-- Create new buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

	-- Set buffer options
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", adapter.get_syntax_info().filetype, { buf = buf })

	open_window(M.config.window.type)

	vim.api.nvim_set_current_buf(buf)

	-- Set up keymaps for the documentation window
	local opts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "q", ":close<CR>", opts)
	vim.keymap.set("n", "<Esc>", ":close<CR>", opts)
end

--- Go to definition on chosen item
--- @param adapter GoDocAdapter
--- @param item string
--- @param picker_gotodef_fun fun()?
--- @return nil
function M.goto_definition(adapter, item, picker_gotodef_fun)
	adapter.goto_definition(item, picker_gotodef_fun)
end

return M
