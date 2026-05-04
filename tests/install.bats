#!/usr/bin/env bats

load 'test_helper'

@test "install.sh --help prints usage and exits 0" {
  run_install --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: install.sh"* ]]
  [[ "$output" == *"--vault"* ]]
  [[ "$output" == *"--no-auto-session"* ]]
  [[ "$output" == *"--target"* ]]
  [[ "$output" == *"--uninstall"* ]]
  [[ "$output" == *"--reset-config"* ]]
}

@test "install.sh with unknown flag exits non-zero with error" {
  run_install --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* || "$output" == *"--bogus"* ]]
}
