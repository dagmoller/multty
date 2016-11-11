#!/bin/bash

GREEN="\033[1;32m"
CLEAR="\033[0m"
CURRENTTAGGED="\033[1;32;43m"
CURRENTNONTAGGED="\033[1;32m"
TAGGED="\033[0;43m"
BGREDBLINK="\033[1;41;5m"

function getKeystroke {
	old_stty_settings=$(stty -g)
	stty -echo raw
	echo "$(dd count=1 2> /dev/null)"
	stty $old_stty_settings
}

function createLayout {
	tmux split-window -h
	tmux split-window -t0 -v

	tmux resize-pane -t0 -x32
	tmux resize-pane -t2 -y2

	tmux send-keys -t1 "$0 startSSH" C-m
	tmux send-keys -t2 "$0 multicastRead" C-m
}

function displayMenu {
	while [ 1 ]; do
		sleep 0.1
		clear
		echo -e "======= [ multty  v0.1 ] ======="
		echo -e "${GREEN}[F2]${CLEAR}:  previous window"
		echo -e "${GREEN}[F3]${CLEAR}:  next window"
		echo -e "${GREEN}[F4]${CLEAR}:  tag/untag window"
		echo -e "${GREEN}[F5]${CLEAR}:  add window"
		echo -e "${GREEN}[F6]${CLEAR}:  del window"
		echo -e "${GREEN}[F7]${CLEAR}:  multicast mode"
		echo -e "${GREEN}[F12]${CLEAR}: quit"
		echo -e "================================"
		echo
	
		OLDIFS=$IFS
		IFS=$'\n'
		for window in $(tmux list-window -F "#I:::#W:::#F"); do
			wIndex=$(echo "$window" | awk -F ':::' '{print $1}')
			wName=$(echo "$window" | awk -F ':::' '{print $2}')
			wActive=$(echo "$window" | awk -F ':::' '{print $3}')

			if [ $(echo "$wName" | grep -c ssh) -eq 0 ]; then
				continue
			fi
			wName=$(echo "$wName" | sed "s/ssh: //")

			echo -ne " ${wIndex}. "
			if [ "$wActive" == "*" ]; then
				if [ $(echo "$wName" | grep -c "(t)") -gt 0 ]; then
					echo -e "${CURRENTTAGGED} ${wName} ${CLEAR}"
				else
					echo -e "${CURRENTNONTAGGED} ${wName} ${CLEAR}"
				fi
			else
				if [ $(echo "$wName" | grep -c "(t)") -gt 0 ]; then
					echo -e "${TAGGED} ${wName} ${CLEAR}"
				else
					echo -e "${CLEAR} ${wName} ${CLEAR}"
				fi
			fi
		done
		IFS=$OLDIFS
	
		echo
		echo -n "================================"

		sessionName=$(tmux display-message -p "#S")
		filename=/tmp/multty-${sessionName}-multicast
		if [ -f $filename ]; then
			echo
			echo -e "${BGREDBLINK}     [ MULTICAST ENABLED ]      ${CLEAR}"
			#tmux set-window-option status-bg red
			tmux select-pane -t 2
		else
			#tmux set-window-option status-bg black
			tmux select-pane -t 1
		fi

		read
	done
}

function updateMenu {
	for window in $(tmux list-window -F "#I"); do
		tmux send-keys -t ${window}.0 C-m
	done
}

function startSSH {
	clear
	tmux rename-window "ssh: new"
	host=
	while [ "$host" == "" ]; do
		read -p "Connect to: " host
		tmux rename-window "ssh: $host"
		updateMenu
		ssh $host
		if [ $? -eq 0 ]; then
			break
		fi
		echo
		host=
	done
	updateMenu
}

if [ "$1" == "displayMenu" ]; then
	displayMenu
	exit 0
fi

if [ "$1" == "newWindow" ]; then
	createLayout
	displayMenu
	exit 0
fi

if [ "$1" == "startSSH" ]; then
	startSSH
	tmux kill-window
	updateMenu
	exit 0
fi

if [ "$1" == "tag" ]; then
	currentName=$(tmux display-message -t! -p "#W")
	count=$(echo "$currentName" | grep -c "(t)")
	if [ $count -eq 0 ]; then
		tmux rename-window -t! "${currentName} (t)"
	else
		newName=$(echo "$currentName" | sed "s/ (t)//")
		tmux rename-window -t! "$newName"
	fi
	updateMenu 
	exit 0
fi

if [ "$1" == "previousWindow" ]; then
	tmux previous-window
	updateMenu
	exit 0
fi
if [ "$1" == "nextWindow" ]; then
	tmux next-window
	updateMenu
	exit 0
fi
if [ "$1" == "killWindow" ]; then
	tmux kill-window -t!
	updateMenu
	exit 0
fi

if [ "$1" == "multicast" ]; then
	sessionName=$(tmux display-message -p "#S")
	filename=/tmp/multty-${sessionName}-multicast
	if [ ! -f $filename ]; then
		touch /tmp/multty-${sessionName}-multicast
	else
		rm -rf $filename
	fi
	updateMenu
	exit 0
fi

if [ "$1" == "multicastRead" ]; then
	tmux resize-pane -y 2
	tmux select-pane -t 1

	sessionName=$(tmux display-message -p "#S")
	filename=/tmp/multty-${sessionName}-multicast

	while [ 1 ]; do
		clear
		key=$(getKeystroke)

		if [ -f $filename ]; then
			isTagged=$(tmux display-message -p "#W" | grep -c "(t)")
			currentIndex=$(tmux display-message -p "#I")

			OLDIFS=$IFS
			IFS=$'\n'
			for window in $(tmux list-window -F "#I:::#W"); do
				wIndex=$(echo "$window" | awk -F ':::' '{print $1}')
				wName=$(echo "$window" | awk -F ':::' '{print $2}')

				if [ $isTagged -gt 0 ]; then
					if [ $(echo "$wName" | grep -c "(t)") -gt 0 ]; then
						tmux send-keys -t ${wIndex}.1 "$key"
					fi
				else
					if [ "$currentIndex" == "$wIndex" ]; then
						tmux send-keys -t ${wIndex}.1 "$key"
					fi
				fi
			done
			IFS=$OLDIFS
		fi
	done
	exit 0
fi

## Main Running
sessionName=multty$$

tmux new-session -s $sessionName -d $0 displayMenu
tmux set-option remain-on-exit on

createLayout


## Key Bindings
tmux bind-key -n F2 new-window -d $0 previousWindow
tmux bind-key -n F3 new-window -d $0 nextWindow
tmux bind-key -n F4 new-window $0 tag
tmux bind-key -n F5 new-window $0 newWindow
tmux bind-key -n F6 new-window $0 killWindow
tmux bind-key -n F7 new-window $0 multicast
tmux bind-key -n F12 kill-session

tmux attach
