# Backup Tool (Linux / WSL)

An automated file-backup tool for Linux and WSL. It keeps one full **base**
backup plus daily **incremental** backups on **Google Drive** using `rclone`,
and schedules the daily backups with `cron`. After a one-command setup it runs
on its own.

---

## How it works

- **Base backup** — one full snapshot of your files, stored as `base.tar.gz`.
- **Incremental backup** — each day only the files that changed (plus a list of
  files that were deleted) are uploaded.
- **Manifest** (`manifest.db`) — records the base date and every incremental
  date, so the latest state can be rebuilt by replaying them in order.
- **15-day fold** — every 15 days the oldest incremental is merged into the
  base to keep the chain short.

### What gets backed up

The source folder is chosen automatically (see `config.sh`):

- **WSL** → the current Windows user's Desktop
  (`/mnt/c/Users/<name>/Desktop`, OneDrive-redirected Desktops are handled too).
- **Plain Linux** → the current user's home directory (`$HOME`).

Only these file types are included: `pdf, doc, docx, jpg, png, cpp, py, ppt, pptx`
(change the `FILTERS` line in `config.sh` to adjust).

---

## Requirements

- `bash`, `make`, `curl`, `cron`, `tar`
- `rclone` (installed automatically by the setup if missing)
- Internet access and a Google account
- **WSL only:** a Windows browser opener (`cmd.exe`) for the one-time login —
  already present on a normal Windows install.

---

## Quick start

Everything is driven by one command: `make`.

The tool has **no hardcoded path** — it runs from wherever you saved the
`backup_tool` folder. Just move into that folder first, then run `make`.
(You can also point make at it from anywhere with
`make -C /path/to/backup_tool`.)

### On WSL (Ubuntu on Windows)

Open your Ubuntu terminal. The folder lives on your Windows drive, reached under
`/mnt` — replace the path below with wherever you saved it (a folder on the
`D:` drive is `/mnt/d/...`, on `C:` it is `/mnt/c/...`):

```bash
cd "/mnt/d/college study/sem 4/os project/backup_tool"
make
```

> If Ubuntu is not your default WSL distro, start it explicitly first with
> `wsl -d Ubuntu`, then run the commands above.

### On plain Linux (Ubuntu, etc.)

Replace the path with wherever you saved the folder:

```bash
cd ~/backup_tool
make
```

### What `make` does

It runs the complete initial setup, in order, and stops if any step fails:

1. `01_setup_environment.sh` – detect environment / prepare the browser opener
2. `02_setup_rclone.sh` – install rclone and log in to Google Drive
3. `03_base_backup.sh` – make and upload the first full backup
4. `04_setup_cron.sh` – schedule **and start** the daily incremental backup

During setup you will be asked for your **sudo password** (to install packages)
and a **browser window opens once** for the Google login. After that, the daily
incremental backup runs automatically — you don't run anything by hand again.

---

## Other commands

| Command | What it does |
|---|---|
| `make` | Complete initial setup (default). |
| `make base` | Make the base backup only. `make base ARGS=--force` rebuilds it. |
| `make backup` | Run an incremental backup right now. |
| `make env` / `make rclone` / `make cron` | Run a single setup step. |
| `make status` | Show the installed cron schedule (`crontab -l`). |
| `make clean` | Remove the temporary work folder (`/tmp/backup_work`). |

---

## Changing the backup time

The schedule is in `cron_jobs.txt` using cron format `minute hour * * *`.
Default is `10 14 * * *` = **2:10 PM daily**. For example, `0 2 * * *` = 2:00 AM.
After editing, re-run `make cron` (remove the old line first with `crontab -e`
to avoid a duplicate).

---

## Files

| File | Purpose |
|---|---|
| `Makefile` | Task runner / entry point. |
| `config.sh` | Shared settings: remote path, source folder, temp folder, file filters. |
| `rclone.conf.txt` | Template rclone config for the `gdrive` remote. |
| `01_setup_environment.sh` | Detect WSL / Linux / headless, prepare a browser opener. |
| `02_setup_rclone.sh` | Install rclone, apply config, log in to Google Drive. |
| `03_base_backup.sh` | Create and upload the first full backup. |
| `04_setup_cron.sh` | Schedule and start the daily incremental backup. |
| `incremental_backup.sh` | The daily incremental backup (run by cron). |
| `cron_jobs.txt` | The cron schedule. |
| `setup.sh` | Plain-shell equivalent of `make` (runs all four steps). |

---

## Notes

- **WSL and cron:** cron only runs while your WSL/Ubuntu instance is running.
  The setup starts the cron service, but if WSL was fully shut down at the
  scheduled time the run is simply picked up the next day.
- **OneDrive:** if your Desktop is in OneDrive, *online-only* files are pulled
  from the cloud before they can be backed up, which can make the first backup
  slower.
- **Cancelling the base backup:** pressing `Ctrl+C` during `03_base_backup.sh`
  still saves whatever was collected so far, then removes the temp folder.
