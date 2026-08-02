#!/bin/bash

# Daily incremental backup. This is the script that cron runs every day.
# It downloads the base backup, replays all past incrementals, compares them
# with the current files, and uploads only what changed today.

source "$(dirname "$0")/config.sh"

TODAY="$(date +%F)"
FIFTEEN_DAYS_AGO="$(date -d "15 days ago" +%F)"

mkdir -p "$TMP/prev_tree" "$TMP/current_tree" "$TMP/inc_files" "$TMP/inc_temp" "$TMP/rolled" "$TMP/old_files"

#do the backup
#for that download and compare

rclone copy "$BASE_REMOTE/base.tar.gz" "$TMP/"
rclone copy "$REMOTE/manifest.db" "$TMP/"

#extract base backup
tar -xzf "$TMP/base.tar.gz" -C "$TMP/prev_tree"

#Storing the incremental changes by replaying all incrementals
while IFS='|' read -r type date rest; do
        [[ "$type" != "INC" ]] && continue

        rm -rf "$TMP/inc_temp"
        mkdir -p "$TMP/inc_temp"

        rclone copy "$INC_REMOTE/$date/" "$TMP/inc_temp/"

        if [[ -d "$TMP/inc_temp/files" ]]; then
                 cp -r "$TMP/inc_temp/files/." "$TMP/prev_tree/"
        fi

        if [[ -f "$TMP/inc_temp/deleted.list" ]]; then
                while IFS= read -r del; do
                        rm -f "$TMP/prev_tree/$del"
                done < "$TMP/inc_temp/deleted.list"
        fi

done < "$TMP/manifest.db"

#sync current filesystem snapshot
rclone sync "$SOURCE" "$TMP/current_tree" $FILTERS -L

#Storing the relative path of deleted files into the deleted.list
>"$TMP/inc_files/deleted.list"

#detect deleted files
while IFS= read -r filepath; do

        rel="${filepath#$TMP/prev_tree/}"

        if [[ ! -e "$TMP/current_tree/$rel" ]]; then
                echo "$rel" >> "$TMP/inc_files/deleted.list"
        fi

done < <(find "$TMP/prev_tree" -type f)

#detect modified or new files for incremental backup
while IFS= read -r filepath; do

        rel="${filepath#$TMP/current_tree/}"
        prev="$TMP/prev_tree/$rel"

        if [[ ! -f "$prev" ]] || ! diff -q "$filepath" "$prev" >/dev/null 2>&1; then
                mkdir -p "$TMP/inc_files/files/$(dirname "$rel")"
                cp "$filepath" "$TMP/inc_files/files/$rel"
        fi

done < <(find "$TMP/current_tree" -type f)

#upload today's incremental backup
rclone copy "$TMP/inc_files/" "$INC_REMOTE/$TODAY/"

echo "INC|$TODAY" >> "$TMP/manifest.db"

#update manifest in remote
rclone copy "$TMP/manifest.db" "$REMOTE/"

#check base backup age
BASE_DATE="$(grep '^BASE|' "$TMP/manifest.db" | cut -d'|' -f2)"

if [[ "$BASE_DATE" < "$FIFTEEN_DAYS_AGO" ]]; then

        #find oldest incremental
        OLDEST_INC="$(grep '^INC|' "$TMP/manifest.db" | head -1 | cut -d'|' -f2)"

        #rebuild base from old base
        tar -xzf "$TMP/base.tar.gz" -C "$TMP/rolled"

        #apply oldest incremental
        rclone copy "$INC_REMOTE/$OLDEST_INC/" "$TMP/old_files/"

        if [[ -d "$TMP/old_files/files" ]]; then
                cp -r "$TMP/old_files/files/." "$TMP/rolled/"
        fi

        if [[ -f "$TMP/old_files/deleted.list" ]]; then
                while IFS= read -r del; do
                        rm -f "$TMP/rolled/$del"
                done < "$TMP/old_files/deleted.list"
        fi

        #create new base archive
        tar -czf "$TMP/new_base.tar.gz" -C "$TMP/rolled" .

        #replace old base backup
        rclone deletefile "$BASE_REMOTE/base.tar.gz"
        rclone copy "$TMP/new_base.tar.gz" "$BASE_REMOTE/"

        #remove applied incremental
        rclone purge "$INC_REMOTE/$OLDEST_INC"

        #update manifest
        sed -i "/^BASE|/d" "$TMP/manifest.db"
        sed -i "/^INC|$OLDEST_INC/d" "$TMP/manifest.db"

        echo "BASE|$OLDEST_INC|base.tar.gz" | cat - "$TMP/manifest.db" > "$TMP/temporary"

        if [[ $? -eq 0 ]]; then
                mv "$TMP/temporary" "$TMP/manifest.db"
        fi

        rclone copy "$TMP/manifest.db" "$REMOTE/"
fi

#cleanup temp data
rm -rf "$TMP"
