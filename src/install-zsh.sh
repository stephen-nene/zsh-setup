#!/usr/bin/env bash
set -e

# Parse arguments
DRY_RUN=false
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
  esac
done

# Check environment variable
if [ "$DRY_RUN_ENV" = "1" ]; then
  DRY_RUN=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[✗]${NC} $1"
}

log_dry_run() {
  echo -e "${MAGENTA}[DRY-RUN]${NC} $1"
}

# Execute command or show what would be executed
exec_cmd() {
  if [ "$DRY_RUN" = true ]; then
    log_dry_run "Would execute: $*"
    return 0
  else
    "$@"
  fi
}

# ============================================================================
# Step 1: Check and install dependencies (wget/curl, git)
# ============================================================================
check_and_install_deps() {
  log_info "Checking dependencies..."

  # Check for git
  if ! command -v git &> /dev/null; then
    log_warn "git not found, installing..."
    if command -v apt-get &> /dev/null; then
      exec_cmd sudo apt-get update && exec_cmd sudo apt-get install -y git
    elif command -v yum &> /dev/null; then
      exec_cmd sudo yum install -y git
    elif command -v apk &> /dev/null; then
      exec_cmd sudo apk add --no-cache git
    else
      log_error "Could not install git. Please install it manually."
      exit 1
    fi
  fi
  log_success "git is available"

  # Check for wget or curl
  if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
    log_warn "Neither wget nor curl found, installing curl..."
    if command -v apt-get &> /dev/null; then
      exec_cmd sudo apt-get update && exec_cmd sudo apt-get install -y curl
    elif command -v yum &> /dev/null; then
      exec_cmd sudo yum install -y curl
    elif command -v apk &> /dev/null; then
      exec_cmd sudo apk add --no-cache curl
    else
      log_error "Could not install curl. Please install it manually."
      exit 1
    fi
  fi
  log_success "wget/curl is available"
}

# ============================================================================
# Step 2: Install zsh if not already installed
# ============================================================================
install_zsh() {
  if command -v zsh &> /dev/null; then
    log_success "zsh is already installed: $(zsh --version)"
    return 0
  fi

  log_info "Installing zsh..."

  if command -v apt-get &> /dev/null; then
    exec_cmd sudo apt-get update && exec_cmd sudo apt-get install -y zsh
  elif command -v yum &> /dev/null; then
    exec_cmd sudo yum install -y zsh
  elif command -v apk &> /dev/null; then
    exec_cmd sudo apk add --no-cache zsh
  else
    log_error "Unsupported package manager. Please install zsh manually."
    exit 1
  fi

  if [ "$DRY_RUN" = true ]; then
    log_success "Would install zsh successfully"
  else
    log_success "zsh installed successfully: $(zsh --version)"
  fi
}

# ============================================================================
# Step 3: Install Oh My Zsh if not already installed
# ============================================================================
install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log_success "Oh My Zsh is already installed"
    return 0
  fi

  log_info "Installing Oh My Zsh..."

  if [ "$DRY_RUN" = true ]; then
    log_dry_run "Would download Oh My Zsh installer"
    log_dry_run "Would run: sh -c \"<installer>\" \"\" --unattended --skip-chsh"
    log_success "Would install Oh My Zsh successfully"
    return 0
  fi

  local install_script
  if command -v curl &> /dev/null; then
    install_script=$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)
  elif command -v wget &> /dev/null; then
    install_script=$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)
  else
    log_error "Neither curl nor wget available. Cannot download Oh My Zsh installer."
    exit 1
  fi

  # Run installer non-interactively (don't change shell)
  sh -c "$install_script" "" --unattended --skip-chsh 2>/dev/null

  log_success "Oh My Zsh installed successfully"
}

# ============================================================================
# Step 4: Select plugins interactively
# ============================================================================
select_plugins() {
  local available_plugins=(
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "fast-syntax-highlighting"
    "zsh-autocomplete"
    "you-should-use"
  )

  local selected_plugins=()
  local i=1

  echo ""
  log_info "Available plugins:"
  for plugin in "${available_plugins[@]}"; do
    echo "  $i) $plugin"
    ((i++))
  done
  echo ""

  read -p "Enter plugin numbers to install (comma-separated, or 'all' for all, or 'none'): " choice

  if [ "$choice" = "all" ]; then
    selected_plugins=("${available_plugins[@]}")
  elif [ "$choice" = "none" ]; then
    selected_plugins=()
  else
    # Parse comma-separated numbers
    IFS=',' read -ra nums <<< "$choice"
    for num in "${nums[@]}"; do
      num=$(echo "$num" | xargs) # trim whitespace
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#available_plugins[@]} ]; then
        selected_plugins+=("${available_plugins[$((num-1))]}")
      else
        log_warn "Invalid selection: $num"
      fi
    done
  fi

  echo "${selected_plugins[@]}"
}

# ============================================================================
# Step 5: Install selected plugins
# ============================================================================
install_plugins() {
  local plugins=("$@")

  if [ ${#plugins[@]} -eq 0 ]; then
    log_warn "No plugins selected"
    return 0
  fi

  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local PLUGINS_DIR="$ZSH_CUSTOM/plugins"

  log_info "Ensuring plugin directory exists: $PLUGINS_DIR"
  exec_cmd mkdir -p "$PLUGINS_DIR"

  local plugin_map=(
    "zsh-autosuggestions:zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting:zsh-users/zsh-syntax-highlighting"
    "fast-syntax-highlighting:zdharma-continuum/fast-syntax-highlighting"
    "zsh-autocomplete:marlonrichert/zsh-autocomplete"
    "you-should-use:MichaelAquilina/zsh-you-should-use"
  )

  for plugin in "${plugins[@]}"; do
    log_info "Processing plugin: $plugin"

    local repo=""
    for mapping in "${plugin_map[@]}"; do
      IFS=':' read -r name url <<< "$mapping"
      if [ "$name" = "$plugin" ]; then
        repo="$url"
        break
      fi
    done

    if [ -z "$repo" ]; then
      log_error "Unknown plugin: $plugin — skipping"
      continue
    fi

    local PLUGIN_PATH="$PLUGINS_DIR/$plugin"
    if [ ! -d "$PLUGIN_PATH" ] || [ "$DRY_RUN" = true ]; then
      log_info "Cloning $repo into $PLUGIN_PATH"
      if exec_cmd git clone --depth 1 "https://github.com/${repo}.git" "$PLUGIN_PATH"; then
        log_success "Plugin $plugin cloned successfully"
      else
        log_error "Failed to clone $plugin"
      fi
    else
      log_success "Plugin $plugin already present, skipping clone"
    fi
  done
}

# ============================================================================
# Step 6: Update .zshrc with plugins
# ============================================================================
update_zshrc() {
  local plugins=("$@")
  local ZSHRC="$HOME/.zshrc"

  if [ ! -f "$ZSHRC" ]; then
    log_error ".zshrc not found at $ZSHRC"
    return 1
  fi

  # Backup existing .zshrc with timestamp
  local backup_file="${ZSHRC}.backup_$(date +%Y%m%d_%H%M%S)"
  exec_cmd cp "$ZSHRC" "$backup_file"
  log_success "Backed up .zshrc to $backup_file"

  if [ ${#plugins[@]} -eq 0 ]; then
    log_warn "No plugins to add to .zshrc"
    return 0
  fi

  # Build plugins string
  local plugins_str="${plugins[0]}"
  for ((i=1; i<${#plugins[@]}; i++)); do
    plugins_str="$plugins_str ${plugins[$i]}"
  done

  if [ "$DRY_RUN" = true ]; then
    log_dry_run "Would update .zshrc with plugins: $plugins_str"
    return 0
  fi

  # Check if plugins= line exists
  if grep -q "^plugins=(" "$ZSHRC"; then
    log_info "Found existing plugins= line, updating..."

    # Extract existing plugins
    local inside=$(grep "^plugins=(" "$ZSHRC" | sed -E 's/plugins=\((.*)\)/\1/')

    # Add new plugins, avoiding duplicates
    for plugin in "${plugins[@]}"; do
      if ! echo "$inside" | grep -qw "$plugin"; then
        inside="$inside $plugin"
      fi
    done

    # Replace the line (escape special characters for sed)
    inside=$(echo "$inside" | sed 's/[&/\]/\\&/g')
    sed -i "s/^plugins=(.*)$/plugins=($inside)/" "$ZSHRC"
  else
    log_info "No plugins= line found, adding one..."
    # Find a good place to insert (after ZSH_THEME line ideally)
    if grep -q "^ZSH_THEME=" "$ZSHRC"; then
      sed -i "/^ZSH_THEME=/a plugins=($plugins_str)" "$ZSHRC"
    else
      echo "plugins=($plugins_str)" >> "$ZSHRC"
    fi
  fi

  log_success "Updated ~/.zshrc with plugins"
}

# ============================================================================
# Main execution
# ============================================================================
main() {
  if [ "$DRY_RUN" = true ]; then
    echo ""
    log_info "DRY-RUN MODE: No actual changes will be made"
    echo ""
  fi

  echo ""
  log_info "Starting zsh setup..."
  echo ""

  check_and_install_deps
  echo ""

  install_zsh
  echo ""

  install_oh_my_zsh
  echo ""

  local selected_plugins=($(select_plugins))
  echo ""

  if [ ${#selected_plugins[@]} -gt 0 ]; then
    log_info "Selected plugins: ${selected_plugins[*]}"
    install_plugins "${selected_plugins[@]}"
    echo ""
    update_zshrc "${selected_plugins[@]}"
  else
    log_warn "No plugins selected"
  fi

  echo ""
  if [ "$DRY_RUN" = true ]; then
    log_success "Dry-run complete! No changes were made."
  else
    log_success "Setup complete!"
    echo ""
    log_info "To apply changes, restart your shell or run: exec zsh"
  fi
  echo ""
}

main "$@"
