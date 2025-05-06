#!/usr/bin/env bats
# Unit-tests for Bash library for compiling PREEMPT_RT Linux kernel from source
# Tobit Flatscher - github.com/2b-t (2022)
#
# Usage:
# - '$ ./test_lib_compile_kernel.bats'


function test_file() {
  declare desc="Get the filename of the file to be tested"
  local DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )" > /dev/null 2>&1 && pwd )"
  echo "${DIR}/../src/lib_compile_kernel.sh"
}

function setup() {
  declare desc="Source the libraries required for unit testing and the file to be tested"
  load "test_helper/bats-support/load"
  load "test_helper/bats-assert/load"
  local TEST_FILE=$(test_file)
  source "${TEST_FILE}"
}

function teardown() {
  declare desc="Make sure that the last test is cleaned up"
  tmux kill-session -t "bats_test_session"
  if [ -f /tmp/capture ] ; then
    rm /tmp/capture
  fi
}

@test "Test is_valid_url" {
  declare desc="Test if a given URL is valid"
  local URL="https://www.google.com/"
  local IS_URL=$(is_valid_url "${URL}")
  assert_equal "${IS_URL}" "true"
}

@test "Test remove_right_of_dot" {
  declare desc="Test if the text right of the dot is removed correctly"
  local INITIAL_STRING="a.b.c"
  local EXPECTED_RESULT_STRING="a.b"
  local RESULT_STRING=$(remove_right_of_dot "${INITIAL_STRING}")
  assert_equal "${RESULT_STRING}" "${EXPECTED_RESULT_STRING}"
}

@test "Test get_preemptrt_minor_versions" {
  declare desc="Test if detected PREEMPT_RT major and minor versions respect the version numbering"
  local PREEMPTRT_MINOR_VERSIONS=$(get_preemptrt_minor_versions)
  assert_not_equal "${PREEMPTRT_MINOR_VERSIONS}" ""
  for PREEMPTRT_MINOR_VERSION in ${PREEMPTRT_MINOR_VERSIONS}; do
    assert_regex "${PREEMPTRT_MINOR_VERSION}" "^[0-9]+\.[0-9]+(\.[0-9]+)?$"
  done
}

@test "Test get_current_kernel_version" {
  declare desc="Test if the detected kernel version respects the version numbering"
  local KERNEL_VERSION=$(get_current_kernel_version)
  assert_not_equal "${KERNEL_VERSION}" ""
  assert_regex "${KERNEL_VERSION}" "^[0-9]+\.[0-9]+(\.[0-9]+)?$"
}

@test "Test select_preemptrt_minor_version" {
  declare desc="Test if the selected PREEMPT_RT patch respects the version numbering"
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_preemptrt_minor_version) > /tmp/capture' Enter
  sleep 5
  tmux send-keys -t "bats_test_session" Enter
  tmux send-keys -t "bats_test_session" "exit" Enter
  local PREEMPTRT_MINOR_VERSION=$(< /tmp/capture)
  assert_not_equal "${PREEMPTRT_MINOR_VERSION}" ""
  assert_regex "${PREEMPTRT_MINOR_VERSION}" "^[0-9]+\.[0-9]+(\.[0-9]+)?$"
}

@test "Test get_preemptrt_full_versions" {
  declare desc="Test if the full PREEMPT_RT version can be fetched from major and minor version and respects the version numbering"
  local PREEMPTRT_MINOR_VERSION="5.11"
  local PREEMPTRT_FULL_VERSIONS=$(get_preemptrt_full_versions "${PREEMPTRT_MINOR_VERSION}")
  assert_not_equal "${PREEMPTRT_FULL_VERSIONS}" ""
  for PREEMPTRT_FULL_VERSION in ${PREEMPTRT_FULL_VERSIONS}; do
    assert_regex "${PREEMPTRT_FULL_VERSION}" "^[0-9]+\.[0-9]+(\.[0-9]+)+\-rt[0-9]+$"
  done
}

@test "Test select_preemptrt_full_version" {
  declare desc="Test if the full PREEMPT_RT version can be selected from major and minor version and respects the version numbering"
  local PREEMPTRT_MINOR_VERSION="5.11"  
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_preemptrt_full_version '"${PREEMPTRT_MINOR_VERSION}"') > /tmp/capture' Enter
  sleep 5
  tmux send-keys -t "bats_test_session" Enter
  tmux send-keys -t "bats_test_session" "exit" Enter
  local PREEMPTRT_FULL_VERSION=$(< /tmp/capture)
  assert_not_equal "${PREEMPTRT_FULL_VERSION}" ""
  assert_regex "${PREEMPTRT_FULL_VERSION}" "^[0-9]+\.[0-9]+(\.[0-9]+)+\-rt[0-9]+$"
}

@test "Test extract_kernel_full_version" {
  declare desc="Test if the full kernel version can be correctly constructed from the full real-time patch version"
  local PREEMPTRT_FULL_VERSION="5.10.78-rt55"
  local KERNEL_FULL_VERSION=$(extract_kernel_full_version "${PREEMPTRT_FULL_VERSION}")
  assert_not_equal "${KERNEL_FULL_VERSION}" ""
  assert_regex "${KERNEL_FULL_VERSION}" "^[0-9]+\.[0-9]+\.[0-9]+$"
}

@test "Test extract_kernel_minor_version" {
  declare desc="Test if the full minor version can be correctly constructed from the full kernel version"
  local KERNEL_FULL_VERSION="5.10.78"
  local KERNEL_MINOR_VERSION=$(extract_kernel_minor_version "${KERNEL_FULL_VERSION}")
  assert_not_equal "${KERNEL_MINOR_VERSION}" ""
  assert_regex "${KERNEL_MINOR_VERSION}" "^[0-9]+\.[0-9]+$"
}

@test "Test reconstruct_kernel_major_tag" {
  declare desc="Test if the kernel major version can be correctly constructed from the kernel minor version"
  local KERNEL_MINOR_VERSION="5.10"
  local KERNEL_MAJOR_VERSION=$(reconstruct_kernel_major_tag "${KERNEL_MINOR_VERSION}")
  assert_not_equal "${KERNEL_MAJOR_VERSION}" ""
  assert_regex "${KERNEL_MAJOR_VERSION}" "^v[0-9]+\.x$"
}

@test "Test valid download links" {
  declare desc="Test if valid download links can be generated by simply following the set-up routine with default values"
  local PREEMPTRT_MINOR_VERSIONS="5.10"
  local PREEMPTRT_MINOR_VERSION=$(echo ${PREEMPTRT_MINOR_VERSIONS} | cut --delimiter " " --fields 1)
  local PREEMPTRT_FULL_VERSIONS=$(get_preemptrt_full_versions "${PREEMPTRT_MINOR_VERSION}")
  local PREEMPTRT_FULL_VERSION=$(echo ${PREEMPTRT_FULL_VERSIONS} | cut --delimiter " " --fields 1)
  local KERNEL_FULL_VERSION=$(extract_kernel_full_version "${PREEMPTRT_FULL_VERSION}")
  local KERNEL_MINOR_VERSION=$(extract_kernel_minor_version "${KERNEL_FULL_VERSION}")
  local KERNEL_MAJOR_TAG=$(reconstruct_kernel_major_tag "${KERNEL_MINOR_VERSION}")
  local KERNEL_DOWNLOAD_LINK=$(get_kernel_link "${KERNEL_MAJOR_TAG}" "${KERNEL_FULL_VERSION}")
  local KERNEL_SIGNATURE_DOWNLOAD_LINK=$(get_kernel_signature_link "${KERNEL_MAJOR_TAG}" "${KERNEL_FULL_VERSION}")
  local PREEMPTRT_DOWNLOAD_LINK=$(get_preemptrt_link "${KERNEL_MINOR_VERSION}" "${PREEMPTRT_FULL_VERSION}")
  local PREEMPTRT_SIGNATURE_DOWNLOAD_LINK=$(get_preemptrt_signature_link "${KERNEL_MINOR_VERSION}" "${PREEMPTRT_FULL_VERSION}")
  local IS_KERNEL_DOWNLOAD_LINK_VALID=$(is_valid_url "${KERNEL_DOWNLOAD_LINK}")
  assert_equal "${IS_KERNEL_DOWNLOAD_LINK_VALID}" "true"
  local IS_KERNEL_SIGNATURE_DOWNLOAD_LINK_VALID=$(is_valid_url "${KERNEL_SIGNATURE_DOWNLOAD_LINK}")
  assert_equal "${IS_KERNEL_SIGNATURE_DOWNLOAD_LINK_VALID}" "true"
  local IS_PREEMPTRT_DOWNLOAD_LINK_VALID=$(is_valid_url "${PREEMPTRT_DOWNLOAD_LINK}")
  assert_equal "${IS_PREEMPTRT_DOWNLOAD_LINK_VALID}" "true"
  local IS_PREEMPTRT_SIGNATURE_DOWNLOAD_LINK_VALID=$(is_valid_url "${PREEMPTRT_SIGNATURE_DOWNLOAD_LINK}")
  assert_equal "${IS_PREEMPTRT_SIGNATURE_DOWNLOAD_LINK_VALID}" "true"
}

@test "Test find_and_replace_in_config" {
  declare desc="Test if a setting is correctly found and replaced in the configuration file"
  local CONFIG_FILE="/tmp/.config"
  echo -e 'SOME_SETTING="old_value"\nANOTHER_SETTING="another_value"' > "${CONFIG_FILE}"
  find_and_replace_in_config "${CONFIG_FILE}" "SOME_SETTING" '"new_value"'
  local RESULT_CONFIG=$(<"${CONFIG_FILE}")
  rm -f "${CONFIG_FILE}"
  assert_regex "${RESULT_CONFIG}" '^SOME_SETTING="new_value"'
}

@test "Test comment_out_in_config" {
  declare desc="Test if a setting is correctly found and commented out in the configuration file"
  local CONFIG_FILE="/tmp/.config"
  echo -e 'SOME_SETTING="some_value"\nANOTHER_SETTING="another_value"' > "${CONFIG_FILE}"
  comment_out_in_config "${CONFIG_FILE}" "SOME_SETTING"
  local RESULT_CONFIG=$(<"${CONFIG_FILE}")
  rm -f "${CONFIG_FILE}"
  assert_regex "${RESULT_CONFIG}" "^#SOME_SETTING"
}

@test "Test select_manual_configuration" {
  declare desc="Test if the manual configuration can be started from the graphic user menu"
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_manual_configuration) > /tmp/capture' Enter
  sleep 5
  tmux send-keys -t "bats_test_session" Enter
  tmux send-keys -t "bats_test_session" "exit" Enter
  local IS_MANUAL_CONFIG=$(< /tmp/capture)
  assert_equal "${IS_MANUAL_CONFIG}" 1
}

@test "Test select_installation_mode" {
  declare desc="Test if the installation mode can be selected from the graphic user menu"
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_installation_mode) > /tmp/capture' Enter
  sleep 5
  tmux send-keys -t "bats_test_session" Enter
  tmux send-keys -t "bats_test_session" "exit" Enter
  local INSTALLATION_MODE=$(< /tmp/capture)
  assert_equal "${INSTALLATION_MODE}" "Debian"
}

@test "Test select_install_now" {
  declare desc="Test if the installation of the Debian package can be started from the graphic user menu"
  tmux new -d -A -s "bats_test_session"
  local TEST_FILE=$(test_file)
  tmux send-keys -t "bats_test_session" "source ${TEST_FILE}" Enter
  tmux send-keys -t "bats_test_session" 'echo $(select_install_now) > /tmp/capture' Enter
  sleep 5
  tmux send-keys -t "bats_test_session" Enter
  tmux send-keys -t "bats_test_session" "exit" Enter
  local IS_INSTALL_NOW=$(< /tmp/capture)
  assert_equal "${IS_INSTALL_NOW}" 0
}

