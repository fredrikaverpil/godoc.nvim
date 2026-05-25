-- Auto-register :GoDoc with the built-in go adapter and default config so the
-- plugin works out of the box without the user calling require("godoc").setup().
--
-- Skipped entirely if:
--   * the plugin has already been loaded (vim.g.loaded_godoc),
--   * setup() was called before this file was sourced (vim.g._godoc_user_configured), or
--   * a :GoDoc command is already registered (e.g., by another plugin).
--
-- Users who want a different command name must call setup() themselves with a
-- free command name — see README for details.

if vim.g.loaded_godoc then
  return
end
vim.g.loaded_godoc = true

if vim.g._godoc_user_configured then
  return
end

if vim.fn.exists(":GoDoc") > 0 then
  return
end

vim.api.nvim_create_user_command("GoDoc", function(args)
  require("godoc")._dispatch_command(args)
end, { nargs = "?", desc = "Fuzzy search Go packages/symbols and view docs" })

-- Record the name we registered so setup() can remove exactly this command
-- without having to spell the name itself.
vim.g._godoc_auto_registered = "GoDoc"
