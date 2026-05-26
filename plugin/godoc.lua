-- Auto-register :GoDoc with the built-in go adapter and default config so the
-- plugin works out of the box without require("godoc").setup().

if vim.g.loaded_godoc then
  return
end
vim.g.loaded_godoc = true

if vim.g.godoc_user_configured then
  return
end

-- If another plugin owns :GoDoc, leave it alone. Users can call setup() with a
-- different adapter command, for example { name = "go", opts = { command = "GoDocs" } }.
if vim.api.nvim_get_commands({}).GoDoc ~= nil then
  return
end

vim.api.nvim_create_user_command("GoDoc", function(args)
  require("godoc")._dispatch_command(args)
end, { nargs = "?", desc = "Fuzzy search Go packages/symbols and view docs" })

-- Record the name so setup() can replace the zero-config command if needed.
vim.g.godoc_auto_command = "GoDoc"
