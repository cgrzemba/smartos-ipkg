# Copyright 2013, Joyent. Inc. All rights reserved.

if [ -x /usr/sbin/mdata-get ]; then
  HAS_METADATA=yes

  log "waiting for metadata to show up"

  until [ -e /.zonecontrol/metadata.sock ] ||\
        [ -e /.zonecontrol/metadata.sock ] ||\
        [ $((MCOUNT++)) -gt 30 ]; do
    sleep 1
  done

  [ -e /.zonecontrol/metadata.sock ] ||\
  [ -e /.zonecontrol/metadata.sock ] ||\
    log "metadata failed to show up"
fi
