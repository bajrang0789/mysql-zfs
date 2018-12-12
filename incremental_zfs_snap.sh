#!/bin/bash

sudo zpool import backup

echo "Remove oldest snapshot in the master pool" (zp0)
sudo zfs destroy -r zp0/mysql@mysql003
echo "Remove oldest snapshot in the backup pool" (backup)
sudo zfs destroy -r backup/mysql@mysql003

echo "Rotate snapshots (aging) in the master pool"
sudo zfs rename -r zp0/mysql@mysql002 mysql003
sudo zfs rename -r zp0/mysql@mysql001 mysql002

echo "Rotate snapshots (aging) in the backup pool"
sudo zfs rename -r backup/mysql@mysql002 mysql003
sudo zfs rename -r backup/mysql@mysql001 mysql002



echo "Create newest snapshot in the master pool"
sudo zfs snapshot -r zp0/mysql@mysql001

echo "Preparations finished..."
echo "Now sending snapshot from the master pool into the backup pool..."
sudo zfs send -i mysql002  zp0/mysql@mysql001 | sudo zfs receive backup/mysql
echo "Done."

sudo zpool export backup
