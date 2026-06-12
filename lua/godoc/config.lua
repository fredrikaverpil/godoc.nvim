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

local window_types = { "split", "vsplit" }
local picker_types = { "native", "telescope", "snacks", "mini", "fzf_lua" }

--- Notify about invalid configuration values.
--- @param config GoDocConfig
local function validate(config)
  if type(config.adapters) ~= "table" then
    vim.notify(
      "Invalid configuration: adapters must be a list",
      vim.log.levels.ERROR
    )
  end
  if not vim.tbl_contains(window_types, config.window.type) then
    vim.notify(
      "Invalid window type: " .. tostring(config.window.type),
      vim.log.levels.ERROR
    )
  end
  if not vim.tbl_contains(picker_types, config.picker.type) then
    vim.notify(
      "Invalid picker type: " .. tostring(config.picker.type),
      vim.log.levels.ERROR
    )
  end
end

--- Merge user options with the defaults and validate the result.
--- @param opts? GoDocConfig
--- @return GoDocConfig
function M.setup(opts)
  local config = vim.tbl_deep_extend("force", M.defaults, opts or {})
  validate(config)
  return config
end

return M
