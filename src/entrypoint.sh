#!/bin/bash

# mju - latest mods 23/03/2024 to simplify to the minimum working level

set -o nounset
set -o errexit
set -o pipefail

CONF_FILE="/data/weewx.conf"

# echo version before starting syslog so we don't confound our tests
if [ "$1" = "--version" ]; then
  gosu weewx:weewx ./bin/weewxd --version
  exit 0
fi

if [ "$(id -u)" = 0 ]; then
  echo start the syslog daemon as root user
  /sbin/syslogd -n -S -O - &
  if [ "${WEEWX_UID:-weewx}" != 0 ]; then
    # drop privileges and restart this script
    echo "Switching uid:gid to ${WEEWX_UID:-weewx}:${WEEWX_GID:-weewx}"
    gosu "${WEEWX_UID:-weewx}:${WEEWX_GID:-weewx}" "$(readlink -f "$0")" "$@"
    exit 0
  fi
fi

#	copy belchertown.py from /data/bin/user to /home/weewx/bin/user/belchertown.py enables updates from the host
cp -f /data/bin/user/belchertown.py ./bin/user/

./bin/weewxd "$@"
