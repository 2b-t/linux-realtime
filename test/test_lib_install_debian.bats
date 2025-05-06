#!/usr/bin/env bats
# Unit-tests for Bash library for installing PREEMPT_RT Linux kernel from a Debian package
# Tobit Flatscher - github.com/2b-t (2022)
#
# Usage:
# - '$ ./test_lib_install_debian.bats'


function test_file() {
  declare desc="Get the filename of the file to be tested"
  local DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )" > /dev/null 2>&1 && pwd )"
  echo "${DIR}/../src/lib_install_debian.sh"
}

function setup() {
  declare desc="Source the libraries required for unit testing and the file to be tested"
  load "test_helper/bats-support/load"
  load "test_helper/bats-assert/load"
  local TEST_FILE=$(test_file)
  source ${TEST_FILE}
}

function teardown() {
  declare desc="Make sure that the last test is cleaned up"
  tmux kill-session -t "bats_test_session"
  if [ -f /tmp/capture ] ; then
    rm /tmp/capture
  fi
}

@test "Test get_debian_versions" {
  declare desc="Test if valid Debian version is detected"
  local DEBIAN_VERSIONS=$(get_debian_versions)
  assert_not_equal "${DEBIAN_VERSIONS}" ""
  assert_regex "${DEBIAN_VERSIONS}" "^([a-z]( )?)+$"
}

@test "Test get_preemptrt_debian_package" {
  declare desc="Test if a valid Debian file is returned for the given Debian version"
  local DEBIAN_VERSION="trixie"
  local ARCHITECTURE=$(get_architecture)
  local PREEMPTRT_FILE=$(get_preemptrt_debian_package "${DEBIAN_VERSION}" "${ARCHITECTURE}")
  assert_regex "${PREEMPTRT_FILE}" "^(linux-image-).+(-rt-${ARCHITECTURE})$"
}

@test "Test select_debian_version" {
  declare desc="Test if select Debian version dialog returns a single option only"
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_debian_version) > /tmp/capture' Enter
  sleep 30
  tmux send-keys -t "bats_test_session" Enter
  sleep 2
  tmux send-keys -t "bats_test_session" "exit" Enter
  sleep 2
  local DEBIAN_VERSION=$(< /tmp/capture)
  assert_regex "${DEBIAN_VERSION}" "^([a-z])+$"
}

@test "Test get_download_locations" {
  declare desc="Test if a valid hyperlink is returned for the given Debian version"
  local DEBIAN_VERSION="trixie"
  local DOWNLOAD_LOCATION=$(get_download_locations "${DEBIAN_VERSION}")
  assert_regex "${DOWNLOAD_LOCATION}" "^(http://).+(\.deb)$"
}

@test "Test select_download_location" {
  declare desc="Test if select download location dialog returns a single option only"
  local DEBIAN_VERSION="trixie"
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_download_location '"${DEBIAN_VERSION})"' > /tmp/capture' Enter
  sleep 30
  tmux send-keys -t "bats_test_session" Enter
  sleep 2
  tmux send-keys -t "bats_test_session" "exit" Enter
  sleep 2
  local DOWNLOAD_LOCATION=$(< /tmp/capture)
  assert_regex "${DOWNLOAD_LOCATION}" "^(http://).+(\.deb)$"
}

@test "Test extract_filename" {
  declare desc="Test if filename is extracted correctly from hyperlink"
  local DOWNLOAD_LOCATION="http://ftp.us.debian.org/debian/pool/main/l/linux-signed-amd64/linux-image-6.12.6-rt-amd64_6.12.6-1_amd64.deb"
  local DOWNLOADED_FILE=$(extract_filename "${DOWNLOAD_LOCATION}")
  assert_regex "${DOWNLOADED_FILE}" "^(linux-image-).+(\.deb)$"
}

