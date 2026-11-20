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

## Radiant heating in Summer airflow mode

The Raspberry Pi's radiant floor heating is independent of the ducted heat pump. The automation loop now evaluates radiant heating requests in both airflow modes while leaving ducted cooling conditional on Summer mode. When a radiant zone is calling for heat, the corresponding AC zone is prevented from requesting cooling on that pass. Existing five-minute boiler/valve warm-up logic remains in place.

The Settings page allows radiant heating to be enabled or disabled regardless of airflow selection. The Climate/Heating page edits radiant-heating setpoints in either airflow mode; the separate Cooling page remains for cooling controls. Summer/Winter mode still controls the physical duct dampers, so leave it on Summer for the heat pump configuration described.

**Deployment caution:** This change has not been run against Raspberry Pi relays. Before deploying, confirm the heat/cool zone ID mappings and exercise heating ON/OFF, simultaneous requests, boiler delay, cooling, and emergency shutdown with the equipment supervised.
