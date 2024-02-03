#!/usr/bin/env bash
set -eo pipefail

CMP_NAME=$(basename "$(dirname "${BASH_SOURCE[0]}")")
CMP_NAME=volumio-kiosk-vivaldi
log "Installing $CMP_NAME" "ext"

#shellcheck source=/dev/null
source /etc/os-release
export DEBIAN_FRONTEND=noninteractive

CMP_PACKAGES=(
  # Keyboard config
  "keyboard-configuration"
  # Display stuff
  "openbox" "xorg" "xinit" "libexif12" "unclutter" "libu2f-udev" "libvulkan1" "xinput"
  # Browser dependencies 
  "fonts-liberation" "libatk-bridge2.0-0" "libatk1.0-0" "libatspi2.0-0" "libgtk-3-0" "libnspr4" "libnss3" "xdg-utils"
  # Fonts
  "fonts-arphic-ukai" "fonts-arphic-gbsn00lp" "fonts-unfonts-core"
)

log "Installing ${#CMP_PACKAGES[@]} ${CMP_NAME} packages:" "" "${CMP_PACKAGES[*]}"
apt-get install -y "${CMP_PACKAGES[@]}" --no-install-recommends

log "${CMP_NAME} Dependencies installed!"

log "Download Vivaldi"
cd /home/volumio/
wget https://github.com/volumio/volumio3-os-static-assets/raw/master/browsers/vivaldi/vivaldi-stable_6.1.3035.302-1_armhf.deb

log "Install  Vivaldi"
sudo dpkg -i /home/volumio/vivaldi-*.deb
sudo apt-get install -y -f --no-install-recommends
sudo dpkg -i /home/volumio/vivaldi-*.deb

rm /home/volumio/vivaldi-*.deb

log "Cleaning Vivaldi Apt Sources"
rm /etc/apt/sources.list.d/vivaldi.list


log "Creating ${CMP_NAME} dirs and scripts"
mkdir /data/volumiokiosk

log " Creating Vivaldi kiosk start script" 

echo '#!/bin/bash 

mkdir -p /data/volumiokiosk 
export DISPLAY=:0 

xset s off -dpms 

if [ -L /data/volumiokiosk/SingletonCookie ]; then
  rm -rf /data/volumiokiosk/Singleton* 
fi

[[ -e /data/volumiokiosk/Default/Preferences ]] && {
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /data/volumiokiosk/Default/Preferences 
  sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' /data/volumiokiosk/Default/Preferences 
}

if [ ! -f /data/volumiokiosk/firststartdone ]; then
  echo "Volumio Kiosk Starting for the first time, giving time for Volumio To start"
  sleep 15
  touch /data/volumiokiosk/firststartdone
fi


# Wait for Volumio webUI to be available
while [[ $(curl -Is http://localhost:3000 | head -n 1 | cut -d " " -f 2) != 200 ]]; do sleep 2; done &

openbox-session & 
sleep 4 

/usr/bin/vivaldi --kiosk --no-sandbox --disable-background-networking --disable-remote-extensions --disable-pinch --ignore-gpu-blacklist --use-gl=egl --disable-gpu-compositing --enable-gpu-rasterization --enable-zero-copy --disable-smooth-scrolling --enable-scroll-prediction --max-tiles-for-interest-area=512 --num-raster-threads=4 --enable-low-res-tiling --user-agent="volumiokiosk-memorysave-touch" --touch-events --user-data-dir='/data/volumiokiosk' --force-device-scale-factor=1.2 --load-extension='/data/volumiokioskextensions/VirtualKeyboard/' --no-first-run --app=http://localhost:3000 
' > /opt/volumiokiosk.sh

/bin/chmod +x /opt/volumiokiosk.sh

log "Creating start script for X and Kioks"
echo '#!/bin/bash

echo "Starting Volumio Kiosk with arguments for cursor display"

KIOSK_ARGUMENTS_FILE=/data/kioskargs
[[ -f $KIOSK_ARGUMENTS_FILE ]] && ARGS=$(<$KIOSK_ARGUMENTS_FILE) || ARGS=""

/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh -- -keeptty $ARGS
' > /opt/startkiosk.sh

/bin/chmod +x /opt/startkiosk.sh


log "Creating Systemd Unit for Kiosk"
echo "[Unit]
Description=Start Volumio Kiosk
Wants=volumio.service
After=volumio.service
[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/startkiosk.sh
# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300
[Install]
WantedBy=multi-user.target
" > /lib/systemd/system/volumio-kiosk.service
/bin/ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service


log "Installing Virtual Keyboard"
mkdir /data/volumiokioskextensions
git clone https://github.com/volumio/chrome-virtual-keyboard.git /data/volumiokioskextensions/VirtualKeyboard

log "  Allowing volumio to start an xsession"
#/bin/sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config

log "Setting HDMI UI enabled by default"
config_path="/volumio/app/plugins/system_controller/system/config.json"
#shellcheck disable=SC2094
cat <<<"$(jq '.hdmi_enabled={value:true, type:"boolean"}' ${config_path})" >${config_path}

log "Show HDMI output selection"

echo '[{"value": false,"id":"section_hdmi_settings","attribute_name": "hidden"},{"value": false,"id":"hdmi_enabled","attribute_name": "hidden"}]' >/volumio/app/plugins/system_controller/system/override.json

log "Disable login prompt before browser starts"
systemctl disable getty@tty1.service

# TODO USE GLOBAL VARIABLE FOR DEVICES WITH INTEGRATED TOUCHSCREEN
if [[ ${VOLUMIO_HARDWARE} = cm4 || ${VOLUMIO_HARDWARE} = pi-kiosk ]]; then

  log "Hide HDMI output selection"
  echo '[{"value": false,"id":"section_hdmi_settings","attribute_name": "hidden"},{"value": true,"id":"hdmi_enabled","attribute_name": "hidden"},{"value": false,"id":"show_mouse_pointer","attribute_name": "hidden"}]' >/volumio/app/plugins/system_controller/system/override.json

  log "Disabling cursor by default on touchscreen devices"
  echo '-- -nocursor' > /data/kioskargs
  chmod 777 /data/kioskargs
fi
