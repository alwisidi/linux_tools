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
#######################################

status () {
  if [ $? -eq 0 ]; then
    printf "${GRN}OK${NC}\n"
  else
    printf "${RED}Failed${NC}\n"
  fi
}

duplicate_command () {

  for i in $( ldd $* | grep -v dynamic | cut -d " " -f 3 | sed 's/://' | sort | uniq )
  do
    echo -n "Copy $i: "
    cp --parents $i $CHROOT
    status
  done

  # ARCH amd64
  if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
    cp --parents /lib64/ld-linux-x86-64.so.2 /$CHROOT
  fi
  # ARCH i386
  if [ -f  /lib/ld-linux.so.2 ]; then
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
  duplicate_command /bin/{ls,pwd,date,cat,rm,vi,mkdir,touch,cp,clear,uname}
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
  SSH="/etc/ssh/sshd_config"
  [[ $(grep -c "^ChrootDirectory" $SSH) -ne 0 ]] &&
  [[ $(grep -c "^ChrootDirectory $CHROOT" $SSH) -ne 0 ]] ||
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
  USERS="$*"
  SSH="/etc/ssh/sshd_config"
  if [ $(cat $SSH | grep -e "^Match User *") ];
  then
    for user in $USERS
    do
      
      sed -i -E "s/^(Match User *)/\1,$user/" $SSH
      status
      ln /home/$user $CHROOT/home/$user
      status
      chown -R $user:$user $CHROOT/home/$user
      status
      chmod -R 770 $CHROOT/home/$user
      status
    done
  else
    echo "Match User $USERS" >> $SSH
    status
  fi
}

usage ()
{
  printf "
    Hi World
  "
}

invalid_option ()
{
  echo "Invalid Option!" && usage
}

main ()
{
  case $1 in
    -a|--add) jail_user "${@:2}" ;;
    -d|--delete) unjail_user "${@:2}" ;;
    -c) ( [[ "$2" -eq "init" ]] && initialize_jail ) ||
        ( [[ "$2" -eq "init" ]] && initialize_jail ) ||
        invalid_option ;;
    *) invalid_option ;;
  esac
}

main $*
