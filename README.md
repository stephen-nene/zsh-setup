


# Zsh Installation Script - Testing Guide

This project includes a comprehensive zsh installation and plugin configuration script with a complete Docker-based testing framework.

## Install Zsh

Run the setup script directly:

```sh
curl -fsSL https://raw.githubusercontent.com/stephen-nene/zsh-setup/master/src/install-zsh.sh | zsh
````

> ⚠️ Review scripts before piping them to a shell.



---

## 🔐 Safer alternative (no pipe-to-shell)

For users who prefer safety:

```sh
curl -fsSL https://raw.githubusercontent.com/stephen-nene/zsh-setup/master/src/install-zsh.sh -o install-zsh.sh.sh
chmod +x install-zsh.sh
./install-zsh.sh
````

---


## Features

✓ **Automatic dependency checking** - Installs git, wget/curl if needed
✓ **Zsh installation** - Detects and installs zsh if missing
✓ **Oh My Zsh setup** - Non-interactive installation with skip-chsh
✓ **Interactive plugin selection** - Choose which plugins to install
✓ **Safe updates** - Backs up .zshrc before modifying with timestamps
✓ **Multi-distro support** - Test on Ubuntu, Debian, Alpine
✓ **Clean testing** - Docker containers reset for each test

## Quick Start

### 1. Prerequisites

- Docker and Docker Compose installed
- Bash shell
- Git (optional, for cloning the repo)



### 2. Setup

```bash
# Make scripts executable
chmod +x install-zsh.sh test.sh automated-test.sh

# Build all Docker images
./test.sh build
```

### 3. Testing Options

#### Manual Interactive Testing (Recommended for debugging)

Test in a specific environment with full shell access:

```bash
# Test in Ubuntu latest
./test.sh run ubuntu-latest

# Test in Alpine
./test.sh run alpine

# Test in any environment (will prompt you to choose)
./test.sh run
```

Inside the container, run:

```bash
# Basic test - prompts for plugin selection
bash /tmp/install-zsh.sh

# Or provide input via pipe
echo "all" | bash /tmp/install-zsh.sh

# Or use specific selections
echo "1,2,4" | bash /tmp/install-zsh.sh

# Or select no plugins
echo "none" | bash /tmp/install-zsh.sh
```

#### Automated Testing

Run predefined tests across all environments:

```bash
# Run automated tests in all services
./test.sh test

# Run automated tests in specific service
./test.sh test ubuntu-latest
```

#### Isolated Automated Tests

For more control:

```bash
chmod +x automated-test.sh
./automated-test.sh
```

### 4. File Structure

```
.
├── install-zsh.sh           # Main installation script
├── test.sh                  # Testing helper script
├── automated-test.sh        # Automated test suite
├── docker-compose.yml       # Docker Compose configuration
├── Dockerfile.ubuntu        # Ubuntu/Debian base image
├── Dockerfile.debian        # Debian specific image
├── Dockerfile.alpine        # Alpine Linux image
└── README.md                # This file
```

## Script Features in Detail

### install-zsh.sh

#### Step 1: Dependency Check
Verifies and installs git, wget, or curl. Supports:
- apt-get (Ubuntu/Debian)
- yum (CentOS/RHEL)
- apk (Alpine)

#### Step 2: Zsh Installation
Checks if zsh is installed. If not, installs via system package manager.

#### Step 3: Oh My Zsh Setup
Downloads and runs Oh My Zsh installer in unattended mode with `--skip-chsh` to avoid changing the default shell automatically.

#### Step 4: Plugin Selection
Interactive menu to choose which plugins to install:

```
[INFO] Available plugins:
  1) zsh-autosuggestions
  2) zsh-syntax-highlighting
  3) fast-syntax-highlighting
  4) zsh-autocomplete
  5) you-should-use

Enter plugin numbers to install (comma-separated, or 'all' for all, or 'none'):
```

Valid inputs:
- `all` - Install all plugins
- `none` - Skip plugin installation
- `1,2,4` - Install plugins 1, 2, and 4
- `1, 3, 5` - Works with spaces too

#### Step 5: Plugin Installation
Clones each selected plugin repository into `~/.oh-my-zsh/custom/plugins/`

#### Step 6: .zshrc Configuration
- **Backs up** the original `.zshrc` with timestamp: `.zshrc.backup_20240215_143022`
- **Updates** the `plugins=()` line with selected plugins
- **Avoids duplicates** if plugins are already present
- **Creates** a `plugins=()` line if none exists

## Testing Workflow

### Complete Test Cycle

```bash
# 1. Build all images
./test.sh build

# 2. Run interactive test in Ubuntu
./test.sh run ubuntu-latest

# 3. Inside container: test the script
bash /tmp/install-zsh.sh
# Follow prompts, select "1,2" for first two plugins

# 4. Verify installation
which zsh
cat ~/.zshrc | grep plugins=
ls ~/.oh-my-zsh/custom/plugins/

# 5. Exit and test in different environment
exit
./test.sh run alpine

# 6. When done, clean up
./test.sh clean
```

### Testing Failed Scenarios

Each Docker container is fresh, so you can test failure cases:

```bash
./test.sh run ubuntu-latest

# Inside container:
# Test what happens if git fails
sudo mv /usr/bin/git /usr/bin/git.bak
bash /tmp/install-zsh.sh  # Should show error for git

# Restore and test
sudo mv /usr/bin/git.bak /usr/bin/git

# Test invalid plugin selection
echo "999" | bash /tmp/install-zsh.sh
```

## Troubleshooting

### Docker Issues

```bash
# If images won't build
docker-compose down --rmi all
./test.sh build

# If containers hang
docker-compose ps
docker-compose kill
```

### Script Issues in Container

```bash
# Debug with more verbosity
bash -x /tmp/install-zsh.sh

# Check Oh My Zsh directory
ls -la ~/.oh-my-zsh

# Check plugin directory
ls -la ~/.oh-my-zsh/custom/plugins/

# View backups
ls -la ~/.zshrc.backup*
```

### Backups

Each time the script modifies `.zshrc`, it creates a timestamped backup:

```bash
# List all backups
ls -1 ~/.zshrc.backup*

# Restore a backup
cp ~/.zshrc.backup_20240215_143022 ~/.zshrc
```

## Running the Script Locally (Outside Docker)

```bash
# Make executable
chmod +x install-zsh.sh

# Run the script
./install-zsh.sh

# Select plugins when prompted
# Follow the interactive menu
```

## Supported Environments

| OS | Version | Status |
|----|---------|--------|
| Ubuntu | Latest | ✓ |
| Ubuntu | Focal (20.04) | ✓ |
| Debian | Bullseye (11) | ✓ |
| Alpine | Latest | ✓ |

## Plugin Details

| Plugin | Repository | Purpose |
|--------|-----------|---------|
| zsh-autosuggestions | zsh-users/zsh-autosuggestions | Fish-like autosuggestions |
| zsh-syntax-highlighting | zsh-users/zsh-syntax-highlighting | Syntax highlighting |
| fast-syntax-highlighting | zdharma-continuum/fast-syntax-highlighting | Faster syntax highlighting |
| zsh-autocomplete | marlonrichert/zsh-autocomplete | Enhanced autocomplete |
| you-should-use | MichaelAquilina/zsh-you-should-use | Alias reminders |

## Advanced Usage

### Building Single Images

```bash
./test.sh build ubuntu-latest
./test.sh build alpine
```

### Creating Your Own Test Case

Edit `automated-test.sh` and add:

```bash
test_case "my-test" "2,3,5" "Testing a custom plugin combination"
```

### Using Docker Directly

```bash
# Build specific service
docker-compose build ubuntu-latest

# Run interactive shell
docker-compose run --rm ubuntu-latest bash

# Run command in container
docker-compose run --rm ubuntu-latest bash /tmp/install-zsh.sh

# Execute with specific input
docker-compose run --rm ubuntu-latest bash -c 'echo "all" | bash /tmp/install-zsh.sh'
```

## Tips for Effective Testing

1. **Always test in clean containers** - Use `./test.sh run` to get a fresh environment
2. **Test failure paths** - Deliberately break things to see error handling
3. **Test multiple shells** - Run across different distros to catch compatibility issues
4. **Check backups** - Verify `.zshrc.backup_*` files are created with timestamps
5. **Verify idempotency** - Run the script twice, it should not fail the second time
6. **Test plugin selection combinations** - Try `none`, `all`, and specific numbers

## Contributing & Improvements

Found an issue or want to improve? Consider:

- Adding more distro support (CentOS, Fedora, Arch)
- Adding non-interactive mode flag
- Adding plugin validation
- Adding rollback functionality
- Adding plugin custom repository support

## License

MIT License - feel free to use and modify
