#!/usr/bin/env bash
#

# ==== Configuração (preencha antes de executar) ====
GITHUB_HOST=
GITHUB_OWNER=
REPO_PREFIX=
INSTALLER_REPO=
VERSION=
# =====================================================

for var in GITHUB_HOST GITHUB_OWNER REPO_PREFIX INSTALLER_REPO VERSION; do
  if [ -z "${!var}" ]; then
    echo -e "[\033[31m ERROR \033[0m] Variável ${var} não definida. Preencha o bloco de configuração no topo do script."
    exit 1
  fi
done

INSTALLER_DIR_NAME="${REPO_PREFIX}${INSTALLER_REPO}"

function install_soft() {
    if command -v dnf &>/dev/null; then
      dnf -q -y install "$1"
    elif command -v yum &>/dev/null; then
      yum -q -y install "$1"
    elif command -v apt &>/dev/null; then
      apt-get -qqy install "$1"
    elif command -v zypper &>/dev/null; then
      zypper -q -n install "$1"
    elif command -v apk &>/dev/null; then
      apk add -q "$1"
      command -v gettext &>/dev/null || {
      apk add -q gettext-dev python3
    }
    else
      echo -e "[\033[31m ERROR \033[0m] $1 command not found, Please install it first"
      exit 1
    fi
}

function prepare_install() {
  for i in curl wget tar iptables gettext; do
    command -v $i &>/dev/null || install_soft $i
  done
}

function get_installer() {
  echo "download install script to /opt/${INSTALLER_DIR_NAME}-${VERSION}"
  cd /opt || exit 1
  if [ ! -d "/opt/${INSTALLER_DIR_NAME}-${VERSION}" ]; then
    timeout 60 wget --show-progress -qO ${INSTALLER_DIR_NAME}-${VERSION}.tar.gz ${GITHUB_HOST}/${GITHUB_OWNER}/${INSTALLER_DIR_NAME}/releases/download/${VERSION}/${INSTALLER_DIR_NAME}-${VERSION}.tar.gz || {
      rm -f /opt/${INSTALLER_DIR_NAME}-${VERSION}.tar.gz
      echo -e "[\033[31m ERROR \033[0m] Failed to download ${INSTALLER_DIR_NAME}-${VERSION}"
      exit 1
    }
    tar -xf /opt/${INSTALLER_DIR_NAME}-${VERSION}.tar.gz -C /opt || {
      rm -rf /opt/${INSTALLER_DIR_NAME}-${VERSION}
      echo -e "[\033[31m ERROR \033[0m] Failed to unzip ${INSTALLER_DIR_NAME}-${VERSION}"
      exit 1
    }
    rm -f /opt/${INSTALLER_DIR_NAME}-${VERSION}.tar.gz
  fi
}

function config_installer() {
  cd /opt/${INSTALLER_DIR_NAME}-${VERSION} || exit 1
  ./jmsctl.sh install
  ./jmsctl.sh start
}

function main(){
  if [[ "${OS}" == 'Darwin' ]]; then
    echo
    echo "Unsupported Operating System Error"
    exit 1
  fi
  prepare_install
  get_installer
  config_installer
}

main
