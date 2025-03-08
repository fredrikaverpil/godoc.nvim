local M = {}

-- Cache for package list
local package_cache = nil
local package_cache_time = 0
local package_cache_cwd = vim.fn.getcwd()
local CACHE_DURATION = 300 -- 5 minutes

---Get standard library packages from 'go list'
---@returns table<string>
local function get_std_packages_golist()
	local std_packages = vim.fn.systemlist("go list std")
	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to get package list using 'go list'", vim.log.levels.ERROR)
		return {}
	end
	return std_packages
end

---Get standard library packages from stdsym, if binary is available
---@returns table<string>
local function get_std_packages_stdsym()
	local stdsym = vim.fn.executable("stdsym")
	if stdsym == 1 then
		-- stdsym is available
		local std_packages_via_stdsym = vim.fn.systemlist("stdsym")
		if vim.v.shell_error ~= 0 then
			vim.notify("Failed to get package list using stdsym, falling back on 'go list'", vim.log.levels.ERROR)
			return get_std_packages_golist()
		end
		return std_packages_via_stdsym
	end

	-- stdsym is not available, fall back to using `go list std`
	return get_std_packages_golist()
end

---Get project and dependency packages, if in a Go module
---@returns table<strings
local function get_gomod_packages()
	-- Search from the directory of the current file upwards until it finds the file "go.mod"
	local go_mod = vim.fn.findfile("go.mod", ".;")
	if go_mod ~= "" then
		-- Get the directory containing go.mod
		local mod_dir = vim.fn.fnamemodify(go_mod, ":p:h")
		-- Execute go list all in the module directory
		local mod_packages = vim.fn.systemlist(string.format("cd %s && go list -e all", vim.fn.shellescape(mod_dir)))
		if vim.v.shell_error ~= 0 then
			vim.notify("Failed to get package list using 'go list'", vim.log.levels.ERROR)
			return {}
		end
		return mod_packages
	end
	return {} -- no go.mod file found
end

--- Get list of packages
---@return table<string>
local function get_packages()
	-- Check cache
	local current_time = os.time()
	if
		package_cache
		and (current_time - package_cache_time) < CACHE_DURATION
		and package_cache_cwd == vim.fn.getcwd()
	then
		return package_cache
	end

	local std_packages = get_std_packages_stdsym()
	local gomod_packages = get_gomod_packages()
	local all_packages = {}
	for _, pkg in ipairs(std_packages) do
		table.insert(all_packages, pkg)
	end
	for _, pkg in ipairs(gomod_packages) do
		table.insert(all_packages, pkg)
	end

	-- Update cache
	package_cache = vim.fn.uniq(all_packages)
	package_cache_time = current_time

	return all_packages
end

--- @param package string
--- @param picker_gotodef_fun fun() | nil
local function goto_package_definition(package, picker_gotodef_fun)
	if not picker_gotodef_fun then
		vim.notify(
			"Picker does not implement a function which can be used for showing definitions",
			vim.log.levels.WARN
		)
		return
	end

	-- Create temp file instead of just in-memory buffer
	local temp_dir = vim.fn.tempname()
	vim.fn.mkdir(temp_dir, "p")
	local temp_file = temp_dir .. "/temp.go"

	-- Write content to the actual file
	local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
    return
end
	file:write(string.format(
		[[
package main

import "%s"

]],
		package
	))
	file:close()

	-- Open the actual file and set cursor immediately
	vim.cmd("edit " .. temp_file)
	local buf = vim.api.nvim_get_current_buf()

	-- Position cursor immediately
	vim.api.nvim_win_set_cursor(0, { 3, 8 })

	vim.wait(100)

	picker_gotodef_fun()
end

local function health()
	--- @type GoDocHealthCheck[]
	local checks = {}

	-- Check if 'go' is available
	local go_version = vim.fn.system("go version")
	if vim.v.shell_error == 0 then
		table.insert(checks, {
			ok = true,
			message = "go binary found: " .. go_version:gsub("\n", ""),
		})
	else
		table.insert(checks, {
			ok = false,
			message = "go binary not found in PATH",
		})
	end

	-- Check if 'stdsym' is available in PATH
	local stdsym = vim.fn.executable("stdsym")
	if stdsym == 1 then
		table.insert(checks, {
			ok = true,
			message = "stdsym binary found",
		})
	else
		table.insert(checks, {
			ok = false,
			message = "stdsym binary not found in PATH",
			optional = true,
		})
	end

	-- Check if we can run 'go help doc'
	local go_help_doc = vim.fn.system("go help doc")
	if vim.v.shell_error == 0 then
		table.insert(checks, {
			ok = true,
			message = "go help doc command found",
		})
	else
		table.insert(checks, {
			ok = false,
			message = "go help doc command not found",
			optional = true,
		})
	end

	-- Check if we can run 'go list std'
	local go_list_std = vim.fn.system("go list std")
	if vim.v.shell_error == 0 then
		table.insert(checks, {
			ok = true,
			message = "go list std command found",
		})
	else
		table.insert(checks, {
			ok = false,
			message = "go list std command not found",
			optional = true,
		})
	end

	-- Check if we can run 'go doc fmt'
	local go_doc_fmt = vim.fn.system("go doc fmt")
	if vim.v.shell_error == 0 then
		table.insert(checks, {
			ok = true,
			message = "go doc fmt command found",
		})
	else
		table.insert(checks, {
			ok = false,
			message = "go doc fmt command not found",
			optional = true,
		})
	end

	-- Check if we can run 'go doc fmt.Printf'
	local go_doc_fmt_printf = vim.fn.system("go doc fmt.Printf")
	if vim.v.shell_error == 0 then
		table.insert(checks, {
			ok = true,
			message = "go doc fmt.Printf command found",
		})
	else
		table.insert(checks, {
			ok = false,
			message = "go doc fmt.Printf command not found",
			optional = true,
		})
	end

	-- Check if we're in a Go project (optional)
	local go_mod = vim.fn.findfile("go.mod", ".;")
	if go_mod ~= "" then
		table.insert(checks, {
			ok = true,
			message = "Go project detected",
			optional = true,
		})
	else
		table.insert(checks, {
			ok = false,
			message = "Go project not detected",
			optional = true,
		})
	end

	return checks
end

---Set up the GoDoc adapter
---@param opts? table
--- @return GoDocAdapter
function M.setup(opts)
	if not opts then
		opts = {}
	end
	return {
		command = "GoDoc",
		get_items = function()
			return get_packages()
		end,
		get_content = function(choice)
			return vim.fn.systemlist("go doc -all " .. choice)
		end,
		get_syntax_info = function()
			return {
				filetype = "godoc",
				language = "go",
			}
		end,
		goto_definition = function(choice, picker_gotodef_fun)
			return goto_package_definition(choice, picker_gotodef_fun)
		end,
		health = health,
	}
end

return M
