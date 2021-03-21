#!/usr/bin/env bash

ensure_py3_bin() {
  # If given executable is not available, the user Python bin dir is not in path
  # This function assumes the executable to be checked was installed with
  # pip3 install --user ...
  if ! command -v "${1}" >/dev/null 2>&1; then
    echo "User's Python3 binary directory must be in \$PATH" 1>&2
    echo "Location of package is:" 1>&2
    pip3 show ${2:-$1} | grep "Location"
    echo "\$PATH is currently: $PATH" 1>&2
    exit 1
  fi
}

ensure_py3() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 binary must be in \$PATH" 1>&2
    exit 1
  fi
  if ! command -v pip3 >/dev/null 2>&1; then
    curl -SsL https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py --user
    rm -f get-pip.py
    ensure_py3_bin pip3
  fi
}
