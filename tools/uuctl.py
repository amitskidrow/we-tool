#!/usr/bin/env python3
"""
uuctl - Python CLI for 'we' development runner
Implements the core logic for service management via systemd-run --user
"""

import os
import subprocess
import hashlib
from pathlib import Path
from typing import Optional, List
import typer
from rich.console import Console
import shutil

app = typer.Typer(
    name="uuctl",
    help="Development service controller for 'we' tool",
    add_completion=False,
)
console = Console()


class ServiceConfig:
    """Configuration for a service derived from environment and project structure"""

    def __init__(self):
        # Get from environment (set by Make)
        self.service = os.environ.get("SERVICE", "")
        self.project = os.environ.get("PROJECT", "")
        self.entry = os.environ.get("ENTRY", "")
        self.reload = os.environ.get("RELOAD", "1") == "1"
        self.keep_n = int(os.environ.get("KEEP_N", "10"))
        self.tail = int(os.environ.get("TAIL", "100"))
        self.secure = os.environ.get("SECURE", "0") == "1"

        # Computed values
        self.unit_suffix = self._compute_unit_suffix()
        self.unit = f"we-{self.service}-{self.unit_suffix}"

        # Paths (under project directory)
        project_path = Path(self.project).resolve() if self.project else Path.cwd()
        self.project_path = project_path
        self.rundir = project_path / ".we" / self.service
        self.runlog = self.rundir / "run.log"
        self.logdir = self.rundir / "logs"
        # PID file at project root
        self.pid_file = project_path / ".we.pid"

        # Commands
        self.wex_cmd = [
            "watchexec",
            "--restart",
            "--watch",
            ".",
            "--exts",
            "py",
            "--ignore",
            ".we",
            "--ignore",
            ".uu",
            "--ignore",
            ".git",
            "--ignore",
            ".venv",
            "--",
        ]

    def _compute_unit_suffix(self) -> str:
        """Compute 8-char hash suffix for unit name"""
        abs_path = os.path.abspath(".")
        return hashlib.sha1(abs_path.encode()).hexdigest()[:8]

    def get_uv_cmd(self) -> List[str]:
        """Get the uv run command for this service"""
        base_cmd = ["uv", "run", "--project", self.project, "--", self.entry]
        if self.reload:
            # Check if watchexec is available
            if not shutil.which("watchexec"):
                console.print("[red]ERROR: watchexec not found in PATH. Please install it or set RELOAD=0[/red]")
                raise typer.Exit(1)
            return self.wex_cmd + base_cmd
        return base_cmd

    def validate(self):
        """Validate required configuration"""
        if not self.service:
            console.print("[red]ERROR: SERVICE environment variable not set[/red]")
            raise typer.Exit(1)
        if not self.project:
            console.print("[red]ERROR: PROJECT environment variable not set[/red]")
            raise typer.Exit(1)
        if not self.entry:
            console.print("[red]ERROR: ENTRY environment variable not set[/red]")
            raise typer.Exit(1)


def run_cmd(
    cmd: List[str], check: bool = True, capture: bool = False
) -> subprocess.CompletedProcess:
    """Run a command with optional error handling"""
    try:
        if capture:
            return subprocess.run(cmd, check=check, capture_output=True, text=True)
        else:
            return subprocess.run(cmd, check=check)
    except subprocess.CalledProcessError as e:
        if check:
            console.print(f"[red]Command failed: {' '.join(cmd)}[/red]")
            console.print(f"[red]Exit code: {e.returncode}[/red]")
            raise typer.Exit(e.returncode)
        return e


def unit_is_active(unit: str) -> bool:
    try:
        subprocess.run(
            ["systemctl", "--user", "is-active", "--quiet", unit],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def get_main_pid(unit: str) -> int:
    try:
        res = subprocess.run(
            ["systemctl", "--user", "show", "-p", "MainPID", "--value", unit],
            check=True,
            capture_output=True,
            text=True,
        )
        pid_s = res.stdout.strip()
        return int(pid_s) if pid_s.isdigit() else 0
    except Exception:
        return 0


@app.command()
def up(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Start the service using systemd-run --user"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()
    # Ensure directories exist under project
    config.logdir.mkdir(parents=True, exist_ok=True)
    config.rundir.mkdir(parents=True, exist_ok=True)

    # Create archive log file and symlink
    from datetime import datetime

    timestamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    archive_log = (
        config.logdir / f"{config.service}-{timestamp}-{config.unit_suffix}.log"
    )

    # Create symlink to current run log
    if config.runlog.exists() or config.runlog.is_symlink():
        config.runlog.unlink()
    config.runlog.symlink_to(archive_log.absolute())

    # If already active, be idempotent
    if unit_is_active(config.unit):
        console.print(f"[yellow]Unit {config.unit} already active[/yellow]")
        return

    console.print(f"Starting unit [bold]{config.unit}[/bold]")

    # Build systemd-run command
    systemd_cmd = [
        "systemd-run",
        "--user",
        f"--unit={config.unit}",
        f"--property=WorkingDirectory={config.project}",
        f"--property=StandardOutput=append:{archive_log.absolute()}",
        f"--property=StandardError=append:{archive_log.absolute()}",
        "--setenv=PYTHONUNBUFFERED=1",
    ]

    # Add security properties if requested
    if config.secure:
        systemd_cmd.extend(
            [
                "--property=PrivateTmp=true",
                "--property=ProtectSystem=strict",
                "--property=ProtectHome=read-only",
            ]
        )

    # Build the command to run
    uv_cmd = config.get_uv_cmd()
    bash_cmd = ["bash", "-lc", " ".join(uv_cmd)]

    systemd_cmd.extend(bash_cmd)

    # Start the service
    run_cmd(systemd_cmd)

    # Best-effort: fetch MainPID and write to .we.pid
    import time
    pid = 0
    for _ in range(30):
        pid = get_main_pid(config.unit)
        if pid > 0:
            break
        time.sleep(0.1)
    if pid > 0:
        try:
            config.pid_file.write_text(str(pid))
        except Exception as e:
            console.print(f"[yellow]Warning: Could not write PID file: {e}[/yellow]")

    # Prune old log files
    _prune_logs(config)

    console.print(f"[green]Service {config.service} started successfully[/green]")


@app.command()
def down(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Stop the service and cleanup"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    # Stop the unit
    run_cmd(["systemctl", "--user", "stop", config.unit], check=False)
    # Avoid noisy message when unit not loaded
    run_cmd(["systemctl", "--user", "reset-failed", config.unit], check=False, capture=True)

    # Remove run log symlink
    if config.runlog.exists() or config.runlog.is_symlink():
        config.runlog.unlink()
    if config.pid_file.exists():
        try:
            config.pid_file.unlink()
        except Exception:
            pass

    console.print(f"[yellow]Stopped {config.unit}[/yellow]")


@app.command()
def ps(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Show service status"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    try:
        result = run_cmd(
            [
                "systemctl",
                "--user",
                "show",
                "-p",
                "ActiveState,MainPID",
                "--value",
                config.unit,
            ],
            capture=True,
        )

        lines = result.stdout.strip().split("\n")
        if len(lines) >= 1:
            console.print(f"{config.unit}: {lines[0]}")
        else:
            console.print(f"Unit not found: {config.unit}")

    except typer.Exit:
        console.print(f"Unit not found: {config.unit}")


@app.command()
def logs(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
    lines: Optional[int] = typer.Option(
        None, "--lines", "-n", help="Number of lines to show"
    ),
):
    """Show service logs"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    # When called programmatically from other commands (launch/run/watch),
    # Typer's default can be a OptionInfo object. Ensure we have an int.
    tail_lines = lines if isinstance(lines, int) and lines >= 0 else config.tail

    # Try to read from run log file first, fallback to journal
    if config.runlog.exists() and config.runlog.is_file():
        run_cmd(["tail", "-n", str(tail_lines), str(config.runlog)])
    else:
        run_cmd(["journalctl", "--user", "-u", config.unit, "-n", str(tail_lines)])


@app.command()
def follow(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Follow service logs in real-time"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    # Try to follow run log file first, fallback to journal
    if config.runlog.exists() and config.runlog.is_file():
        run_cmd(["tail", "-F", str(config.runlog)])
    else:
        run_cmd(["journalctl", "--user", "-u", config.unit, "-f"])


@app.command()
def restart(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Restart the service"""
    config = ServiceConfig()
    if service:
        config.service = service

    console.print("Stopping service...")
    down(ctx, service)

    console.print("Starting service...")
    up(ctx, service)


@app.command()
def watch(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Start or restart the service, then follow logs"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    if unit_is_active(config.unit):
        console.print("Service active; restarting before follow...")
        restart(ctx, service)
    else:
        up(ctx, service)

    follow(ctx, service)


@app.command()
def launch(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Start or restart the service, then show recent logs"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    if unit_is_active(config.unit):
        console.print("Service active; restarting before logs...")
        restart(ctx, service)
    else:
        up(ctx, service)

    logs(ctx, service)


@app.command(name="run")
def run_alias(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Alias for launch"""
    launch(ctx, service)


@app.command()
def kill(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Stop all user units for this service (we-<service>-*)"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    # List all matching units
    try:
        res = subprocess.run(
            [
                "systemctl",
                "--user",
                "list-units",
                "--type=service",
                "--all",
                "--no-legend",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        stopped_any = False
        for line in res.stdout.splitlines():
            parts = line.split()
            if not parts:
                continue
            unit_name = parts[0]
            if unit_name.startswith(f"we-{config.service}-"):
                run_cmd(["systemctl", "--user", "stop", unit_name], check=False)
                run_cmd(["systemctl", "--user", "reset-failed", unit_name], check=False, capture=True)
                console.print(f"[yellow]Stopped {unit_name}[/yellow]")
                stopped_any = True
        if not stopped_any:
            console.print(f"No matching units for service {config.service}")
    except Exception as e:
        console.print(f"[red]kill failed: {e}[/red]")


@app.command()
def doctor(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Run service in foreground for debugging (no systemd)"""
    config = ServiceConfig()
    if service:
        config.service = service
    config.validate()

    console.print(f"[blue]Running {config.service} in doctor mode (foreground)[/blue]")

    # Change to project directory and run directly
    os.chdir(config.project)
    os.environ["PYTHONUNBUFFERED"] = "1"

    # Run without watchexec in doctor mode for simpler debugging
    cmd = ["uv", "run", "--project", config.project, "--", config.entry]
    run_cmd(cmd)


@app.command()
def unit(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Show detailed systemd unit status"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    run_cmd(["systemctl", "--user", "status", config.unit], check=False)


@app.command()
def journal(
    ctx: typer.Context,
    service: Optional[str] = typer.Option(
        None, help="Service name (overrides SERVICE env var)"
    ),
):
    """Show full systemd journal for the service"""
    config = ServiceConfig()
    if service:
        config.service = service
        config.unit = f"we-{service}-{config.unit_suffix}"
    config.validate()

    run_cmd(["journalctl", "--user", "-u", config.unit])


def _prune_logs(config: ServiceConfig):
    """Prune old log files, keeping the most recent KEEP_N"""
    try:
        if not config.logdir.exists():
            return

        # Get all log files sorted by modification time (newest first)
        log_files = sorted(
            config.logdir.glob(f"{config.service}-*-{config.unit_suffix}.log"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )

        # Remove files beyond KEEP_N
        for old_file in log_files[config.keep_n :]:
            old_file.unlink()

    except Exception as e:
        console.print(f"[yellow]Warning: Could not prune logs: {e}[/yellow]")


if __name__ == "__main__":
    app()
