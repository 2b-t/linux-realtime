#!/bin/bash
# This library holds functions for searching https://packages.debian.org/ for Debian packages of Linux kernels with the PREEMPT_RT patch and 
# installing the desired version interactively
# Tobit Flatscher - github.com/2b-t (2022)


function install_dependencies() {
  declare desc="Install the missing dependencies for the PREEMPT_RT installation from a Debian package"
  sudo apt-get install -y curl dialog dpkg-dev grep sed
}

function get_debian_versions() {
  declare desc="Get the possible Debian versions of the kernel"
  echo $(cat /etc/debian_version | tr / " ")
}

function get_architecture() {
  declare desc="Get the computer architecture"
  echo $(dpkg --print-architecture)
}

function get_preemptrt_debian_package() {
  declare desc="Get the Debian package dependency referred to by the meta-package"
  local DEBIAN_VERSION=$1
  local ARCHITECTURE=$2
  echo $(curl -Ls https://packages.debian.org/${DEBIAN_VERSION}/linux-image-rt-${ARCHITECTURE} | grep -o -P "(?<=<a href=\"\/${DEBIAN_VERSION}\/)(linux-image-.*-rt-${ARCHITECTURE})(?=\")")
}

function select_debian_version() {
  declare desc="Select the Debian version from a list of given Debian versions"
  local POSSIBLE_DEBIAN_VERSIONS=$(get_debian_versions)
  local ARCHITECTURE=$(get_architecture)
  local DIALOG_POSSIBLE_DEBIAN_VERSIONS=""
  for VER in ${POSSIBLE_DEBIAN_VERSIONS}; do
    local PREEMPTRT_DEBIAN_PACKAGE=$(get_preemptrt_debian_package "${VER}" "${ARCHITECTURE}")
    if [ ! -z "${PREEMPTRT_DEBIAN_PACKAGE}" ]; then
      DIALOG_POSSIBLE_DEBIAN_VERSIONS="${DIALOG_POSSIBLE_DEBIAN_VERSIONS} ${VER} ${PREEMPTRT_DEBIAN_PACKAGE}"
    fi
  done
  echo $(dialog --keep-tite --stdout --menu "Select the desired PREEMPT_RT kernel version:" 0 0 4 ${DIALOG_POSSIBLE_DEBIAN_VERSIONS})
}

function get_download_locations() {
  declare desc="Get a list of available download servers for the PREEMPT_RT Debian package given the Debian version by crawling the website"
  local DEBIAN_VERSION=$1
  local ARCHITECTURE=$(get_architecture)
  local DEBIAN_PACKAGE=$(get_preemptrt_debian_package "${DEBIAN_VERSION}" "${ARCHITECTURE}")
  echo $(curl -Ls https://packages.debian.org/${DEBIAN_VERSION}/${ARCHITECTURE}/${DEBIAN_PACKAGE}/download | grep -o -P '(?<=<li><a href=\")(.*\.deb)(?=\">)')
}

function select_download_location() {
  declare desc="Select the desired download server from a list of given download servers"
  local DEBIAN_VERSION=$1
  local DOWNLOAD_SERVERS=$(get_download_locations "${DEBIAN_VERSION}")
  local DIALOG_DOWNLOAD_SERVERS=""
  for SERVER in ${DOWNLOAD_SERVERS}; do
    DIALOG_DOWNLOAD_SERVERS="${DIALOG_DOWNLOAD_SERVERS} ${SERVER} ${SERVER}"
  done
  echo $(dialog --keep-tite --no-tags --stdout --menu "Select a download server:" 0 0 5 ${DIALOG_DOWNLOAD_SERVERS})
}

function extract_filename {
  declare desc="Extract the filename from a given PREEMPT_RT download link"
  local DOWNLOAD_LINK=$1
  echo "${DOWNLOAD_LINK}" | rev | cut -d'/' -f 1 | rev
}

function download_file() {
  declare desc="Downloads a given file and returns the filename"
  local DOWNLOAD_LOCATION=$1
  curl -SLO --fail "${DOWNLOAD_LOCATION}"
  echo $(extract_filename "${DOWNLOAD_LOCATION}")
}

function select_install_now() {
  declare desc="Select if the Debian package should be installed now or the installation should be performed at a later point"
  dialog  --keep-tite --stdout --title "Install Debian package" --yesno "Want to install the Debian package now?" 0 0
  echo $?
}

function install_debian_pkg {
  declare desc="Install a Debian package given by its file location"
  local DEBIAN_PKG=$1
  sudo dpkg -i ${DEBIAN_PKG}
  sudo apt-get install -f
}

