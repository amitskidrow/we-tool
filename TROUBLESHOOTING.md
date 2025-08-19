# Troubleshooting Guide

## Common Issues and Solutions

### Installation Issues

#### `uv` not found
```bash
# Install uv (recommended method)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or via pip
pip install uv
```

#### `make` not found
```bash
# Ubuntu/Debian
sudo apt install make

# Arch Linux
sudo pacman -S make

# macOS
xcode-select --install
```

### Service Issues

#### Service won't start
1. **Check if service is already running:**
   ```bash
   make ps
   ```

2. **Run in doctor mode for debugging:**
   ```bash
   make doctor
   ```

3. **Check systemd user session:**
   ```bash
   systemctl --user status
   ```

4. **Verify Python environment:**
   ```bash
   uv run -- python -c "print('Python works')"
   ```

#### Service starts but crashes immediately
1. **Check logs:**
   ```bash
   make logs
   # or
   make journal
   ```

2. **Verify entry point:**
   ```bash
   # Test your entry point directly
   uv run -- python your_entry.py
   ```

3. **Check dependencies:**
   ```bash
   uv sync
   ```

### Live Reload Issues

#### `watchexec` not found
```bash
# Install watchexec
# Ubuntu/Debian (via cargo)
cargo install watchexec-cli

# Arch Linux
sudo pacman -S watchexec

# macOS
brew install watchexec
```

#### Live reload not triggering
1. **Check ignore patterns** in your project
2. **Verify file changes are in watched directories**
3. **Test watchexec directly:**
   ```bash
   watchexec --version
   ```

### Permission Issues

#### systemd user session not available
```bash
# Enable user session
sudo loginctl enable-linger $USER

# Start user session
systemctl --user daemon-reload
```

#### Log directory permissions
```bash
# Check state directory
ls -la ~/.local/state/we/

# Fix permissions if needed
chmod -R u+w ~/.local/state/we/
```

### Development Issues

#### Pre-commit hooks failing
```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

#### Tests failing
```bash
# Install bats
# Ubuntu/Debian
sudo apt install bats

# Arch Linux
sudo pacman -S bats

# macOS
brew install bats-core

# Run tests
make -f Makefile.dev test
```

### Multi-Service Projects

#### Wrong service selected
```bash
# List all services
make ps

# Specify service explicitly
SERVICE=my-service make up
```

#### Service conflicts
```bash
# Stop all services
make down

# Check for running units
systemctl --user list-units 'we-*'
```

## Environment Variables

### Debug Mode
```bash
# Enable verbose output
export DEBUG=1
make up
```

### Custom Paths
```bash
# Custom state directory
export XDG_STATE_HOME=/custom/path
make up
```

## Getting Help

### Check System Status
```bash
# Full system check
make -f Makefile.dev check

# Python CLI help
uv run -- python tools/uuctl.py --help

# Validate Makefile
./tools/we-validate-makefile.sh
```

### Logs and Debugging
```bash
# Recent logs
make logs

# Follow live logs
make follow

# systemd journal
make journal

# Service status
make ps

# Unit details
make unit
```

### Reset Everything
```bash
# Stop all services
make down

# Clean logs
rm -rf ~/.local/state/we/

# Regenerate Makefile
./we . --service YOUR_SERVICE --entry YOUR_ENTRY --yes
```

## Known Limitations

1. **Linux/WSL only** - Requires systemd user session
2. **Single entry point** - Each service needs one main entry point
3. **uv dependency** - Requires uv for Python environment management

## Reporting Issues

When reporting issues, please include:

1. **System information:**
   ```bash
   uname -a
   python --version
   uv --version
   make --version
   ```

2. **Service configuration:**
   ```bash
   head -20 Makefile
   ```

3. **Error logs:**
   ```bash
   make logs
   make journal
   ```

4. **Steps to reproduce** the issue