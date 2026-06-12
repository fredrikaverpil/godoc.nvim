-- Register :GoDoc at startup so the plugin works out of the box, without
-- requiring a setup() call. See :h lua-plugin for the rationale.

if vim.g.loaded_godoc then
  return
end
vim.g.loaded_godoc = true

-- The user already called setup() — their config owns command registration.
if vim.g.godoc_did_setup then
  return
end

-- Another plugin or the user's config owns :GoDoc — don't clobber it.
if vim.api.nvim_get_commands({}).GoDoc ~= nil then
  return
end

vim.api.nvim_create_user_command("GoDoc", function(args)
  require("godoc")._dispatch_command("GoDoc", args)
end, {
  nargs = "?",
  desc = "Fuzzy search Go packages/symbols and view docs",
})

-- Let setup() know it can reclaim this command when applying user config.
vim.g.godoc_auto_registered = true
