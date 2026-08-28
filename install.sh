#!/usr/bin/env sh
# install.sh

# 20260828
# 0.3.0

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
# Piped from curl it finds nothing by its own path and installs the gem to get the
# command it hands over to.  Run from a clone it hands over to that clone's
# bin/namo instead, so a checkout with the gem not yet installed works as it
# stands.  Every step asks first, so running it twice is not a mistake.

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
    report brew "$(brew --version 2>/dev/null | awk 'NR==1{print $2}')" 'already installed'
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

# The status and the version, one line per check, as bin/namo reports the gems.
report() {
  printf '  %-11s %-8s %s\n' "$1" "${2:--}" "$3"
}

# A package manager which is already here is used before one is installed, so a
# machine with apt or MacPorts is never asked about Homebrew.  Homebrew comes
# first among them only because it needs no password.  Only reached for where
# Ruby is actually missing: a machine with Ruby by any other means — rbenv,
# ruby-install, a distribution package — is asked nothing.
install_ruby() {
  if command -v ruby > /dev/null 2>&1; then
    report ruby "$(ruby -e 'print RUBY_VERSION')" 'already installed'
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
    return
  fi
  if install_ruby_install && ruby_from_ruby_install; then
    return
  fi
  ruby_routes
  exit 1
}

# The last resort before giving up, and the only route here which builds Ruby
# rather than fetching it.  ruby-install ships no installer of its own beyond a
# tarball and a make, and the tag is resolved rather than pinned so that this does
# not rot against a version.
install_ruby_install() {
  if command -v ruby-install > /dev/null 2>&1; then
    report ruby-install "$(ruby-install --version 2>/dev/null | awk '{print $NF}')" 'already installed'
    return 0
  fi
  agreed 'No package manager was found.  Install ruby-install from source and build Ruby with it?' || return 1

  tag="$(curl -fsSLI https://github.com/postmodern/ruby-install/releases/latest 2>/dev/null |
    awk -F/ '/^[Ll]ocation:/{print $NF}' | tr -d '\r')"
  if [ -z "$tag" ]; then
    echo 'Could not find the latest ruby-install release.'
    return 1
  fi
  version="${tag#v}"
  directory="$(mktemp -d)"

  curl -fsSL "https://github.com/postmodern/ruby-install/releases/download/$tag/ruby-install-$version.tar.gz" |
    tar -xz -C "$directory" || return 1
  echo 'make install runs as root, so this asks for your password.'
  (cd "$directory/ruby-install-$version" && sudo make install) || return 1
}

# ruby-install leaves its Ruby under ~/.rubies, which nothing puts on the PATH —
# chruby's job, and chruby is not here either.  The newest is taken for this run,
# and offered to the shell for the next one.
ruby_from_ruby_install() {
  ruby-install --no-reinstall ruby || return 1
  newest="$(ls -d "$HOME"/.rubies/*/bin 2>/dev/null | sort | tail -1)"
  if [ -z "$newest" ]; then
    echo 'ruby-install finished, but left no Ruby under ~/.rubies.'
    return 1
  fi
  wants_on_path "$newest"
}

# gem install runs on every occasion: it is idempotent for a version already
# installed and fetches a newer one where there is one, so this is what makes a
# second run an upgrade.  Its output is held rather than shown, gem being noisy
# about work it did not do, and shown in full if it fails.
# The clone this script was run from, where it was run from one.  $0 is the path
# to a real file only when the script was run as a file: piped from curl it is
# the shell's own name, and there is nothing to find.  A namo checkout is one
# carrying bin/namo beside the gemspec which ships it, both together rather than
# either alone, so that a stray bin/namo on some other tree is not mistaken for
# this one.
repository() {
  [ -f "$0" ] || return 1
  directory="$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)" || return 1
  [ -x "$directory/bin/namo" ] || return 1
  [ -f "$directory/namo.gemspec" ] || return 1
  echo "$directory"
}

namo_version() {
  gem list -e namo 2>/dev/null | awk 'NR==1{gsub(/[(),]/, "", $2); print $2}'
}

install_namo() {
  before="$(namo_version)"
  if ! output="$(gem install namo 2>&1)"; then
    echo "$output"
    return 1
  fi
  after="$(namo_version)"
  # Silent where nothing changed: `namo setup`, a moment later, reports the gem
  # and its version anyway, and two identical lines are not two facts.
  if [ "$before" = "$after" ]; then
    return 0
  elif [ -z "$before" ]; then
    report namo "$after" 'installed'
  else
    report namo "$after" "upgraded from $before"
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

# Directories which want to be on the PATH, gathered as they are found so that the
# shell configuration is written to once rather than once per directory: a machine
# taking the ruby-install route has a Ruby under ~/.rubies and its gems elsewhere,
# and being asked the same question twice, seconds apart, is not two decisions.
PENDING_PATH=''

wants_on_path() {
  directory="$1"
  [ -n "$directory" ] || return 0
  PATH="$directory:$PATH"
  export PATH
  case " $PENDING_PATH " in
    *" $directory "*) return 0 ;;
  esac
  PENDING_PATH="$PENDING_PATH $directory"
}

# Writing to somebody's shell configuration is the one thing here which outlives
# an uninstall, so it is asked for like the rest — once, naming every directory it
# would add.
add_to_path() {
  file="$(shell_configuration_file)"
  wanted=''
  for directory in $PENDING_PATH; do
    grep -qF "$directory" "$file" 2>/dev/null && continue
    wanted="$wanted $directory"
  done

  if [ -z "$wanted" ]; then
    [ -n "$PENDING_PATH" ] && echo "$file already names everything Namo needs on the PATH."
    return 0
  fi

  line="export PATH=\"$(echo "$wanted" | sed 's/^ //; s/ /:/g'):\$PATH\""
  if agreed "Namo needs$wanted on the PATH.  Add to $file?"; then
    echo "$line" >> "$file"
    echo "Added to $file:"
    echo "  $line"
  else
    echo 'Leaving your shell configuration alone.  Add this to it yourself:'
    echo "  $line"
  fi
}

# The gem's bin directory goes on the PATH either way: `namo console` has to run
# from anywhere afterwards, and a clone's bin/namo is not what will be answering.
hand_over() {
  clone="$1"
  # wants_on_path puts it on this run's PATH too, so that `namo setup` happens now
  # rather than being left as a further instruction.
  command -v namo > /dev/null 2>&1 || wants_on_path "$(gem_bin_directory)"
  add_to_path
  if [ -n "$clone" ]; then
    "$clone/bin/namo" setup
  elif command -v namo > /dev/null 2>&1; then
    namo setup
  else
    echo 'namo is installed but still not on the PATH; skipping `namo setup`.'
    return
  fi
  echo ''
  echo 'Open a new shell, and `namo console` will run from anywhere.'
}

# install_namo is the bootstrap for the handover and nothing more: it is there to
# put the `namo` command somewhere it can be run from.  A clone already carries
# one, so the gem is left to `namo setup`, which installs it as its own first act
# and says so once rather than twice.
main() {
  parse_arguments "$@"
  install_ruby
  clone="$(repository)" || clone=''
  [ -n "$clone" ] || install_namo
  hand_over "$clone"
}

main "$@"
