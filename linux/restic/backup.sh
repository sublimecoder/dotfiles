#!/bin/bash
# Nightly restic backup of @HOST@ to Backblaze B2.
# Output goes to stdout (journal) and /var/log/restic-backup.log; the
# Backup Sizzle widget parses the === markers and restic's summary lines.
set -euo pipefail

LOG=/var/log/restic-backup.log
set -a; . /root/.restic-env; set +a

exec > >(tee -a "$LOG") 2>&1

echo "=== Backup started: $(date) ==="

# Explicit package list so a restore can rebuild the system.
pacman -Qqe > /root/pkglist.txt
pacman -Qqm > /root/pkglist-aur.txt || true  # exits 1 when no AUR packages

restic unlock || true
# Exit 3 = snapshot saved but some files were unreadable or vanished mid-scan,
# routine on a live /home; anything else is a real failure.
rc=0
restic backup \
  --one-file-system \
  --exclude-caches \
  --exclude-file /etc/restic/excludes \
  @USER_HOME@ /etc /root || rc=$?
if [[ $rc -eq 3 ]]; then
  echo "warning: some source files could not be read (restic exit 3)"
elif [[ $rc -ne 0 ]]; then
  exit "$rc"
fi

restic forget --prune \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6

echo "=== Backup completed: $(date) ==="
