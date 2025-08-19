<!-- BEGIN: we-readme -->
# Development runner (we)

This project includes a Make block managed by the `we` tool.

Quick commands:

- make up        # start service (RELOAD=1 uses watchexec)
- make follow     # tail logs
- make down       # stop service

RELOAD=1 enables live reload via watchexec; set RELOAD=0 to disable. Set SECURE=1 to enable systemd hardening flags.

<!-- END: we-readme -->
