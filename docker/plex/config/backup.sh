#!/bin/bash
echo "Starting Plex server backup"
tar \
  --exclude='*/Cache' \
  --exclude='*/Crash Reports' \
  --exclude='*/Logs' \
  --exclude='*/Media' \
  --exclude='*/Metadata' \
  -zcf /backups/plex.tar.gz "/config/Library/Application Support/Plex Media Server"
echo "Completed Plex server backup"
