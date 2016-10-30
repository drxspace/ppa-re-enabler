#!/usr/bin/env bash
#
# _________        ____  ____________         _______ ___________________
# ______  /__________  |/ /___  ____/________ ___    |__  ____/___  ____/
# _  __  / __  ___/__    / ______ \  ___  __ \__  /| |_  /     __  __/
# / /_/ /  _  /    _    |   ____/ /  __  /_/ /_  ___ |/ /___   _  /___
# \__,_/   /_/     /_/|_|  /_____/   _  .___/ /_/  |_|\____/   /_____/
#                                    /_/           drxspace@gmail.com
#

# Getting access to the display
LANG=en_US.UTF-8
[[ -z "$DISPLAY" ]] && export DISPLAY=:0;
[[ -z "$XAUTHORITY" ]] && [[ -e "$HOME/.Xauthority" ]] && export XAUTHORITY="$HOME/.Xauthority";

PREOption="$1"

if [[ "$XAUTHORITY" ]]; then
	pkexec "$(which ppa-reeanabler)" ${PREOption}
elif [[ -x "$(which gksu)" ]]; then
	gksu -S -m "Re-enable Repositories requires admin privileges for its tasks" "$(which ppa-reeanabler)" ${PREOption}
elif [[ -x "$(which kdesu)" ]]; then
	kdesu "$(which ppa-reeanabler)" ${PREOption}
else
	notify-send "Re-enable Repositories" "No authentication program found." -i face-sad &
	exit 1
fi

exit 0
