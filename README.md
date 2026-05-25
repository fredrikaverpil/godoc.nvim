![godoc](https://github.com/user-attachments/assets/10e8403a-0384-4599-bc9f-9a0ffb919994)

# godoc.nvim

Fuzzy search Go docs from within Neovim.

> [!TIP]
>
> - **Works out of the box**: install the plugin and `:GoDoc` just works — no
>   `setup()` call required. Loading is fully deferred until first invocation.
> - **Extensible via adapters**: bring your own language/data source (Python,
>   Rust, dad jokes — whatever you want to pick).

## Screenshots

![Snacks picker](https://github.com/user-attachments/assets/4c364390-2d4f-4508-9c2a-a589c99e1078)
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
- Go to definition from picker
- Optionally leverage [`stdsym`](https://github.com/lotusirous/gostdsym) for
  symbol search
- Optional syntax highlighting via tree-sitter
- Supports pickers:
  - Native Neovim picker (no preview)
  - [Telescope](https://github.com/nvim-telescope/telescope.nvim) (with preview)
  - [Snacks](https://github.com/folke/snacks.nvim) (with preview)
  - [mini.pick](https://github.com/echasnovski/mini.pick) (with preview)
  - [fzf-lua](https://github.com/ibhagwan/fzf-lua) (with preview)
- Extend to other languages and data sources via adapters

## Requirements

- Neovim >= 0.8.0 (>= 0.12 if installing via `vim.pack`)
- Go installation with `go doc` and `go list` commands available

## Installation

Pick whichever plugin manager you use. The built-in `go` adapter is loaded by
default, so `:GoDoc` works immediately without any `setup()` call — see
[Configuration](#configuration) if you want to customize.

### Using [vim.pack](https://neovim.io/doc/user/pack.html) (built-in, Neovim 0.12+)

```lua
vim.pack.add({
  {
    src = "https://github.com/fredrikaverpil/godoc.nvim",
    -- Follow any tagged release. Omit `version` to track the default
    -- branch (every commit, not just releases).
    version = vim.version.range("*"),
  },

  -- Optional picker dependencies — pick whichever you prefer:
  { src = "https://github.com/nvim-telescope/telescope.nvim" },
  { src = "https://github.com/folke/snacks.nvim" },
  { src = "https://github.com/echasnovski/mini.pick" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
})
```

Optionally install [`stdsym`](https://github.com/lotusirous/gostdsym) (enables
symbol search) on plugin install/update:

```lua
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if
      ev.data.spec.name == "godoc.nvim"
      and (ev.data.kind == "install" or ev.data.kind == "update")
    then
      vim.system({
        "go",
        "install",
        "github.com/lotusirous/gostdsym/stdsym@latest",
      }):wait()
    end
  end,
})
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "fredrikaverpil/godoc.nvim",
  version = "*",
  dependencies = {
    { "nvim-telescope/telescope.nvim" }, -- optional
    { "folke/snacks.nvim" },             -- optional
    { "echasnovski/mini.pick" },         -- optional
    { "ibhagwan/fzf-lua" },              -- optional
  },
  build = "go install github.com/lotusirous/gostdsym/stdsym@latest", -- optional
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
" Optional picker dependencies
Plug 'nvim-telescope/telescope.nvim'
Plug 'folke/snacks.nvim'
Plug 'echasnovski/mini.pick'
Plug 'ibhagwan/fzf-lua'

Plug 'fredrikaverpil/godoc.nvim'
```

## Usage

The built-in `go` adapter provides:

- `:GoDoc` — open the picker and search packages.
- `:GoDoc <package>` — open documentation for a specific package or symbol.
- In the picker, press `gd` to go to the package definition (supported by Snacks
  and Telescope; for fzf-lua the keymap is `<C-s>`).

```vim
:GoDoc                  " browse all standard library packages
:GoDoc strings          " view documentation for the strings package
:GoDoc strings.Builder  " view documentation for strings.Builder
```

> [!WARNING]
>
> `:GoDoc` is also used by [ray-x/go.nvim](https://github.com/ray-x/go.nvim). To
> avoid the collision, either pass `remap_commands = { GoDoc = false }` to
> go.nvim or rename the godoc.nvim command (see
> [Configuration](#configuration)).

## Configuration

`:GoDoc` works with defaults out of the box. Call `setup()` only if you want to
customize behavior — any options you omit fall back to the defaults below.

```lua
require("godoc").setup({
  adapters = {
    {
      name = "go",
      opts = {
        command = "GoDoc", -- the vim command to invoke Go documentation
        get_syntax_info = function()
          return {
            filetype = "godoc", -- filetype of the documentation buffer
            language = "",      -- tree-sitter parser, for syntax highlighting
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

    -- per-picker options (see lua/godoc/pickers/<name>.lua for available fields)
    native = {},
    telescope = {},
    snacks = {},
    mini = {},
    fzf_lua = {},
  },
})
```

See the source for further details:

- Go adapter: [lua/godoc/adapters/go.lua](lua/godoc/adapters/go.lua)
- Pickers: [lua/godoc/pickers/](lua/godoc/pickers/)
- Types: [lua/godoc/types.lua](lua/godoc/types.lua)

## Syntax highlighting via tree-sitter

By default, `go doc` output is rendered without syntax highlighting. You can opt
in by installing the
[tree-sitter-godoc](https://github.com/fredrikaverpil/tree-sitter-godoc) and
[tree-sitter-go](https://github.com/tree-sitter/tree-sitter-go) parsers.
tree-sitter-godoc provides base highlighting and uses injection queries to hand
off Go code regions to tree-sitter-go.

### 1. Install nvim-treesitter

Install [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
using your plugin manager of choice (branch `main`).

### 2. Register the `godoc` parser

Run this once at startup (for example, in your `init.lua`):

```lua
local godoc_parser = {
  install_info = {
    url = "https://github.com/fredrikaverpil/tree-sitter-godoc",
    files = { "src/parser.c" },
    version = "*",
  },
  filetype = "godoc",
}

require("nvim-treesitter.parsers").godoc = godoc_parser

-- Map godoc filetype to the godoc parser
vim.treesitter.language.register("godoc", "godoc")

-- Re-register after :TSUpdate so the parser survives parser-list reloads
vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = function()
    require("nvim-treesitter.parsers").godoc = godoc_parser
  end,
})

-- Optional: also use the godoc filetype for `.godoc` files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.godoc",
  callback = function()
    vim.bo.filetype = "godoc"
  end,
})
```

### 3. Install the parsers

```vim
:TSInstall go godoc
```

### 4. Tell godoc.nvim to use the godoc parser

Override the go adapter's `get_syntax_info` in your `setup()` call:

```lua
require("godoc").setup({
  adapters = {
    {
      name = "go",
      opts = {
        get_syntax_info = function()
          return {
            filetype = "godoc",
            language = "godoc",
          }
        end,
      },
    },
  },
})
```

## Adapters

godoc.nvim is extensible via adapters. Three flavors are supported:

- **Built-in** — shipped in [lua/godoc/adapters/](lua/godoc/adapters/). Only
  `go` today.
- **User-defined** — written inline in your own config.
- **Third-party** — installed as a separate plugin that exposes a `setup()`
  function returning a `GoDocAdapter`.

You can override any adapter's options (including the command name) via `opts`.

```lua
require("godoc").setup({
  adapters = {
    -- Built-in, default options
    { name = "go" },

    -- Built-in with user override (rename command)
    { name = "go", opts = { command = "GoDocs" } },

    -- User-defined (no `name` field)
    {
      command = "MyDoc",
      get_items = function()
        return vim.fn.systemlist("mylang doc --list")
      end,
      get_content = function(choice)
        return vim.fn.systemlist("mylang doc " .. choice)
      end,
      get_syntax_info = function()
        return { filetype = "mydoc", language = "mylang" }
      end,
      goto_definition = function() end,
    },

    -- User-defined, purely for fun
    {
      command = "DadJokes",
      get_items = function()
        return { "coffee", "pasta" }
      end,
      get_content = function(choice)
        local db = {
          coffee = { "What did the coffee report to the police?", "A mugging!" },
          pasta  = { "What do you call a fake noodle?",            "An impasta!" },
        }
        return db[choice]
      end,
      get_syntax_info = function()
        return { filetype = "text", language = "text" }
      end,
      goto_definition = function() end,
    },

    -- Third-party
    {
      setup = function()
        return require("pydoc.nvim").setup({ --[[ third-party opts ]] })
      end,
    },

    -- Third-party with override
    {
      setup = function()
        return require("pydoc.nvim").setup({ --[[ third-party opts ]] })
      end,
      opts = { command = "PyDocs" },
    },
  },
})
```

> [!NOTE]
>
> `pydoc.nvim` and `mylang` above are fictional — illustrative only.

### Adapter interface

All adapters must implement the `GoDocAdapter` interface:

```lua
--- @class GoDocAdapter
--- @field command string The vim command name to register
--- @field get_items fun(): string[] Function that returns a list of available items
--- @field get_content fun(choice: string): string[] Function that returns the content
--- @field get_syntax_info fun(): GoDocSyntaxInfo Function that returns syntax info
--- @field goto_definition? fun(choice: string, picker_gotodef_fun: fun()?): nil Function that returns the definition location
--- @field health? fun(): GoDocHealthCheck[] Optional health check function
```

User overrides use `GoDocAdapterOpts`:

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

See [lua/godoc/adapters/go.lua](lua/godoc/adapters/go.lua) for a reference
implementation, and [lua/godoc/types.lua](lua/godoc/types.lua) for the full type
definitions.

Pull requests for new built-in adapters or improvements to existing ones are
welcome!

## Health Check

```vim
:checkhealth godoc
```

Runs the health checks associated with every enabled adapter that provides one.

## Contributing

Contributions are very much welcome! ❤️ Please feel free to submit a pull
request.

This project uses [Pocket](https://github.com/fredrikaverpil/pocket) for
formatting and linting tasks. Run `./pok` to execute all tasks, or `./pok -h` to
see available tasks.
