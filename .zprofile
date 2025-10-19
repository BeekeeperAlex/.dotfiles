# If we are in WSL then configure Windows path variables.
if command -v powershell.exe > /dev/null ; then
	export WINHOME=$(wslpath -u "$(powershell.exe '$env:Userprofile' | tr -d '\r')")
	export APPDATA=$WINHOME/AppData/Roaming
	export DESKTOP=$WINHOME/Desktop
	export DOWNLOADS=$WINHOME/Downloads
	# If Google Drive is mounted then set some more path variables.
	if [[ -d "/mnt/g" ]] ; then
		export GDRIVE="/mnt/g/My Drive"
		export GBACKUPS="/mnt/g/My Drive/Backups"
	fi
fi

# Source Homebrew shell configuration.
if command -v brew > /dev/null ; then
	eval "$(brew shellenv)"
else
	[[ -d "/opt/homebrew" ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
	[[ -d "/home/linuxbrew/.linuxbrew" ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Ensure Linuxbrew headers and libraries are discoverable for native builds.
if [[ "$(uname -s)" == "Linux" && -n "${HOMEBREW_PREFIX:-}" ]]; then
	export CPATH="${HOMEBREW_PREFIX}/include${CPATH:+:${CPATH}}"
	export LIBRARY_PATH="${HOMEBREW_PREFIX}/lib${LIBRARY_PATH:+:${LIBRARY_PATH}}"
	export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/lib/pkgconfig:${HOMEBREW_PREFIX}/share/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
	export CMAKE_PREFIX_PATH="${HOMEBREW_PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
	export CPPFLAGS="-I${HOMEBREW_PREFIX}/include${CPPFLAGS:+ ${CPPFLAGS}}"
	export LDFLAGS="-L${HOMEBREW_PREFIX}/lib${LDFLAGS:+ ${LDFLAGS}}"
fi

# Activate mise shims so managed runtimes resolve first.
if command -v mise > /dev/null ; then
	eval "$(mise activate zsh)"
fi

# If Bun is installed then add it to our PATH.
[[ -d "$HOME/.bun" ]] && export PATH="$HOME/.bun/bin:$PATH"

# If Volta is installed then add it to our PATH.
[[ -d "$HOME/.volta/bin" ]] && export PATH="$HOME/.volta/bin:$PATH"

# If cargo is installed then source its env file.
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# If there is a local bin directory then add it to our PATH.
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# If Go is installed then add it to PATH.
[[ -d "/usr/local/go/bin" ]] && export PATH="$PATH:/usr/local/go/bin"
[[ -d "$HOME/go/bin" ]] && export PATH="$PATH:$HOME/go/bin"

load_dotfiles_env_file() {
	local env_file="$1"
	if [[ -f "$env_file" ]]; then
		set -a
		if source "$env_file"; then
			set +a
			return 0
		else
			local status=$?
			set +a
			return "$status"
		fi
	fi
	return 1
}

load_dotfiles_env_file "$HOME/.dotfiles/.env"

unset -f load_dotfiles_env_file

export SSL_CERT_DIR=/etc/ssl/certs
export EDITOR="nvim"
export HOMEBREW_NO_ENV_HINTS=1
export MS_COG_SVC_SPEECH_SKIP_BINDGEN=1
export NEOVIM_SRC_DIR="$HOME/.cache/neovim"
