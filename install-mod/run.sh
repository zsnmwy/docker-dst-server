#!/bin/bash
set -Eeuo pipefail

for i in {1..19}; do
  cat "./item-list-$i" > /opt/dst_server/mods/dedicated_server_mods_setup.lua
  timeout 15m dontstarve_dedicated_server_nullrenderer -persistent_storage_root /data -ugc_directory /data/ucg_mods/
done
