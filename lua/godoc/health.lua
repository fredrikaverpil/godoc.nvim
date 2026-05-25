local health = vim.health or require("health")

local M = {}

function M.check()
  health.start("godoc.nvim")

  -- Report configuration source. The plugin works without setup(): plugin/godoc.lua
  -- auto-registers :GoDoc against the defaults, so "no setup()" is healthy, not an error.
  local godoc = require("godoc")
  if godoc.config then
    health.ok("Plugin configured via setup()")
  else
    health.ok("Running with default configuration (setup() not called)")
  end

  -- Ensure adapters are initialized so health checks work even if no command has been run yet.
  godoc._ensure_initialized()

  for _, adapter in pairs(godoc._adapters) do
    -- Get adapter name for display
    local name = adapter.command
    health.start(name)

    -- Run adapter health checks if available
    if adapter.health then
      local checks = adapter.health()
      for _, check in ipairs(checks) do
        if check.ok then
          health.ok(check.message)
        else
          if check.optional then
            health.warn(check.message)
          else
            health.error(check.message)
          end
        end
      end
    else
      health.info("No health checks implemented")
    end
  end
end

return M
