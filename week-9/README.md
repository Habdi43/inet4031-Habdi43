# Week 9 — Data Observability and Backup

## Setup

The Postgres exporter reports database availability, size, and estimated table row counts to Prometheus. The network policy allows the web app and exporter to connect to Postgres.

Cron runs `week-9/backup.sh` every five minutes. It checks each dump for table data entries, saves it privately in `~/backups`, and keeps the newest 12. Run `./week-9/check.sh` to verify the setup.

## What lives where

| Location | Contents | Survives VM deletion? |
| --- | --- | --- |
| GitHub repository | Scripts, OpenTofu configuration, and this runbook | Yes |
| MacBook | One manually copied backup | Yes |
| Ubuntu VM | Database volume, scheduled backups, and cron entries | No |
| Prometheus | Metrics history | No |

## Restore runbook

If the app loses its tickets, run `./week-9/sql.sh` to check whether the table is still there. Postgres can remain reachable even when its tables are gone.

1. Run `ls -lt ~/backups` and pick a dump from before the data loss.
2. Run `./week-9/restore.sh ~/backups/<file>`.
3. Run `./week-9/sql.sh` and verify the restored row count.

## Drill results

- Tickets before and after restore — 3
- Backup age at the start of the drill — 0 seconds (target of 5 minutes)
- Recovery time — 16 seconds (target of 10 minutes)

## Rebuild on a fresh VM

1. Follow the Week 7 and Week 8 rebuild steps to restore the cluster and deployment loop.
2. On Ubuntu, create the private backup directory with `mkdir -m 700 ~/backups`.
3. From Mac Terminal, upload the saved dump with `scp -P 2222 <file> habdi@127.0.0.1:backups/`.
4. On Ubuntu, run `./week-9/restore.sh ~/backups/<file>` and verify the rows.
5. Restore the five-minute cron entry with `crontab -e`, using the full path to `week-9/backup.sh` and redirecting output to `~/backup.log`.

## Known limitations

The backups are unencrypted, and the Mac copy is manual. The exporter uses the database superuser. There are no alerts for exporter failures or stale backups. The drill used the existing cluster, so a fresh-VM restore is untested. The Postgres image uses a floating tag.
