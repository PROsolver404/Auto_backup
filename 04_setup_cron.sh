#!/bin/bash

# Step 4: Add the daily incremental backup to cron so it runs automatically.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Setting up cron job..."

# Read the current crontab into a temp file.
crontab -l 2>/dev/null > current_cron.txt

# Add each job from cron_jobs.txt, skipping ones that are already there.
while IFS= read -r job
do
    # If the line is empty then skip it.
    [[ -z "$job" ]] && continue

    # Fill in this folder's real path where the job refers to __TOOL_DIR__.
    job="${job//__TOOL_DIR__/$SCRIPT_DIR}"

    # If the job is already in the crontab then don't add it again.
    grep -Fq "$job" current_cron.txt || echo "$job" >> current_cron.txt

done < "$SCRIPT_DIR/cron_jobs.txt"

crontab current_cron.txt

rm -f current_cron.txt

# Make sure the cron service is actually running. On WSL it is off by default,
# so the scheduled job would never fire until cron is started.
sudo service cron start >/dev/null 2>&1 || true

echo "Cron job installed and cron service started."
