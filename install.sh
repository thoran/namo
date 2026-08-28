#!/usr/bin/env sh
# install.sh

# 20260827
# 0.0.0

# Bootstraps the two things Ruby cannot bootstrap for itself — Homebrew, and Ruby
# — and hands the rest to bin/namo, which is Ruby and can say what it is doing in
# the language of the thing it is installing.
#
# Every step asks first, so running this twice is not a mistake.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

install_homebrew() {
  if command -v brew > /dev/null 2>&1; then
    echo 'Homebrew is already installed!'
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

install_ruby() {
  if command -v ruby > /dev/null 2>&1; then
    echo "Ruby is already installed! ($(ruby -e 'print RUBY_VERSION'))"
  else
    brew install ruby
  fi
}

main() {
  install_homebrew
  install_ruby
  "$SCRIPT_DIR/bin/namo" setup
}

main
