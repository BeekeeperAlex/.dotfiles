#!/usr/bin/env bash
set -euo pipefail

NEOVIM_SRC_DIR="${HOME}/.cache/neovim"
UPDATE_TIMESTAMP_FILE="${HOME}/.last_update_check"
NEOVIM_SOURCE_MESSAGE=""

COLOR_RESET=$'\033[0m'
COLOR_GREEN=$'\033[32m'
COLOR_RED=$'\033[31m'
COLOR_BLUE=$'\033[34m'
COLOR_ENABLED=0
if [[ -z "${NO_COLOR:-}" ]]; then
	if [[ -n "${FORCE_COLOR:-}" || -n "${CLICOLOR_FORCE:-}" ]]; then
		COLOR_ENABLED=1
	elif [[ -t 1 ]]; then
		COLOR_ENABLED=1
	fi
fi

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

supports_tty_progress() {
	[[ -t 1 ]] && [[ -z "${CI:-}" ]]
}

use_color() {
	(( COLOR_ENABLED ))
}

format_step_tag() {
	local __var="$1"
	local kind="$2"
	local text
	local color=""
	case "$kind" in
		start)
			text='==>'
			color="$COLOR_BLUE"
			;;
		done)
			text='[DONE]'
			color="$COLOR_GREEN"
			;;
		fail)
			text='[FAIL]'
			color="$COLOR_RED"
			;;
		*)
			text="$kind"
			;;
	esac
	if use_color && [[ -n "$color" ]]; then
		printf -v "$__var" '%s%s%s' "$color" "$text" "$COLOR_RESET"
	else
		printf -v "$__var" '%s' "$text"
	fi
}

collapse_progress_line() {
	local title="$1"
	local displayed="$2"
	local status="$3"
	local tag
	if (( status == 0 )); then
		format_step_tag tag done
	else
		format_step_tag tag fail
	fi
	local move_lines=$((displayed + 1))
	printf '\033[%dF' "$move_lines"
	printf '\033[2K\033[J'
	printf '\r%s %s\n' "$tag" "$title"
	if (( status != 0 )); then
		printf '\n'
	fi
}

run_step_internal() {
	local title="$1"
	shift
	local log_file
	log_file="$(mktemp -t install-step.XXXX.log)"
	local status=0
	local use_progress=0
	local fifo=""
	local count_file=""
	local reader_pid=""
	local displayed=0
	local max_lines="${PROGRESS_WINDOW_LINES:-5}"

	if supports_tty_progress; then
		use_progress=1
		fifo="$(mktemp -u)"
		mkfifo "$fifo"
		count_file="$(mktemp -t install-step.XXXX.count)"
		local start_tag
		format_step_tag start_tag start
		printf '%s %s\n' "$start_tag" "$title"
		(
			trap 'printf "\033[?25h"' EXIT
			exec 3>"$count_file"
			local -a buffer=()
			local line
			local clear_line=$'\033[2K'
			local hide_cursor=$'\033[?25l'
			printf '%s' "$hide_cursor"
			while IFS= read -r line || [[ -n "$line" ]]; do
				line="${line//$'\r'/}"
				printf '%s\n' "$line" >>"$log_file"
				buffer+=("$line")
				if (( ${#buffer[@]} > max_lines )); then
					buffer=("${buffer[@]: -max_lines}")
				fi
				if (( displayed > 0 )); then
					printf '\033[%dF' "$displayed"
				fi
				displayed=${#buffer[@]}
				for entry in "${buffer[@]}"; do
					printf '%s\r%s\n' "$clear_line" "$entry"
				done
			done
			printf '%d\n' "$displayed" >&3
		) <"$fifo" &
		reader_pid=$!
		set +e
		"$@" >"$fifo" 2>&1
		status=$?
		set -e
		wait "$reader_pid" 2>/dev/null || true
		if [[ -f "$count_file" ]]; then
			if ! read -r displayed <"$count_file"; then
				displayed=0
			fi
		fi
		rm -f "$fifo" "$count_file"
	else
		local start_tag
		format_step_tag start_tag start
		printf '%s %s\n' "$start_tag" "$title"
		set +e
		"$@" 2>&1 | tee "$log_file"
		status=${PIPESTATUS[0]}
		set -e
	fi

	if (( use_progress )); then
		collapse_progress_line "$title" "$displayed" "$status"
	elif (( status == 0 )); then
		local done_tag
		format_step_tag done_tag done
		printf '%s %s\n' "$done_tag" "$title"
	else
		local fail_tag
		format_step_tag fail_tag fail
		printf '%s %s\n' "$fail_tag" "$title"
	fi

	if (( status != 0 )); then
		cat "$log_file"
		rm -f "$log_file"
		return "$status"
	fi

	rm -f "$log_file"
	return 0
}

run_step() {
	local title="$1"
	shift
	if (( $# == 0 )); then
		fail "run_step requires a command to execute"
	fi
	if ! run_step_internal "$title" "$@"; then
		exit 1
	fi
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

trap_add() {
	local new_cmd="$1"
	local signal="${2:-EXIT}"
	local current_trap
	current_trap="$(trap -p "$signal")"
	if [[ -n "$current_trap" ]]; then
		current_trap="${current_trap#*\'}"
		current_trap="${current_trap%\'*}"
		new_cmd="${current_trap};${new_cmd}"
	fi
	trap "$new_cmd" "$signal"
}

stop_sudo_keepalive() {
	if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
		kill "${SUDO_KEEPALIVE_PID}" >/dev/null 2>&1 || true
		wait "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
		unset SUDO_KEEPALIVE_PID
	fi
}

start_sudo_keepalive() {
	if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
		return
	fi
	if ! command_exists sudo; then
		return
	fi
	if ! sudo -n true >/dev/null 2>&1; then
		return
	fi
	local parent_pid="$$"
	(
		while kill -0 "$parent_pid" >/dev/null 2>&1; do
			sleep 60
			sudo -n true >/dev/null 2>&1 || exit
		done
	) &
	SUDO_KEEPALIVE_PID=$!
	trap_add 'stop_sudo_keepalive' EXIT
}

confirm_sudo() {
	if ! command_exists sudo; then
		fail "sudo is required. Please install sudo and rerun."
	fi
	if ! sudo -n true >/dev/null 2>&1; then
		log "sudo access is required. You may be prompted for your password."
	fi
	if ! sudo -v; then
		fail "Unable to obtain sudo credentials."
	fi
	start_sudo_keepalive
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

windows_symlinks_up_to_date() {
	if [[ -z "${WSL_DISTRO_NAME:-}" ]]; then
		return 0
	fi

	if ! command_exists powershell.exe; then
		return 1
	fi

	local dotfiles_dir="${HOME}/.dotfiles"
	local wezterm_config_target
	local wezterm_dir_target
	local nvim_config_target

	if ! wezterm_config_target=$(wslpath -w "${dotfiles_dir}/.wezterm.lua" 2>/dev/null); then
		return 1
	fi
	if ! wezterm_dir_target=$(wslpath -w "${dotfiles_dir}/wezterm" 2>/dev/null); then
		return 1
	fi
	if ! nvim_config_target=$(wslpath -w "${dotfiles_dir}/nvim" 2>/dev/null); then
		return 1
	fi

	local ps_tmp
	ps_tmp="$(mktemp)"
	local ps_script="${ps_tmp}.ps1"

cat >"${ps_script}" <<'EOF_PS'
param(
   [string]$WeztermConfigTarget,
   [string]$WeztermDirTarget,
   [string]$NvimConfigTarget
)

$ErrorActionPreference = 'Stop'
$needsUpdate = $false

function Normalize-Target {
   param([string]$Path)

   if ($null -eq $Path) {
      return $null
   }

   if ($Path.StartsWith('UNC\', [System.StringComparison]::OrdinalIgnoreCase)) {
      $Path = '\\' + $Path.Substring(4)
   }

   return $Path.TrimEnd('\')
}

function Check-Link {
   param(
      [string]$Name,
      [string]$LinkPath,
      [string]$ExpectedTarget
   )

   if (-not (Test-Path -LiteralPath $LinkPath)) {
      Write-Host ("Missing symlink: {0}" -f $Name)
      $script:needsUpdate = $true
      return
   }

   $item = Get-Item -LiteralPath $LinkPath -Force
   if (-not ($item.PSObject.Properties.Name -contains 'Target')) {
      Write-Host ("Unable to determine target for {0}" -f $Name)
      $script:needsUpdate = $true
      return
   }

   $target = $item.Target
   if ($null -eq $target) {
      Write-Host ("Null target for {0}" -f $Name)
      $script:needsUpdate = $true
      return
   }

   if ($target -is [Array]) {
      $target = $target[0]
   }

   $normalizedActual = Normalize-Target $target
   $normalizedExpected = Normalize-Target $ExpectedTarget

   if (-not [string]::Equals($normalizedActual, $normalizedExpected, [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Host ("Target mismatch for {0}. Current: {1}" -f $Name, $target)
      $script:needsUpdate = $true
   }
}

$weztermConfigLink = Join-Path $env:USERPROFILE '.wezterm.lua'
$weztermDirLink = Join-Path $env:USERPROFILE '.wezterm'
$nvimConfigLink = Join-Path $env:LOCALAPPDATA 'nvim'

Check-Link 'WezTerm config file' $weztermConfigLink $WeztermConfigTarget
Check-Link 'WezTerm directory' $weztermDirLink $WeztermDirTarget
Check-Link 'Neovim config directory' $nvimConfigLink $NvimConfigTarget

if ($needsUpdate) {
   exit 1
}

exit 0
EOF_PS

	local ps_path
	ps_path=$(wslpath -w "${ps_script}")

	if powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${ps_path}" "${wezterm_config_target}" "${wezterm_dir_target}" "${nvim_config_target}"; then
		rm -f "${ps_script}"
		rm -f "${ps_tmp}"
		return 0
	fi

	rm -f "${ps_script}"
	rm -f "${ps_tmp}"
	return 1
}

launch_windows_symlink_terminal() {
	if [[ -z "${WSL_DISTRO_NAME:-}" ]]; then
		return
	fi

	if ! command_exists powershell.exe; then
		log "powershell.exe not found; skipping elevated Windows symlink helper."
		return
	fi

	if windows_symlinks_up_to_date; then
		log "Windows symlinks already configured; skipping elevated helper."
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
exit "\$?"
EOF_WSL
	chmod +x "${wsl_script}"

	local wsl_script_ps
	wsl_script_ps=$(printf '%s' "${wsl_script}" | sed "s/'/''/g")
	local distribution_ps
	distribution_ps=$(printf '%s' "${WSL_DISTRO_NAME}" | sed "s/'/''/g")

	local ps_tmp
	ps_tmp="$(mktemp)"
	local ps_script="${ps_tmp}.ps1"

	cat >"${ps_script}" <<'EOF_PS'
$ErrorActionPreference = 'Stop'
$distribution = '__DISTRO__'
$symlinkScript = '__WSL_SCRIPT__'
$wslExe = '__WSL_EXE__'
if (-not (Test-Path -Path $wslExe)) {
	Write-Error "wsl.exe not found at $wslExe"
	exit 1
}
$arguments = @('-d', $distribution, '--', '/bin/bash', $symlinkScript)
Write-Host ('WSL args: {0}' -f ($arguments -join ' '))
$process = Start-Process -FilePath $wslExe -ArgumentList $arguments -Verb RunAs -Wait -PassThru
$exitCode = $process.ExitCode
if ($exitCode -ne 0) {
	Write-Host ('Windows symlink setup failed with exit code {0}' -f $exitCode)
	Read-Host 'Press Enter to close...'
}
exit $exitCode
EOF_PS

	local wsl_exe_win='C:\Windows\System32\wsl.exe'
	local wsl_exe_ps=${wsl_exe_win//\/\\}

	DISTRIBUTION="${distribution_ps}" 	WSL_SCRIPT_PS="${wsl_script_ps}" 	WSL_EXE_PS="${wsl_exe_ps}" 	PS_SCRIPT="${ps_script}" 	python - <<'PY_PS'
import os
from pathlib import Path
ps_path = Path(os.environ['PS_SCRIPT'])
text = ps_path.read_text()
text = text.replace('__DISTRO__', os.environ['DISTRIBUTION'])
text = text.replace('__WSL_SCRIPT__', os.environ['WSL_SCRIPT_PS'])
text = text.replace('__WSL_EXE__', os.environ['WSL_EXE_PS'])
ps_path.write_text(text)
PY_PS

	local ps_path
	ps_path=$(wslpath -w "${ps_script}")

	if powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${ps_path}"; then
		log "Windows symlink helper launched. Approve the UAC prompt to finish setup."
	else
		local ps_status=$?
		log "Unable to launch elevated Windows PowerShell automatically (exit code: ${ps_status}). Run manually:"
		log "  wsl.exe -d ${WSL_DISTRO_NAME} -- bash -lc 'cd ${REPO_ROOT} && ./create-symlinks.sh --windows-only'"
		rm -f "${wsl_script}"
	fi

	rm -f "${ps_script}"
}




install_terminfo() {
	local tempfile
	tempfile="$(mktemp)"
	trap 'tmp="${tempfile:-}"; [[ -n "$tmp" ]] && rm -f "$tmp"' RETURN
	if command_exists curl; then
		curl -fsSL -o "$tempfile" https://raw.githubusercontent.com/wez/wezterm/main/termwiz/data/wezterm.terminfo
	elif command_exists wget; then
		wget -q -O "$tempfile" https://raw.githubusercontent.com/wez/wezterm/main/termwiz/data/wezterm.terminfo
	else
		fail "Neither curl nor wget is available to download WezTerm terminfo."
	fi
	/usr/bin/tic -x -o "$HOME/.terminfo" "$tempfile"
}

link_dotfiles() {
	(
		cd "$REPO_ROOT"
		bash "./create-symlinks.sh" "$@"
	)
}

brew_taps() {
	brew tap jesseduffield/lazygit >/dev/null
	brew tap oven-sh/bun >/dev/null
	brew tap wez/wezterm-linuxbrew >/dev/null
}

brew_cleanup_all() {
	brew cleanup -s --prune=all --verbose
}

brew_upgrade_casks() {
	brew upgrade --cask --verbose 2>/dev/null || true
}

gh_extension_upgrade_all() {
	gh extension upgrade --all || log "Failed to upgrade GitHub CLI extensions. Continuing."
}

mise_use_global() {
	mise use -g "$1"
}

mise_install_all() {
	mise install
	mise upgrade
}

mise_doctor_check() {
	if ! mise doctor; then
		printf 'mise doctor reported issues. Please resolve them and rerun.\n' >&2
		return 1
	fi
}

npm_install_agents() {
	npm install -g "$@"
}

npm_update_agents() {
	npm update -g "$@" || log "npm update for coding agents failed; continuing."
}

sync_neovim_sources() {
	NEOVIM_SOURCE_MESSAGE=""
	neovim_build_needed=1
	prev_commit=""
	new_commit=""
	if [[ -d "${NEOVIM_SRC_DIR}/.git" ]]; then
		if ! prev_commit="$(git -C "${NEOVIM_SRC_DIR}" rev-parse HEAD 2>/dev/null)"; then
			prev_commit=""
		fi
		git -C "${NEOVIM_SRC_DIR}" fetch --tags --prune --force
		git -C "${NEOVIM_SRC_DIR}" reset --hard origin/master
		new_commit="$(git -C "${NEOVIM_SRC_DIR}" rev-parse HEAD)"
		if [[ -n "$prev_commit" && "$prev_commit" == "$new_commit" ]]; then
			neovim_build_needed=0
			NEOVIM_SOURCE_MESSAGE="Neovim source already at ${new_commit}; skipping rebuild/install."
		else
			NEOVIM_SOURCE_MESSAGE="Neovim source updated to ${new_commit} (was ${prev_commit:-unknown}); rebuilding."
		fi
	else
		rm -rf "${NEOVIM_SRC_DIR}"
		git clone https://github.com/neovim/neovim.git "${NEOVIM_SRC_DIR}"
		new_commit="$(git -C "${NEOVIM_SRC_DIR}" rev-parse HEAD)"
		NEOVIM_SOURCE_MESSAGE="Cloned Neovim sources at ${new_commit}; building."
	fi
}

neovim_build_from_source() {
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

run_step "Install WezTerm terminfo" install_terminfo

if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
	run_step "Link dotfiles (WSL Linux side)" link_dotfiles --posix-only
	launch_windows_symlink_terminal
else
	run_step "Link dotfiles" link_dotfiles
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
	run_step "Refresh apt repositories" sudo apt-get update -y
	run_step "Upgrade apt packages" sudo apt-get upgrade -y
	run_step "Install Ubuntu prerequisites" sudo apt-get install -y --no-install-recommends \
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
	run_step "Apt autoremove" sudo apt-get autoremove -y
	run_step "Apt clean" sudo apt-get clean
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

run_step "Ensure brew taps" brew_taps
run_step "brew update" brew update --verbose
run_step "brew upgrade (formula)" brew upgrade --formula --verbose
run_step "brew upgrade (cask)" brew_upgrade_casks
run_step "brew cleanup" brew_cleanup_all

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

run_step "Install brew packages" brew install "${brew_formulae[@]}"

log "Cloning fzf-git"
if [[ -d "$HOME/.fzf-git/.git" ]]; then
	run_step "Update fzf-git" git -C "$HOME/.fzf-git" pull --ff-only
elif [[ -d "$HOME/.fzf-git" ]]; then
	log "Existing ~/.fzf-git directory without git found. Skipping clone."
else
	run_step "Clone fzf-git" git clone https://github.com/junegunn/fzf-git.sh.git "$HOME/.fzf-git"
fi

log "Ensuring GitHub CLI configuration"
if command_exists gh; then
	if ! gh auth status >/dev/null 2>&1; then
		log "GitHub CLI is installed but not authenticated. Launching authentication flow..."
		if ! gh auth login --web -h github.com; then
			log "GitHub CLI authentication skipped or failed. Continuing without it."
		fi
	fi
	run_step "Upgrade GitHub CLI extensions" gh_extension_upgrade_all
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
	run_step "Ensure ${tool} via mise" mise_use_global "$tool"
done

run_step "Install/upgrade mise runtimes" mise_install_all

eval "$(mise activate bash)"

run_step "Run mise doctor" mise_doctor_check

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
	run_step "Install global coding agents" npm_install_agents "${needed_agents[@]}"
else
	log "Global coding agents already installed; skipping npm install."
	run_step "Update global coding agents" npm_update_agents @openai/codex @just-every/code
fi

log "Building Neovim from source into ${NEOVIM_SRC_DIR}"
run_step "Sync Neovim sources" sync_neovim_sources
if [[ -n "$NEOVIM_SOURCE_MESSAGE" ]]; then
	log "$NEOVIM_SOURCE_MESSAGE"
fi

if [[ "$neovim_build_needed" == "1" ]]; then
	run_step "Build Neovim from source" neovim_build_from_source
fi

run_step "Prime Neovim plugins" bootstrap_neovim

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
