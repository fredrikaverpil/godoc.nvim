-- lua/godoc/health.lua
local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local error = health.error or health.report_error
local warn = health.warn or health.report_warn
local info = health.info or health.report_info

local M = {}

-- Helper function to safely get environment variables
local function get_env(name)
	local value = vim.fn.getenv(name)
	return type(value) == "string" and value or ""
end

function M.check()
	start("godoc.nvim")

	-- Check if 'go' is available in PATH
	local go_binary = vim.fn.executable("go")
	if go_binary == 1 then
		ok("'go' binary found in PATH")

		-- Check go version
		local version = vim.fn.system("go version")
		if vim.v.shell_error == 0 then
			ok(string.format("Go version: %s", version:gsub("\n", "")))
		else
			error("Failed to get Go version")
		end
	else
		error("'go' binary not found in PATH")
		return
	end

	-- Check if 'stdsym' is available in PATH
	local stdsym_binary = vim.fn.executable("stdsym")
	if stdsym_binary == 1 then
		ok("'stdsym' binary found in PATH")
	else
		error("'stdsym' binary not found in PATH")
		return
	end

	-- Check if we can get doc help
	local help_test = vim.fn.system("go help doc")
	if vim.v.shell_error == 0 then
		ok("'go help doc' command is working")
	else
		error("'go help doc' command failed", {
			"Error running 'go help doc'",
			"Output: " .. help_test,
		})
		return
	end

	-- Check if we can list packages
	local list_test = vim.fn.system("go list std")
	if vim.v.shell_error == 0 then
		ok("'go list' command is working")
	else
		error("'go list' command failed", {
			"Error running 'go list std'",
			"Output: " .. list_test,
		})
		return
	end

	-- Check if we can run basic go doc command
	local doc_test = vim.fn.system("go doc fmt")
	if vim.v.shell_error == 0 then
		ok("'go doc' package lookup is working")
	else
		error("'go doc' package lookup failed", {
			"Error running 'go doc fmt'",
			"Output: " .. doc_test,
		})
		return
	end

	-- Check if we can look up specific symbols
	local symbol_test = vim.fn.system("go doc fmt.Printf")
	if vim.v.shell_error == 0 then
		ok("'go doc' symbol lookup is working")
	else
		error("'go doc' symbol lookup failed", {
			"Error running 'go doc fmt.Printf'",
			"Output: " .. symbol_test,
		})
	end

	-- Check if we're in a Go project (optional)
	local go_mod = vim.fn.findfile("go.mod", ".;")
	if go_mod ~= "" then
		ok("Found go.mod file: " .. go_mod)
	else
		info("No go.mod file found in current directory or parent directories")
	end

	-- Check GOPATH environment
	local gopath = get_env("GOPATH")
	if gopath ~= "" then
		ok("GOPATH is set: " .. gopath)
	else
		warn("GOPATH is not set")
	end

	-- Check GOROOT environment
	local goroot = get_env("GOROOT")
	if goroot ~= "" then
		ok("GOROOT is set: " .. goroot)
	else
		warn("GOROOT is not set")
	end
end

return M
