#!/usr/bin/env bash
set -euo pipefail

NEOVIM_SRC_DIR="${HOME}/.cache/neovim"
UPDATE_TIMESTAMP_FILE="${HOME}/.last_update_check"

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -h "$SCRIPT_SOURCE" ]]; do
	SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
	SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
	[[ "$SCRIPT_SOURCE" != /* ]] && SCRIPT_SOURCE="${SCRIPT_DIR}/${SCRIPT_SOURCE}"
done
REPO_ROOT="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

log() {
	printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$@"
}

fail() {
	printf '\nERROR: %s\n' "$@" >&2
	exit 1
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

require_command() {
	if ! command_exists "$1"; then
		fail "$2"
	fi
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
	if command_exists curl; then
		if ! curl -fsSL --connect-timeout 10 --max-time 20 "$target" >/dev/null; then
			fail "Network check failed for ${target}. Please ensure internet connectivity."
		fi
		return
	fi

	if command_exists wget; then
		if ! wget -q --timeout=20 --tries=1 "$target" -O /dev/null; then
			fail "Network check failed for ${target}. Please ensure internet connectivity."
		fi
		return
	fi

	fail "Neither curl nor wget is available for network checks. Please install curl and rerun."
}

launch_windows_symlink_terminal() {
	if [[ -z "${WSL_DISTRO_NAME:-}" ]]; then
		return
	fi

	if ! command_exists powershell.exe; then
		log "powershell.exe not found; skipping elevated Windows symlink helper."
		return
	fi

	local repo_quoted
	repo_quoted=$(printf '%q' "${REPO_ROOT}")

	local wsl_script
	wsl_script="$(mktemp)"
	cat >"${wsl_script}" <<EOF_WSL
#!/usr/bin/env bash
set -euo pipefail
trap 'rm -f "\$0"' EXIT
cd ${repo_quoted}
./create-symlinks.sh --windows-only
status=\$?
if [[ -e /dev/tty ]]; then
	printf '\nWindows symlink setup exited with code %s. Press Enter to close...' "\$status" >/dev/tty
	read -r _ </dev/tty
else
	printf 'Windows symlink setup exited with code %s\n' "\$status"
	sleep 5
fi
exit "\$status"
EOF_WSL
	chmod +x "${wsl_script}"

	local wsl_script_ps
	wsl_script_ps=$(printf '%s' "${wsl_script}" | sed "s/'/''/g")

	local ps_tmp
	ps_tmp="$(mktemp)"
	local ps_script="${ps_tmp}.ps1"

	cat >"${ps_script}" <<'EOF_PS'
$ErrorActionPreference = 'Stop'
$distribution = '__DISTRIBUTION__'
$wslScript = '__WSL_SCRIPT__'
$pwsh = Get-Command powershell.exe
if (-not $pwsh) {
	Write-Error 'powershell.exe not found.'
	exit 1
}
$wslCommand = "wsl.exe -d $distribution -- /bin/bash `"$wslScript`""
$pwshArgs = @(
	'-NoLogo',
	'-NoProfile',
	'-NoExit',
	'-Command',
	$wslCommand
)
Write-Host "Launching elevated Windows PowerShell with:`n  $wslCommand"
Start-Process -FilePath $pwsh.Source -ArgumentList $pwshArgs -Verb RunAs -WindowStyle Normal | Out-Null
EOF_PS

	DISTRIBUTION="${WSL_DISTRO_NAME}" \
	WSL_SCRIPT_PS="${wsl_script_ps}" \
	PS_SCRIPT="${ps_script}" \
	python - <<'PY_PS'
import os
from pathlib import Path
path = Path(os.environ['PS_SCRIPT'])
text = path.read_text()
text = text.replace('__DISTRIBUTION__', os.environ['DISTRIBUTION'])
text = text.replace('__WSL_SCRIPT__', os.environ['WSL_SCRIPT_PS'])
path.write_text(text)
PY_PS

	local ps_path
	ps_path=$(wslpath -w "${ps_script}")

	if powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${ps_path}"; then
		log "Elevated Windows PowerShell launched. Approve the UAC prompt to finish Windows symlink setup."
	else
		log "Unable to launch elevated Windows PowerShell automatically. Run manually:"
		log "  wsl.exe -d ${WSL_DISTRO_NAME} -- bash -lc 'cd ${REPO_ROOT} && ./create-symlinks.sh --windows-only'"
		rm -f "${wsl_script}"
	fi

	rm -f "${ps_script}"
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
if command_exists curl; then
	curl -fsSL -o "$tempfile" https://raw.githubusercontent.com/wez/wezterm/main/termwiz/data/wezterm.terminfo
elif command_exists wget; then
	wget -q -O "$tempfile" https://raw.githubusercontent.com/wez/wezterm/main/termwiz/data/wezterm.terminfo
else
	fail "Neither curl nor wget is available to download WezTerm terminfo."
fi
/usr/bin/tic -x -o "$HOME/.terminfo" "$tempfile"
rm -f "$tempfile"
trap - EXIT

if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
	log "Linking dotfiles (WSL Linux side)"
	(cd "$REPO_ROOT" && bash "./create-symlinks.sh" --posix-only)
	launch_windows_symlink_terminal
else
	log "Linking dotfiles"
	(cd "$REPO_ROOT" && bash "./create-symlinks.sh")
fi

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
	log "Refreshing apt repositories"
	sudo apt-get update -y
	log "Upgrading apt packages"
	sudo apt-get upgrade -y
	log "Installing Ubuntu prerequisites"
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
	sudo apt-get autoremove -y
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

if ! command_exists brew; then
	fail "Homebrew shellenv did not expose brew at ${BREW_BIN}. Please check the installation."
fi

log "Ensuring brew taps"
brew tap jesseduffield/lazygit >/dev/null
brew tap oven-sh/bun >/dev/null
brew tap wez/wezterm-linuxbrew >/dev/null

log "Updating brew"
brew update --verbose
brew upgrade --formula --verbose
brew upgrade --cask --verbose 2>/dev/null || true
brew cleanup -s --prune=all --verbose

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

log "Ensuring GitHub CLI configuration"
if command_exists gh; then
	if ! gh auth status >/dev/null 2>&1; then
		log "GitHub CLI is installed but not authenticated. Launching authentication flow..."
		if ! gh auth login --web -h github.com; then
			log "GitHub CLI authentication skipped or failed. Continuing without it."
		fi
	fi
	if ! gh copilot -v >/dev/null 2>&1; then
		log "Installing GitHub Copilot CLI extension"
		gh extension install github/gh-copilot --force || log "Failed to install GitHub Copilot CLI extension."
	fi
	log "Upgrading GitHub CLI extensions"
	gh extension upgrade --all || log "Failed to upgrade GitHub CLI extensions. Continuing."
else
	log "GitHub CLI not found; skipping GitHub-specific configuration."
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
mise upgrade

eval "$(mise activate bash)"

log "Running mise doctor"
if ! mise doctor; then
	fail "mise doctor reported issues. Please resolve them and rerun."
fi

if ! command_exists npm; then
	fail "npm is not available after mise activation"
fi

log "Installing global coding agents via npm"
needed_agents=()
if ! npm list -g @openai/codex >/dev/null 2>&1; then
	needed_agents+=("@openai/codex")
fi
if ! npm list -g @just-every/code >/dev/null 2>&1; then
	needed_agents+=("@just-every/code")
fi

if (( ${#needed_agents[@]} > 0 )); then
	npm install -g "${needed_agents[@]}"
else
	log "Global coding agents already installed; skipping npm install."
	npm update -g @openai/codex @just-every/code || log "npm update for coding agents failed; continuing."
fi

log "Building Neovim from source into ${NEOVIM_SRC_DIR}"
neovim_build_needed=1
prev_commit=""
new_commit=""

if [[ -d "${NEOVIM_SRC_DIR}/.git" ]]; then
	# Force tag updates (e.g. nightly retag) when fetching Neovim sources
	if ! prev_commit="$(git -C "${NEOVIM_SRC_DIR}" rev-parse HEAD 2>/dev/null)"; then
		prev_commit=""
	fi
	git -C "${NEOVIM_SRC_DIR}" fetch --tags --prune --force
	git -C "${NEOVIM_SRC_DIR}" reset --hard origin/master
	new_commit="$(git -C "${NEOVIM_SRC_DIR}" rev-parse HEAD)"

	if [[ -n "$prev_commit" && "$prev_commit" == "$new_commit" ]]; then
		log "Neovim source already at ${new_commit}; skipping rebuild/install."
		neovim_build_needed=0
	else
		log "Neovim source updated to ${new_commit} (was ${prev_commit:-unknown}); rebuilding."
	fi
else
	rm -rf "${NEOVIM_SRC_DIR}"
	git clone https://github.com/neovim/neovim.git "${NEOVIM_SRC_DIR}"
	new_commit="$(git -C "${NEOVIM_SRC_DIR}" rev-parse HEAD)"
	log "Cloned Neovim sources at ${new_commit}; building."
fi

if [[ "$neovim_build_needed" == "1" ]]; then
	require_command ninja "'ninja' not found; install it via Homebrew (brew install ninja) or system packages."
	require_command cmake "'cmake' not found; install it via Homebrew (brew install cmake) or system packages."

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
fi

bootstrap_neovim

log "Recording update timestamp"
touch "$UPDATE_TIMESTAMP_FILE"

log "Ensuring default shell is zsh"
zsh_path="$(command -v zsh)"
if [[ -n "$zsh_path" ]]; then
	if ! grep -Fq "$zsh_path" /etc/shells; then
		sudo sh -c "echo ${zsh_path} >> /etc/shells"
	fi

	current_shell=""
	if command_exists getent; then
		if current_shell="$(getent passwd "$USER" | cut -d: -f7)"; then
			:
		else
			current_shell=""
		fi
	elif command_exists dscl; then
		if dscl_output="$(dscl . -read "/Users/${USER}" UserShell 2>/dev/null)"; then
			current_shell="${dscl_output##* }"
		fi
	fi
	if [[ -z "$current_shell" ]]; then
		current_shell="${SHELL:-}"
	fi

	if [[ "$current_shell" == "$zsh_path" ]]; then
		log "Default shell already set to ${zsh_path}; skipping change."
	else
		log "Changing default shell to ${zsh_path}"
		sudo chsh -s "$zsh_path" "$USER"
	fi
else
	log "zsh not found in PATH; skipping shell change."
fi

log "Summary:"
log "- Platform: ${platform}"
if [[ "$neovim_build_needed" == "1" ]]; then
	log "- Neovim commit installed: ${new_commit}"
else
	log "- Neovim install skipped; already at ${new_commit:-unknown}"
fi
if (( ${#needed_agents[@]} > 0 )); then
	log "- Installed npm agents: ${needed_agents[*]}"
else
	log "- npm agents already up to date"
fi
log "- Dotfiles bootstrap complete. Please restart your shell."
