#!/bin/bash

case "$1" in
"plugin")
APP="ALSA plug-in \[plugin-container\]"
;;
"mplayer")
APP="MPlayer"
;;
*)
APP=$1
;;
esac
if [ -z $1 ]; then
APP='amarok'
fi
if [ -z $2 ]; then
	SINK='1'
else
	SINK=$2
fi
pacmd move-sink-input $(pacmd list-sink-inputs | grep -B 19 "application.name = \"${APP}\"" | head -1 | cut -c 12-) ${SINK} > /dev/null 2>&1
