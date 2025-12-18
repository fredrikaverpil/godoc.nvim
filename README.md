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

- Search and browse docs for Go standard library packages and project packages
- Go to definition capability
- Optionally leverage [`stdsym`](https://github.com/lotusirous/gostdsym) for
  symbols searching
- Optional syntax highlighting using tree-sitter with
  [tree-sitter-godoc](https://github.com/fredrikaverpil/tree-sitter-godoc) and
  [tree-sitter-go](https://github.com/tree-sitter/tree-sitter-go) parsers
- Supports pickers:
  - Native Neovim picker (no preview)
  - [Telescope](https://github.com/nvim-telescope/telescope.nvim) picker with
    preview
  - [Snacks](https://github.com/folke/snacks.nvim) picker with preview
  - [mini.pick](https://github.com/echasnovski/mini.pick) picker with preview
  - [fzf-lua](https://github.com/ibhagwan/fzf-lua) picker with preview
- Adapters can extend functionality to cover other languages (and anything else
  you might want to pick, really)

## Requirements

- Neovim >= 0.8.0
- Go installation with `go doc` and `go list` commands available

## Installation

> [!NOTE]
>
> Currently only the "go" adapter is built in (and loaded by default), but
> additional adapters could be implemented.

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "fredrikaverpil/godoc.nvim",
    version = "*",
    dependencies = {
        { "nvim-telescope/telescope.nvim" }, -- optional
        { "folke/snacks.nvim" }, -- optional
        { "echasnovski/mini.pick" }, -- optional
        { "ibhagwan/fzf-lua" }, -- optional
    },
    build = "go install github.com/lotusirous/gostdsym/stdsym@latest", -- optional
    cmd = { "GoDoc" }, -- optional
    ft = "godoc", -- optional
    opts = {}, -- see further down below for configuration
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
" Dependencies
Plug 'nvim-telescope/telescope.nvim'   " optional
Plug 'folke/snacks.nvim'               " optional
Plug 'echasnovski/mini.pick'           " optional
Plug 'ibhagwan/fzf-lua'                " optional

" Configure the plugin and load it.
" See the configuration further down below and apply
" any options to the lua opts table.
Plug 'fredrikaverpil/godoc.nvim'

lua <<EOF
local opts = {}
require('godoc').setup(opts)
EOF
```

### Syntax highlighting via tree-sitter parsers

By default, godoc.nvim does not apply any syntax highlighting to `go doc`
documentation. But by leveraging the
[tree-sitter-godoc](https://github.com/fredrikaverpil/tree-sitter-godoc) and
[tree-sitter-go](https://github.com/tree-sitter/tree-sitter-go) parsers, you can
enable syntax highlighting.

The way it works is by having tree-sitter-godoc provide some basic highlighting,
but more importantly, identify where actual Go code is. Then, tree-sitter-go can
step in and provide proper Go code syntax highlighting via injection queries.

**Add tree-sitter as a dependency** and make it aware of the tree-sitter-godoc
parser:

```lua
{
    "fredrikaverpil/godoc.nvim",
    version = "*",
    dependencies = {
        {
            "nvim-treesitter/nvim-treesitter",
            branch = "main",
            build = ":TSUpdate godoc go", -- install/update parsers
            config = function()
                require("nvim-treesitter.parsers").godoc = {
                    install_info = {
                        url = "https://github.com/fredrikaverpil/tree-sitter-godoc",
                        files = { "src/parser.c" },
                        version = "*",
                    },
                    filetype = "godoc",
                }

                -- Map godoc filetype to use godoc parser
                vim.treesitter.language.register('godoc', 'godoc')

                -- Enable :TSInstall godoc, :TSUpdate godoc
                vim.api.nvim_create_autocmd("User", {
                  pattern = "TSUpdate",
                  callback = function()
                    require("nvim-treesitter.parsers").godoc = parser_config
                  end,
                })

                -- Enable godoc filetype for .godoc files (optional)
                vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
                  pattern = "*.godoc",
                  callback = function()
                    vim.bo.filetype = "godoc"
                  end,
                })
            end,
        },
    },
    cmd = { "GoDoc" },
    ft = "godoc",
    opts = {
        adapters = {
            {
                name = "go",
                opts = {
                    get_syntax_info = function()
                        return {
                            filetype = "godoc",
                            language = "godoc",  -- Enable tree-sitter godoc parser
                        }
                    end,
                },
            },
        },
    },
}
```

**Install the parsers**:

```vim
:TSInstall go godoc
```

## Usage

When using the `go` adapter (specified above), the following command is
provided:

- `:GoDoc` - Open picker and search packages.
- `:GoDoc <package>` - Directly open documentation for the specified package or
  symbol.
- In Normal mode, press `gd` to go package definition (only supported by Snacks
  and Telescope pickers). For fzf-lua, the keymap is `ctrl-s`.

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
                command = "GoDoc", -- the vim command to invoke Go documentation
                get_syntax_info = function()
                    return {
                        filetype = "godoc", -- filetype for the buffer
                        language = "", -- tree-sitter parser, for syntax highlighting
                    }
                end,
            },
        },
    },
    window = {
        type = "split", -- split | vsplit
    },
    picker = {
        type = "native", -- native (vim.ui.select) | telescope | snacks | mini | fzf_lua

        -- see respective picker in lua/godoc/pickers for available options
        native = {},
        telescope = {},
        snacks = {},
        mini = {},
        fzf_lua = {},
    },
}
```

For further details, see the actual implementation.

Adapters:

- [lua/godoc/adapters/go.lua](lua/godoc/adapters/go.lua)

Pickers

- [lua/godoc/pickers/native.lua](lua/godoc/pickers/native.lua)
- [lua/godoc/pickers/telescope.lua](lua/godoc/pickers/telescope.lua)
- [lua/godoc/pickers/snacks.lua](lua/godoc/pickers/snacks.lua)
- [lua/godoc/pickers/mini.lua](lua/godoc/pickers/mini.lua)
- [lua/godoc/pickers/fzf_lua.lua](lua/godoc/pickers/fzf_lua.lua)

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
                        filetype = "mydoc", -- filetype for buffer that is opened
                        language = "mylang" -- tree-sitter parser
                    }
                end
            },

            -- user-provided (another example)
            {
                command = "DadJokes",
                get_items = function()
                    return { "coffee", "pasta" }
                end,
                get_content = function(choice)
                    local db = {
                        coffee = {
                            "What did the coffee report to the police?",
                            "A mugging!"
                        },
                        pasta = {
                            "What do you call a fake noodle?",
                            "An impasta!"
                        },
                    }
                    return db[choice]
                end,
                get_syntax_info = function()
                    return {
                        filetype = "text",
                        language = "text",
                    }
                end,
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
> The `pydoc.nvim` and `mylang` above are just fictional examples to illustrate
> functionality.

### Adapter interface

All adapters must implement the interface of `GoDocAdapter`:

```lua
--- @class GoDocAdapter
--- @field command string The vim command name to register
--- @field get_items fun(): string[] Function that returns a list of available items
--- @field get_content fun(choice: string): string[] Function that returns the content
--- @field get_syntax_info fun(): GoDocSyntaxInfo Function that returns syntax info
--- @field goto_definition? fun(choice: string, picker_gotodef_fun: fun()?): nil Function that returns the definition location
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
--- @field goto_definition? fun(choice: string, picker_gotodef_fun: fun()?): nil Override the get_definition function
--- @field health? fun(): GoDocHealthCheck[] Override the health check function
--- @field [string] any Other adapter-specific options
```

- See the example implementation for the built-in Go adapter at
  [lua/adapters/go.lua](lua/adapters/go.lua).
- If implementing a third-party adapter, make sure it has an exposed `setup`
  function which returns a `GoDocAdapter`.

The `GoDocAdapter` type is defined in
[lua/godoc/types.lua](lua/godoc/types.lua).

Feel free to open a pull request if you want to add a new built-in adapter or
improve on existing ones!

## Contributing

Contributions are very much welcome! ❤️ Please feel free to submit a pull
request.
