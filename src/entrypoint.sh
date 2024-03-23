#!/bin/bash

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

#	code was inserted here to copy belchertown.py from /data/bin/user to /home/weewx/bin/user/belchertown.py
#	so that all Belchertown skin configuration is external to the container where I can modify them from homepi, not the weewx container

#echo ./bin
#ls -l ./bin
chmod 777 ./bin/user
#echo ./bin
#ls -l ./bin

echo ./bin/user before remove
ls -l ./bin/user
rm ./bin/user/belchertown.py
#mv ./bin/user/belchertown.py /data/bin/user/belchertown.py.cntnr
echo ./bin/user after remove
ls -l ./bin/user
cp -f /data/bin/user/belchertown.py ./bin/user/
echo .bin/user after copy
ls -l ./bin/user

chmod 775 ./bin/user
#echo ./bin
#ls -l ./bin

#ls -l /data/bin/user
#cp ./bin/user/belchertown.py /data/bin/user/belchertown.py.cntnr

./bin/weewxd "$@"
