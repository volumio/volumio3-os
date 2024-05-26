#!/bin/bash

# stop mpd unit systemd service
/usr/bin/sudo /bin/systemctl stop mpd.service
# mpd socket left behind and unit file is the way to stop it
/usr/bin/sudo /bin/systemctl stop mpd.socket

sleep 2;

# Find PID of mpd process
MPDPID=`ps -eaf | grep mpd | grep -v grep | awk '{print $2}'`

# Find PID of mpd.socket
PORT=6600
SOCPID=$(/usr/bin/lsof -ti:$PORT)

# mpd process left abandon and unit file is not able to stop it

if ! [[ "$MPDPID" = ^[0-9]+$ ]] ;
then
  printf "No abandon mpd process found.\n"
  exit 0
fi

if [[ "" !=  "$MPDPID" ]]; then
  printf "Killing abandon mpd under PID $MPDPID\n"
  /usr/bin/sudo /bin/kill -9 $MPDPID
fi

# mpd socket left abandon and unit file is not able to stop it
if ! [[ "$SOCPID" = ^[0-9]+$ ]] ;
then
  printf "No mpd socket process found, exiting.\n"
  exit 0
fi

if [[ "" !=  "SOCPID" ]]; then
  printf "Killing mpd socket process PID $SOCPID running on port: $PORT\n"
  /usr/bin/sudo /bin/kill -9 $SOCPID
fi

# start mpd unit systemd service
# socket service will be started by mpd service
/usr/bin/sudo /bin/systemctl start mpd.service
