#!/usr/bin/env zsh

set -e

# List of plugins you want to ensure are installed
PLUGINS=(
  zsh-autosuggestions
  zsh-syntax-highlighting
  fast-syntax-highlighting
  zsh-autocomplete
  you-should-use
)

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"
ZSHRC="$HOME/.zshrc"

echo "Ensuring plugin directory exists: $PLUGINS_DIR"
mkdir -p "$PLUGINS_DIR"

for p in "${PLUGINS[@]}"; do
  echo "Processing plugin: $p"
  repo=""
  case "$p" in
    zsh-autosuggestions) repo="zsh-users/zsh-autosuggestions" ;;
    zsh-syntax-highlighting) repo="zsh-users/zsh-syntax-highlighting" ;;
    fast-syntax-highlighting) repo="zdharma-continuum/fast-syntax-highlighting" ;;
    zsh-autocomplete) repo="marlonrichert/zsh-autocomplete" ;;
    you-should-use) repo="MichaelAquilina/zsh-you-should-use" ;;  # <-- replace with actual repo if exists
    *) echo "Unknown plugin: $p — skipping clone"; continue ;;
  esac
# https://github.com/MichaelAquilina/zsh-you-should-use
  PLUGIN_PATH="$PLUGINS_DIR/$p"

  if [ ! -d "$PLUGIN_PATH" ]; then
    echo "Cloning $repo into $PLUGIN_PATH"
    git clone --depth 1 "https://github.com/${repo}.git" "$PLUGIN_PATH"
  else
    echo "Plugin $p already present, skipping clone"
  fi
done

# Backup existing .zshrc
cp "$ZSHRC" "${ZSHRC}.backup_$(date +%Y%m%d_%H%M%S)"

# Build new plugins line
# First, read existing plugins (if any)
old_plugins=$(grep -E "^plugins=\(" "$ZSHRC" || true)
if [ -z "$old_plugins" ]; then
  # no plugins= found; insert at top
  echo "plugins=(${PLUGINS[*]})" >> "$ZSHRC"
else
  # extract inside of parentheses
  inside=$(echo "$old_plugins" | sed -E 's/plugins=\((.*)\)/\1/')
  # build list, avoiding duplicates
  for p in "${PLUGINS[@]}"; do
    if ! echo "$inside" | grep -qw "$p"; then
      inside="$inside $p"
    fi
  done
  # replace plugins= line
  sed -i -E "s|^plugins=\(.*\)|plugins=($inside)|" "$ZSHRC"
fi

echo "Updated ~/.zshrc plugins line."

# Optionally source .zshrc to apply changes
echo "Sourcing ~/.zshrc..."
source "$ZSHRC"

echo "Done. Please restart shell to ensure everything loads correctly."
