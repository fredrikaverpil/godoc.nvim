local health = vim.health or require("health")

local M = {}

function M.check()
	health.start("godoc.nvim")

	-- Check plugin setup
	local config = require("godoc").config
	if not config then
		health.error("Plugin not configured")
		return
	else
		health.ok("Plugin configured")
	end

	local configured_adapters = require("godoc").configured_adapters
	for _, adapter in ipairs(configured_adapters) do
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
