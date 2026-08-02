# Makefile for the backup tool.
#
# This Makefile uses relative script names, so it has NO hardcoded path and
# runs from wherever the folder is saved. Just run 'make' from inside the
# backup_tool folder (or use 'make -C /path/to/backup_tool').
#
# Quick start:
#   make          Run the COMPLETE initial setup, in order:
#                   1. environment / browser opener
#                   2. install rclone and log in to Google Drive
#                   3. make the first full (base) backup
#                   4. schedule + start the daily incremental backup
#                 After this the system is fully set up and backs up daily on its own.
#
# Other targets:
#   make base     Make/rebuild the base backup (add ARGS=--force to rebuild).
#   make backup   Run an incremental backup now (normally cron does this).
#   make env      Step 1 only: environment / browser opener.
#   make rclone   Step 2 only: install rclone and log in to Google Drive.
#   make cron     Step 4 only: schedule + start the daily incremental backup.
#   make status   Show the installed cron schedule.
#   make clean    Remove the temporary work folder.

SHELL := /bin/bash

.DEFAULT_GOAL := setup

.PHONY: setup base env rclone cron backup status clean

# Default target: the complete initial setup, in the correct order.
setup:
	bash 01_setup_environment.sh
	bash 02_setup_rclone.sh
	bash 03_base_backup.sh
	bash 04_setup_cron.sh
	@echo ""
	@echo "Initial setup complete. Incremental backups now run automatically every day."

base:
	bash 03_base_backup.sh $(ARGS)

env:
	bash 01_setup_environment.sh

rclone:
	bash 02_setup_rclone.sh

cron:
	bash 04_setup_cron.sh

backup:
	bash incremental_backup.sh

status:
	crontab -l

clean:
	rm -rf /tmp/backup_work
	@echo "Temporary work folder removed."
