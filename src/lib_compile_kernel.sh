#!/bin/bash
# Library for compiling a Linux kernel with the PREEMPT_RT real-time patch using a simple graphical interface
# Tobit Flatscher - github.com/2b-t (2022)


function is_valid_url() {
  declare desc="Check if a given url exists or not"
  local POTENTIAL_URL=$1
  if curl --head --silent --fail "${POTENTIAL_URL}" > /dev/null; then
    echo "true"
  else
    echo "false"
  fi
}

function remove_right_of_dot() {
  declare desc="Remove contents right of dot and return remaining string left of it"
  local INPUT_STRING=$1
  echo "${INPUT_STRING%.*}"
}

function install_dependencies() {
  declare desc="Install the missing dependencies for the PREEMPT_RT compilation from source"
  sudo apt-get install -y curl grep sed
  sudo apt-get install -y bc bison build-essential ca-certificates cpio debhelper-compat dpkg-dev dwarves flex gnupg2 libelf-dev libncurses-dev libssl-dev lsb-release rsync zstd
}

function get_preemptrt_minor_versions() {
  declare desc="Get the major and minor PREEMPT_RT versions by crawling website  (e.g. 5.10 ...)"
  echo $(curl -Ls https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt | grep -o -P '(?<=href\=\")(\d\.\d*)+(?=/\">)')
}

function get_current_kernel_version() {
  declare desc="Get the version of the currently used kernel (e.g. 5.10)"
  echo $(uname -r | sed 's/\.[^\.]*//2g')
}

function select_preemptrt_minor_version() {
  declare desc="Select the desired major and minor version with a user dialog"
  local PREEMPTRT_MINOR_VERSIONS=$(get_preemptrt_minor_versions)
  local DIALOG_PREEMPTRT_MINOR_VERSIONS=""
  for VER in ${PREEMPTRT_MINOR_VERSIONS}; do
    DIALOG_PREEMPTRT_MINOR_VERSIONS="${DIALOG_PREEMPTRT_MINOR_VERSIONS} ${VER} ${VER}"
  done
  local CURRENT_KERNEL_VERSION=$(get_current_kernel_version)
  echo $(dialog --keep-tite --no-tags --stdout --default-item ${CURRENT_KERNEL_VERSION} --menu "Select a major kernel version:" 30 40 10 ${DIALOG_PREEMPTRT_MINOR_VERSIONS})
}

function get_preemptrt_full_versions() {
  declare desc="Get the full PREEMPT_RT versions (major.minor.patch.rt-rtpatch) from major and minor version by crawling website (e.g. 5.10.78-rt55 ...)"
  local PREEMPTRT_MINOR_VERSION=$1
  echo $(curl -Ls https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPTRT_MINOR_VERSION} | grep -o -P '(?<=href\=\"patch-).*(?=.patch.gz\">)')
}

function select_preemptrt_full_version() {
  declare desc="Select the desired full version (e.g. 5.10.78-rt55) with a user dialog given the corresponding minor version (e.g. 5.10)"
  local PREEMPTRT_MINOR_VERSION=$1
  local PREEMPTRT_FULL_VERSIONS=$(get_preemptrt_full_versions "${PREEMPTRT_MINOR_VERSION}")
  local DIALOG_PREEMPTRT_FULL_VERSIONS=""
  for VER in ${PREEMPTRT_FULL_VERSIONS}; do
    DIALOG_PREEMPTRT_FULL_VERSIONS="${DIALOG_PREEMPTRT_FULL_VERSIONS} ${VER} ${VER}"
  done
  echo $(dialog --keep-tite --no-tags --stdout --menu "Select the desired version of PREEMPT_RT:" 30 40 10 ${DIALOG_PREEMPTRT_FULL_VERSIONS})
}

function select_preemptrt() {
  declare desc="Select the desired full version (e.g. 5.10.78-rt55) with a user dialog by first selecting the corresponding minor version (e.g. 5.10)"
  local PREEMPTRT_MINOR_VERSION=$(select_preemptrt_minor_version)
  echo $(select_preemptrt_full_version "${PREEMPTRT_MINOR_VERSION}")
}

function extract_kernel_full_version() {
  declare desc="Extract the full kernel version (major.minor.patch, e.g. 5.10.78) from the full PREEMPT_RT patch version (e.g. 5.10.78-rt55)"
  local PREEMPTRT_FULL_VERSION=$1
  echo "${PREEMPTRT_FULL_VERSION}" | sed 's/-rt.*//g'
}

function extract_kernel_minor_version() {
  declare desc="Extract the kernel minor version (major.minor, e.g. 5.10) from the full kernel version (e.g. 5.10.78)"
  local KERNEL_FULL_VERSION=$1
  echo "${KERNEL_FULL_VERSION}" | sed 's/\.[^\.]*//2g'
}

function reconstruct_kernel_major_tag() {
  declare desc="Extract the kernel major tag (vmajor.x, e.g. v5.x) from the minor kernel version (e.g. 5.10)"
  local KERNEL_MINOR_VERION=$1
  local KERNEL_MAJOR_VERSION=$(echo "${KERNEL_MINOR_VERSION}" | grep -o -P '^\s*(\d)+')
  echo "$(curl -Ls https://www.kernel.org/pub/linux/kernel | grep -o -P "(?<=href\=\")(v${KERNEL_MAJOR_VERSION}.*)(?=/\">)")"
}

function get_kernel_link() {
  declare desc="Get the link where the kernel can be downloaded from"
  local KERNEL_MAJOR_TAG=$1
  local KERNEL_FULL_VERSION=$2
  echo "https://www.kernel.org/pub/linux/kernel/${KERNEL_MAJOR_TAG}/linux-${KERNEL_FULL_VERSION}.tar.xz"
}

function get_kernel_signature_link() {
  declare desc="Get the link where the kernel signature can be downloaded from"
  local KERNEL_MAJOR_TAG=$1
  local KERNEL_FULL_VERSION=$2
  echo "https://www.kernel.org/pub/linux/kernel/${KERNEL_MAJOR_TAG}/linux-${KERNEL_FULL_VERSION}.tar.sign"
}

function get_preemptrt_link() {
  declare desc="Get the link where the PREEMPT_RT-patch can be downloaded from"
  local KERNEL_MINOR_VERSION=$1
  local PREEMPTRT_FULL_VERSION=$2
  echo "https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${KERNEL_MINOR_VERSION}/patch-${PREEMPTRT_FULL_VERSION}.patch.xz"
}

function get_preemptrt_signature_link() {
  declare desc="Get the link where the PREEMPT_RT-patch signature can be downloaded from"
  local KERNEL_MINOR_VERSION=$1
  local PREEMPTRT_FULL_VERSION=$2
  echo "https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${KERNEL_MINOR_VERSION}/patch-${PREEMPTRT_FULL_VERSION}.patch.sign"
}

function sign_file() {
  declare desc="Sign a given file"
  local UNSIGNED_FILE=$1
  gpg2 --verify "${UNSIGNED_FILE}"
  if [ $? -ne 0 ]
    then
      local RECEIVED_KEY=$(gpg2 --verify "${UNSIGNED_FILE}" 2>&1 | grep -o -P '(?<=RSA key )(.*)')
      gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "${RECEIVED_KEY}"
      gpg2 --verify "${UNSIGNED_FILE}"
  fi
}

function download_and_extract_kernel() {
  declare desc="Download and extract the vanilla kernel and sign it"
  local KERNEL_FULL_VERSION=$1
  local KERNEL_MINOR_VERSION=$(extract_kernel_minor_version "${KERNEL_FULL_VERSION}")
  local KERNEL_MAJOR_TAG=$(reconstruct_kernel_major_tag "${KERNEL_MINOR_VERSION}")
  local KERNEL_DOWNLOAD_LINK=$(get_kernel_link "${KERNEL_MAJOR_TAG}" "${KERNEL_FULL_VERSION}")
  local KERNEL_SIGNATURE_DOWNLOAD_LINK=$(get_kernel_signature_link "${KERNEL_MAJOR_TAG}" "${KERNEL_FULL_VERSION}")
  curl -SLO --fail "${KERNEL_DOWNLOAD_LINK}"
  curl -SLO --fail "${KERNEL_SIGNATURE_DOWNLOAD_LINK}"
  xz -d "linux-${KERNEL_FULL_VERSION}.tar.xz"
  sign_file "linux-${KERNEL_FULL_VERSION}.tar.sign"
  echo "linux-${KERNEL_FULL_VERSION}.tar"
}

function download_and_extract_preemptrt() {
  declare desc="Download and extract the PREEMPT_RT patch and sign it"
  local PREEMPTRT_FULL_VERSION=$1
  local KERNEL_FULL_VERSION=$(extract_kernel_full_version "${PREEMPTRT_FULL_VERSION}")
  local PREEMPTRT_MINOR_VERSION=$(extract_kernel_minor_version "${KERNEL_FULL_VERSION}")
  local PREEMPTRT_DOWNLOAD_LINK=$(get_preemptrt_link "${PREEMPTRT_MINOR_VERSION}" "${PREEMPTRT_FULL_VERSION}")
  local PREEMPTRT_SIGNATURE_DOWNLOAD_LINK=$(get_preemptrt_signature_link "${PREEMPTRT_MINOR_VERSION}" "${PREEMPTRT_FULL_VERSION}")
  curl -SLO --fail "${PREEMPTRT_DOWNLOAD_LINK}"
  curl -SLO --fail "${PREEMPTRT_SIGNATURE_DOWNLOAD_LINK}"
  xz -d "patch-${PREEMPTRT_FULL_VERSION}.patch.xz"
  sign_file "patch-${PREEMPTRT_FULL_VERSION}.patch.sign"
  echo "patch-${PREEMPTRT_FULL_VERSION}.patch"
}

function apply_patch_to_kernel() {
  declare desc="Apply the PREEMPT_RT patch to the kernel"
  local PREEMPTRT_FILE=$1
  local KERNEL_FILE=$2
  tar xf "${KERNEL_FILE}"
  local KERNEL_FOLDER=$(remove_right_of_dot "${KERNEL_FILE}")
  cd "${KERNEL_FOLDER}"
  patch -p1 < "../${PREEMPTRT_FILE}"
}

function generate_new_kernel_configuration() {  
  declare desc="Generate a new kernel configuration"
  # Only option set in the configuration is full PREEMPT_RT, rest is left on default
  echo "4" | make oldconfig
}

function find_and_replace_in_config() {
  declare desc="Add or replace (if exists) given setting in the configuration file"
  local KERNEL_CONFIG_FILE=$1
  local SETTING_NAME=$2
  local DESIRED_VALUE=$3
  grep -E "${SETTING_NAME}=" "${KERNEL_CONFIG_FILE}" && sed -i "s/${SETTING_NAME}=.*/${SETTING_NAME}=${DESIRED_VALUE}/" "${KERNEL_CONFIG_FILE}" || echo "${SETTING_NAME}=${DESIRED_VALUE}" >> "${KERNEL_CONFIG_FILE}"
}

function comment_out_in_config() {
  declare desc="Comment out certain setting in the configuration file"
  local KERNEL_CONFIG_FILE=$1
  local SETTING_NAME=$2
  sed -E "/${SETTING_NAME}/ s/^#*/#/" -i ${KERNEL_CONFIG_FILE}
}

function unsign_kernel_configuration() {
  declare desc="Force unsigned kernel configuration"
  local KERNEL_CONFIG_FILE=".config"
  find_and_replace_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_SYSTEM_TRUSTED_KEYS" '""'
  find_and_replace_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_SYSTEM_REVOCATION_KEYS" '""'
}

function set_recommended_preemptrt_settings() {
  declare desc="Set recommended PREEMPT_RT kernel configuration"
  local KERNEL_CONFIG_FILE=".config"
  comment_out_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_HZ_250"
  find_and_replace_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_HZ_1000" "y"
  find_and_replace_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_HZ" "1000"
  find_and_replace_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_NO_HZ_IDLE" "y"
  find_and_replace_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_NO_HZ" "y"
  find_and_replace_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_HIGH_RES_TIMERS" "y"
  find_and_replace_in_config "${KERNEL_CONFIG_FILE}" "CONFIG_CPU_ISOLATION" "y"
}

function select_manual_configuration() {
  declare desc="Decide whether to make additional changes with menuconfig to the kernel configuration or not"
  dialog --keep-tite --stdout --title "Start menuconfig" --defaultno --yesno "Do you want to make manual changes to the kernel configuration with menuconfig?" 0 0
  echo $?
}

function select_installation_mode() {
  declare desc="Select installation modality"
  echo $(dialog --keep-tite --stdout --default-item "Debian package" --menu "Select the desired installation mode:" 0 0 5 "Debian" "Debian package" "Classic" "Install directly")
}

function generate_preemptrt_kernel_debian_package() {
  declare desc="Generate Debian package for easier installation and uninstallation"
  sudo make -j$(nproc) bindeb-pkg
}

function select_install_now() {
  declare desc="Decide whether to install the patched kernel from Debian package now or install it later on"
  dialog --keep-tite --stdout --title "Install Debian package" --yesno "Want to install the Debian package now?" 0 0
  echo $?
}

function install_preemptrt_kernel_debian_package() {
  declare desc="Install the PREEMPT_RT-patched kernel from Debian package"
  local PREEMPTRT_FULL_VERSION=$1
  local ARCHITECTURE=$(dpkg --print-architecture)
  sudo dpkg -i "../linux-image-${PREEMPTRT_FULL_VERSION}_${PREEMPTRT_FULL_VERSION}-1_${ARCHITECTURE}.deb"
}

function install_preemptrt_kernel_directly() {
  declare desc="Install the PREEMPT_RT-patched kernel directly from source with Make"
  sudo make -j$(nproc)
  sudo make modules_install -j$(nproc)
  sudo make install -j$(nproc)
}

