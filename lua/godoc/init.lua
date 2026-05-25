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

-- The configured adapters, keyed by command name.
--- @type table<string, GoDocAdapter>
M._adapters = {}

M._lazy_initialized = false

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
      if adapter_config.setup and type(adapter_config.setup) == "function" then
        -- Handle third-party adapter
        local default_adapter = adapter_config.setup() -- Get default adapter implementation
        local final_adapter =
          adapters.override_adapter(default_adapter, adapter_config.opts)
        local is_valid, error_message = adapters.validate_adapter(final_adapter)
        if is_valid then
          table.insert(configured_adapters, final_adapter)
        else
          vim.notify(
            string.format("Invalid third-party adapter: %s", error_message),
            vim.log.levels.WARN
          )
        end
      elseif
        adapter_config.name and adapters.has_adapter(adapter_config.name)
      then
        -- Handle built-in adapter
        local default_adapter = adapters.get_adapter(adapter_config.name)
        if default_adapter ~= nil then
          local final_adapter =
            adapters.override_adapter(default_adapter, adapter_config.opts)
          table.insert(configured_adapters, final_adapter)
        else
          vim.notify(
            string.format("Adapter %s not found", adapter_config.name),
            vim.log.levels.WARN
          )
        end
      else
        -- Handle user-defined adapter
        local is_valid, error_message =
          adapters.validate_adapter(adapter_config)
        if is_valid then
          table.insert(configured_adapters, adapter_config)
        else
          vim.notify(
            string.format("Invalid user-defined adapter: %s", error_message),
            vim.log.levels.WARN
          )
        end
      end
    end
  end

  return configured_adapters
end

--- Lazy-initialize adapters and treesitter on first command use.
--- Also called by health.lua so :checkhealth works before any command is run.
function M._ensure_initialized()
  if M._lazy_initialized then
    return
  end
  M._lazy_initialized = true

  -- Fall back to defaults when setup() was never called so the auto-registered
  -- :GoDoc (and :checkhealth) work out of the box.
  local configured = configure_adapters(M.config or M.defaults)
  for _, adapter in ipairs(configured) do
    -- Skip adapters that were already eagerly initialized
    if not M._adapters[adapter.command] then
      local syntax = adapter.get_syntax_info()
      vim.treesitter.language.register(syntax.language, { syntax.filetype })
      M._adapters[adapter.command] = adapter
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
--- Uses M.config when setup() has been called, otherwise falls back to defaults
--- so plugin/godoc.lua's auto-registered :GoDoc works without setup().
--- @param adapter GoDocAdapter
--- @param args table command arguments table from nvim_create_user_command
local function dispatch(adapter, args)
  local config = M.config or M.defaults

  if args.args ~= nil and args.args ~= "" then
    M.show_documentation(adapter, args.args)
    return
  end

  local pickers = require("godoc.pickers")
  local picker = pickers.get_picker(config.picker.type)
  if not picker then
    vim.notify(
      "Picker not implemented: " .. config.picker.type,
      vim.log.levels.ERROR
    )
    return
  end

  ---@type GoDocPicker
  picker.show(adapter, config, function(data)
    if data.choice then
      if data.type == "show_documentation" then
        open_window(config.window.type)
        M.show_documentation(adapter, data.choice)
      elseif data.type == "goto_definition" then
        open_window(config.window.type)
        M.goto_definition(adapter, data.choice, picker.goto_definition)
      end
    end
  end)
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

    dispatch(adapter, args)
  end, { nargs = "?" })
end

--- Entry point for the command auto-registered by plugin/godoc.lua, so it works
--- out-of-the-box without the user calling setup(). Initializes the default
--- adapters lazily (_ensure_initialized falls back to M.defaults) and dispatches
--- the adapter whose command matches the one that was invoked.
--- @param args table command arguments table from nvim_create_user_command
function M._run_default_go(args)
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

--- Eagerly initialize a single adapter and register its command.
--- Used for third-party adapters whose command name is only known at runtime.
--- @param adapter_config table
local function register_eager(adapter_config)
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
    return
  end
  local syntax = final_adapter.get_syntax_info()
  vim.treesitter.language.register(syntax.language, { syntax.filetype })
  M._adapters[final_adapter.command] = final_adapter
  register_command(final_adapter.command)
end

-- Set up the plugin with user config
--- @param opts? GoDocConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})

  -- Tell plugin/godoc.lua that the user owns the plugin — it should not
  -- auto-register :GoDoc (in case plugin scripts load after user init).
  vim.g._godoc_user_configured = true

  -- Remove the command auto-registered by plugin/godoc.lua so the loop below is
  -- the single source of truth for which commands exist. This keeps the end
  -- state independent of load order: whether setup() runs before or after
  -- plugin/godoc.lua, the resulting commands are exactly what the config asks
  -- for. If the config still maps an adapter to that name (the default), the
  -- loop re-registers it; if the user renamed it, the old command is gone.
  if vim.g._godoc_auto_registered then
    pcall(vim.api.nvim_del_user_command, vim.g._godoc_auto_registered)
    vim.g._godoc_auto_registered = nil
  end

  for _, adapter_config in ipairs(M.config.adapters) do
    local command = (adapter_config.opts and adapter_config.opts.command)
      or adapter_config.command
    if command then
      -- Skip if a command with this name already exists (e.g., registered
      -- by another plugin, or the user's vimrc) — don't clobber.
      if vim.fn.exists(":" .. command) == 0 then
        register_command(command)
      end
    elseif
      adapter_config.setup and type(adapter_config.setup) == "function"
    then
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
