--- @class GoDocConfig
--- @field adapters GoDocAdapterConfig[] List of adapter configurations
--- @field window GoDocWindowConfig Window configuration
--- @field picker GoDocPickerConfig Picker configuration

--- @class GoDocAdapter
--- @field command string The vim command name to register
--- @field get_items fun(): string[] Function that returns a list of available items
--- @field get_content fun(choice: string): string[] Function that returns the content
--- @field get_syntax_info fun(): GoDocSyntaxInfo Function that returns syntax info
--- @field health? fun(): GoDocHealthCheck[] Optional health check function

--- @class GoDocAdapterOpts
--- @field command? string Override the command name
--- @field get_items? fun(): string[] Override the get_items function
--- @field get_content? fun(choice: string): string[] Override the get_content function
--- @field get_syntax_info? fun(): GoDocSyntaxInfo Override the get_syntax_info function
--- @field health? fun(): GoDocHealthCheck[] Override the health check function
--- @field [string] any Other adapter-specific options

--- @class GoDocBuiltinAdapter
--- @field name string The name of the built-in adapter to extend
--- @field opts? GoDocAdapterOpts Configuration options for the built-in adapter

--- @class GoDocUserAdapter: GoDocAdapter
--- @field name? nil Must not have a name field

--- @class GoDocThirdPartyAdapter
--- @field setup fun(): GoDocAdapter Function that returns the base adapter
--- @field opts? GoDocAdapterOpts Options to override the returned adapter

--- @alias GoDocAdapterConfig GoDocBuiltinAdapter|GoDocUserAdapter|GoDocThirdPartyAdapter

--- @class GoDocHealthCheck
--- @field ok boolean Whether the check passed
--- @field message string Message describing the check result
--- @field optional? boolean Whether this check is optional (default: false)

--- @class GoDocSyntaxInfo
--- @field filetype string The filetype to set for the documentation buffer
--- @field language string The treesitter language to use for syntax highlighting

--- @class GoDocWindowConfig
--- @field type "split"|"vsplit" The type of window to open

--- @class GoDocPicker
--- @field show fun(adapter: GoDocAdapter, user_config: GoDocConfig, callback: fun(choice: string|nil)) Shows the picker UI with items from adapter

--- @class GoDocPickerConfig
--- @field type "native"|"telescope"|"snacks"|"mini"|"fzf_lua" The type of picker to use
--- @field native? table Options for native picker
--- @field telescope? table Options for telescope picker
--- @field snacks? table Options for snacks picker
--- @field mini? table Options for mini.pick picker
--- @field fzf_lua? table Options for fzf-lua picker

return {}
