#!/bin/bash

SSH_CONFIG="$HOME/.ssh/config"

function usage() {
    echo "Usage: $0 {add|delete|update|get} -h <Hostname> [-u <Username>] [-i <IP-Address>] [-k <Keyfile>] [-p <ProxyCommand>]"
    exit 1
}

function add_entry() {
    local host="$1"
    local user="$2"
    local ip="$3"
    local keyfile="$4"
    local proxy="$5"

    # Prüfen, ob der Host bereits existiert
    if grep -q "Host $host" "$SSH_CONFIG"; then
        echo "Error: Host '$host' already exists. Use update instead."
        exit 1
    fi

    echo "Adding SSH config entry for $host..."
    {
        echo "Host $host"
        echo "    HostName $ip"
        echo "    User $user"
        echo "    IdentityFile $keyfile"
        [ -n "$proxy" ] && echo "    ProxyCommand $proxy"
        echo ""
    } >> "$SSH_CONFIG"

    echo "Added successfully."
}

function delete_entry() {
    local host="$1"

    # Prüfen, ob der Host existiert
    if ! grep -q "Host $host" "$SSH_CONFIG"; then
        echo "Error: Host '$host' does not exist."
        exit 1
    fi

    echo "Deleting SSH config entry for $host..."
    awk -v h="$host" '
        $1 == "Host" && $2 == h {skip=1; next}
        skip && /^$/ {skip=0; next}
        !skip {print}
    ' "$SSH_CONFIG" > "$SSH_CONFIG.tmp" && mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"

    echo "Deleted successfully."
}

function update_entry() {
    local host="$1"
    local user="$2"
    local ip="$3"
    local keyfile="$4"
    local proxy="$5"

    # Prüfen, ob der Host existiert
    if ! grep -q "Host $host" "$SSH_CONFIG"; then
        echo "Error: Host '$host' does not exist. Use add instead."
        exit 1
    fi

    echo "Updating SSH config entry for $host..."
    delete_entry "$host"
    add_entry "$host" "$user" "$ip" "$keyfile" "$proxy"
}

function get_entry() {
    local host="$1"

    # Prüfen, ob der Host existiert
    if ! grep -q "Host $host" "$SSH_CONFIG"; then
        echo "Error: Host '$host' does not exist."
        exit 1
    fi

    echo "SSH config entry for $host:"
    awk -v h="$host" '
        $1 == "Host" && $2 == h {print; flag=1; next}
        flag && /^$/ {flag=0}
        flag {print}
    ' "$SSH_CONFIG"
}

# Parameter einlesen
COMMAND="$1"
shift

while getopts "h:u:i:k:p:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG" ;;
        u) USERNAME="$OPTARG" ;;
        i) IP_ADDRESS="$OPTARG" ;;
        k) KEYFILE="$OPTARG" ;;
        p) PROXY_COMMAND="$OPTARG" ;;
        *) usage ;;
    esac
done

# Überprüfen, ob notwendige Parameter angegeben sind
if [[ -z "$HOSTNAME" ]]; then
    echo "Error: Hostname (-h) is required."
    usage
fi

case "$COMMAND" in
    add)
        [[ -z "$USERNAME" || -z "$IP_ADDRESS" || -z "$KEYFILE" ]] && usage
        add_entry "$HOSTNAME" "$USERNAME" "$IP_ADDRESS" "$KEYFILE" "$PROXY_COMMAND"
        ;;
    delete)
        delete_entry "$HOSTNAME"
        ;;
    update)
        [[ -z "$USERNAME" || -z "$IP_ADDRESS" || -z "$KEYFILE" ]] && usage
        update_entry "$HOSTNAME" "$USERNAME" "$IP_ADDRESS" "$KEYFILE" "$PROXY_COMMAND"
        ;;
    get)
        get_entry "$HOSTNAME"
        ;;
    *)
        usage
        ;;
esac
