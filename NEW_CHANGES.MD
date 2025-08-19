Here’s a straight, low-risk way to stop your *.sh* pain without losing any of your current features.

# What you already have (good foundation)

Your repo is already moving the *right* direction: thin Make targets, `systemd-run --user` for transient processes, per-run log files with a stable `./.uu/<svc>/run.log` handle, and opt-in live-reload. That design avoids in-place rotation and the usual “cd/dir” sh foot-guns.    &#x20;

# Recommend: “Shell as glue, logic in tools”

Keep only *minimal* shell (entry glue), and move everything else into durable tools:

1. **Keep Make as the single front-door**

   * Phony targets for `up`, `down`, `logs`, `follow`, `ps`, `restart`, `doctor`, `unit`, `journal` are exactly what Make is good at. Phony targets run unconditionally and don’t fight filesystem state. ([GNU][1])
   * Your generated Makefile already binds `MODULE`, `PROJECT`, `RUNLOG`, etc., with `$(abspath .)`, which solves “dir navigation” bugs.&#x20;

2. **Push all real logic to Python (via `uv`)**

   * Create a tiny Python CLI (e.g., `tools/uuctl.py`) with **Typer** for arguments/help, and call it from Make: `uv run --project <root> -- python tools/uuctl.py ...`. Typer gives you structured params, subcommands, shell completion, and rich `--help`—far less fragile than ad-hoc Bash. ([typer.tiangolo.com][2])
   * `uv` keeps envs reproducible and fast (on Arch it’s snappy), so your CLI “just works” across modules. ([Astral Docs][3])

3. **Rely on `systemd-run --user` for process lifecycle & logs**

   * You’re already using this correctly: transient units, per-run log files, `journalctl` fallback. Keep that—*it’s more robust than backgrounding shells*. ([Freedesktop][4])&#x20;

4. **Swap fragile file watchers for a battle-tested one**

   * If `py-mon` is giving you grief later, standardize on **watchexec** (Rust). It’s a small, mature watcher with ignore/glob support; perfect for `RELOAD=1` mode. Wire it the same way you do now (tty kept open) and keep your ignore list. ([GitHub][5], [watchexec.github.io][6])
   * (Your current README already documents ignored paths and RELOAD behavior—retain that contract.)&#x20;

5. **Quality gates for the tiny shell that remains**

   * Add **ShellCheck** and **shfmt** to CI/pre-commit; they catch quoting/undef/IFS issues and keep style consistent. ([shellcheck.net][7], [GitHub][8])
   * For critical glue, add a couple of **bats-core** tests (e.g., “`make up` emits unit name”, “logs fallback to journal”). ([bats-core.readthedocs.io][9], [GitHub][10])

---

## If you want to *further* cut shell surface area

Two proven alternatives; both play nicely with your current `systemd` + `uv` model:

* **Use `just` as a friendlier command runner**
  Syntax is simpler than Make for “run this command” recipes; great for developer UX. Map today’s `make up/down/logs` to `just up/down/logs`, and have those call your Typer CLI. ([Just][11], [GitHub][12])

* **Use `Taskfile` (Go Task)**
  YAML tasks with namespaces, caching, and solid cross-platform behavior. Again, tasks call your Typer CLI and `systemd-run`. ([Task][13])

Make vs Just vs Task: you already ship Make glue; I’d keep it (zero re-training), and only introduce *Just/Task* if you want nicer ergonomics or Windows contributors later.

---

## Concrete next steps (surgical, low churn)

1. **Add a Python CLI** (`tools/uuctl.py`) with Typer: subcommands `up/down/logs/follow/ps/doctor`. Make targets call it through `uv run`. ([typer.tiangolo.com][2])
2. **Keep the `uu` generator** as-is for Makefiles & README; it already encodes logging Policy-A and unit naming—don’t re-solve solved problems.&#x20;
3. **Replace any ad-hoc watchers** with `watchexec` in the same RELOAD flow (or keep `py-mon` if stable enough in your env). ([GitHub][5])
4. **Wire pre-commit**: `shellcheck`, `shfmt`, and a couple **bats** tests that exercise the common paths. ([shellcheck.net][7], [GitHub][8])

This keeps your developer workflow (`make up`, `make logs`) unchanged, kills the most common Bash failure modes (quoting, unset vars, brittle `cd`), and centralizes logic where you’re strongest—Python.

If you want, I can draft the Typer CLI skeleton + the Make glue calls in your style next.

[1]: https://www.gnu.org/s/make/manual/html_node/Phony-Targets.html?utm_source=chatgpt.com "Phony Targets (GNU make)"
[2]: https://typer.tiangolo.com/?utm_source=chatgpt.com "Typer"
[3]: https://docs.astral.sh/uv/?utm_source=chatgpt.com "uv - Astral Docs"
[4]: https://www.freedesktop.org/software/systemd/man/systemd-run.html?utm_source=chatgpt.com "systemd-run"
[5]: https://github.com/watchexec/watchexec?utm_source=chatgpt.com "watchexec/watchexec: Executes commands in response to ..."
[6]: https://watchexec.github.io/?utm_source=chatgpt.com "Watchexec"
[7]: https://www.shellcheck.net/?utm_source=chatgpt.com "ShellCheck – shell script analysis tool"
[8]: https://github.com/mvdan/sh?utm_source=chatgpt.com "mvdan/sh: A shell parser, formatter, and interpreter with ..."
[9]: https://bats-core.readthedocs.io/?utm_source=chatgpt.com "Welcome to bats-core's documentation! — bats-core 1 ..."
[10]: https://github.com/bats-core/bats-core?utm_source=chatgpt.com "bats-core/bats-core: Bash Automated Testing System"
[11]: https://just.systems/man/en/?utm_source=chatgpt.com "Introduction - Just Programmer's Manual - A Command Runner"
[12]: https://github.com/casey/just?utm_source=chatgpt.com "casey/just: Just a command runner - GitHub"
[13]: https://taskfile.dev/?utm_source=chatgpt.com "Taskfile.dev"
