#!/usr/bin/env sh
# install.sh

# 20260828
# 0.1.0

# Bootstraps what has to be there before Ruby can speak for itself, and hands the
# rest to `namo setup`, which is Ruby and can say what it is doing in the language
# of the thing it is installing.
#
# Homebrew or MacPorts is used where either is already installed.  Where neither
# is, and Ruby is missing too, you are asked before anything is installed — `-y` answers yes in
# advance, and a machine with nothing on its standard input is treated as having
# said no, since a script piped into a shell must not install a package manager
# because nobody was there to refuse.
#
# It finds nothing by its own path, so it runs the same piped from curl as it does
# from a clone.  Every step asks first, so running it twice is not a mistake.

AUTOMATIC=0

usage() {
  echo 'install.sh - Install Namo, and what Namo needs.'
  echo ''
  echo 'Usage: install.sh [-y]'
  echo ''
  echo '  -y, --yes  install Homebrew without asking, where Ruby needs it'
}

parse_arguments() {
  for argument in "$@"; do
    case "$argument" in
      -y|--yes) AUTOMATIC=1 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "install.sh: unknown option '$argument'"; usage; exit 1 ;;
    esac
  done
}

agreed() {
  [ "$AUTOMATIC" -eq 1 ] && return 0
  [ -t 0 ] || return 1
  printf '%s [y/N] ' "$1"
  read -r answer
  case "$answer" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

install_homebrew() {
  if command -v brew > /dev/null 2>&1; then
    echo 'Homebrew is already installed!'
  elif agreed 'Homebrew was not found, and Ruby needs it.  Install Homebrew?'; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    echo 'Leaving Homebrew alone.  Nothing has been installed.'
  fi
}

# Naming the routes rather than the absence of one.  Homebrew is given as the
# command because that is what it is; the other two are given as pages, MacPorts
# shipping an installer to download and ruby-install wanting a tarball, a make
# and a password.
ruby_routes() {
  echo ''
  echo 'Namo needs Ruby.  The usual ways to get it on macOS:'
  echo ''
  echo '  Homebrew      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo '  MacPorts      https://www.macports.org/install.php'
  echo '  ruby-install  https://github.com/postmodern/ruby-install#install'
  echo ''
  echo 'On Linux, your distribution ships one: apt install ruby, dnf install ruby,'
  echo 'pacman -S ruby, and so on.'
  echo ''
  echo 'Install Ruby by whichever suits this machine, then run this again.'
}

# A package manager which is already here is used before one is installed, so a
# MacPorts machine is never asked about Homebrew.  Only reached for where Ruby is
# actually missing: a machine with Ruby by any other means — rbenv, ruby-install,
# a distribution package — is asked nothing.
install_ruby() {
  if command -v ruby > /dev/null 2>&1; then
    echo "Ruby is already installed! ($(ruby -e 'print RUBY_VERSION'))"
    return
  fi
  if command -v brew > /dev/null 2>&1; then
    brew install ruby
    return
  fi
  if command -v port > /dev/null 2>&1; then
    echo 'MacPorts installs as root, so this asks for your password.'
    sudo port install ruby
    return
  fi
  install_homebrew
  if command -v brew > /dev/null 2>&1; then
    brew install ruby
  else
    ruby_routes
    exit 1
  fi
}

install_namo() {
  if command -v namo > /dev/null 2>&1; then
    echo 'namo is already installed!'
  else
    gem install namo
  fi
}

# gem puts the command in its own directory, which is on the PATH on some machines
# and not on others.  Saying which directory is the honest thing a script can do
# without editing somebody's shell.
hand_over() {
  if command -v namo > /dev/null 2>&1; then
    namo setup
  else
    echo ''
    echo 'namo is installed, but its directory is not on the PATH.  Add it with:'
    echo "  export PATH=\"$(gem environment gemdir)/bin:\$PATH\""
    echo 'and then run `namo setup` for the gems the scripts want.'
  fi
}

main() {
  parse_arguments "$@"
  install_ruby
  install_namo
  hand_over
}

main "$@"
