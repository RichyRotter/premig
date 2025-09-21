#!/bin/bash

SSH_CONFIG="$HOME/.ssh/config"
PROXY_LIST="$HOME/.ssh/proxy_list"
SSH_KEYS=("$HOME/.ssh/"priv_*)

function usage() {
    echo "Usage: $0 -n <Name> -ip <ip-adr> -u <User>"
    exit 1
}

function check_ssh_config() {
    local name="$1"
    local ip=$2

     timeout 5 ssh "$ip" "pwd"
     if [ $? -eq 0 ]; then
#    if grep -q "Host $name" "$SSH_CONFIG"; then
        echo "✅ Host '$name' is already configured in $SSH_CONFIG. Nothing to do."
        exit 0
    fi
}

function try_ssh_connection() {
    local ip="$1"
    local user="$2"
    local keyfile="$3"
    local name="$4"
    local proxy_cmd="$5"

    local ssh_options="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=2"

    sleep 1

if [[ -n "$proxy_cmd" ]]; then
    ssh_options="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=1 -o ProxyCommand=\"$proxy_cmd\""
fi

#echo "Trying SSH with key: $keyfile..."
#ssh $ssh_options -i "$keyfile" "$user@$ip" "exit" &>/dev/null
cmd=$(echo "ssh  -i $keyfile $ssh_options  $user@$ip \"exit\"")
eval $cmd &>/dev/null
return $?
}

function find_working_key() {
local ip="$1"
local user="$2"
local name="$3"
local cnt=0
local cnt2=0

for keyfile in "${SSH_KEYS[@]}"; do
[[ ! -f "$keyfile" || "$keyfile" == *.pub ]] && continue # Skip invalid files
let cnt=${cnt}+1
let cnt2=${cnt2}+1
if [ $cnt2 -eq 5 ]; then
	cnt2=0
        printf "\r%-22s %-15s %-15s %-15s %-12s %-10s" "Trying ssh for" "$IP" "$USER" "$NAME" "w.o. proxy:" "$cnt"
fi

try_ssh_connection "$ip" "$user" "$keyfile" "$name"
if [[ $? -eq 0 ]]; then
    keyf=$(echo "~/.ssh/`basename $keyfile`")

    prconf=$(cat $PROXY_LIST | grep $ip | wc -l )

    if [[ $prconf -eq 0 ]]; then
	if [[ "$prxy" != "zdm" ]]; then
            echo "ssh -i ssh -i $keyfile  -o StrictHostKeyChecking=no -W %h:%p $user@$ip" >> $PROXY_LIST
        fi
    fi

    echo
    echo "-------------FOUND KEY----------------------------"
    echo "Found working key: $keyfile"
    echo "Host $name" >> "$SSH_CONFIG"
    echo " HostName $ip" >> "$SSH_CONFIG"
    echo " User $user" >> "$SSH_CONFIG"
    echo " IdentityFile $keyf" >> "$SSH_CONFIG"
    echo "" >> "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    exit 0
fi
done
}

function try_proxy_connections() {
local ip="$1"
local user="$2"
local name="$3"
local cnt=0
local cnt2=0

if [[ ! -f "$PROXY_LIST" ]]; then
echo "No proxy list found. Cannot try proxy connections."
exit 1
fi

while IFS= read -r proxy_cmd; do
for keyfile in "${SSH_KEYS[@]}"; do
    [[ ! -f "$keyfile" || "$keyfile" == *.pub ]] && continue
let cnt=${cnt}+1
let cnt2=${cnt2}+1
if [ $cnt2 -eq 5 ]; then
	cnt2=0
    printf "\r%-22s %-15s %-15s %-15s %-22s %-28s %-10s" "Trying ssh for" "$IP" "$USER" "$NAME" "w.o. proxy:" "not possibel; try w, proxy:" "$cnt"
fi
    try_ssh_connection "$ip" "$user" "$keyfile" "$name" "$proxy_cmd" 
    if [[ $? -eq 0 ]]; then
	keyf=$(echo "~/.ssh/`basename $keyfile`")
	echo "✅ Found working key via proxy: $keyfile (ProxyCommand: $proxy_cmd)"
	echo "Host $name" >> "$SSH_CONFIG"
	echo " HostName $ip" >> "$SSH_CONFIG"
	echo " User $user" >> "$SSH_CONFIG"
	echo " IdentityFile $keyf" >> "$SSH_CONFIG"
	echo " ProxyCommand $proxy_cmd" >> "$SSH_CONFIG"
	echo "" >> "$SSH_CONFIG"
	chmod 600 "$SSH_CONFIG"
	exit 0
    fi
done
done < "$PROXY_LIST"

echo "❌ No working key found, even via proxy."
exit 1
}

# Parameter einlesen
while getopts "n:u:i:x:" opt; do
case $opt in
i) IP="$OPTARG" ;;
n) NAME="$OPTARG" ;;
u) USER="$OPTARG" ;;
x) prxy="$OPTARG" ;;
*) usage ;;
esac
done

if [[ -z "$IP" || -z "$USER" || -z "$NAME" ]]; then
    echo "Error: Name (-n), Ip (-i) and User (-u) are required."
    usage
fi

check_ssh_config "$NAME" "$IP"


printf "%-22s %-15s %-15s %-15s %-12s" "Trying ssh for" "$IP" "$USER" "$NAME" "w.o. proxy:"
nc -zv -w 3 $IP 22  &>/dev/null
if [[ $? -eq 0 ]]; then
  find_working_key "$IP" "$USER" "$NAME"
else
   printf "\r%-22s %-15s %-15s %-15s %-22s" "Trying ssh for" "$IP" "$USER" "$NAME" "w.o. proxy:" "not possibel"
fi

if [[ "$prxy" == "zdm" ]]; then
  PROXY_LIST="$HOME/.ssh/proxy_list_zdm"
fi

if [[ "$prxy" != "no" ]]; then
   
  printf "\r%-22s %-15s %-15s %-15s %-22s %-28s" "Trying ssh for" "$IP" "$USER" "$NAME" "w.o. proxy:" "not possibel; try w, proxy:"
  try_proxy_connections "$IP" "$USER" "$NAME"               

fi
echo "Could not connect to '$IP' with any key or proxy."
exit 1
