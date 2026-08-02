#!/bin/bash

# One-time setup. Run this once to get everything ready:
#   1. prepare the environment / browser opener
#   2. install rclone and log in to Google Drive
#   3. make the first full (base) backup
#   4. schedule the daily incremental backup in cron
#
# After this finishes, the incremental backup runs automatically every day
# from cron. You do not run anything by hand again.
#
# The steps are chained with && so setup stops at the first one that fails.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

bash 01_setup_environment.sh && \
bash 02_setup_rclone.sh && \
bash 03_base_backup.sh && \
bash 04_setup_cron.sh && \
echo "" && \
echo "Setup complete. Incremental backups will now run automatically every day." && \
echo "Check the schedule any time with: crontab -l"
