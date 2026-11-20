# Greenleaf Home Automation

Raspberry Pi home automation system for radiant heating, cooling, irrigation, and relay controls.

The original source snapshot was provided in November 2026. The pending import excludes backup/editor files and compiled CGI programs containing embedded database credentials. The Perl source scripts must read their database password from `GREENLEAF_DB_PASSWORD` rather than storing it in Git.

**Caution:** The Summer/Winter interlock and relay-control logic have not been changed or validated on hardware. The source alone is not a deployable Raspberry Pi image.
