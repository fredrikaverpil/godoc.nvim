![godoc](https://github.com/user-attachments/assets/10e8403a-0384-4599-bc9f-9a0ffb919994)

# godoc.nvim

Fuzzy search Go std lib packages and project packages.

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
- Native syntax highlighting for Go documentation.
- Optionally leverage [`stdsym`](https://github.com/lotusirous/gostdsym) for
  symbols searching.
- Supports pickers:
  - Native Neovim picker (no preview)
  - [Telescope](https://github.com/nvim-telescope/telescope.nvim) picker with
    preview
  - [Snacks](https://github.com/folke/snacks.nvim) picker with preview

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
        {
            "nvim-treesitter/nvim-treesitter",
            opts = {
              ensure_installed = { "go" },
            },
        },
    },
    build = "go install github.com/lotusirous/gostdsym/stdsym@latest", -- optional
    cmd = { "GoDoc" }
    opts = {},
}
```

## Usage

The plugin provides the following command:

- `:GoDoc` - Open picker and search packages.
- `:GoDoc <package>` - Directly open documentation for the specified package or
  symbol.

> [!WARNING]
>
> The `:GoDoc` command is also used by
> [x-ray/go.nvim](https://github.com/ray-x/go.nvim). You can configure this
> plugin's command to something else if you wish.

### Examples

```vim
:GoDoc                  " browse all standard library packages
:GoDoc strings          " view documentation for the strings package
:GoDoc strings.Builder  " view documentation for strings.Builder
```

```lua
local godoc = require("godoc.nvim")
godoc.show_native_picker()  -- search packages using the native Neovim picker
godoc.show_snacks_picker()  -- search packages using the Snacks.nvim picker
godoc.show_documentation("strings.Builder")  -- view docs for strings.Builder
```

## Configuration

These are the defaults:

```lua
opts = {
    command = "GoDoc", -- the desired Vim command to use
    window = {
        type = "split", -- split or vsplit
    },
    highlighting = {
        language = "go", -- the tree-sitter parser used for syntax highlighting
    },
    picker = {
        type = "native", -- native, telescope or snacks
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
```

## Health Check

The plugin includes a health check to verify your Go installation and
documentation system:

```vim
:checkhealth godoc
```

## Contributing

Contributions are welcome! Please feel free to submit a pull request.

I would be extra interested in discussions and contributions around improving
the syntax highlighting of `go doc` output, as it is currently quite messy to
just apply the syntax highlighting of Go syntax.
