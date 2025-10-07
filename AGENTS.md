# Repository Guidelines

## Project Structure & Module Organization

- Dotfiles root uses scripts `create-symlinks.sh`, `install-arch.sh`, `devenv.sh`, `nvim.sh` to bootstrap Linux, WSL, and containerized workflows.
- Editor configs live in `nvim/` (LazyVim-based Lua modules) and `wezterm/` (terminal profiles and color schemes). Auxiliary configs sit in `komorebi/`.
- Assets are under `images/`; helper binaries land in `bin/`. Root-level config files (`.zshrc`, `.wezterm.lua`, `.gitconfig`) mirror their home-directory targets.

## Build, Test, and Development Commands

- `./create-symlinks.sh` backs up existing dotfiles to `~/.backup_dotfiles/` and updates symlinks—run after any structural change.
- `./devenv.sh [path]` rebuilds the full `chevcast/devenv:latest` image and optionally mounts a workspace for interactive validation.
- `./nvim.sh [path]` rebuilds the slim `chevcast/nvim:latest` image for editor-only smoke tests.
- On fresh Arch Linux installs, run `./install-arch.sh` to provision packages, WezTerm terminfo, Volta, Rust, and Neovim nightly.

## Coding Style & Naming Conventions

- Shell scripts stay POSIX-friendly but use Bash features; match tab-indented blocks as seen in existing scripts.
- Lua files follow `stylua.toml` (tabs, width 3, 120-column wrap). Run `stylua .` inside `nvim/` before committing.
- TypeScript/Markdown snippets follow `prettier.config.js` (tabs, width 3, trailing commas disabled). Use `npx prettier --check .`.
- Rust snippets honor `rustfmt.toml` (hard tabs, grouped imports). Format with `rustfmt` when touching Rust files.

## Testing Guidelines

- For Neovim config updates, run `nvim --headless "+Lazy! sync" +qa` inside the `./nvim.sh` container to catch plugin errors.
- WezTerm changes should be loaded with `wezterm start --config-file $PWD/.wezterm.lua` to verify profiles.
- After modifying symlink lists, rerun `./create-symlinks.sh` and inspect `~/.backup_dotfiles/` for unintended moves.

## Commit & Pull Request Guidelines

- Keep commit summaries short and in present tense (e.g., `plugin updates`). Add Conventional Commit prefixes when clarifying scope (`fix: Update for Ubuntu WSL distro`).
- Group related changes; avoid mixing Neovim, terminal, and OS-specific tweaks in a single commit.
- Pull requests need a short description, validation notes (commands run), and screenshots when UI themes or prompt visuals change.
- Link GitHub issues when applicable and call out platform-specific impacts (Linux, macOS, WSL).

## Environment & Security

- Never commit personal secrets or machine-specific IDs; use placeholders and document required env vars in `README.md`.
- Prefer testing destructive commands (package installs, symlink cleanup) inside the Docker images before running on a host system.
