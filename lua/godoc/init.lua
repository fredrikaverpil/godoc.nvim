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

-- Active configuration. Starts with defaults so :GoDoc works without setup().
--- @type GoDocConfig
M.config = vim.deepcopy(M.defaults)

-- The configured adapters, keyed by command name.
--- @type table<string, GoDocAdapter>
M._adapters = {}

M._lazy_initialized = false

--- @param adapter_config GoDocAdapterConfig
--- @return boolean
local function is_third_party_adapter(adapter_config)
  return type(adapter_config.setup) == "function"
end

--- @param adapter_config GoDocAdapterConfig
--- @return string?
local function adapter_command(adapter_config)
  return (adapter_config.opts and adapter_config.opts.command)
    or adapter_config.command
end

--- @param adapter_config GoDocThirdPartyAdapter
--- @param adapters table
--- @return GoDocAdapter?
local function configure_third_party_adapter(adapter_config, adapters)
  local default_adapter = adapter_config.setup()
  local final_adapter =
    adapters.override_adapter(default_adapter, adapter_config.opts)
  local is_valid, error_message = adapters.validate_adapter(final_adapter)
  if is_valid then
    return final_adapter
  end

  vim.notify(
    string.format("Invalid third-party adapter: %s", error_message),
    vim.log.levels.WARN
  )
end

--- @param adapter_config GoDocBuiltinAdapter
--- @param adapters table
--- @return GoDocAdapter?
local function configure_builtin_adapter(adapter_config, adapters)
  local default_adapter = adapters.get_adapter(adapter_config.name)
  if default_adapter ~= nil then
    return adapters.override_adapter(default_adapter, adapter_config.opts)
  end

  vim.notify(
    string.format("Adapter %s not found", adapter_config.name),
    vim.log.levels.WARN
  )
end

--- @param adapter_config GoDocUserAdapter
--- @param adapters table
--- @return GoDocAdapter?
local function configure_user_adapter(adapter_config, adapters)
  local is_valid, error_message = adapters.validate_adapter(adapter_config)
  if is_valid then
    return adapter_config
  end

  vim.notify(
    string.format("Invalid user-defined adapter: %s", error_message),
    vim.log.levels.WARN
  )
end

--- @param config GoDocConfig
local function configure_adapters(config)
  local adapters = require("godoc.adapters")

  if not config.adapters or type(config.adapters) ~= "table" then
    vim.notify(
      "Invalid configuration: adapters must be a list",
      vim.log.levels.ERROR
    )
    return {}
  end

  local configured_adapters = {}

  for _, adapter_config in ipairs(config.adapters) do
    if type(adapter_config) == "table" then
      local adapter

      if is_third_party_adapter(adapter_config) then
        ---@cast adapter_config GoDocThirdPartyAdapter
        if adapter_command(adapter_config) then
          adapter = configure_third_party_adapter(adapter_config, adapters)
        else
          -- Already initialized eagerly by register_eager in setup(): its command
          -- name is only known after calling setup(), so calling setup() again
          -- here would duplicate any side effects and re-emit validation warnings.
        end
      elseif
        adapter_config.name and adapters.has_adapter(adapter_config.name)
      then
        ---@cast adapter_config GoDocBuiltinAdapter
        adapter = configure_builtin_adapter(adapter_config, adapters)
      else
        ---@cast adapter_config GoDocUserAdapter
        adapter = configure_user_adapter(adapter_config, adapters)
      end

      if adapter then
        table.insert(configured_adapters, adapter)
      end
    end
  end

  return configured_adapters
end

--- Register syntax highlighting metadata and remember the adapter by command.
--- @param adapter GoDocAdapter
local function activate_adapter(adapter)
  local syntax = adapter.get_syntax_info()
  vim.treesitter.language.register(syntax.language, { syntax.filetype })
  M._adapters[adapter.command] = adapter
end

--- Lazy-initialize adapters and treesitter on first command use.
--- Also called by health.lua so :checkhealth works before any command is run.
function M._ensure_initialized()
  if M._lazy_initialized then
    return
  end
  M._lazy_initialized = true

  local configured = configure_adapters(M.config)
  for _, adapter in ipairs(configured) do
    -- Skip adapters that were already eagerly initialized
    if not M._adapters[adapter.command] then
      activate_adapter(adapter)
    end
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

--- Run the picker/documentation flow for the given adapter.
--- @param adapter GoDocAdapter
--- @param args table command arguments table from nvim_create_user_command
local function dispatch(adapter, args)
  if args.args ~= nil and args.args ~= "" then
    M.show_documentation(adapter, args.args)
    return
  end

  local pickers = require("godoc.pickers")
  local picker = pickers.get_picker(M.config.picker.type)
  if not picker then
    vim.notify(
      "Picker not implemented: " .. M.config.picker.type,
      vim.log.levels.ERROR
    )
    return
  end

  ---@type GoDocPicker
  picker.show(adapter, M.config, function(data)
    if data.choice then
      if data.type == "show_documentation" then
        open_window(M.config.window.type)
        M.show_documentation(adapter, data.choice)
      elseif data.type == "goto_definition" then
        open_window(M.config.window.type)
        M.goto_definition(adapter, data.choice, picker.goto_definition)
      end
    end
  end)
end

--- Command callback shared by setup()-registered commands and the auto command.
--- @param args table command arguments table from nvim_create_user_command
function M._dispatch_command(args)
  M._ensure_initialized()

  local adapter = M._adapters[args.name]
  if not adapter then
    vim.notify(
      "No adapter found for command: " .. args.name,
      vim.log.levels.ERROR
    )
    return
  end

  dispatch(adapter, args)
end

--- Create a user command that delegates to its matching adapter.
--- @param command string
local function register_command(command)
  vim.api.nvim_create_user_command(
    command,
    M._dispatch_command,
    { nargs = "?" }
  )
end

--- Register a user command unless something else already owns that exact name.
--- @param command string
--- @return boolean
local function register_command_if_available(command)
  if vim.api.nvim_get_commands({})[command] == nil then
    register_command(command)
    return true
  end

  vim.notify(
    string.format(
      "Command :%s already exists; choose another adapter command in setup()",
      command
    ),
    vim.log.levels.WARN
  )
  return false
end

--- Remove the zero-config command registered by plugin/godoc.lua, if present.
local function remove_auto_command()
  if vim.g.godoc_auto_command then
    pcall(vim.api.nvim_del_user_command, vim.g.godoc_auto_command)
    vim.g.godoc_auto_command = nil
  end
end

--- Reset runtime state before applying user configuration.
local function reset_runtime()
  M._adapters = {}
  M._lazy_initialized = false
  remove_auto_command()
end

--- Eagerly initialize a single adapter and register its command.
--- Used for third-party adapters whose command name is only known at runtime.
--- @param adapter_config table
local function register_eager(adapter_config)
  local adapters = require("godoc.adapters")
  local final_adapter = configure_third_party_adapter(adapter_config, adapters)
  if not final_adapter then
    return
  end
  activate_adapter(final_adapter)
  register_command_if_available(final_adapter.command)
end

-- Set up the plugin with user config
--- @param opts? GoDocConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})

  -- A user-supplied adapters list replaces the defaults wholesale rather than
  -- being merged in.
  if opts and opts.adapters then
    M.config.adapters = opts.adapters
  end

  -- Make setup() the single source of truth, even if the default :GoDoc command
  -- or default adapters were initialized before user config was applied.
  vim.g.godoc_user_configured = true
  reset_runtime()

  for _, adapter_config in ipairs(M.config.adapters) do
    local command = adapter_command(adapter_config)
    if command then
      register_command_if_available(command)
    elseif is_third_party_adapter(adapter_config) then
      -- Third-party adapter without opts.command — must call setup() to learn the command name
      register_eager(adapter_config)
    end
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
  vim.api.nvim_set_option_value(
    "filetype",
    adapter.get_syntax_info().filetype,
    { buf = buf }
  )

  vim.api.nvim_set_current_buf(buf)

  -- Set up keymaps for the documentation window
  local opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set("n", "q", "<cmd>close<CR>", opts)
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", opts)
end

--- Go to definition on chosen item
--- @param adapter GoDocAdapter
--- @param choice string The chosen item (package, symbol)
--- @param picker_gotodef_fun fun()? The picker's goto_definition function
--- @return nil
function M.goto_definition(adapter, choice, picker_gotodef_fun)
  if not picker_gotodef_fun then
    vim.notify(
      "Picker does not implement a function which can be used for showing definitions",
      vim.log.levels.WARN
    )
  end
  adapter.goto_definition(choice, picker_gotodef_fun)
end

return M
