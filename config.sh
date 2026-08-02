#!/bin/bash

# Shared settings for the backup tool.
# Every script reads its common values from here, so the remote path,
# the source folder and the file filters stay the same everywhere.

# Google Drive remote (set up with rclone) and the folders inside it.
REMOTE="gdrive:Backups"
BASE_REMOTE="$REMOTE/base"
INC_REMOTE="$REMOTE/incremental"

# Folder that gets backed up. This depends on the system:
#   - WSL:         the current Windows user's Desktop
#                  (under /mnt/c/Users/<name>/Desktop, found via %USERPROFILE%).
#   - Plain Linux: the current user's home directory ($HOME).

if grep -qi microsoft /proc/version 2>/dev/null; then
	# WSL: find cmd.exe even under cron, where Windows paths may not be on PATH.
	CMD_EXE="$(command -v cmd.exe 2>/dev/null || echo /mnt/c/Windows/System32/cmd.exe)"

	# %USERPROFILE% is C:\Users\<current user>; convert it to a WSL path.
	WIN_PROFILE="$("$CMD_EXE" /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')"
	PROFILE_DIR="$(wslpath "$WIN_PROFILE")"

	# Prefer the normal Desktop, fall back to a OneDrive-redirected one.
	if [ -d "$PROFILE_DIR/Desktop" ]; then
		SOURCE="$PROFILE_DIR/Desktop"
	elif [ -d "$PROFILE_DIR/OneDrive/Desktop" ]; then
		SOURCE="$PROFILE_DIR/OneDrive/Desktop"
	else
		SOURCE="$PROFILE_DIR/Desktop"
	fi
else
	# Plain Linux: back up the user's home directory.
	SOURCE="$HOME"
fi

# Temporary working folder used while a backup runs.
TMP="/tmp/backup_work"

# Only these file types are backed up, everything else is skipped.
FILTERS="--include=*.pdf --include=*.doc --include=*.docx --include=*.jpg --include=*.png --include=*.cpp --include=*.py --include=*.ppt --include=*.pptx --exclude=*"
