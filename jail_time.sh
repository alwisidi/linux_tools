#!/bin/bash
# This script initialize, update, and remove jail if needed
# WARNING: run the script as ROOT

#######################################
# COLOURS:
  GRN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m'
# JAIL directory:
  CHROOT="/jail"
# SSH Configuration directory:
  SSH="/etc/ssh/sshd_config"
#######################################

status () {
  if [[ $? -eq 0 ]]; then
    printf "${GRN}OK${NC}\n"
  else
    printf "${RED}Failed${NC}\n"
  fi
}

generate_fail_status ()
{
  😞 &> /dev/null
  status
}

duplicate_command () {

  for i in $( ldd $* | grep -v dynamic | cut -d " " -f 3 | sed 's/://' | sort | uniq )
  do
    echo -n "Copy $i: "
    cp --parents $i $CHROOT
    status
  done

  # ARCH amd64
  if [[ -f /lib64/ld-linux-x86-64.so.2 ]]; then
    cp --parents /lib64/ld-linux-x86-64.so.2 /$CHROOT
  fi
  # ARCH i386
  if [[ -f  /lib/ld-linux.so.2 ]]; then
    cp --parents /lib/ld-linux.so.2 /$CHROOT
  fi
  echo -n "Copy linux library: "
  status
}

initialize_jail ()
{
  echo -n "Create JAIL directories: "
  mkdir -p $CHROOT/{home,bin,dev,etc,lib64}
  status
  echo -n "Add NULL value: "
  mknod -m 666 $CHROOT/dev/null c 1 3
  status
  echo -n "Add RANDOM value: "
  mknod -m 666 $CHROOT/dev/random c 1 8
  status
  echo -n "Add TTY value: "
 mknod -m 666 $CHROOT/dev/tty c 5 0
  status
  echo -n "Add ZERO value: "
  mknod -m 666 $CHROOT/dev/zero c 1 5
  status
  echo "#-- Copy linux commands to JAIL --#"
  # ---------------- Commands to copy ---------------- #
  duplicate_command /bin/{bash,ls,pwd,date,cat,rm,vi,mkdir,touch,cp,clear,uname}
  # -------------------------------------------------- #
  echo -n "Link PASSWD & GROUP: "
  ln -s /etc/{passwd,group} $CHROOT/etc/
  status
  echo -n "Change OWNER of JAIL: "
  chown -R root:root $CHROOT
  status
  echo -n "Change PERMISSIONS for JAIL: "
  chmod -R 755 $CHROOT
  status
  echo -n "Add JAIL to SSH Configuration: "
  [[ $(grep -c "^ChrootDirectory $CHROOT" $SSH) -eq 0 ]] &&
  echo -n "ChrootDirectory $CHROOT" >> $SSH
  status
  echo -e "\e[4mChroot jail is ready. To access it execute: chroot $CHROOT\e[0m"
}

update_jail_cmds ()
{
  echo -n "Copy default COMMANDS to JAIL: "
  for i in $CMDS
  do
    duplicate_command /bin/$i
  done
}

jail_user ()
{
  USERS="$(echo $* | sed -e 's/\,/\ /g')"
  [[ $(grep -c "^Match User*" $SSH) -eq 0 ]] &&
  echo -e "\nMatch User" >> $SSH
  for user in $USERS
  do
    echo -n "Jail the user $user: "
    if [[ $(cat /etc/passwd | grep $user) ]] &&
       [[ $(grep -c "^Match User *$user*" $SSH) -eq 0 ]];
    then
      sed -Ei "s/^(Match User .*)/\1,$user/" $SSH &&
      sed -Ei "s/^(Match User)$/\1 $user/" $SSH &&
      cp -r /home/$user $CHROOT/home/$user &&
      chown -R $user:$user $CHROOT/home/$user &&
      chmod -R 770 $CHROOT/home/$user &&
      systemctl restart sshd &&
      status ||
      generate_fail_status
    else
      generate_fail_status
    fi
  done
}

unjail_user ()
{
  user="$1"
  echo -n "Unjail the user $user"
  if [[ $(grep -c "^Match User *$user*" $SSH) ]];
  then
    sed -Ei "s/^(Match User .*),$user(.*)/\1\2/" $SSH &&
    sed -Ei "s/^(Match User .*)$user,(.*)/\1\2/" $SSH &&
    unlink $CHROOT/home/$user &&
    systemctl restart sshd &&
    status ||
    generate_fail_status
  else
    generate_fail_status
  fi
}

usage ()
{
  printf "
Usage: jail [OPTION]... [PARAMETERS]...
Manage JAIL concept in ssh by initializing the environment, updating cmd tools, and jailing/unjailing users.

Mandatory arguments:
-j, --jail \t\t Jail a user/users.
Example:
jail -j user1,user2
-u, --unjail \t\t Unjail one user.
-x, --execute \t init \t Initialize Jail environment.
              \t update\t Update shell commands in jail environment.
"
}

invalid_option ()
{
  echo "Invalid Option!" && usage
}

main ()
{
  case $1 in
    -j|--jail) jail_user "${@:2}" ;;
    -u|--unjail) unjail_user "${@:2}" ;;
    -x|--execute)
      ( [[ "$2" -eq "init" ]] && initialize_jail ) ||
      ( [[ "$2" -eq "update" ]] && update_jail_cmds ) ||
      invalid_option ;;
    *) invalid_option ;;
  esac
}

main $*
