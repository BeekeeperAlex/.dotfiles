#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
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
exit "\$?"
EOF_WSL
chmod +x "${wsl_script}"

ps_tmp="$(mktemp)"
ps_script="${ps_tmp}.ps1"

cat >"${ps_script}" <<'EOF_PS'
$ErrorActionPreference = 'Stop'
$distribution = '__DISTRO__'
$symlinkScript = '__WSL_SCRIPT__'
$pwsh = Get-Command powershell.exe
if (-not $pwsh) {
  Write-Error 'powershell.exe not found.'
  exit 1
}
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

wsl_exe_win='C:\Windows\System32\wsl.exe'
WSL_SCRIPT_ESC=${wsl_script//\\/\\\\}
DISTRO_ESC=${distribution//\\/\\\\}
WSL_EXE_ESC=${wsl_exe_win//\\/\\\\}

PS_SCRIPT="$ps_script" WSL_SCRIPT="$WSL_SCRIPT_ESC" DISTRO="$DISTRO_ESC" WSL_EXE="$WSL_EXE_ESC" python - <<'PY'
import os
from pathlib import Path
ps_path = Path(os.environ['PS_SCRIPT'])
text = ps_path.read_text()
text = text.replace('__WSL_SCRIPT__', os.environ['WSL_SCRIPT'])
text = text.replace('__DISTRO__', os.environ['DISTRO'])
text = text.replace('__WSL_EXE__', os.environ['WSL_EXE'])
ps_path.write_text(text)
PY

cleanup() {
  rm -f "${ps_script}"
}
trap cleanup EXIT

ps_path_win="$(wslpath -w "${ps_script}")"
if powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${ps_path_win}"; then
  echo "Windows handoff completed."
else
  status=$?
  echo "Windows handoff failed (exit code: ${status})." >&2
  rm -f "${wsl_script}"
  exit 1
fi
