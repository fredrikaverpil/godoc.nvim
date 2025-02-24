![godoc](https://github.com/user-attachments/assets/10e8403a-0384-4599-bc9f-9a0ffb919994)

# godoc.nvim

Fuzzy search Go docs from within Neovim.

> [!TIP]
>
> New: define adapters to extend this functionality to other languages/things!

## Screenshots

![Snacks picker](https://github.com/user-attachments/assets/928593b8-29d1-422a-a799-9d8617c086ba)
_Screenshot is showing the Snacks picker._

<details>
<summary>Telescope picker</summary>

![Telescope picker](https://github.com/user-attachments/assets/5a5ae525-4b5a-4ea1-9363-4a80e02b75b8)

</details>

<details>
<summary>Native picker</summary>

![Native picker](https://github.com/user-attachments/assets/7b875776-a098-43a2-a49e-9cfb31cb6eed)

</details>

## Features

- Browse and search Go standard library packages and project packages.
- Syntax highlighting for Go documentation.
- Optionally leverage [`stdsym`](https://github.com/lotusirous/gostdsym) for
  symbols searching.
- Supports pickers:
  - Native Neovim picker (no preview)
  - [Telescope](https://github.com/nvim-telescope/telescope.nvim) picker with
    preview
  - [Snacks](https://github.com/folke/snacks.nvim) picker with preview
  - [mini.pick](https://github.com/echasnovski/mini.pick) picker with preview
- Adapters can extend functionality to cover other languages (and anything else
  you might want to pick, really).

## Requirements

- Neovim >= 0.8.0
- Go installation with `go doc` and `go list` commands available
- Tree-sitter (for syntax highlighting)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "fredrikaverpil/godoc.nvim",
    version = "*",
    dependencies = {
        { "nvim-telescope/telescope.nvim" }, -- optional
        { "folke/snacks.nvim" }, -- optional
        { "echasnovski/mini.pick" }, -- optional
        {
            "nvim-treesitter/nvim-treesitter",
            opts = {
              ensure_installed = { "go" },
            },
        },
    },
    build = "go install github.com/lotusirous/gostdsym/stdsym@latest", -- optional
    cmd = { "GoDoc" }, -- optional
    opts = {},
}
```

> [!NOTE]
>
> The above configuration is an example configuration for Go. There are other
> adapters and configurations for other languages too (please continue reading
> for more details).

## Usage

When using the `go` adapter (specified above), the following command is
provided:

- `:GoDoc` - Open picker and search packages.
- `:GoDoc <package>` - Directly open documentation for the specified package or
  symbol.

For details, see the actual implementation in
[lua/godoc/adapters/go.lua](lua/godoc/adapters/go.lua).

> [!WARNING]
>
> The `:GoDoc` command is also used by
> [x-ray/go.nvim](https://github.com/ray-x/go.nvim). You can disable this by
> passing `remap_commands = { GoDoc = false }` to x-ray/go.nvim or you can
> customize the godoc.nvim command.

### Examples

```vim
:GoDoc                  " browse all standard library packages
:GoDoc strings          " view documentation for the strings package
:GoDoc strings.Builder  " view documentation for strings.Builder
```

## Default configuration (`opts`)

```lua
local godoc = require("godoc")

---@type godoc.types.GoDocConfig
{
    adapters = {
        -- for details, see lua/godoc/adapters/go.lua
        {
            name = "go",
            opts = {
                command = "GoDoc",
            },
        },
    },
    window = {
        type = "split", -- split | vsplit
    },
    picker = {
        type = "native", -- native (vim.ui.select) | telescope | snacks | mini

        -- see respective picker in lua/godoc/pickers for available options
        native = {},
        telescope = {},
        snacks = {},
        mini = {},
    },
}
```

Currently only the "go" adapter is built in, but additional adapters could be
implemented.

## Health Check

The plugin includes a health check. It will run the checks associated with the
adapters you have enabled (and which have specified a health check).

```vim
:checkhealth godoc
```

## Adapters

It's possible to extend the functionality of godoc.nvim with adapters. There are
different kinds of adapters:

- Built-in, added to this very project, into the
  [lua/godoc/adapters](lua/godoc/adapters) directory.
- User-defined, defined inline in the user's own config.
- Third-party, defined in a different git repo and pulled in as separate
  dependency.

For all these kinds of adapters, it's possible to perform user-provided
overrides.

```lua
{
    "fredrikaverpil/godoc.nvim",
    version = "*",
    dependencies = {
        {
            "nvim-treesitter/nvim-treesitter",
            opts = {
              ensure_installed = { "go", "mylang", "python" },
            },
        },
        { "someuser/pydoc.nvim" }, -- third-party
    },
    opts = {
        adapters = {
            -- built-in
            { name = "go" },

            -- built-in, but with user-override
            { name = "go", opts = { command = "MyCustomCommand" }, },

            -- user-provided (note the omission of a 'name' field)
            {
                command = "MyDoc",
                get_items = function()
                    return vim.fn.systemlist("mylang doc --list")
                end,
                get_content = function(choice)
                    return vim.fn.systemlist("mylang doc " .. choice)
                end,
                get_syntax_info = function()
                    return {
                        filetype = "mydoc",
                        language = "mylang"
                    }
                end
            },

            -- third-party
            {
                setup = function()
                    opts = {...} -- third-party opts
                    return require("pydoc.nvim").setup(opts)
                end,
            },

            -- third-party with user-override
            {
                setup = function()
                    opts = {...} -- third-party opts
                    return require("pydoc.nvim").setup(opts)
                end,
                opts = {
                    command = "CustomPyDocCommand",
                },
            },
        }
    },
}
```

> [!NOTE]
>
> The `pydoc.nvim` and `mylang` above are just a fictional example to illustrate
> functionality.

### Adapter interface

All adapters must implement the interface of `GoDocAdapter`:

```lua
--- @class GoDocAdapter
--- @field command string The vim command name to register
--- @field get_items fun(): string[] Function that returns a list of available items
--- @field get_content fun(choice: string): string[] Function that returns the content
--- @field get_syntax_info fun(): GoDocSyntaxInfo Function that returns syntax info
--- @field health? fun(): GoDocHealthCheck[] Optional health check function
```

The `opts` which can be passed into an adapter (by the user) is implemented by
`GoDocAdapterOpts`:

```lua
--- @class GoDocAdapterOpts
--- @field command? string Override the command name
--- @field get_items? fun(): string[] Override the get_items function
--- @field get_content? fun(choice: string): string[] Override the get_content function
--- @field get_syntax_info? fun(): GoDocSyntaxInfo Override the get_syntax_info function
--- @field health? fun(): GoDocHealthCheck[] Override the health check function
--- @field [string] any Other adapter-specific options
```

- See the example implementation for the built-in Go adapter at
  [lua/adapters/go.lua](lua/adapters/go.lua).
- If implementing a third-party adapter, make sure it has an exposed `setup`
  function which returns an `GoDocAdapter`.

The `GoDocAdapter` type is defined in
[lua/godoc/types.lua](lua/godoc/types.lua).

Feel free to open a pull request if you want to add a new built-in adapter or
improve on existing ones!

## Contributing

Contributions are very much welcome! ❤️ Please feel free to submit a pull
request.

I would be extra interested in discussions and contributions around improving
the syntax highlighting of `go doc` output, as it the output becomes quite
"busy" and incoherent now, when applying the syntax highlighting of Go syntax.
