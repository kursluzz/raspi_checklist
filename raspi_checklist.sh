#!/bin/bash

# USER SETTINGS
# 1. Set your configuration
MYUSER=username
MYGITNAME=John
MYGITEMAIL=john@work
SAMBA_SHARE_DIR=/home/${MYUSER}/Shared
SAMBA_SHARE_NAME=Shared
SAMBA_SHARE_READONLY=no
SAMBA_SHARE_PASSWORD=sharesecret
YANDEX_DISK_USERNAME=username
YANDEX_DISK_PASSWORD=password
SSH_CONFIG='Host someserver
    HostName 10.0.0.100
    User user
Host someserver2
    HostName 10.0.0.101
    User user
    IdentityFile ~/.ssh/someserver2.pem
Host bitbucket.org
    HostName bitbucket.org
    User git
    IdentityFile ~/.ssh/id_rsa
Host bitbucket.org-id_rsa2
    HostName bitbucket.org
    User git
    IdentityFile ~/.ssh/id_rsa2
'
BASH_ALIASES='alias git-branch-sort="git branch -a --sort=-committerdate"
'

if [[ -f raspi_checklist_config.sh ]]; then
  source raspi_checklist_config.sh
fi

# 2. Set what you want to install 1 for yes, 0 for no
INSTALL_CURL=1
INSTALL_VIM=1
INSTALL_BYOBU=1
INSTALL_WAKEONLAN=1
INSTALL_MAKE=1
INSTALL_GIT=1
INSTALL_PIP3=1
INSTALL_VENV=1
ADD_SSH_KEY_FOR_GIT=1
CREATE_ALIASES=1
CREATE_SSH_CONFIG_FILE=1
INSTALL_DOCKER=1
INSTALL_YOUTUBE_DL=1
INSTALL_SAMBA=1
INSTALL_YANDEXDISK=1


# FUNCTIONS
get_os_version_id() {
  cat /etc/os-release | while read line; do
    if [[ $line == "VERSION_ID="* ]]; then
      eval "local $line"
      echo $VERSION_ID
      break
    fi
  done
}

# MAIN RUN
# must run as sudo check
if [ "$EUID" -ne 0 ]; then
  echo Please run as sudo
  exit
fi

sudo -u $MYUSER mkdir -p /home/$MYUSER/Downloads
cd /home/$MYUSER/Downloads

apt -y update
apt -y upgrade

if [ "$INSTALL_CURL" -eq 1 ]; then
  echo ---------- Installing curl
  apt -y install curl
fi

if [ "$INSTALL_VIM" -eq 1 ]; then
  echo ---------- Installing vim
  apt -y install vim
fi

if [ "$INSTALL_BYOBU" -eq 1 ]; then
  echo ---------- Installing byobu
  apt -y install byobu
fi

if [ "$INSTALL_WAKEONLAN" -eq 1 ]; then
  echo ---------- Installing wakeonlan
  apt -y install wakeonlan
fi

if [ "$INSTALL_MAKE" -eq 1 ]; then
  echo ---------- Installing make
  apt -y install make
fi

if [ "$INSTALL_GIT" -eq 1 ]; then
  echo ---------- Installing git
  apt -y install git

  echo ---------- Setting git global user and password
  sudo -u $MYUSER git config --global user.email "$MYGITEMAIL"
  sudo -u $MYUSER git config --global user.name "$MYGITNAME"
fi

if [ "$INSTALL_PIP3" -eq 1 ]; then
  echo ---------- Installing pip3
  apt -y install python3-pip
fi

if [ "$INSTALL_VENV" -eq 1 ]; then
  echo ---------- Installing VENV
  apt -y install python3-venv
fi

if [ "$ADD_SSH_KEY_FOR_GIT" -eq 1 ]; then
  echo ---------- Adding SSH key for git
  DO_SSH=0
  if [ -e /home/$MYUSER/.ssh/id_rsa ]; then
    read -p 'File ~/.ssh/id_rsa already exists! Do you want do delete it? [Y/n]: ' CH
    if [ "$CH" = '' ] || [ "$CH" = 'y' ] || [ "$CH" = 'Y' ]; then
      sudo -u $MYUSER rm ~/.ssh/id_rsa*
      DO_SSH=1
    fi
  else
    DO_SSH=1
  fi
  if [ "$DO_SSH" -eq 1 ]; then
    sudo -u $MYUSER ssh-keygen -f /home/$MYUSER/.ssh/id_rsa -P ''
    eval $(sudo -u $MYUSER ssh-agent)
    ssh-add /home/$MYUSER/.ssh/id_rsa
  fi
fi


if [ "$CREATE_ALIASES" -eq 1 ]; then
  echo ---------- Creating aliases
  su - $MYUSER -c "echo '${BASH_ALIASES}' > /home/$MYUSER/.bash_aliases"
fi

if [ "$CREATE_SSH_CONFIG_FILE" -eq 1 ]; then
  echo ---------- Creating ssh .config example
  su - $MYUSER -c "echo '${SSH_CONFIG}' > /home/$MYUSER/.ssh/config"
fi

if [ "$INSTALL_DOCKER" -eq 1 ]; then
  echo ---------- Installing Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
  usermod -aG docker $MYUSER
fi

if [ "$INSTALL_YOUTUBE_DL" -eq 1 ]; then
  echo ---------- Installing youtube-dl
  apt -y install ffmpeg
  sudo -u $MYUSER pip3 install youtube-dl
fi

if [ "$INSTALL_SAMBA" -eq 1 ]; then
  echo ---------- Installing Samba
  sudo -u $MYUSER mkdir -p "${SAMBA_SHARE_DIR}"
  apt -y install samba
  echo --- creating backup for samba config
  cp /etc/samba/smb.conf /etc/samba/smb-bk.conf
  echo "
[${SAMBA_SHARE_NAME}]
    comment = shared dir
    path = ${SAMBA_SHARE_DIR}
    read only = ${SAMBA_SHARE_READONLY}
    browsable = yes
" >>/etc/samba/smb.conf
  service smbd restart
  (
    echo "${SAMBA_SHARE_PASSWORD}"
    echo "${SAMBA_SHARE_PASSWORD}"
  ) | smbpasswd -s -a ${MYUSER}
fi

if [ "$INSTALL_YANDEXDISK" -eq 1 ]; then
  echo ---------- Installing Yandex Disk
  # original command with sudo [https://yandex.com/support/disk/cli-clients.html]
  # echo "deb http://repo.yandex.ru/yandex-disk/deb/ stable main" | sudo tee -a /etc/apt/sources.list.d/yandex-disk.list > /dev/null && wget http://repo.yandex.ru/yandex-disk/YANDEX-DISK-KEY.GPG -O- | sudo apt-key add - && sudo apt-get update && sudo apt-get install -y yandex-disk
  echo "deb http://repo.yandex.ru/yandex-disk/deb/ stable main" | tee -a /etc/apt/sources.list.d/yandex-disk.list > /dev/null && wget http://repo.yandex.ru/yandex-disk/YANDEX-DISK-KEY.GPG -O- | apt-key add - && apt-get update && apt-get install -y yandex-disk
  printf "n\n%s\n%s\n\n" "$YANDEX_DISK_USERNAME" "$YANDEX_DISK_PASSWORD" | yandex-disk setup
fi

if [ "$ADD_SSH_KEY_FOR_GIT" -eq 1 ]; then
  echo '- Please set SSH public key in Bitbucket and Github!'
fi

