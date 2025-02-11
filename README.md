# Chev's .dotfiles

This is my personal development environment. You are welcome to use it or borrow
from it. I'm doing my best to keep all of it as portable as possible, but I make
no guarantees. If you find any issues please feel free to submit a PR or open a
Github issue.

## Try it out with Docker

My full development environment is about 2.22gb in size. The image contains almost
everything I'd ever need for nearly any app I'm working on. Most folks wanting to
try it out are likely just looking for my Neovim setup. So, I have created a
slimmed down Alpine image that is 300.52mb in size. It contains only what is needed
to run my full Neovim setup and nothing extra.

### My full development environment image (2.22gb)

#### `docker run -it chevcast/devenv`

### Alpine Neovim image (300.52mb)

#### `docker run -it chevcast/nvim`

> You can even edit your own files with my Neovim setup by mounting a volume to the
> container and specifying the path for Neovim to open.
>
> `docker run -itv /path/to/your/files:/yourfiles chevcast/nvim /yourfiles`

## Installation

1. Clone the repository into a place of your choosing.

   ```sh
   git clone git@github.com:chevcast/.dotfiles.git
   ```

2. Run the install script.

   > Note that the install script does NOT automatically back up any existing
   > configuration files. Run at your own risk. If you want to try out the setup
   > before installing then see above for how to run the setup in a Docker container.

   ```sh
   cd .dotfiles && install.sh
   ```

3. ???

4. Profit!

## What's Included

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)
- [Bun](https://bun.sh)
- [Dotnet SDK](https://dotnet.microsoft.com/en-us/download)
- [CMake](https://cmake.org/)
- [fd](https://github.com/sharkdp/fd)
- [Git](https://git-scm.com/)
- [Github CLI](https://cli.github.com/)
- [Golang](https://go.dev/doc/install)
- [Homebrew](https://docs.brew.sh/Homebrew-on-Linux)
- [Lazygit](https://github.com/jesseduffield/lazygit#readme)
- [Lua](https://www.lua.org/download.html)
- [Markdown Preview](https://github.com/iamcco/markdown-preview.nvim#readme)
- [Neovim](https://neovim.io/)
- [Oh My ZSH](https://ohmyz.sh/)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k#readme)
- [Python](https://www.python.org/downloads/)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [Volta](https://volta.sh/)
- [Wezterm](https://wezfurlong.org/wezterm/)
- [ZSH](https://www.zsh.org/)
- [Zsh Vi Mode](https://github.com/jeffreytse/zsh-vi-mode#readme)

### Neovim Plugin Manager

- [folke/lazy.nvim](https://github.com/folke/lazy.nvim)
- [LazyVim/starter](https://github.com/LazyVim/starter)

### Neovim Plugins (45)

- [blink.cmp](https://github.com/saghen/blink.cmp.git)
- [bufferline.nvim](https://github.com/akinsho/bufferline.nvim.git)
- [catppuccin](https://github.com/catppuccin/nvim.git)
- [conform.nvim](https://github.com/stevearc/conform.nvim.git)
- [firenvim](https://github.com/glacambre/firenvim.git)
- [flash.nvim](https://github.com/folke/flash.nvim.git)
- [friendly-snippets](https://github.com/rafamadriz/friendly-snippets.git)
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim.git)
- [grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim.git)
- [gruvbox.nvim](https://github.com/ellisonleao/gruvbox.nvim.git)
- [lazydev.nvim](https://github.com/folke/lazydev.nvim.git)
- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim.git)
- [mason-lspconfig.nvim](https://github.com/williamboman/mason-lspconfig.nvim.git)
- [mason.nvim](https://github.com/williamboman/mason.nvim.git)
- [matrix-nvim](https://github.com/iruzo/matrix-nvim.git)
- [mini.ai](https://github.com/echasnovski/mini.ai.git)
- [mini.icons](https://github.com/echasnovski/mini.icons.git)
- [noice.nvim](https://github.com/folke/noice.nvim.git)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim.git)
- [nvim-autopairs](https://github.com/windwp/nvim-autopairs.git)
- [nvim-hlslens](https://github.com/kevinhwang91/nvim-hlslens.git)
- [nvim-lint](https://github.com/mfussenegger/nvim-lint.git)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig.git)
- [nvim-scrollbar](https://github.com/petertriho/nvim-scrollbar.git)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter.git)
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects.git)
- [nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag.git)
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons.git)
- [oil.nvim](https://github.com/stevearc/oil.nvim.git)
- [persistence.nvim](https://github.com/folke/persistence.nvim.git)
- [playtime.nvim](https://github.com/rktjmp/playtime.nvim.git)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim.git)
- [rainbow_csv](https://github.com/mechatroner/rainbow_csv.git)
- [screenkey.nvim](https://github.com/NStefan002/screenkey.nvim.git)
- [snacks.nvim](https://github.com/folke/snacks.nvim.git)
- [tiny-devicons-auto-colors.nvim](https://github.com/rachartier/tiny-devicons-auto-colors.nvim.git)
- [todo-comments.nvim](https://github.com/folke/todo-comments.nvim.git)
- [tokyonight.nvim](https://github.com/folke/tokyonight.nvim.git)
- [treesj](https://github.com/Wansmer/treesj.git)
- [trouble.nvim](https://github.com/folke/trouble.nvim.git)
- [ts-comments.nvim](https://github.com/folke/ts-comments.nvim.git)
- [unicode.vim](https://github.com/chrisbra/unicode.vim.git)
- [vim-visual-multi](https://github.com/mg979/vim-visual-multi.git)
- [which-key.nvim](https://github.com/folke/which-key.nvim.git)
- [window-picker](https://github.com/s1n7ax/nvim-window-picker.git)
