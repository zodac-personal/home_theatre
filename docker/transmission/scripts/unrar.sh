#!/bin/bash
# A simple script to extract a rar file inside a directory downloaded by Transmission
find /"${TR_TORRENT_DIR}"/"${TR_TORRENT_NAME}" -name "*.rar" -execdir unrar e -o- "{}" \;
