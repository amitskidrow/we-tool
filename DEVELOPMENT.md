# Development Guide

## Project Architecture

**"we"** implements a **"Shell as glue, logic in Python tools"** architecture per NEW_CHANGES.MD:

```
User Command (make up)
    ↓
Generated Makefile
    ↓
Python CLI (tools/uuctl.py)
    ↓
systemd-run --user
    ↓
Your Service
```

### Key Components

```
we                           # Main CLI (bash) - generates Makefiles
├── lib/we/
│   ├── common.sh           # Utilities
│   ├── args.sh             # CLI argument parsing  
│   ├── project.sh          # uv project resolution
│   ├── fs.sh               # Makefile/README generation
│   └── watchexec.sh        # watchexec command composition
├── tools/
│   ├── uuctl.py            # Python CLI with Typer (9 commands)
│   ├── we-validate-makefile.sh # Makefile validator
│   └── run-we-fixture-tests.sh # Smoke tests
└── tests/
    └── test_we_integration.bats # Integration tests
```

## Development Workflow

### Setup Development Environment

```bash
# Install development dependencies
make -f Makefile.dev setup-dev

# This installs:
# - Pre-commit hooks (ShellCheck, Black, Ruff)
# - Python dependencies via uv
# - Development tools
```

### Quality Gates Pipeline

```bash
# Run all quality checks
make -f Makefile.dev check

# Individual checks:
make -f Makefile.dev lint      # ShellCheck + Ruff
make -f Makefile.dev format    # shfmt + Black + Ruff
make -f Makefile.dev test      # Integration tests
make -f Makefile.dev validate  # Makefile structure
```

### Testing Strategy

#### 1. Integration Tests (bats)
```bash
# Run all integration tests
make -f Makefile.dev test

# Tests cover:
# ✅ Makefile generation
# ✅ Python CLI integration  
# ✅ Environment variable passing
# ✅ README generation
# ✅ Target completeness
# ✅ Gitignore management
# ⚠️ Doctor mode (environment-dependent)
# ⚠️ Status reporting (environment-dependent)
```

#### 2. Python CLI Tests
```bash
# Quick Python CLI validation
make -f Makefile.dev test-python

# Manual testing
uv run -- python tools/uuctl.py --help
uv run -- python tools/uuctl.py up --help
```

#### 3. Makefile Validation
```bash
# Validate generated Makefiles
./tools/we-validate-makefile.sh

# Test with real project
cd /tmp && mkdir test-proj && cd test-proj
echo '[project]\nname="test"\nversion="0.1.0"' > pyproject.toml
echo 'def main(): print("test")' > main.py
/path/to/we . --service test --entry main.py --yes
make doctor  # Should work
```

## Code Style and Standards

### Shell Scripts
- **ShellCheck compliant** - All warnings addressed or documented
- **shfmt formatted** - 2-space indentation, simplified syntax
- **Minimal logic** - Only glue code, real logic in Python

### Python Code
- **Black formatted** - Consistent code style
- **Ruff linted** - Fast, comprehensive linting
- **Typer CLI** - Rich help, validation, error handling
- **Type hints** - Where beneficial for clarity

### Pre-commit Hooks
Automatically run on commit:
- ShellCheck (shell script analysis)
- shfmt (shell formatting)
- Black (Python formatting)
- Ruff (Python linting)
- General hooks (trailing whitespace, YAML validation)

## Making Changes

### 1. Shell Components (`lib/we/`)
```bash
# Edit shell files
vim lib/we/fs.sh

# Check with ShellCheck
shellcheck lib/we/fs.sh

# Test integration
./we /tmp/test-project --service test --entry main.py --yes
```

### 2. Python CLI (`tools/uuctl.py`)
```bash
# Edit Python CLI
vim tools/uuctl.py

# Format and lint
uv run black tools/uuctl.py
uv run ruff check tools/uuctl.py

# Test standalone
uv run -- python tools/uuctl.py --help

# Test integration
cd /tmp/test-project && make up
```

### 3. Tests (`tests/`)
```bash
# Edit tests
vim tests/test_we_integration.bats

# Run specific test
bats tests/test_we_integration.bats -f "generates Makefile"

# Run all tests
make -f Makefile.dev test
```

## Release Process

### 1. Pre-release Validation
```bash
# Full quality pipeline
make -f Makefile.dev ci

# Manual smoke test
cd /tmp && mkdir release-test && cd release-test
echo '[project]\nname="release-test"\nversion="0.1.0"' > pyproject.toml
echo 'def main(): print("Release test")' > main.py
/path/to/we . --service release-test --entry main.py --yes
make doctor  # Should work without errors
```

### 2. Version Management
- Update version in `pyproject.toml` if needed
- Update any version references in documentation
- Tag release: `git tag v1.0.0`

### 3. Installation Testing
```bash
# Test installation
./install.sh

# Verify installation
~/.local/bin/we --help
```

## Debugging

### Shell Issues
```bash
# Enable shell debugging
bash -x ./we . --service test --entry main.py --yes

# Check specific shell functions
source lib/we/common.sh
source lib/we/project.sh
# Test functions individually
```

### Python Issues
```bash
# Debug Python CLI
uv run -- python -c "
import sys
sys.path.insert(0, 'tools')
from uuctl import app
app()
"

# Check environment passing
cd /tmp/test-project
SERVICE=test PROJECT=/tmp/test-project ENTRY=main.py \
  uv run -- python tools/uuctl.py doctor
```

### systemd Issues
```bash
# Check user session
systemctl --user status

# List running units
systemctl --user list-units 'we-*'

# Check specific unit
systemctl --user status we-test-12345678

# View logs
journalctl --user -u we-test-12345678
```

## Performance Considerations

### Startup Time
- **uv** is fast for Python environment setup
- **systemd-run** has minimal overhead
- **Make** target resolution is instant

### Memory Usage
- Services run in separate systemd units
- No persistent daemon processes
- Logs are rotated automatically

### File Watching (RELOAD=1)
- **watchexec** is efficient for file monitoring
- Ignore patterns reduce unnecessary triggers
- Debouncing prevents rapid restarts

## Contributing

1. **Fork and clone** the repository
2. **Setup development environment**: `make -f Makefile.dev setup-dev`
3. **Make changes** following code style guidelines
4. **Run quality checks**: `make -f Makefile.dev check`
5. **Test thoroughly** with real projects
6. **Submit pull request** with clear description

### Pull Request Checklist
- [ ] All quality checks pass
- [ ] Integration tests pass (7/9 minimum)
- [ ] Manual testing completed
- [ ] Documentation updated if needed
- [ ] No breaking changes to user interface