#!/bin/bash
#se#t -Eeuo pipefail

# ==========================
# Configuration (SEPS / Wallet)
# ==========================
# TNS_ADMIN must point to your wallet directory (sqlnet.ora, tnsnames.ora, ewallet.sso)
. ../premigration.env

RESET="\e[0m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
BOLD="\e[1m"
ITALIC="\e[3m"


# TNS alias stored in SEPS credentials (mkstore)
DB_ALIAS="${DB_ALIAS:-mondbp_mig}"   # -> connect with: sqlplus /@mondb_mig

rrent_user=$(whoami)

if [ "$current_user" != "mig" ]; then
   trap cleanup EXIT INT TERM
fi


cleanup() {
        exit
}




# ==========================
# Dependency check
# ==========================
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need gum
need sqlplus
need openssl

# ==========================
# Helper functions
# ==========================

run_sqlplus() {
  # Usage: run_sqlplus <<'SQL' ... SQL
  local tmpfile
  tmpfile="$(mktemp /tmp/sqlplus_debug_XXXX.sql)"

  # Copy stdin (SQL text) into tmp file and also feed to sqlplus
  # tee -a appends to debug log for history
  tee "$tmpfile" | tee -a /tmp/sqlplus_debug_all.sql | sqlplus -s "/@mondbp_mig"

}

run_sqlplus2() {
  # Usage: run_sqlplus <<'SQL' ... SQL
  sqlplus -s "/@${DB_ALIAS}"
}

sql_scalar() { awk 'NF {print; exit}'; }  # to be used after run_sqlplus output

esc_sql() { echo "$1" | sed "s/'/''/g"; }

banner() {
  clear
  gum style --foreground=$AC_RED --background=$AC_BLACK \
    --border rounded --margin "1 2" --padding "1 3" \
    --align center --width 70 --bold \
"PRE-MIGRATION TEST SUITE" \
"Oracle Infrastructure Checks for OD@Azure"

  gum style  --foreground=$AC_RED --background=$AC_BLACK \
    --align left --width 90 --bold \
" " \
" " \
"      M     M   OOOOO   DDDDD   EEEEE  RRRRR   N     N  EEEEE  X     X" \
"      MM   MM  O     O  D    D  E      R    R  NN    N  E       X   X" \
"      M M M M  O     O  D     D EEEE   RRRRR   N N   N  EEEE     X X" \
"      M  M  M  O     O  D    D  E      R   R   N  N  N  E       X   X" \
"      M     M   OOOOO   DDDDD   EEEEE  R    R  N   N N  EEEEE  X     X" 

  gum style  --foreground=$AC_YELLOW --background=$AC_BLACK \
    --align left --width 90 --bold \
" " \
" " \
"              PPPPPP   RRRRRR   EEEEE  M     M  III  GGGGG" \
"              P     P  R     R  E      MM   MM   I  G" \
"              PPPPPP   RRRRRR   EEEE   M M M M   I  G  GGG" \
"              P        R  R     E      M  M  M   I  G    G" \
"              P        R   R    EEEEE  M     M  III  GGGGG" 

  gum style  --foreground=$AC_CYAN --background=$AC_BLACK \
    --align left --width 90 --bold \
" " \
" " \
"   TTTTTTT  EEEEE  SSSSS  TTTTTTT  SSSSS   U     U  III  TTTTTTT  EEEEE" \
"      T     E      S         T     S       U     U   I      T     E" \
"      T     EEEE    SSS      T      SSS    U     U   I      T     EEEE" \
"      T     E          S     T         S   U     U   I      T     E" \
"      T     EEEEE  SSSSS     T     SSSSS    UUUUU   III     T     EEEEE" \
" " \
" " 
  gum style --foreground=$AC_WHITE --background=$AC_BLACK \
     --width 80 --bold \
"Please do a quick one time registration to get your personal workspace..." \
"  "
}

# ==========================
# Ensure table exists
# ==========================
ensure_table() {
  # check if table exists
  exists="$(
    run_sqlplus <<SQL | sql_scalar
set heading off feedback off pagesize 0 verify off linesize 32767 trims on termout on
select count(*) from user_tables where table_name='MIG_PREMIG_USERS';
SQL
  )"

  if [[ "${exists:-0}" == "0" ]]; then
    gum style --foreground 4 "Creating MIG_PREMIG_USERS table..."
    run_sqlplus <<'SQL'
set heading off feedback off pagesize 0 verify off linesize 32767 trims on termout on
declare
  e_exists exception; pragma exception_init(e_exists, -955);
begin
  execute immediate '[
    create table MIG_PREMIG_USERS (
      USERNAME       varchar2(128) not null,
      email_user     varchar2(128) not null,
      PASSWORD_HASH  varchar2(64)  not null,
      SALT_HEX       varchar2(32)  not null,
      CREATED_AT     timestamp(6)  default systimestamp not null,
      LAST_LOGIN_AT  timestamp(6),
      wokspace_nr    number,
      constraint PK_MIG_PREMIG_USERS primary key (USERNAME)
    )
  ]';
exception when e_exists then null;
end;
/
create index IX_MPU_CREATED on MIG_PREMIG_USERS(CREATED_AT);
commit;
SQL
    gum style --foreground 2 "Table created (or already existed)."
  fi
}

user_exists() {
  local u; u="$(esc_sql "$1")"
  run_sqlplus <<SQL | sql_scalar
set heading off feedback off pagesize 0 verify off linesize 32767 trims on
select trim(to_char(count(*))) from MIG_PREMIG_USERS where USERNAME='${u}';
SQL
}

insert_user() {
  local user="$1" pass="$2" email="$3"
  local salt hash u
  salt="$(openssl rand -hex 16)"
  hash="$(printf "%s" "${salt}:${pass}" | openssl dgst -sha256 | awk '{print $2}')"
  u="$(esc_sql "$user")"
  run_sqlplus <<SQL >/dev/null
set heading off feedback off pagesize 0 verify off linesize 32767 trims on termout on
declare
  v_wsnr number;
begin
  select s1.nextval into v_wsnr from dual;
  insert into MIG_PREMIG_USERS (USERNAME, email_user, PASSWORD_HASH, SALT_HEX, CREATED_AT, wokspace_nr)
  values ('${u}', '$email', '${hash}', '${salt}', systimestamp,v_wsnr);
end;
/
commit;
SQL
}

read_email() {
  local u="$1"
email=$( run_sqlplus <<SQL | sql_scalar
set heading off feedback off pagesize 0 verify off linesize 32767 trims on termout on
select email_user from MIG_PREMIG_USERS where USERNAME='${u}';
SQL
)
}

read_wsnr() { 
  local u="$1"
	wsnr=$( run_sqlplus <<SQL | sql_scalar
set heading off feedback off pagesize 0 verify off linesize 32767 trims on termout on
select ltrim(rtrim(nvl(wokspace_nr,999999))) from MIG_PREMIG_USERS where USERNAME='${u}';
SQL
)
}


verify_login() {
  local user="$1" pass="$2"
  local u row salt dbhash cand
u="$(esc_sql "$user")"
  row="$(
    run_sqlplus <<SQL | sql_scalar
set heading off feedback off pagesize 0 verify off linesize 32767 trims on termout on
select SALT_HEX||'|'||PASSWORD_HASH from MIG_PREMIG_USERS where USERNAME='${u}';
SQL
  )" || true
  [[ -z "${row:-}" ]] && return 2
  salt="${row%%|*}"; dbhash="${row##*|}"
  cand="$(printf "%s" "${salt}:${pass}" | openssl dgst -sha256 | awk '{print $2}')"
  if [[ "$cand" == "$dbhash" ]]; then
    run_sqlplus <<SQL >/dev/null
set heading off feedback off pagesize 0 verify off linesize 32767 trims on termout on
update MIG_PREMIG_USERS set LAST_LOGIN_AT=systimestamp where USERNAME='${u}';
commit;
SQL
    return 0
  else
    return 1
  fi
}

# ==========================
# UI flows
# ==========================
register_flow() {
  while true; do
    local user email pass1 pass2 exists
    user="$(gum input --placeholder 'Username' --width 60 || true)"
    [[ -z "${user:-}" ]] && { gum style --foreground 3 "Cancelled."; return 130; }

    exists="$(user_exists "$user")"
    if [[ "${exists:-0}" != "0" ]]; then
      gum style --foreground 1 "User already exists."
      gum confirm "Try another name?" || return 1
      continue
    fi

is_valid_email() {
  local e="$1"
  [[ "$e" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}$ ]]
}

# Prompt until valid (Ctrl-C or Esc to abort)
ask_email() {
  local email
  while :; do
    email="$(gum input --prompt 'Email: ' --placeholder 'name@example.com')" || return 1
    # optional trim
    email="${email#"${email%%[![:space:]]*}"}"; email="${email%"${email##*[![:space:]]}"}"
    if [[ -z "$email" ]]; then
      gum style --foreground 1 "Email is required."
      continue
    fi
    if is_valid_email "$email"; then
      printf '%s\n' "$email"
      return 0
    else
      gum style --foreground 1 "Invalid email format. Try again (e.g., name@example.com)."
    fi
  done
}

# Example usage:
email="$(ask_email)" 

    pass1="$(gum input --password --placeholder 'Password' --width 60 || true)"
    [[ -z "${pass1:-}" ]] && { gum style --foreground 3 "Cancelled."; return 130; }
    pass2="$(gum input --password --placeholder 'Repeat password' --width 60 || true)"
    [[ -z "${pass2:-}" ]] && { gum style --foreground 3 "Cancelled."; return 130; }
    if [[ "$pass1" != "$pass2" ]]; then
      gum style --foreground 1 "Passwords do not match."
      gum confirm "Try again?" || return 1
      continue
    fi

    gum style --foreground 4 "Registering user..."
    insert_user "$user" "$pass1" "$email"
    gum style --foreground 2 --bold "Registration successful."
    return 0
  done
}

login_flow() {
  local user pass
  user="$(gum input --placeholder 'Username' --width 60 || true)"
  [[ -z "${user:-}" ]] && { gum style --foreground 3 "Cancelled."; return 130; }
  pass="$(gum input --password --placeholder 'Password' --width 60 || true)"
  [[ -z "${pass:-}" ]] && { gum style --foreground 3 "Cancelled."; return 130; }

  gum style --foreground 4 "Checking credentials..."
  if verify_login "$user" "$pass"; then
    read_email  ${user}
    read_wsnr  ${user}
    ws_user=${user}
    gum style --foreground 2 --bold "Login successful. Welcome, ${user} - $email - $wsnr"
    sleep 2

    goto="$HOME/$wsnr/premigration/scripts"
    if [ ! -d $goto ]; then
       goto="$HOME/newuser/premigration/scripts"
    fi
    
    if [ ! -d $goto ]; then
       echo "Error - login no possibel"
       sleep 3
       exit 1 
    fi

    cd $goto
    source ../premigration.env
    ./premig_menu.sh "${user}" "$email" "$wsnr"

    return 0
  else
    local exists; exists="$(user_exists "$user")"
    if [[ "${exists:-0}" != "0" ]]; then
      gum style --foreground 1 "Login failed (wrong password)."
    else
      gum style --foreground 1 "Unknown user."
    fi
    return 1
  fi
}





# ==========================
# Main
# ==========================
# Bildschirm löschen, Hintergrund schwarz setzen, Text weiß
printf "\033[40;37m\033[2J\033[H"

# Sanity check: can we connect to DB?
if ! echo "select 1 from dual;" | run_sqlplus >/dev/null; then
  gum style --foreground 1 --bold "Cannot connect to DB using SEPS alias '${DB_ALIAS}'."
  gum style --foreground 3 "Check TNS_ADMIN, wallet, and mkstore credentials."
  exit 2
fi

ensure_table

while true; do
  banner
  choice="$(gum choose  "Login" "Register" "Exit")"
  case "$choice" in
    "Register") register_flow; sleep 3;;
    "Login")    login_flow; sleep 3 ;;
    "Exit")     exit 0 ;;
  esac
done
exit 0
