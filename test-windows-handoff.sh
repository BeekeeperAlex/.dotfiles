#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$SCRIPT_DIR}"

if [[ ! -x "${REPO_ROOT}/create-symlinks.sh" ]]; then
	echo "create-symlinks.sh not found or not executable in ${REPO_ROOT}." >&2
	exit 1
fi

if ! command -v powershell.exe >/dev/null 2>&1; then
	echo "powershell.exe not available in PATH; skipping Windows handoff test." >&2
	exit 1
fi

distribution="${WSL_DISTRO_NAME:-}"
if [[ -z "${distribution}" ]]; then
	echo "WSL_DISTRO_NAME is not set; cannot determine target distro." >&2
	exit 1
fi

repo_quoted=$(printf '%q' "${REPO_ROOT}")

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

wsl_script_ps=$(printf '%s' "${wsl_script}" | sed "s/'/''/g")

ps_tmp="$(mktemp)"
ps_script="${ps_tmp}.ps1"

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

DISTRIBUTION="${distribution}" \
WSL_SCRIPT_PS="${wsl_script_ps}" \
PS_SCRIPT="${ps_script}" \
python - <<'PY_SUB'
import os
from pathlib import Path
path = Path(os.environ['PS_SCRIPT'])
text = path.read_text()
text = text.replace('__DISTRIBUTION__', os.environ['DISTRIBUTION'])
text = text.replace('__WSL_SCRIPT__', os.environ['WSL_SCRIPT_PS'])
path.write_text(text)
PY_SUB

cleanup() {
	rm -f "${ps_script}"
}
trap cleanup EXIT

ps_path=$(wslpath -w "${ps_script}")

printf 'Launching Windows PowerShell handoff test...\n'
if powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${ps_path}"; then
	echo "Windows handoff completed."
else
	echo "Windows handoff failed." >&2
	rm -f "${wsl_script}"
	exit 1
fi
