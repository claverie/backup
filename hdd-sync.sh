#!/bin/bash

APPNAME=$(basename $0 | sed "s/\.sh$//")
APPDIR=$(dirname `realpath $0`)

_ID=$(id -u)
[ $_ID != 0 ] && {
  echo "** Must be run as root !"
  echo "** Aborting."
  exit 1
}

APPCONF="$APPDIR/$APPNAME.conf"
[ ! -f "$APPCONF" ] && {
  echo "** Missing configuration file $APPCONF."
  echo "** Aborting."
  exit 1
}
source "$APPCONF"

RSYNC_OPTS="--stats "
EXCLUDE_FILE="$APPDIR/$APPNAME.exclude"
[ -f "$EXCLUDE_FILE" ] && {
  RSYNC_OPTS="$RSYNC_OPTS --exclude-from=$EXCLUDE_FILE"
}
ISMOUNT=`mount -l | grep "$DD_BACKUP_DEVICE"`
[ "$ISMOUNT" == "" ] && {
  echo "** Backup disk not mounted ($DD_BACKUP_MOUNT)."
  echo "** Aborting."
  exit 1
}
[ ! -d "$DD_BACKUP_MOUNT" ] && {
  echo "** Backup disk not present ($DD_BACKUP_MOUNT)."
  echo "** Aborting."
  exit 1
}
[ ! -f ${DD_BACKUP_MOUNT}/.backup.marker ] && {
  echo "** Safe mode checking detect target disk is not dedicated to backup !"
  echo "** Check it, and mark it if it was the good disk !"
  echo "      touch \"$DD_BACKUP_MOUNT/.backup.marker\""
  echo "** Aborting."
  exit 1
}

set -e

fn_get_uuid() {
  UUID=$(blkid $1 | sed -n 's/.* UUID=\"\([^\"]*\)\".*/\1/p')
  echo $UUID
}

UUID_SOURCE=$( fn_get_uuid $DD_SOURCE_DEVICE )
UUID_BACKUP=$( fn_get_uuid $DD_BACKUP_DEVICE )

echo "Backup in progres from / to ${DD_BACKUP_MOUNT}/..."
rsync -a --delete --one-file-system $RSYNC_OPTS / ${DD_BACKUP_MOUNT}/

echo "Setting UUID on ${DD_BACKUP_MOUNT} : $UUID_SOURCE --> $UUID_BACKUP..."
sed -i -e "s/$UUID_SOURCE/$UUID_BACKUP/g;" ${DD_BACKUP_MOUNT}/boot/grub/grub.cfg
sed -i -e "s/$UUID_SOURCE/$UUID_BACKUP/g;" ${DD_BACKUP_MOUNT}/etc/fstab
sed -i -e "s/$UUID_SOURCE/$UUID_BACKUP/g;" ${DD_BACKUP_MOUNT}/boot/grub/x86_64-efi/load.cfg

touch "$DD_BACKUP_MOUNT/.backup.marker"

echo "Ejecting (...) $DD_BACKUP_DEVICE !"
eject $DD_BACKUP_DEVICE
echo "Done."
exit 0
