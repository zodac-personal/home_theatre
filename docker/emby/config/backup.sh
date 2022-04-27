#!/bin/bash
echo "Starting Emby server backup"
tar \
  --exclude='*/cache' \
  --exclude='*/logs' \
  --exclude='*/metadata' \
  -zcf /backups/emby.tar.gz /config/
echo "Completed Emby server backup"
