#!/usr/bin/env sh
# install.sh

# 20260828
# 0.2.0

# Bootstraps what has to be there before Ruby can speak for itself, and hands the
# rest to `namo setup`, which is Ruby and can say what it is doing in the language
# of the thing it is installing.
#
# Whichever package manager is already installed is used — Homebrew, MacPorts, apt,
# dnf, pacman or zypper.  Where none is, and Ruby is missing too, you are asked
# before anything is installed — `-y` answers yes in
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
  echo 'On Linux this is unusual — apt, dnf, pacman and zypper are all used where'
  echo 'they are found — so a machine reaching this message has none of them.'
  echo ''
  echo 'Install Ruby by whichever suits this machine, then run this again.'
}

# Every package manager but Homebrew installs as root, so the password is asked
# for by name rather than arriving unannounced in the middle of a run.
install_with_sudo() {
  echo "$* installs as root, so this asks for your password."
  sudo "$@"
}

# A package manager which is already here is used before one is installed, so a
# machine with apt or MacPorts is never asked about Homebrew.  Homebrew comes
# first among them only because it needs no password.  Only reached for where
# Ruby is actually missing: a machine with Ruby by any other means — rbenv,
# ruby-install, a distribution package — is asked nothing.
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
    install_with_sudo port install ruby
    return
  fi
  if command -v apt-get > /dev/null 2>&1; then
    install_with_sudo apt-get install -y ruby-full
    return
  fi
  if command -v dnf > /dev/null 2>&1; then
    install_with_sudo dnf install -y ruby
    return
  fi
  if command -v pacman > /dev/null 2>&1; then
    install_with_sudo pacman -S --noconfirm ruby
    return
  fi
  if command -v zypper > /dev/null 2>&1; then
    install_with_sudo zypper install -y ruby
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

# gem's EXECUTABLE DIRECTORY rather than gemdir/bin: they agree on most machines
# and the former is what gem itself reports.
gem_bin_directory() {
  gem environment 2>/dev/null | awk '/EXECUTABLE DIRECTORY/{print $NF}'
}

# The login shell decides the file, not whichever file happens to exist: a stock
# macOS account runs zsh and may still carry a .bashrc that nothing reads.
shell_configuration_file() {
  case "$(basename "${SHELL:-/bin/sh}")" in
    zsh) echo "$HOME/.zshrc" ;;
    bash) if [ -f "$HOME/.bashrc" ]; then echo "$HOME/.bashrc"; else echo "$HOME/.bash_profile"; fi ;;
    *) echo "$HOME/.profile" ;;
  esac
}

# gem puts the command in its own directory, which is on the PATH on some machines
# and not on others.  Writing to somebody's shell configuration is the one thing
# here which outlives an uninstall, so it is asked for like the rest.
add_to_path() {
  directory="$(gem_bin_directory)"
  file="$(shell_configuration_file)"
  line="export PATH=\"$directory:\$PATH\""

  if [ -n "$directory" ] && grep -qF "$directory" "$file" 2>/dev/null; then
    echo "$file already names $directory."
  elif agreed "namo is installed, but $directory is not on the PATH.  Add it to $file?"; then
    echo "$line" >> "$file"
    echo "Added to $file:"
    echo "  $line"
  else
    echo 'Leaving your shell configuration alone.  Add this to it yourself:'
    echo "  $line"
    return 1
  fi
}

hand_over() {
  if ! command -v namo > /dev/null 2>&1; then
    add_to_path || return
    # For this run as well as the next shell, so that `namo setup` happens now.
    PATH="$(gem_bin_directory):$PATH"
    export PATH
  fi
  namo setup
  echo ''
  echo 'Open a new shell, and `namo console` will run from anywhere.'
}

main() {
  parse_arguments "$@"
  install_ruby
  install_namo
  hand_over
}

main "$@"
