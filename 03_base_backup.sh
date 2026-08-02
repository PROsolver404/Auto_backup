#!/bin/bash

# Step 3: Make the first full ("base") backup and upload it.
# If the backup is cancelled (Ctrl+C) partway through, whatever was collected
# up to that point is still archived and uploaded. The temporary work folder
# is always removed at the end, whether the run finished or was cancelled.

source "$(dirname "$0")/config.sh"

# Safety check so we never work on the root directory.
if [[ "$TMP" == "/" || -z "$TMP" ]]; then
    echo "Invalid TMP directory"
    exit 1
fi

# The base backup is a one-time step. If one already exists on the remote,
# setup was already done, so skip it (run with --force to rebuild it).
if [[ "$1" != "--force" ]] && rclone lsf "$BASE_REMOTE/" 2>/dev/null | grep -qx "base.tar.gz"; then
    echo "Base backup already exists. Skipping (use --force to rebuild)."
    echo "Incremental backups keep running automatically from cron."
    exit 0
fi

TODAY="$(date +%F)"

mkdir -p "$TMP/base_tree" "$TMP/logs"

LOG="$TMP/logs/backup.log"

# Print each log line to the screen AND save it to the log file.
log() {
    echo "[$(date +%F_%T)] $*" | tee -a "$LOG"
}

# Remove the whole temporary work folder.
cleanup() {
    rm -rf "$TMP"
}

# Archive whatever is in base_tree, upload it as the base backup, then clean up.
# Runs on a normal finish and also when the run is cancelled, so files that
# were already collected are still saved. FINALIZED makes sure it runs once.
FINALIZED=0
finalize() {
    [[ "$FINALIZED" -eq 1 ]] && return
    FINALIZED=1

    echo "Creating archive base.tar.gz ..."
    tar -czf "$TMP/base.tar.gz" -C "$TMP/base_tree" .

    echo "BASE|$TODAY|base.tar.gz" > "$TMP/manifest.db"

    # Make sure both files were created before uploading them.
    for f in "$TMP/base.tar.gz" "$TMP/manifest.db"; do
        if [[ ! -f "$f" ]]; then
            echo "Missing file: $f"
            cleanup
            exit 1
        fi
    done

    echo "Uploading base backup to Google Drive..."
    rclone copy "$TMP/base.tar.gz" "$BASE_REMOTE/" -P

    echo "Uploading manifest..."
    rclone copy "$TMP/manifest.db" "$REMOTE/" -P

    log "done"
    echo "Base backup complete."

    cleanup
}

# If the user presses Ctrl+C, still save what was copied so far, then clean up.
on_cancel() {
    echo ""
    echo "Cancelled. Saving the files collected so far as the base backup..."
    finalize
    cleanup
    exit 0
}
trap on_cancel INT TERM

log "start"

echo "Backing up from: $SOURCE"
echo "Collecting matching files (this may take a moment)..."
# -P shows live progress in the terminal.
rclone copy "$SOURCE" "$TMP/base_tree" $FILTERS -L -P

# Copy finished normally — save the backup and clean up.
finalize
