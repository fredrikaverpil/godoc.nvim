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

--- @param item string
--- @param picker_gotodef_fun fun()
local function goto_definition(item, picker_gotodef_fun)
	-- write temp file
	local content = {}
	local cursor_pos = {}
	-- check if the chosen item contains a symbol
	local is_symbol = string.match(item, "%.%a[%w_]*$") ~= nil
	if is_symbol then
		-- an import with symbol is passed, e.g. archive/tar.FileInfoNames
		--
		-- extract the import path (archive/tar)
		local import_path = item:match("^(.-)%.")
		-- extract the package name, which comes after the last slash (e.g. tar)
		local package_name = import_path:match("([^/]+)$")
		-- extract the symbol name, which comes after the last dot (e.g. FileInfoNames)
		local symbol = item:match("([^%.]+)$")
		-- the contents of the go file, which contains imports to the package and the symbol as well as the fmt package
		local line = '  fmt.Printf("%v", ' .. package_name .. "." .. symbol .. ")"
		content = {
			"package main",
			"",
			"import (",
			'  "' .. import_path .. '"',
			'  "fmt"',
			")",
			"",
			"func main() {",
			line,
			"}",
		}
		-- put the position/cursor on the symbol, e.g. on the 'F' of FileInfoNames
		cursor_pos = { 9, line:find(symbol) + 1 }
	else
		-- a package name is passed, e.g. "archive/tar"
		content = {
			"package main",
			"",
			'import "' .. item .. '"',
		}
		cursor_pos = { 3, 9 }
	end
	local now = os.time()
	local filename = "godoc_" .. now .. ".go"
	local tempfile = vim.fn.getcwd() .. "/" .. filename
	local go_mod_filepath = vim.fn.findfile("go.mod", vim.fn.getcwd() .. ";")
	local go_mod_dir = vim.fn.fnamemodify(go_mod_filepath, ":p:h")
	if go_mod_dir == "" then
		vim.notify("Failed to find go.mod file, can only gotodef on std lib", vim.log.levels.WARN)
	else
		tempfile = go_mod_dir .. "/" .. filename
	end
	vim.fn.writefile(content, tempfile)

	-- Open the temp file in the current (godoc-managed) buffer
	vim.cmd("silent! e " .. tempfile)
	local window = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_get_current_buf()

	-- Set buffer options
	vim.api.nvim_set_option_value("filetype", "go", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.diagnostic.enable(false, { bufnr = buf })

	-- Wait until LSP has attached, can be queried and returns a client_id
	local client_id = nil
	local maxretries = 50
	while client_id == nil and maxretries >= 0 do
		for _, client in ipairs(vim.lsp.get_clients({ name = "gopls", bufnr = buf })) do
			client_id = client.id
			break
		end
		vim.wait(50)
		maxretries = maxretries - 1
	end

	-- Position cursor at the right spot
	vim.api.nvim_win_set_cursor(window, cursor_pos)

	-- Execute goto definition in the new window
	vim.api.nvim_win_call(window, function()
		picker_gotodef_fun()
	end)

	-- Delete the temp file on disk
	vim.fn.delete(tempfile)
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
				language = "text",
			}
		end,
		goto_definition = function(choice, picker_gotodef_fun)
			return goto_definition(choice, picker_gotodef_fun)
		end,
		health = health,
	}
end

return M
