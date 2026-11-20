# Greenleaf Home Automation

Archived Raspberry Pi home automation source, imported from the supplied `html` directory snapshot (November 2026).

## Components

- `html/io2db.pl`: minute-by-minute automation loop, including relays, heating, cooling, and irrigation.
- `html/*.html`: web control and scheduling pages.
- `html/getAny.cgi` and `html/setAny.cgi`: Perl database-backed CGI endpoints.
- `html/relays/`: relay-control web UI.
- `html/css`, `html/js`, `html/images`: static assets.

## Important limitations

This is a source archive, not a deployable system image. The original database, cron jobs, external scripts, hardware settings, and compiled CGI executables are not included. Do not deploy without checking the Raspberry Pi's actual configuration and testing relay behavior.

The original source contained a hardcoded database password. It has been removed from the three Perl source files; set the `GREENLEAF_DB_PASSWORD` environment variable for these processes before running them. The original compiled CGI executables also embedded credentials, and have been omitted rather than committed. They must be rebuilt from verified source if still required.

The Summer/Winter radiant heating interlock remains unchanged. No hardware logic has been modified in this archival import.
