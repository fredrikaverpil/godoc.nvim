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
--- @param picker GoDocPicker
--- @return GoDocDefinition?
local function get_package_definition(package, picker)
	if not picker.lsp_definitions then
		vim.notify("Picker does not implement 'lsp_definitions'", vim.log.levels.WARN)
		return
	end

	local content = {
		"package main",
		'import "' .. package .. '"',
	}

	-- creating a new buffer and reading the content into it results in a gopls error: 'no package metadata for file file:///'
	-- using a tempfile as a workaround fixes this
	local tempfile = vim.fn.stdpath("cache") .. "/godoc-tmp.go"
	vim.fn.writefile(content, tempfile)

	-- create hidden window to run picker `get_definition` in
	local window = vim.api.nvim_open_win(0, false, {
		hide = true,
		relative = "win",
		row = 0,
		col = 0,
		width = 1,
		height = 1,
	})

	vim.fn.win_execute(window, "silent! e " .. tempfile, true)

	-- lsp client won't attach in time so it has to be done manually
	local buf = vim.api.nvim_win_get_buf(window)
	for _, client in ipairs(vim.lsp.get_clients()) do
		if client.name == "gopls" then
			vim.lsp.buf_attach_client(buf, client.id)
			break
		end
	end

	-- move cursor to the beginning of import string
	vim.api.nvim_win_set_cursor(window, { 2, 8 })

	vim.api.nvim_win_call(window, function()
		picker.lsp_definitions()
	end)

	-- picker fails to open if this call isn't deferred
	vim.defer_fn(function()
		vim.api.nvim_win_close(window, true)
		vim.cmd("!rm " .. tempfile)
	end, 50)
end

-- running with ':so %' works on the second try, getting errors when ran trough GoDoc usercommand
get_package_definition("bytes", { lsp_definitions = require("telescope.builtin").lsp_definitions })

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
		get_definition = function(choice, picker)
			return get_package_definition(choice, picker)
		end,
		get_syntax_info = function()
			return {
				filetype = "godoc",
				language = "go",
			}
		end,
		health = health,
	}
end

return M
