#!/usr/bin/env bash
set -euo pipefail

NEOVIM_SRC_DIR="${HOME}/.cache/neovim"

log() {
	printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
	printf '\nERROR: %s\n' "$*" >&2
	exit 1
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

confirm_sudo() {
	if ! command_exists sudo; then
		fail "sudo is required. Please install sudo and rerun."
	fi
	if ! sudo -n true >/dev/null 2>&1; then
		log "sudo access is required. You may be prompted for your password."
		sudo true
	fi
}

ensure_network() {
	local target="https://github.com"
	if ! curl -fsSL --connect-timeout 10 --max-time 20 "$target" >/dev/null; then
		fail "Network check failed for ${target}. Please ensure internet connectivity."
	fi
}

bootstrap_neovim() {
	if ! command_exists nvim; then
		log "Skipping Neovim bootstrap. 'nvim' not found in PATH."
		return
	fi

	log "Priming Neovim plugins (Lazy sync, MasonUpdate, TSUpdateSync)"
	if ! nvim --headless "+Lazy! sync" "+MasonUpdate" "+TSUpdateSync" +qa; then
		fail "Neovim plugin bootstrap failed."
	fi
}

platform=""
case "$(uname -s)" in
	Darwin)
		platform="macos"
		;;
	Linux)
		if [[ -f /etc/os-release ]]; then
			. /etc/os-release
			if [[ "${ID:-}" == "ubuntu" ]] || [[ "${ID_LIKE:-}" == *ubuntu* ]] || [[ "${ID_LIKE:-}" == *debian* ]]; then
				platform="ubuntu"
			fi
		fi
		;;
	esac

[[ -n "$platform" ]] || fail "Unsupported platform. Only macOS and Ubuntu are supported."

log "Running bootstrap on ${platform}."
confirm_sudo
ensure_network

log "Installing WezTerm terminfo"
tempfile="$(mktemp)"
trap 'rm -f "$tempfile"' EXIT
curl -fsSL -o "$tempfile" https://raw.githubusercontent.com/wez/wezterm/main/termwiz/data/wezterm.terminfo
/usr/bin/tic -x -o "$HOME/.terminfo" "$tempfile"
rm -f "$tempfile"
trap - EXIT

log "Linking dotfiles"
bash "${PWD}/create-symlinks.sh"

if [[ "$platform" == "macos" ]]; then
	if ! xcode-select -p >/dev/null 2>&1; then
		log "Installing Xcode Command Line Tools"
		xcode-select --install || true
		while ! xcode-select -p >/dev/null 2>&1; do
			log "Waiting for Xcode Command Line Tools installation..."
			sleep 20
		done
	fi
else
	log "Installing Ubuntu prerequisites"
	sudo apt-get update -y
	sudo apt-get install -y --no-install-recommends \
		build-essential \
		cmake \
		ca-certificates \
		curl \
		file \
		git \
		procps \
		sudo \
		tzdata \
		unzip
	sudo apt-get clean
fi

log "Bootstrapping Homebrew"
export HOMEBREW_NO_ENV_HINTS=1
if ! command_exists brew; then
	export NONINTERACTIVE=1
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if command_exists /opt/homebrew/bin/brew; then
	BREW_BIN=/opt/homebrew/bin/brew
elif command_exists /home/linuxbrew/.linuxbrew/bin/brew; then
	BREW_BIN=/home/linuxbrew/.linuxbrew/bin/brew
else
	BREW_BIN="$(command -v brew)"
fi

eval "$("${BREW_BIN}" shellenv)"

log "Ensuring brew taps"
brew tap jesseduffield/lazygit >/dev/null
brew tap oven-sh/bun >/dev/null
brew tap wez/wezterm-linuxbrew >/dev/null

log "Updating brew"
brew update
brew upgrade

brew_formulae=(
	azure-cli
	bat
	cmake
	dotnet
	eza
	fastfetch
	fd
	fzf
	gcc
	gh
	git-delta
	go
	helm
	gettext
	libtool
	lazygit
	lynx
	mise
	ninja
	automake
	pkg-config
	ripgrep
	rust-analyzer
	tlrc
	wezterm
	wordnet
	zoxide
	zsh
	powerlevel10k
	zsh-vi-mode
)

if [[ "$platform" == "ubuntu" ]]; then
	brew_formulae+=(llvm)
fi

log "Installing brew packages"
brew install "${brew_formulae[@]}"

log "Cloning fzf-git"
if [[ -d "$HOME/.fzf-git/.git" ]]; then
	git -C "$HOME/.fzf-git" pull --ff-only
elif [[ -d "$HOME/.fzf-git" ]]; then
	log "Existing ~/.fzf-git directory without git found. Skipping clone."
else
	git clone https://github.com/junegunn/fzf-git.sh.git "$HOME/.fzf-git"
fi

log "Configuring mise runtimes"
if ! command_exists mise; then
	fail "mise is not available after Homebrew installation"
fi

mise_globals=(
	node@latest
	bun@latest
	lua@latest
	python@latest
	rust@stable
)

for tool in "${mise_globals[@]}"; do
	log "Ensuring ${tool} via mise"
	mise use -g "$tool"
done

mise install

eval "$(mise activate bash)"

log "Running mise doctor"
if ! mise doctor; then
	fail "mise doctor reported issues. Please resolve them and rerun."
fi

if ! command_exists npm; then
	fail "npm is not available after mise activation"
fi

log "Installing global coding agents via npm"
npm install -g @openai/codex @just-every/code

log "Building Neovim from source into ${NEOVIM_SRC_DIR}"
if [[ -d "${NEOVIM_SRC_DIR}/.git" ]]; then
	git -C "${NEOVIM_SRC_DIR}" fetch --tags --prune
	git -C "${NEOVIM_SRC_DIR}" reset --hard origin/master
else
	rm -rf "${NEOVIM_SRC_DIR}"
	git clone https://github.com/neovim/neovim.git "${NEOVIM_SRC_DIR}"
fi

pushd "${NEOVIM_SRC_DIR}" >/dev/null
export CMAKE_GENERATOR=Ninja
export DEPS_CMAKE_GENERATOR=Ninja
export CMAKE_MAKE_PROGRAM="$(command -v ninja)"
rm -rf build .deps
cmake -S cmake.deps -B .deps -G Ninja
cmake --build .deps
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
sudo cmake --install build
popd >/dev/null

if [[ "$platform" == "ubuntu" ]]; then
	sudo ldconfig
fi

bootstrap_neovim

log "Setting default shell to zsh"
zsh_path="$(command -v zsh)"
if [[ -n "$zsh_path" ]]; then
	if ! grep -Fq "$zsh_path" /etc/shells; then
		sudo sh -c "echo ${zsh_path} >> /etc/shells"
	fi
	current_shell="$(getent passwd "$USER" | cut -d: -f7)"
	if [[ "$current_shell" != "$zsh_path" ]]; then
		sudo chsh -s "$zsh_path" "$USER"
	fi
fi

log "Bootstrap complete. Please restart your shell."
