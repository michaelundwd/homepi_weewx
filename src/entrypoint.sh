#!/bin/ash

# all code below here to the final fi is skipped for testing a highly compact entrypoint.sh
#if [ ]]; then

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
  # set timezone using environment
  ln -snf /usr/share/zoneinfo/"${TIMEZONE:-UTC}" /etc/localtime
  # start the syslog daemon as root
  /sbin/syslogd -n -S -O - &
  if [ "${WEEWX_UID:-weewx}" != 0 ]; then
    # drop privileges and restart this script
    echo "Switching uid:gid to ${WEEWX_UID:-weewx}:${WEEWX_GID:-weewx}"
    gosu "${WEEWX_UID:-weewx}:${WEEWX_GID:-weewx}" "$(readlink -f "$0")" "$@"
    exit 0
  fi
fi

copy_default_config() {
  # create a default configuration on the data volume
  echo "Creating a configration file on the container data volume."
  cp weewx.conf "${CONF_FILE}"
  echo "The default configuration has been copied."
  # Change the default location of the SQLITE database to the volume
  echo "Setting SQLITE_ROOT to the container volume."
  sed -i "s/SQLITE_ROOT =.*/SQLITE_ROOT = \/data/g" "${CONF_FILE}"
}


#fi
# this is the end of the code to be skipped

#	code was inserted here to copy /data/bin/user/belchertown.py to /home/weewx/bin/user/belchertown.py
#	so that all changes relating to Belchertown skin are external to the container where I can modify them

chmod 777 /home/weewx/bin/user
cp /data/bin/user/belchertown.py ./bin/user
chmod 775 /home/weewx/bin/user

./bin/weewxd "$@"
