local M = {}

-- Default configuration.
M.config = {
	command = "GoDoc",
	window = {
		type = "split", -- split or vsplit
	},
	highlighting = {
		language = "go",
	},
	picker = {
		type = "native", -- native or snacks
		snacks_options = {
			layout = {
				layout = {
					height = 0.8,
					width = 0.9, -- Take up 90% of the total width (adjust as needed)
					box = "horizontal", -- Horizontal layout (input and list on the left, preview on the right)
					{ -- Left side (input and list)
						box = "vertical",
						width = 0.3, -- List and input take up 30% of the width
						border = "rounded",
						{ win = "input", height = 1, border = "bottom" },
						{ win = "list", border = "none" },
					},
					{ win = "preview", border = "rounded", width = 0.7 }, -- Preview window takes up 70% of the width
				},
			},
			win = {
				preview = {
					wo = { wrap = true },
				},
			},
		},
	},
}

-- Set up syntax highlighting
vim.treesitter.language.register(M.config.highlighting.language, { "godoc" })

-- Check if go is available
local function check_requirements()
	if vim.fn.executable("go") == 0 then
		return false, "'go' binary not found in PATH"
	end

	-- Test go doc functionality
	local test = vim.fn.system("go doc fmt")
	if vim.v.shell_error ~= 0 then
		return false, "'go doc' command failed. Please run :checkhealth godoc for more information"
	end

	return true, nil
end

-- Set up the plugin with user config
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create user command
	vim.api.nvim_create_user_command(M.config.command, function(args)
		-- Check requirements
		local ok, err = check_requirements()
		if not ok then
			vim.notify(string.format("godoc.nvim: %s", err), vim.log.levels.ERROR)
			return
		end

		-- if args were passed, show documentation directly
		if args.args ~= nil and args.args ~= "" then
			M.show_documentation(args.args)
			return
		end

		if M.config.picker.type == "native" then
			M.show_native_picker()
		elseif M.config.picker.type == "telescope" then
			M.show_telescope_picker()
		elseif M.config.picker.type == "snacks" then
			M.show_snacks_picker()
		else
			vim.notify("Picker not implemented: " .. M.config.picker.type, vim.log.levels.ERROR)
		end
	end, { nargs = "?" })
end

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

-- Cache for package list
local package_cache = nil
local package_cache_time = 0
local package_cache_cwd = vim.fn.getcwd()
local CACHE_DURATION = 300 -- 5 minutes

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

-- Show Neovim-native picker
function M.show_native_picker()
	-- Show native picker with packages
	vim.ui.select(get_packages(), {
		prompt = "Select Go Package:",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			M.show_documentation(choice)
		end
	end)
end

-- Show telescope picker
function M.show_telescope_picker()
	local action_state = require("telescope.actions.state")
	local finders = require("telescope.finders")
	local pickers = require("telescope.pickers")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values

	local function go_packages_finder(opts, ctx)
		local output = get_packages()
		local items = {}
		for _, package_name in ipairs(output) do
			table.insert(items, {
				value = package_name,
				display = package_name,
				ordinal = package_name,
			})
		end
		return items
	end

	-- Create custom previewer
	local package_previewer = previewers.new_buffer_previewer({
		title = "Package Documentation",
		get_buffer_by_name = function(_, entry)
			return entry.value
		end,
		define_preview = function(self, entry)
			local docs = M.get_documentation(entry.value)
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, docs)
			vim.api.nvim_set_option_value("filetype", "godoc", { buf = self.state.bufnr })
		end,
	})

	local function on_package_select(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if selection then
			M.show_documentation(selection.value)
		end
	end

	local opts = {
		finder = finders.new_table({
			results = go_packages_finder(),
			entry_maker = function(entry)
				return {
					display = entry.display,
					value = entry.value,
					ordinal = entry.ordinal,
				}
			end,
		}),
		sorter = conf.generic_sorter(),
		previewer = package_previewer,
		attach_mappings = function(_, map)
			map("i", "<CR>", function(prompt_bufnr)
				vim.cmd("stopinsert")
				on_package_select(prompt_bufnr)
			end)
			map("n", "<CR>", function(prompt_bufnr)
				on_package_select(prompt_bufnr)
			end)
			return true
		end,
	}

	if M.config and M.config.picker and M.config.picker.telescope_options then
		opts = vim.tbl_extend("force", opts, M.config.picker.telescope_options)
	end

	pickers.new(opts, {}):find()
end

-- Show Snacks picker
function M.show_snacks_picker()
	local snacks = require("snacks")

	local function go_packages_finder(opts, ctx)
		local output = get_packages()
		local items = {}
		for _, package_name in ipairs(output) do
			table.insert(items, {
				text = package_name, -- The package name as the main text in the picker
				package_name = package_name, -- Store the package name for the action
			})
		end
		return items
	end

	local function on_package_select(package_name)
		M.show_documentation(package_name)
	end

	local opts = {
		finder = go_packages_finder,
		format = "text",
		title = "Go Standard Packages",
		preview = function(ctx)
			if ctx.item then
				local package_name = ctx.item.package_name
				ctx.preview:set_lines(M.get_documentation(package_name))
				ctx.preview:highlight({ ft = "godoc" })
			else
				ctx.preview:reset()
			end
		end,
		actions = {
			confirm = function(picker, item)
				if item then
					snacks.picker.actions.close(picker) -- Close the picker
					on_package_select(item.package_name) -- Call your custom action
				end
			end,
		},
	}

	if M.config and M.config.picker and M.config.picker.snacks_options then
		opts = vim.tbl_extend("force", opts, M.config.picker.snacks_options)
	end

	snacks.picker.pick(opts)
end

-- Package docs cache
local package_docs = {}

-- Get the documentation
function M.get_documentation(package_name)
	if package_docs[package_name] == nil then
		local docs = vim.fn.systemlist("go doc --all " .. package_name)
		if vim.v.shell_error ~= 0 then
			return { "No documentation available for " .. package_name }
		end

		package_docs[package_name] = docs
	end

	return package_docs[package_name]
end

-- Show documentation in new buffer
function M.show_documentation(package_name)
	local doc = M.get_documentation(package_name)

	-- Create new buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, doc)

	-- Set buffer options
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "godoc", { buf = buf })

	-- Open window based on config
	if M.config.window.type == "split" then
		vim.cmd("split")
	elseif M.config.window.type == "vsplit" then
		vim.cmd("vsplit")
	else -- floating
		-- TODO: Implement floating window?
	end

	vim.api.nvim_set_current_buf(buf)
	-- vim.cmd("file " .. package_name .. ".godoc")

	-- Set up keymaps for the documentation window
	local opts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "q", ":close<CR>", opts)
	vim.keymap.set("n", "<Esc>", ":close<CR>", opts)
end

return M
