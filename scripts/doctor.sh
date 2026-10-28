#!/usr/bin/env bash
# Checks everything this project needs and offers to install / fix what is missing.
#
#   npm run doctor            interactive: asks before every change
#   npm run doctor -- --check report only, change nothing
#   npm run doctor -- --yes   accept every fix without asking (except passwords / sign-in input)

set -uo pipefail

MODE=ask
for arg in "$@"; do
  case "$arg" in
    --check) MODE=check ;;
    --yes|-y) MODE=yes ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

if [ -t 1 ]; then
  G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' B=$'\e[1m' D=$'\e[2m' N=$'\e[0m'
else
  G='' Y='' R='' B='' D='' N=''
fi

PASS=0 WARNS=0 FAILS=0
ok()      { echo "  ${G}✔${N} $*"; PASS=$((PASS + 1)); }
warn()    { echo "  ${Y}!${N} $*"; WARNS=$((WARNS + 1)); }
fail()    { echo "  ${R}✘${N} $*"; FAILS=$((FAILS + 1)); }
info()    { echo "    ${D}$*${N}"; }
fixed()   { echo "  ${G}✔${N} $*"; FAILS=$((FAILS - 1)); PASS=$((PASS + 1)); }
section() { echo; echo "${B}$*${N}"; }

# ask "question" -> 0 when the fix should be applied
ask() {
  case "$MODE" in
    check) info "(--check: skipped)"; return 1 ;;
    yes) return 0 ;;
  esac
  [ -t 0 ] || return 1
  local reply
  read -r -p "    → $1 [Y/n] " reply
  [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

# run a command, echoing it first
run() { echo "    ${D}\$ $*${N}"; "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

IS_LINUX=false IS_WSL=false HAS_APT=false
[ "$(uname -s)" = Linux ] && IS_LINUX=true
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true
have apt-get && HAS_APT=true

apt_install() {
  if ! $HAS_APT; then
    info "Install manually with your package manager: $*"
    return 1
  fi
  run sudo apt-get update -qq && run sudo apt-get install -y "$@"
}

PA=(npx --no-install pa)

# Stores and deletes a dummy secret. 0 = keyring works, 124 = hangs (locked), other = no keyring.
keyring_probe() {
  timeout 8 node -e '
    const k = require("keytar");
    k.setPassword("pa-doctor", "probe", "x")
      .then(() => k.deletePassword("pa-doctor", "probe"))
      .then(() => process.exit(0), () => process.exit(2));
  ' >/dev/null 2>&1
}

echo "${B}Power Apps code app — environment doctor${N}"
echo "${D}Project: $ROOT${N}"

# ---------------------------------------------------------------------------
section "1. System"
if $IS_WSL; then ok "WSL detected ($(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}"))"
elif $IS_LINUX; then ok "Linux ($(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}"))"
else ok "$(uname -s)"; fi

if have git; then
  ok "git $(git --version | awk '{print $3}')"
else
  warn "git is not installed (recommended)"
  ask "Install git?" && apt_install git
fi

# ---------------------------------------------------------------------------
section "2. Node.js (22+ required)"
NODE_OK=false
if have node; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
  if [ "$NODE_MAJOR" -ge 22 ]; then
    ok "node $(node -v), npm $(npm -v)"
    NODE_OK=true
  else
    fail "node $(node -v) is too old"
  fi
else
  fail "node is not installed"
fi

if ! $NODE_OK; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    if ask "Install Node 22 LTS with nvm?"; then
      # shellcheck disable=SC1091
      . "$NVM_DIR/nvm.sh"
      run nvm install 22 && run nvm alias default 22 && NODE_OK=true
      info "Open a new terminal afterwards so the new node is on your PATH."
    fi
  else
    info "Install nvm, then Node 22:"
    info "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
    info "  nvm install 22"
  fi
  if ! $NODE_OK; then
    echo; echo "${R}Node.js 22+ is required for everything else. Fix this first, then re-run.${N}"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
section "3. Project dependencies"
if [ ! -d node_modules ] || [ ! -x node_modules/.bin/pa ]; then
  fail "node_modules missing or incomplete"
  ask "Run npm install?" && run npm install
elif [ package-lock.json -nt node_modules/.package-lock.json ]; then
  warn "package-lock.json changed since the last npm install"
  ask "Run npm install?" && run npm install
else
  ok "node_modules installed"
fi

if [ -x node_modules/.bin/pa ]; then
  ok "Power Apps CLI (local) $("${PA[@]}" --version 2>/dev/null)"
else
  fail "Local Power Apps CLI not found (node_modules/.bin/pa)"
fi

# keytar is a native module the CLI uses to store the sign-in token
if node -e 'require("keytar")' >/dev/null 2>&1; then
  ok "keytar native module loads"
else
  fail "keytar native module is missing or broken (token storage will fail)"
  info "It must be compiled: needs build tools + libsecret headers."
  if ask "Install build tools and rebuild keytar?"; then
    $IS_LINUX && apt_install build-essential python3 libsecret-1-dev
    run npm rebuild keytar
    node -e 'require("keytar")' >/dev/null 2>&1 && fixed "keytar rebuilt" || info "keytar still does not load"
  fi
fi

# ---------------------------------------------------------------------------
section "4. Global 'pa' command"
if have pa; then
  PA_BIN="$(command -v pa)"
  PA_REAL="$(readlink -f "$PA_BIN")"
  # .../node_modules/@microsoft/power-apps-cli/dist/Bin.js -> package dir
  PA_PKG="$(dirname "$(dirname "$PA_REAL")")"
  if [[ "$PA_REAL" == "$ROOT/"* ]]; then
    ok "'pa' points to this project's CLI"
  elif node -e "require(require.resolve('keytar', { paths: ['$PA_PKG'] }))" >/dev/null 2>&1; then
    warn "'pa' runs a global copy ($PA_PKG) — it works, but may differ from the project version"
    info "Prefer: npx --no-install pa …"
  else
    fail "'pa' runs a broken global copy ($PA_PKG): its keytar module is not compiled"
    info "That's the 'Cannot find module ../build/Release/keytar.node' error."
    if ask "Remove the broken global copy ($PA_BIN)?"; then
      SUDO=""; [ -w "$(dirname "$PA_BIN")" ] && [ -w "$(dirname "$PA_PKG")" ] || SUDO=sudo
      run $SUDO rm -f "$PA_BIN" && run $SUDO rm -rf "$PA_PKG" && fixed "Global copy removed"
      hash -r
    fi
  fi
  if ! grep -qs "alias pa='npx --no-install pa'" "$HOME/.bashrc"; then
    info "Tip: alias pa='npx --no-install pa'  (add to ~/.bashrc to always use the project CLI)"
  fi
else
  ok "No global 'pa' (use npx --no-install pa)"
fi

# ---------------------------------------------------------------------------
KEYRING_OK=true
if $IS_LINUX; then
  section "5. Keyring (where the sign-in token is stored)"
  KEYRING_OK=false

  if have gnome-keyring-daemon; then
    ok "gnome-keyring installed"
  else
    fail "gnome-keyring is not installed (error: org.freedesktop.secrets was not provided)"
    ask "Install gnome-keyring?" && apt_install gnome-keyring libsecret-1-0
  fi

  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    fail "No D-Bus session in this shell"
    info "Start one, then re-run the doctor inside it:"
    info "  dbus-run-session -- bash"
  elif have gnome-keyring-daemon && node -e 'require("keytar")' >/dev/null 2>&1; then
    keyring_probe; rc=$?
    if [ $rc -eq 0 ]; then
      ok "Keyring is unlocked and accepts secrets"
      KEYRING_OK=true
    elif [ $rc -eq 124 ]; then
      fail "Keyring is locked (pa commands would hang)"
      if [ "$MODE" != check ] && [ -t 0 ]; then
        KR_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/keyrings"
        if [ -f "$KR_DIR/login.keyring" ]; then
          info "Enter the keyring password you chose earlier."
          info "Forgot it? The keyring can be reset (old one is backed up; you only need to pa auth login again)."
          # always ask, even with --yes: this discards the stored secrets
          read -r -p "    → Forgot the password — reset the keyring? [y/N] " KR_RESET
          if [[ "$KR_RESET" =~ ^[Yy] ]]; then
            KR_BAK="$KR_DIR/backup-$(date +%Y%m%d-%H%M%S)"
            run mkdir -p "$KR_BAK" && run mv "$KR_DIR/login.keyring" "$KR_BAK/"
            info "First time: the password you type now becomes the keyring password."
          fi
        else
          info "First time: the password you type now becomes the keyring password."
        fi
        read -r -s -p "    → Keyring password (empty to skip): " KR_PW; echo
        if [ -n "$KR_PW" ]; then
          printf %s "$KR_PW" | gnome-keyring-daemon --replace --unlock --components=secrets >/dev/null 2>&1
          unset KR_PW
          sleep 1
          if keyring_probe; then
            fixed "Keyring unlocked"
            KEYRING_OK=true
          else
            info "Still locked — wrong password?"
          fi
        fi
      else
        info "Unlock it:  printf %s 'YOUR_PASSWORD' | gnome-keyring-daemon --replace --unlock --components=secrets"
      fi
    else
      fail "Keyring service not reachable on D-Bus"
      info "Try: dbus-run-session -- bash   then re-run the doctor"
    fi
    $KEYRING_OK && $IS_WSL && info "WSL: after 'wsl --shutdown' or a reboot the keyring is locked again — just re-run the doctor."
  fi
fi

# ---------------------------------------------------------------------------
section "6. Power Platform sign-in"
if ! $KEYRING_OK; then
  warn "Skipped — fix the keyring first (pa would hang or fail)"
elif [ ! -x node_modules/.bin/pa ]; then
  warn "Skipped — CLI not installed"
else
  STATUS="$(timeout 30 "${PA[@]}" auth status 2>&1)"
  if grep -q "Signed in as" <<<"$STATUS"; then
    ok "$(grep -m1 "Signed in as" <<<"$STATUS")"
  else
    fail "Not signed in"
    [ -n "$STATUS" ] && info "$(head -3 <<<"$STATUS")"
    if ask "Sign in now (device code — open the URL in your Windows browser)?"; then
      run "${PA[@]}" auth login --device-code
      STATUS="$(timeout 30 "${PA[@]}" auth status 2>&1)"
      grep -q "Signed in as" <<<"$STATUS" && fixed "$(grep -m1 "Signed in as" <<<"$STATUS")" || info "Sign-in did not complete"
    fi
  fi
fi

# ---------------------------------------------------------------------------
section "7. App registration (power.config.json)"
cfg() { node -p "try { require('./power.config.json')['$1'] || '' } catch { '' }"; }
if [ -f power.config.json ] && [ -n "$(cfg environmentId)" ] && [ -n "$(cfg appId)" ]; then
  ok "Registered: \"$(cfg appDisplayName)\""
  info "environment $(cfg environmentId)"
  info "app         $(cfg appId)"
elif [ -f power.config.json ] && [ -n "$(cfg environmentId)" ]; then
  ok "Initialized for environment $(cfg environmentId) (app ID is assigned on first push)"
else
  fail "Not registered yet — 'pa app push' will keep asking for the environment ID"
  info "Find the environment ID in https://make.powerapps.com/environments/<env-id>/…"
  if $KEYRING_OK && [ "$MODE" != check ] && [ -t 0 ] && ask "Run pa app init now?"; then
    read -r -p "    → App display name: " APP_NAME
    read -r -p "    → Environment ID (GUID): " ENV_ID
    if [[ "$ENV_ID" =~ ^[0-9a-fA-F-]{36}$ ]] && [ -n "$APP_NAME" ]; then
      run "${PA[@]}" app init --display-name "$APP_NAME" --environment-id "$ENV_ID"
      [ -f power.config.json ] && fixed "power.config.json created" || info "pa app init failed"
    else
      info "Need a display name and a GUID environment ID"
    fi
  else
    info "Run: npx --no-install pa app init --display-name \"My App\" --environment-id <env-id>"
  fi
fi

# ---------------------------------------------------------------------------
section "8. Build"
if [ -f dist/index.html ]; then
  ok "dist/ built ($(date -r dist/index.html '+%Y-%m-%d %H:%M'))"
  newest_src="$(find src index.html -type f -newer dist/index.html 2>/dev/null | head -1)"
  [ -n "$newest_src" ] && warn "Sources changed since the last build — run npm run build before pushing"
else
  warn "Not built yet — run npm run build before pa app push"
fi

# ---------------------------------------------------------------------------
section "9. Optional tools"
if have az; then
  ok "Azure CLI $(az version --query '"azure-cli"' -o tsv 2>/dev/null) (needed by the flowagent MCP server)"
else
  warn "Azure CLI not installed — only needed for the Power Automate flow skills (flowagent)"
  info "Install: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash   then: az login"
fi

# ---------------------------------------------------------------------------
echo
echo "${B}Summary:${N} ${G}$PASS ok${N}, ${Y}$WARNS warnings${N}, ${R}$FAILS problems${N}"
if [ "$FAILS" -eq 0 ]; then
  echo "Next: ${B}npm run build && npx --no-install pa app push${N}"
else
  echo "Fix the ✘ items above (re-run ${B}npm run doctor${N} to try the fixes again)."
fi
[ "$FAILS" -eq 0 ]
