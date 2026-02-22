#!/bin/bash

set -eu

LOG_DIR=/tmp/redirect
mkdir -p "$LOG_DIR"

pids=()
remote_servers=()

start_ddnet_srv() {
	local origins="$1"
	local port="$2"
	if [[ "$origins" != origins=* ]]; then
		echo "wrong origins"
		exit 1
	fi
	if [[ "$port" != port=* ]]; then
		echo "wrong port"
		exit 1
	fi
	origins="$(printf '%s' "$origins" | cut -d'=' -f2- | xargs)"
	port="$(printf '%s' "$port" | cut -d'=' -f2-)"

	pushd ~/Desktop/git/ddnet/build/ &> /dev/null
	local slug_origins
	slug_origins="$(printf '%s' "$origins" | sed 's/*/_WILD_/' | sed 's/[^a-z0-9\.]/_/')"
	name="localhost:$port, new ddnet, origins: $origins"
	if ./DDNet-Server "sv_allowed_origins $origins;sv_port $port;sv_name \"$name\"" &> "$LOG_DIR/new_ddnet_${port}_${slug_origins}.log" & then
		pids+=($!)
		printf '[*] started server on port %d\n' "$port"
		popd &> /dev/null
		return
	fi
	printf '[-] failed to start %s\n' "$name"
	exit 1
}

_start_ddnet_remote_srv() {
	set -eu
	printf '[*] connected to remote server %s .. OK\n' "$(hostname)"

	local remote="$1"
	local origins="$2"
	local port="$3"
	if [[ "$origins" != origins=* ]]; then
		echo "wrong origins: $origins"
		exit 1
	fi
	if [[ "$port" != port=* ]]; then
		echo "wrong port"
		exit 1
	fi
	origins="$(printf '%s' "$origins" | cut -d'=' -f2- | xargs)"
	port="$(printf '%s' "$port" | cut -d'=' -f2-)"

	cd ~/git/ddnet/build 2>/dev/null || cd ~/Desktop/git/ddnet/build

	local slug_origins
	slug_origins="$(printf '%s' "$origins" | sed 's/*/_WILD_/' | sed 's/[^a-z0-9\.]/_/')"
	name="$remote:$port, new ddnet, origins: $origins"
	if nohup ./DDNet-Server "sv_allowed_origins $origins;sv_port $port;sv_name \"$name\";echo kill-me-daddy" &> /tmp/error.log & then
		printf '[*] started server on host %s with port %d\n' "$remote" "$port"
		return
	fi
	printf '[-] failed to start %s\n' "$name"
	exit 1
}

start_ddnet_remote_srv() {
	local remote="$1"
	if ssh "$remote" "$(typeset -f _start_ddnet_remote_srv);_start_ddnet_remote_srv $*"; then
		printf '[*] started remote srv OK\n'
		remote_servers+=("$remote")
		return
	fi
	printf '[-] failed to start remote server\n'
	exit 1
}

start_ddnet_insta_srv() {
	local port="$1"
	if [[ "$port" != port=* ]]; then
		echo "wrong port"
		exit 1
	fi
	port="$(printf '%s' "$port" | cut -d'=' -f2-)"

	pushd ~/Desktop/git/ddnet-insta/build/ &> /dev/null
	name="localhost:$port, old ddnet, origins: NULL"
	if ./DDNet-Server "sv_port $port;sv_name \"$name\"" &> "$LOG_DIR/ddnet_insta_${port}.log" & then
		pids+=($!)
		printf '[*] started server on port %d\n' "$port"
		popd &> /dev/null
		return
	fi
	printf '[-] failed to start %s\n' "$name"
	exit 1
}

start_ddnet_srv origins='*' port=8303
start_ddnet_srv origins='192.168.178.78:*' port=8304
start_ddnet_insta_srv port=8305
start_ddnet_remote_srv 192.168.178.27 origins='*' port=8303
start_ddnet_remote_srv 192.168.178.27 origins='129.*' port=8303

kill_servers() {
	printf '[*] killing %d servers\n' "${#pids[@]}"
	local pid
	local remote
	for pid in "${pids[@]}"; do
		printf '[*] killid pid %d\n' "$pid"
		kill -9 "$pid"
	done

	for remote in "${remote_servers[@]}"; do
		printf '[*] killing servers on remote %s\n' "$remote"
		ssh "$remote" 'pkill -f kill-me-daddy'
	done
}

trap kill_servers EXIT

printf '[*] all servers started. CTRL+C to quit\n'
wait
