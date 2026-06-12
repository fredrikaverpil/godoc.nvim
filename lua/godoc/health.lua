local health = vim.health or require("health")

local M = {}

function M.check()
  health.start("godoc.nvim")

  -- Check plugin setup
  if vim.g.godoc_did_setup then
    health.ok("Plugin configured via setup()")
  else
    health.ok("Using default configuration (setup() was not called)")
  end

  -- Ensure adapters are initialized so health checks work even if no command has been run yet.
  local godoc = require("godoc")
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
