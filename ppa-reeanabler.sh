#!/usr/bin/env bash
#
# _________        ____  ____________         _______ ___________________
# ______  /__________  |/ /___  ____/________ ___    |__  ____/___  ____/
# _  __  / __  ___/__    / ______ \  ___  __ \__  /| |_  /     __  __/
# / /_/ /  _  /    _    |   ____/ /  __  /_/ /_  ___ |/ /___   _  /___
# \__,_/   /_/     /_/|_|  /_____/   _  .___/ /_/  |_|\____/   /_____/
#                                    /_/           drxspace@gmail.com
#
#set -e
#set -x

# Using przemoc's lockable script boilerplate
# https://gist.github.com/przemoc/571091
LOCKFILE="/var/lock/`basename $0`"
LOCKFD=99

_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }

_prepare_locking

exlock_now()        { _lock xn; }  # obtain an exclusive lock immediately or fail
exlock()            { _lock x; }   # obtain an exclusive lock
unlock()            { _lock u; }   # drop a lock

# Check to see if all needed tools are present
# Prerequisites
if ! hash notify-send &>/dev/null; then
	echo -e ":: \e[1mnotify-send\e[0m: command not found!\nUse sudo apt-get install libnotify-bin to install it" 1>&2;
	exit 2;
fi
if ! hash wget &>/dev/null; then
	echo -e ":: \e[1mwget\e[0m: command not found!\nUse sudo apt-get install wget to install it" 1>&2;
	exit 3;
fi

# Getting access to the display
LANG=en_US.UTF-8
[[ -z "$DISPLAY" ]] && export DISPLAY=:0;
[[ -z "$XAUTHORITY" ]] && [[ -e "$HOME/.Xauthority" ]] && export XAUTHORITY="$HOME/.Xauthority";

# Run script as root
if [[ $EUID -ne 0 ]]; then
	exec $(which sudo) "$0" || exit 4;
fi

scriptName="PPA ReEanabler" # "$(basename $0)"

# Initialize the sound system
[[ -x $(which paplay 2>/dev/null) ]] && [[ -d /usr/share/sounds/freedesktop/stereo/ ]] && {
	WarnSnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/suspend-error.oga";
	StartSnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/window-attention.oga";
	FoundSnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/complete.oga";
	NoneSnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/message-new-instant.oga";
	HappySnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/bell.oga";
	UnhappySnd=${StartSnd};
}

ok () {
	local okay_x_col=$(($(tput cols)-6))
	echo -en "\r\033[${okay_x_col}C\e[104;97m[ OK ]\e[0m"
}
no () {
	local okay_x_col=$(($(tput cols)-6))
	echo -en "\r\033[${okay_x_col}C\e[100;97m[ NO ]\e[0m"
}

nUpRepos=0
nUpNewRepos=0
nEnabledRepos=0
nDisabledRepos=0
ReleaseCodename="$(lsb_release -cs)"

if [ -t 0 ]; then Terminal=true; else Terminal=false; fi

makeURL() {
	if $1; then
		local url="$(sed -n -e "s/^\(# \|\)deb //" -e "s/ # disabled on upgrade to $(echo ${ReleaseCodename})//"p "$2")";
	else
		local url="$(sed -n "s/^deb //"p "$2")";
	fi;
	if [[ $(echo -n "$url" | wc -w) -gt 2 ]]; then
		url="$(echo -n $url | tr \  \/)";
		echo -n "${url//$ReleaseCodename/dists\/$ReleaseCodename}";
	else
		echo -n "${url% *}";
	fi;
}

PPAisOK() {
	if [[ $(wget -q -t 1 --no-check-certificate -S --spider "$1" 2>&1 | grep -E '^\s*HTTP.*?200') ]]; then
		return 0;
	else
		return 1;
	fi;
}

getPPAsName() {
	echo -n "$(cat "$1" | grep -E "^deb " | cut -d\/ -f4)";
}

exlock_now || {
	$Terminal && echo -e "\e[1;31m (!) ${scriptName}:\e[0;31m This script is already running.\n    Please try again later...\e[0m" 1>&2 || {
		notify-send -h int:transient:1 -t 10000 -u normal -i face-sad "${scriptName}" "\nThis script is already running.\nPlease try again later...";
	}
	$(${WarnSnd});
	exit 1;
}

# ______________________________________________________________________________
# ------------------------------------------------------------------------------

# Turns OFF the cursor
echo -en "\e[?25l"

# Silently change/update the release's codename in these lines containing
# the string "# disabled on upgrade to <whatever>" to the current codename
grep -lE "# disabled on upgrade to" /etc/apt/sources.list.d/*.list \
	| xargs sed -i "s/# disabled on upgrade to .*/# disabled on upgrade to $(echo ${ReleaseCodename})/"

# ------------------------------------------------------------------------------

if [[ $# -ge 1 ]] && [[ "$1" == @(-e|--check-enabled) ]]; then
	# Check enabled repositories to see if they exist and if not disable those
	# that don't
	grep -lEv "^# (deb|deb-src) " /etc/apt/sources.list.d/*.list > /tmp/wantchk4exst.lst
	nEnabledRepos=$(wc -l < /tmp/wantchk4exst.lst)

	if [[ $nEnabledRepos -gt 0 ]]; then
		$Terminal && echo -en "\e[1;94m::\e[0;94m There are $nEnabledRepos enabled repositories that I'll check for their well-being.\n   Please wait for this process to complete...\e[0m" || {
			notify-send "${scriptName}" "\nThere are $nEnabledRepos enabled repositories that I'll check for their well-being.\nPlease wait for this process to complete..." -h int:transient:1 -t 3000 -u normal -i face-wink;
			$(${StartSnd});
		}
		for PPAfn in $(cat /tmp/wantchk4exst.lst); do
			PPAurl=$(makeURL false "${PPAfn}");
			if ! PPAisOK "${PPAurl}"; then
				sed -i -e "s/^deb /# deb /" -e "/deb /s/$/ # disabled on upgrade to $(echo ${ReleaseCodename})/" "${PPAfn}";
				: $(( nDisabledRepos++ ));
			fi;
		done
	fi
	[[ $nDisabledRepos -gt 0 ]] && {
		$Terminal && echo -e "\n\e[1;31m (!) ${scriptName}:\e[0;31m $nDisabledRepos repositories were disabled.\e[0m" || {
			notify-send "${scriptName}" "\n$nDisabledRepos repositories were disabled." -h int:transient:1 -t 3000 -u normal -i face-worried;
		}
		$(${WarnSnd});
	} || {
		$Terminal && echo -e "\nDone. All enabled repositories are okay." || {
			notify-send "${scriptName}" "\nAll enabled repositories are okay." -h int:transient:1 -t 3000 -u normal -i face-cool;
			$(${HappySnd});
		}
	}
fi

# ------------------------------------------------------------------------------

grep -lE "# disabled on upgrade to" /etc/apt/sources.list.d/*.list > /tmp/wantchk4upg.lst
nUpRepos=$(wc -l < /tmp/wantchk4upg.lst)

if [[ $nUpRepos -gt 0 ]]; then
	$Terminal && echo -en "\e[1;94m::\e[0;94m There are $nUpRepos disabled repositories that I'll try to re-enable.\n   Please wait for this process to complete...\e[0m" || {
		notify-send "${scriptName}" "\nThere are $nUpRepos disabled repositories that I'll try to re-enable.\nPlease wait for this process to complete..." -h int:transient:1 -t 3000 -u normal -i face-wink;
		$(${StartSnd});
	}

	for PPAfn in $(cat /tmp/wantchk4upg.lst); do
		PPAurl=$(makeURL true "${PPAfn}");
		$Terminal && echo -en "\n  -> URL in process: ${PPAurl}";
		if PPAisOK "${PPAurl}"; then
			$Terminal && ok
			: $(( nUpNewRepos++ ));
			$Terminal && echo -en "\e[1;32m\n +++ Re-enabled repository's URL: ${PPAurl}\e[0m" || {
				notify-send "${scriptName}" "\n$(getPPAsName "${PPAfn}") repository was re-enabled." -h int:transient:1 -t 3000 -u normal -i face-smile;
			}
			$(${FoundSnd});
			echo ${PPAfn} >> /tmp/wantupg.new-lst;
		else
			$Terminal && no;
		fi;
	done
	# Re-enable any working repositories
	[[ -f /tmp/wantupg.new-lst ]] && \
		cat /tmp/wantupg.new-lst \
		| xargs sed -i -e "s/^# deb /deb /" -e "/deb /s/ # disabled on upgrade to $(echo ${ReleaseCodename})$//";
fi

# ______________________________________________________________________________
# ------------------------------------------------------------------------------

if [[ $nUpRepos -eq 0 ]]; then
	$Terminal && echo -e "There are no repositories to re-enable. Bye!" || {
		notify-send "${scriptName}" "\nThere are no repositories to re-enable. Bye!" -h int:transient:1 -t 3000 -u normal -i face-smirk;
		$(${NoneSnd});
	}
elif [[ $nUpNewRepos -gt 0 ]]; then
	$Terminal && echo -e "\nDone. $nUpNewRepos disabled repositories were re-enabled." || {
		notify-send "${scriptName}" "\n$nUpNewRepos repositories were re-enabled." -h int:transient:1 -t 3000 -u normal -i face-cool;
		$(${HappySnd});
	}
else # $nUpRepos -gt 0 && $nUpNewRepos -eq 0
	$Terminal && echo -e "\nDone. None of the disabled repositories was re-enabled." || {
		notify-send "${scriptName}" "\nNone of the repositories was re-enabled." -h int:transient:1 -t 3000 -u normal -i face-sad;
		$(${UnhappySnd});
	}
fi

# Do some clean up
rm -f /tmp/wantchk4upg.lst /tmp/wantchk4exst.lst

# Turns ON the cursor
echo -en "\e[?25h"

unlock

exit $?
