# "we" Quick Reference Card

## Installation
```bash
./install.sh                    # Install to ~/.local/bin
./we --help                     # Show help
```

## Project Setup
```bash
./we . --service NAME --entry main.py --yes    # Generate Makefile + README
```

## Service Commands
```bash
make up                         # Start service
make up RELOAD=1               # Start with live reload
make down                      # Stop service
make ps                        # Show status
make logs                      # Recent logs
make follow                    # Follow logs live
make restart                   # Restart service
make doctor                    # Run in foreground (debug)
make unit                      # systemd unit details
make journal                   # systemd journal logs
```

## Multi-Service Projects
```bash
SERVICE=api make up            # Start specific service
make ps                        # Show all services
```

## Development Workflow
```bash
make -f Makefile.dev setup-dev # Setup development environment
make -f Makefile.dev check     # Run all quality checks
make -f Makefile.dev test      # Run integration tests
make -f Makefile.dev format    # Format all code
make -f Makefile.dev ci        # Simulate CI pipeline
```

## Environment Variables
- `RELOAD=1` - Enable live reload with watchexec
- `SECURE=1` - Enable systemd security hardening  
- `SERVICE=name` - Target specific service
- `DEBUG=1` - Enable verbose output

## Troubleshooting
```bash
make doctor                    # Debug mode
make journal                   # Check systemd logs
systemctl --user status       # Check user session
uv run -- python entry.py     # Test entry point directly
```

## File Locations
- **Logs**: `~/.local/state/we/SERVICE/logs/`
- **Run logs**: `.we/SERVICE/run.log`
- **Generated**: `Makefile`, `README.md`, `.gitignore`

## Requirements
- Python 3.8+ with `uv`
- systemd user session (Linux/WSL)
- GNU Make
- Optional: watchexec, bats-core, pre-commit

---
*"we" development tool - Production Ready ✅*