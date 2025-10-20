[[ -r "$HOME/.dotfiles/wezterm-shell-integration.sh" ]] && source "$HOME/.dotfiles/wezterm-shell-integration.sh"

: "${NEOVIM_SRC_DIR:=$HOME/.cache/neovim}"

# Set the terminal title to the current directory.
function chpwd {
	echo "\x1b]1337;SetUserVar=panetitle=$(echo -n $(basename $(pwd)) | base64)\x07"
}
chpwd

# Define function to check if we should run system updates.
TIMESTAMP_FILE="$HOME/.last_update_check"
check_last_run() {
	if [ -f "$TIMESTAMP_FILE" ]; then
		last_run=$(date -r "$TIMESTAMP_FILE" +%s)
		current_time=$(date +%s)
		time_diff=$((current_time - last_run))
		if [ $time_diff -lt 604800 ]; then
			return 1 # Less than 7 days.
		fi
	fi
	return 0 # More than 7 days or timestamp file doesn't exist.
}

updoot() {
	echo "Running dotfiles installer for maintenance..."
	if "$HOME/.dotfiles/install.sh"; then
		echo "Maintenance run completed."
	else
		echo "Dotfiles installer reported an error; check logs above." >&2
	fi
}

# Check if we should run system updates.
if check_last_run; then
	echo "System packages have not been updated in more than 7 days."
	updoot
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Enable vi mode
bindkey -v

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# Define custom prompt segmenet outside of generated .p10k.zsh file so it doesn't get overwritten.
prompt_customprefix() {
	# p10k segment -f "#0f0" -t '🦇🧛🎃'
	# p10k segment -f "#0f0" -t '📜'
}
# typeset index=0 # Adjust this to move the segment left or right.
# POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
#   "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[@]:0:$index}"
#   customprefix 
#   "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[@]:$index}"
# )
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
	customprefix
	os_icon
	dir
	vcs
	newline
	prompt_char
)
# typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND="#FF6AC1"
# typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND="#FF5c57"

# If homebrew is installed then source zsh plugins from their brew locations.
# Otherwise source from their default locations.
if command -v brew &> /dev/null; then
	P10K_THEME="$(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme"
	ZVM_PLUGIN="$(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
	[[ -f "$P10K_THEME" ]] && source "$P10K_THEME"
	[[ -f "$ZVM_PLUGIN" ]] && source "$ZVM_PLUGIN"
else
	[[ -f "/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme" ]] && source "/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme"
	[[ -f "/usr/share/zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]] && source "/usr/share/zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
fi

# If fzf is installed them pull in its shell completion and key bindings.
if command -v fzf &> /dev/null ; then
	# Generated with `fzf --zsh`
    source "$HOME/.dotfiles/fzf.zsh"
	# If fd is also installed then use it as the default fzf functionality.
	if command -v fd &> /dev/null ; then
		export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
		export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
		export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
		export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
		export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
		_fzf_compgen_path() {
			fd --hidden --exclude .git . "$1"
		}
		_fzf_compgen_dir() {
			fd --type=d --hidden --exclude .git . "$1"
		}
		_fzf_comprun() {
			local command=$1
			shift
			case "$command" in
				cd)				fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
				export|unset)	fzf --preview "eval 'echo {}=\$'{}" "$@" ;;
				ssh)				fzf --preview 'dig {}' "$@" ;;
				*)					fzf --preview "--preview 'bat -n --color=always --line-range :500 {}'" "$@" ;;
			esac
		}
	fi
	# If fzf-git is installed then pull in its shell completion and key bindings.
	if [[ -f ~/.fzf-git/fzf-git.sh ]]; then
		source ~/.fzf-git/fzf-git.sh
		# Set keybindings for zsh-vi-mode insert mode
		function zvm_after_init() {
			zvm_bindkey viins "^P" up-line-or-beginning-search
			zvm_bindkey viins "^N" down-line-or-beginning-search
			for o in files branches tags remotes hashes stashes lreflogs each_ref; do
				eval "zvm_bindkey viins '^g^${o[1]}' fzf-git-$o-widget"
				eval "zvm_bindkey viins '^g${o[1]}' fzf-git-$o-widget"
			done
		}
		# Set keybindings for zsh-vi-mode normal and visual modes
		function zvm_after_lazy_keybindings() {
			for o in files branches tags remotes hashes stashes lreflogs each_ref; do
				eval "zvm_bindkey vicmd '^g^${o[1]}' fzf-git-$o-widget"
				eval "zvm_bindkey vicmd '^g${o[1]}' fzf-git-$o-widget"
				eval "zvm_bindkey visual '^g^${o[1]}' fzf-git-$o-widget"
				eval "zvm_bindkey visual '^g${o[1]}' fzf-git-$o-widget"
			done
		}
	fi
fi

# Generated with `zoxide init zsh`
command -v zoxide &> /dev/null && source "$HOME/.dotfiles/zoxide.zsh"

HISTFILE="$HOME/.zsh_history"
SAVEHIST=10000
HISTSIZE=10000
setopt SHARE_HISTORY

setup_1password_ssh_agent() {
	if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
		if command -v ssh.exe >/dev/null 2>&1; then
			alias ssh="ssh.exe"
			alias scp="scp.exe"
			alias sftp="sftp.exe"
			alias ssh-add="ssh-add.exe"
			alias ssh-agent="ssh-agent.exe"
			export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh.exe}"
		fi
		unset SSH_AUTH_SOCK
		return
	fi

	local sock="$HOME/.1password/agent.sock"
	if [[ -S "$sock" || ! -e "$sock" ]]; then
		export SSH_AUTH_SOCK="$sock"
	fi
}
setup_1password_ssh_agent

# Set personal aliases.
alias cat="bat --paging=never"
alias help="run-help"
alias lg="lazygit"
alias ll="eza --color=always --all --long --git --icons=always --no-time --no-permissions"
alias nv="nvim"
alias vi="nvim"
alias vim="nvim"
# alias cd="z"
alias ff="fastfetch"

. "$HOME/.local/bin/env"
