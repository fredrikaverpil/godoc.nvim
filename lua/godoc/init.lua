local M = {}

-- Default configuration.
--- @type GoDocConfig
M.defaults = require("godoc.config").defaults

-- Final configuration (defaults + user-provided) after setup.
--- @type GoDocConfig
M.config = nil

-- The configured adapters, keyed by command name.
--- @type table<string, GoDocAdapter>
M._adapters = {}

M._lazy_initialized = false

--- @param adapter_config GoDocAdapterConfig
--- @return boolean
local function is_third_party_adapter(adapter_config)
  return type(adapter_config.setup) == "function"
end

--- The command name declared in the adapter config, if any.
--- @param adapter_config GoDocAdapterConfig
--- @return string?
local function adapter_command(adapter_config)
  return (adapter_config.opts and adapter_config.opts.command)
    or adapter_config.command
end

--- @param adapter_config GoDocThirdPartyAdapter
--- @return GoDocAdapter?
local function configure_third_party_adapter(adapter_config)
  local adapters = require("godoc.adapters")
  local default_adapter = adapter_config.setup()
  local final_adapter =
    adapters.override_adapter(default_adapter, adapter_config.opts)
  local is_valid, error_message = adapters.validate_adapter(final_adapter)
  if not is_valid then
    vim.notify(
      string.format("Invalid third-party adapter: %s", error_message),
      vim.log.levels.WARN
    )
    return nil
  end
  return final_adapter
end

--- @param adapter_config GoDocBuiltinAdapter
--- @return GoDocAdapter?
local function configure_builtin_adapter(adapter_config)
  local adapters = require("godoc.adapters")
  local default_adapter = adapters.get_adapter(adapter_config.name)
  if default_adapter == nil then
    vim.notify(
      string.format("Adapter %s not found", adapter_config.name),
      vim.log.levels.WARN
    )
    return nil
  end
  return adapters.override_adapter(default_adapter, adapter_config.opts)
end

--- @param adapter_config GoDocUserAdapter
--- @return GoDocAdapter?
local function configure_user_adapter(adapter_config)
  local adapters = require("godoc.adapters")
  local is_valid, error_message = adapters.validate_adapter(adapter_config)
  if not is_valid then
    vim.notify(
      string.format("Invalid user-defined adapter: %s", error_message),
      vim.log.levels.WARN
    )
    return nil
  end
  return adapter_config
end

--- Resolve each adapter config into a ready-to-use adapter.
--- @param config GoDocConfig
--- @return GoDocAdapter[]
local function configure_adapters(config)
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
        adapter = configure_third_party_adapter(adapter_config)
      elseif adapter_config.name then
        ---@cast adapter_config GoDocBuiltinAdapter
        adapter = configure_builtin_adapter(adapter_config)
      else
        ---@cast adapter_config GoDocUserAdapter
        adapter = configure_user_adapter(adapter_config)
      end
      if adapter then
        table.insert(configured_adapters, adapter)
      end
    end
  end

  return configured_adapters
end

--- Register syntax highlighting and remember the adapter by command name.
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

--- Create a user command that delegates to the given adapter.
--- @param command string
local function register_command(command)
  vim.api.nvim_create_user_command(command, function(args)
    M._ensure_initialized()

    local adapter = M._adapters[command]
    if not adapter then
      vim.notify(
        "No adapter found for command: " .. command,
        vim.log.levels.ERROR
      )
      return
    end

    -- If args were passed, show documentation directly
    if args.args ~= nil and args.args ~= "" then
      M.show_documentation(adapter, args.args)
      return
    end

    -- Show picker
    local pickers = require("godoc.pickers")
    local picker = pickers.get_picker(M.config.picker.type)
    if picker then
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
    else
      vim.notify(
        "Picker not implemented: " .. M.config.picker.type,
        vim.log.levels.ERROR
      )
    end
  end, { nargs = "?" })
end

--- Eagerly initialize a single adapter and register its command.
--- Used for third-party adapters whose command name is only known at runtime.
--- @param adapter_config GoDocThirdPartyAdapter
local function register_eager(adapter_config)
  local adapter = configure_third_party_adapter(adapter_config)
  if not adapter then
    return
  end
  activate_adapter(adapter)
  register_command(adapter.command)
end

-- Set up the plugin with user config
--- @param opts? GoDocConfig
function M.setup(opts)
  M.config = require("godoc.config").setup(opts)

  for _, adapter_config in ipairs(M.config.adapters) do
    local command = adapter_command(adapter_config)
    if command then
      -- Command name known from config — register lazily
      register_command(command)
    elseif is_third_party_adapter(adapter_config) then
      ---@cast adapter_config GoDocThirdPartyAdapter
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
