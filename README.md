# godoc.nvim

A Neovim plugin that provides quick access to Go documentation using Go's native
`go doc` command.

## Features

- Browse and search Go standard library packages and project packages.
- Native syntax highlighting for Go documentation.
- Optionally leverage [`stdsym`](https://github.com/lotusirous/gostdsym) for
  symbols searching.
- Supports native Neovim picker and optionally the
  [snacks.nvim](https://github.com/folke/snacks.nvim) picker.

## Requirements

- Neovim >= 0.8.0
- Go installation with `go doc` command available

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "fredrikaverpil/godoc.nvim",
    version = "*",
    dependencies = {
        "folke/snacks.nvim", -- optional, for Snacks picker
    },
    cmd = { "GoDoc" }
    opts = {},
}
```

### Optionally install `stdsym`

Install [`stdsym`](https://github.com/lotusirous/gostdsym) for ability to search
standard library symbols.

```bash
go install github.com/lotusirous/godocsym/stdsym@latest
```

## Usage

The plugin provides the following command:

- `:GoDoc` - Open picker and search packages.
- `:GoDoc <package>` - Directly open documentation for the specified package or
  symbol.

### Examples

```vim
:GoDoc             " browse all standard library packages
:GoDoc strings     " view documentation for the strings package
:GoDoc strings.Builder  " view documentation for strings.Builder
```

```lua
local godoc require("godoc.nvim")
godoc.show_native_picker()  -- search packages using the native Neovim picker
godoc.show_snacks_picker()  -- search packages using the Snacks.nvim picker
godoc.show_documentation("strings.Builder")  -- view docs for strings.Builder
```

## Configuration

The plugin can be configured by passing options to the setup function. These are
the defaults:

```lua
opts = {
    window = {
        type = "split", -- split or vsplit
    },
    highlighting = {
        language = "go", -- the language used for syntax highlighting
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
```

## Health Check

The plugin includes a health check to verify your Go installation and
documentation system:

```vim
:checkhealth godoc
```

## Contributing

Contributions are welcome! Please feel free to submit a pull request.

## License

MIT - See [LICENSE](LICENSE) for more information.
