#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# zsh + Oh My Zsh + plugins setup
#
# Usage:
#   curl -fsSL <url> | bash
#   curl -fsSL <url> | bash -s -- --dry-run
#   curl -fsSL <url> | PLUGINS="zsh-autosuggestions,zsh-syntax-highlighting" bash
#   curl -fsSL <url> | bash -s -- --yes        # non-interactive: recommended set
#
# Flags:
#   --dry-run   Show what would happen, change nothing
#   --yes, -y   Non-interactive; install the recommended plugin set
#   --no-chsh   Never offer to change the default shell
#   --help, -h  Show help
#
# Env:
#   DRY_RUN_ENV=1        same as --dry-run
#   PLUGINS="a,b,c"      preselect plugins (comma-separated)
# ============================================================================

# Must run under bash (not zsh/sh)
if [ -z "${BASH_VERSION:-}" ]; then
  echo "This script requires bash. Run: curl -fsSL <url> | bash" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# Args
# ----------------------------------------------------------------------------
DRY_RUN=false
ASSUME_YES=false
ALLOW_CHSH=true

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=true ;;
    --yes|-y)   ASSUME_YES=true ;;
    --no-chsh)  ALLOW_CHSH=false ;;
    --help|-h)
      sed -n '4,20p' "$0" 2>/dev/null || true
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

[ "${DRY_RUN_ENV:-}" = "1" ] && DRY_RUN=true

# ----------------------------------------------------------------------------
# Logging (all to stderr so stdout is never polluted)
# ----------------------------------------------------------------------------
if [ -t 2 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; MAGENTA=$'\033[0;35m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; NC=''
fi

log_info()    { printf '%s[INFO]%s %s\n'    "$BLUE"    "$NC" "$1" >&2; }
log_success() { printf '%s[✓]%s %s\n'       "$GREEN"   "$NC" "$1" >&2; }
log_warn()    { printf '%s[WARN]%s %s\n'    "$YELLOW"  "$NC" "$1" >&2; }
log_error()   { printf '%s[✗]%s %s\n'       "$RED"     "$NC" "$1" >&2; }
log_dry_run() { printf '%s[DRY-RUN]%s %s\n' "$MAGENTA" "$NC" "$1" >&2; }

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# Run a command, or just print it in dry-run mode
exec_cmd() {
  if [ "$DRY_RUN" = true ]; then
    log_dry_run "Would execute: $*"
    return 0
  fi
  "$@"
}

# sudo only when needed and available
SUDO=""
setup_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    if have sudo; then
      SUDO="sudo"
    else
      log_warn "Not root and sudo not found; package installs may fail."
    fi
  fi
}

# Detect package manager once
PKG_MGR=""
detect_pkg_mgr() {
  if   have apt-get; then PKG_MGR="apt"
  elif have dnf;     then PKG_MGR="dnf"
  elif have yum;     then PKG_MGR="yum"
  elif have pacman;  then PKG_MGR="pacman"
  elif have zypper;  then PKG_MGR="zypper"
  elif have apk;     then PKG_MGR="apk"
  elif have brew;    then PKG_MGR="brew"
  fi
}

pkg_install() {
  [ -z "$PKG_MGR" ] && { log_error "No supported package manager found. Install '$*' manually."; return 1; }
  case "$PKG_MGR" in
    apt)    exec_cmd $SUDO apt-get update -y && exec_cmd $SUDO apt-get install -y "$@" ;;
    dnf)    exec_cmd $SUDO dnf install -y "$@" ;;
    yum)    exec_cmd $SUDO yum install -y "$@" ;;
    pacman) exec_cmd $SUDO pacman -Sy --noconfirm "$@" ;;
    zypper) exec_cmd $SUDO zypper install -y "$@" ;;
    apk)    exec_cmd $SUDO apk add --no-cache "$@" ;;
    brew)   exec_cmd brew install "$@" ;;
  esac
}

# Can we read from a terminal? (works even under `curl | bash`)
HAS_TTY=false
{ [ -r /dev/tty ] && : </dev/tty; } 2>/dev/null && HAS_TTY=true

# ----------------------------------------------------------------------------
# Plugin catalog
# ----------------------------------------------------------------------------
AVAILABLE_PLUGINS=(
  "zsh-autosuggestions"
  "zsh-syntax-highlighting"
  "fast-syntax-highlighting"
  "zsh-autocomplete"
  "you-should-use"
)

plugin_repo() {
  case "$1" in
    zsh-autosuggestions)      echo "zsh-users/zsh-autosuggestions" ;;
    zsh-syntax-highlighting)  echo "zsh-users/zsh-syntax-highlighting" ;;
    fast-syntax-highlighting) echo "zdharma-continuum/fast-syntax-highlighting" ;;
    zsh-autocomplete)         echo "marlonrichert/zsh-autocomplete" ;;
    you-should-use)           echo "MichaelAquilina/zsh-you-should-use" ;;
    *) return 1 ;;
  esac
}

# Plugins that must be last in the plugins=() list (in this order)
LOAD_LAST=("zsh-autosuggestions" "fast-syntax-highlighting" "zsh-syntax-highlighting")

# Recommended set for --yes
RECOMMENDED_PLUGINS=("zsh-autosuggestions" "zsh-syntax-highlighting" "you-should-use")

SELECTED_PLUGINS=()

in_array() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

# ============================================================================
# Step 1: Dependencies
# ============================================================================
check_and_install_deps() {
  log_info "Checking dependencies..."

  if ! have git; then
    log_warn "git not found, installing..."
    pkg_install git || exit 1
  fi
  log_success "git is available"

  if ! have curl && ! have wget; then
    log_warn "Neither curl nor wget found, installing curl..."
    pkg_install curl || exit 1
  fi
  log_success "curl/wget is available"
}

# ============================================================================
# Step 2: zsh
# ============================================================================
install_zsh() {
  if have zsh; then
    log_success "zsh is already installed: $(zsh --version)"
    return 0
  fi

  log_info "Installing zsh..."
  pkg_install zsh || exit 1

  if [ "$DRY_RUN" = true ]; then
    log_success "Would install zsh successfully"
  else
    log_success "zsh installed: $(zsh --version)"
  fi
}

# ============================================================================
# Step 3: Oh My Zsh
#   --keep-zshrc  -> never clobber an existing ~/.zshrc
#   --unattended  -> no prompts, no launching zsh at the end
#   --skip-chsh   -> we handle shell change ourselves (with consent)
# ============================================================================
install_oh_my_zsh() {
  if [ -d "${ZSH:-$HOME/.oh-my-zsh}" ]; then
    log_success "Oh My Zsh is already installed"
    return 0
  fi

  log_info "Installing Oh My Zsh..."

  if [ "$DRY_RUN" = true ]; then
    log_dry_run "Would download and run the Oh My Zsh installer (--unattended --skip-chsh --keep-zshrc)"
    log_success "Would install Oh My Zsh successfully"
    return 0
  fi

  local url="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
  local installer
  if have curl; then
    installer=$(curl -fsSL "$url")
  else
    installer=$(wget -qO- "$url")
  fi

  # </dev/null so the installer can't swallow our piped script
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$installer" "" --unattended --skip-chsh --keep-zshrc </dev/null >&2

  # If there was no .zshrc to keep, make sure we have one from the template
  if [ ! -f "$HOME/.zshrc" ] && [ -f "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
    sed -i "s|^export ZSH=.*|export ZSH=\"\$HOME/.oh-my-zsh\"|" "$HOME/.zshrc"
  fi

  log_success "Oh My Zsh installed successfully"
}

# ============================================================================
# Step 4: Plugin selection
#   Menu and prompt go to stderr; input is read from /dev/tty.
#   Result goes into the global SELECTED_PLUGINS (no stdout capture).
# ============================================================================
select_plugins() {
  SELECTED_PLUGINS=()

  # 1) Preselected via env var
  if [ -n "${PLUGINS:-}" ]; then
    local p
    IFS=',' read -ra _pre <<< "$PLUGINS"
    for p in "${_pre[@]}"; do
      p=$(echo "$p" | xargs)
      [ -z "$p" ] && continue
      if plugin_repo "$p" >/dev/null; then
        SELECTED_PLUGINS+=("$p")
      else
        log_warn "Ignoring unknown plugin in PLUGINS: $p"
      fi
    done
    return 0
  fi

  # 2) Non-interactive
  if [ "$ASSUME_YES" = true ]; then
    SELECTED_PLUGINS=("${RECOMMENDED_PLUGINS[@]}")
    log_info "Non-interactive mode: using recommended plugins."
    return 0
  fi

  # 3) Interactive
  if [ "$HAS_TTY" != true ]; then
    log_warn "No terminal available for interactive selection; using recommended plugins."
    SELECTED_PLUGINS=("${RECOMMENDED_PLUGINS[@]}")
    return 0
  fi

  {
    echo ""
    log_info "Available plugins:"
    local i=1 plugin
    for plugin in "${AVAILABLE_PLUGINS[@]}"; do
      printf '  %d) %s\n' "$i" "$plugin"
      i=$((i + 1))
    done
    echo "  r) recommended (${RECOMMENDED_PLUGINS[*]})"
    echo ""
  } >&2

  local choice
  printf "Enter numbers (comma-separated), 'r' for recommended, 'all', or 'none' [r]: " >&2
  read -r choice </dev/tty || choice="r"
  choice="${choice:-r}"

  case "$choice" in
    all)         SELECTED_PLUGINS=("${AVAILABLE_PLUGINS[@]}") ;;
    none)        SELECTED_PLUGINS=() ;;
    r|recommended) SELECTED_PLUGINS=("${RECOMMENDED_PLUGINS[@]}") ;;
    *)
      local nums num
      IFS=',' read -ra nums <<< "$choice"
      for num in "${nums[@]}"; do
        num=$(echo "$num" | xargs)
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#AVAILABLE_PLUGINS[@]}" ]; then
          SELECTED_PLUGINS+=("${AVAILABLE_PLUGINS[$((num - 1))]}")
        else
          log_warn "Invalid selection: $num"
        fi
      done
      ;;
  esac
}

# ============================================================================
# Resolve conflicts between selected plugins (in place, on SELECTED_PLUGINS)
#   - zsh-syntax-highlighting vs fast-syntax-highlighting: keep fast, drop other
#   - zsh-autocomplete vs zsh-autosuggestions: keep autosuggestions
# ============================================================================
resolve_conflicts() {
  local result=() p

  if in_array "fast-syntax-highlighting" "${SELECTED_PLUGINS[@]}" \
     && in_array "zsh-syntax-highlighting" "${SELECTED_PLUGINS[@]}"; then
    log_warn "Both syntax highlighters selected; keeping fast-syntax-highlighting only."
    for p in "${SELECTED_PLUGINS[@]}"; do
      [ "$p" != "zsh-syntax-highlighting" ] && result+=("$p")
    done
    SELECTED_PLUGINS=("${result[@]}")
  fi

  if in_array "zsh-autocomplete" "${SELECTED_PLUGINS[@]}" \
     && in_array "zsh-autosuggestions" "${SELECTED_PLUGINS[@]}"; then
    log_warn "zsh-autocomplete conflicts with zsh-autosuggestions; keeping zsh-autosuggestions only."
    result=()
    for p in "${SELECTED_PLUGINS[@]}"; do
      [ "$p" != "zsh-autocomplete" ] && result+=("$p")
    done
    SELECTED_PLUGINS=("${result[@]}")
  fi
}

# ============================================================================
# Step 5: Install (or update) plugins
# ============================================================================
install_plugins() {
  local plugins=("$@")

  if [ ${#plugins[@]} -eq 0 ]; then
    log_warn "No plugins selected"
    return 0
  fi

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local plugins_dir="$zsh_custom/plugins"

  log_info "Ensuring plugin directory exists: $plugins_dir"
  exec_cmd mkdir -p "$plugins_dir"

  local plugin repo path
  for plugin in "${plugins[@]}"; do
    log_info "Processing plugin: $plugin"

    if ! repo=$(plugin_repo "$plugin"); then
      log_error "Unknown plugin: $plugin — skipping"
      continue
    fi

    path="$plugins_dir/$plugin"

    if [ -d "$path/.git" ]; then
      log_info "Already present, updating $plugin..."
      if exec_cmd git -C "$path" pull --ff-only --quiet; then
        log_success "Plugin $plugin is up to date"
      else
        log_warn "Could not update $plugin (continuing with existing copy)"
      fi
    else
      # Remove a broken/partial directory from a previous failed run
      [ -d "$path" ] && exec_cmd rm -rf "$path"
      log_info "Cloning $repo"
      if exec_cmd git clone --depth 1 --quiet "https://github.com/${repo}.git" "$path"; then
        log_success "Plugin $plugin installed"
      else
        log_error "Failed to clone $plugin"
      fi
    fi
  done
}

# ============================================================================
# Step 6: Update ~/.zshrc
#   - Reads existing plugins from the plugins=(...) block (single or multi-line)
#   - Discards garbage tokens left by earlier broken runs ("[INFO]", "1)", ...)
#   - Merges, de-duplicates, resolves conflicts, enforces load order
#   - Rewrites the block with awk (no sed escaping issues)
# ============================================================================
is_valid_plugin_name() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

update_zshrc() {
  local new_plugins=("$@")
  local zshrc="$HOME/.zshrc"

  if [ ! -f "$zshrc" ]; then
    log_error ".zshrc not found at $zshrc"
    return 1
  fi

  local backup="${zshrc}.backup_$(date +%Y%m%d_%H%M%S)"
  exec_cmd cp "$zshrc" "$backup"
  log_success "Backed up .zshrc to $backup"

  # --- read existing plugins from the active block ---------------------------
  local existing_raw
  existing_raw=$(awk '
    /^[[:space:]]*plugins=\(/ && !seen { inblock=1; seen=1 }
    inblock {
      line=$0
      sub(/^[[:space:]]*plugins=\(/, "", line)
      sub(/#.*$/, "", line)
      closed = (line ~ /\)/)
      sub(/\).*$/, "", line)
      printf "%s ", line
      if (closed) exit
    }
  ' "$zshrc")

  # --- merge -----------------------------------------------------------------
  local merged=() tok
  # existing first (skip junk), then new ones
  for tok in $existing_raw "${new_plugins[@]}"; do
    is_valid_plugin_name "$tok" || continue
    in_array "$tok" "${merged[@]:-}" && continue
    merged+=("$tok")
  done

  # --- conflict resolution on the full merged list ---------------------------
  local tmp=()
  if in_array "fast-syntax-highlighting" "${merged[@]}" && in_array "zsh-syntax-highlighting" "${merged[@]}"; then
    for tok in "${merged[@]}"; do [ "$tok" != "zsh-syntax-highlighting" ] && tmp+=("$tok"); done
    merged=("${tmp[@]}"); tmp=()
    log_info "Removed duplicate syntax highlighter (kept fast-syntax-highlighting)"
  fi
  if in_array "zsh-autocomplete" "${merged[@]}" && in_array "zsh-autosuggestions" "${merged[@]}"; then
    for tok in "${merged[@]}"; do [ "$tok" != "zsh-autocomplete" ] && tmp+=("$tok"); done
    merged=("${tmp[@]}"); tmp=()
    log_info "Removed zsh-autocomplete (conflicts with zsh-autosuggestions)"
  fi

  # --- enforce load order: everything else first, LOAD_LAST at the end -------
  local ordered=() last
  for tok in "${merged[@]}"; do
    in_array "$tok" "${LOAD_LAST[@]}" || ordered+=("$tok")
  done
  for last in "${LOAD_LAST[@]}"; do
    in_array "$last" "${merged[@]}" && ordered+=("$last")
  done

  # Always keep git first if the user had it; add it if the block was empty
  if ! in_array "git" "${ordered[@]:-}"; then
    ordered=("git" "${ordered[@]:-}")
  fi

  local plugins_str="${ordered[*]}"

  if [ "$DRY_RUN" = true ]; then
    log_dry_run "Would set in .zshrc: plugins=($plugins_str)"
    return 0
  fi

  # --- rewrite the file ------------------------------------------------------
  local out
  out=$(mktemp)

  if grep -qE '^[[:space:]]*plugins=\(' "$zshrc"; then
    log_info "Updating existing plugins=(...) block"
    awk -v newline="plugins=($plugins_str)" '
      /^[[:space:]]*plugins=\(/ && !done {
        print newline
        done=1
        if ($0 !~ /\)/) skipping=1
        next
      }
      skipping { if ($0 ~ /\)/) skipping=0; next }
      { print }
    ' "$zshrc" > "$out"
  else
    log_info "No plugins=(...) line found, adding one"
    if grep -q '^ZSH_THEME=' "$zshrc"; then
      awk -v newline="plugins=($plugins_str)" '
        { print }
        /^ZSH_THEME=/ && !done { print newline; done=1 }
      ' "$zshrc" > "$out"
    else
      cp "$zshrc" "$out"
      printf '\nplugins=(%s)\n' "$plugins_str" >> "$out"
    fi
  fi

  # Sanity check before replacing: must contain exactly one active plugins line
  if [ "$(grep -cE '^[[:space:]]*plugins=\(' "$out")" -ne 1 ]; then
    log_error "Sanity check failed; leaving .zshrc untouched (backup at $backup)"
    rm -f "$out"
    return 1
  fi

  cat "$out" > "$zshrc"   # preserves original file mode/ownership
  rm -f "$out"

  log_success "Updated ~/.zshrc: plugins=($plugins_str)"
}

# ============================================================================
# Step 7: Offer to make zsh the default shell
# ============================================================================
maybe_change_shell() {
  [ "$ALLOW_CHSH" = true ] || return 0

  local zsh_path current_shell
  zsh_path=$(command -v zsh || true)
  [ -z "$zsh_path" ] && return 0

  current_shell="${SHELL:-}"
  if [ "$(basename "$current_shell")" = "zsh" ]; then
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry_run "Would offer to run: chsh -s $zsh_path"
    return 0
  fi

  local answer="n"
  if [ "$ASSUME_YES" = true ]; then
    answer="y"
  elif [ "$HAS_TTY" = true ]; then
    printf "Make zsh your default shell? [Y/n]: " >&2
    read -r answer </dev/tty || answer="n"
    answer="${answer:-y}"
  else
    return 0
  fi

  case "$answer" in
    y|Y|yes|YES)
      # zsh must be listed in /etc/shells
      if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null || true
      fi
      if chsh -s "$zsh_path" 2>/dev/null || $SUDO chsh -s "$zsh_path" "$(id -un)" 2>/dev/null; then
        log_success "Default shell changed to zsh (takes effect on next login)"
      else
        log_warn "Could not change shell automatically. Run: chsh -s $zsh_path"
      fi
      ;;
    *) log_info "Leaving default shell unchanged" ;;
  esac
}

# ============================================================================
# Main
# ============================================================================
main() {
  echo "" >&2
  [ "$DRY_RUN" = true ] && { log_info "DRY-RUN MODE: no changes will be made"; echo "" >&2; }

  log_info "Starting zsh setup..."
  echo "" >&2

  setup_sudo
  detect_pkg_mgr

  check_and_install_deps
  install_zsh
  install_oh_my_zsh

  select_plugins
  if [ ${#SELECTED_PLUGINS[@]} -gt 0 ]; then
    resolve_conflicts
  fi

  if [ ${#SELECTED_PLUGINS[@]} -gt 0 ]; then
    log_info "Selected plugins: ${SELECTED_PLUGINS[*]}"
    install_plugins "${SELECTED_PLUGINS[@]}"
    echo "" >&2
    update_zshrc "${SELECTED_PLUGINS[@]}"
  else
    log_warn "No plugins selected; still checking .zshrc for leftovers from earlier runs..."
    update_zshrc
  fi

  echo "" >&2
  maybe_change_shell

  echo "" >&2
  if [ "$DRY_RUN" = true ]; then
    log_success "Dry-run complete! No changes were made."
  else
    log_success "Setup complete!"
    log_info "Apply changes now with: exec zsh"
  fi
  echo "" >&2
}

main "$@"