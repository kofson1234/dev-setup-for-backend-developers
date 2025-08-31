#!/bin/bash

# ---------------------------------------------
# Dev Setup Menu (macOS/Homebrew)
# Java 25 (Homebrew if possible, else Adoptium GA→EA, else jdk.java.net EA),
# Maven, Git, Docker, kubectl, Minikube
# ---------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

JAVA_TARGET_MAJOR=25

detect_shell() {
  if [[ $SHELL == *"zsh"* ]]; then
    echo "$HOME/.zshrc"
  elif [[ $SHELL == *"bash"* ]]; then
    if [[ -f "$HOME/.bash_profile" || ! -f "$HOME/.bashrc" ]]; then
      echo "$HOME/.bash_profile"
    else
      echo "$HOME/.bashrc"
    fi
  else
    echo "$HOME/.bashrc"
  fi
}
CONFIG_FILE="$(detect_shell)"

print_header() {
  clear
  echo -e "${CYAN}---------------------------------------------"
  echo -e "         🌟 Welcome to Dev Setup Menu 🌟"
  echo -e "---------------------------------------------${NC}"
}

ensure_macos() {
  if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${YELLOW}This script is optimized for macOS with Homebrew.${NC}"
  fi
}

ensure_brew_on_path() {
  if command -v brew &>/dev/null; then return; fi
  local HB_BIN_AS="/opt/homebrew/bin"
  local HB_BIN_INTEL="/usr/local/bin"
  if [[ -x "$HB_BIN_AS/brew" ]]; then
    if ! grep -q "/opt/homebrew/bin" "$CONFIG_FILE" 2>/dev/null; then
      echo 'export PATH="/opt/homebrew/bin:$PATH"' >> "$CONFIG_FILE"
      echo -e "${GREEN}✔ Added /opt/homebrew/bin to PATH in ${CONFIG_FILE}${NC}"
      source "$CONFIG_FILE"
    fi
  elif [[ -x "$HB_BIN_INTEL/brew" ]]; then
    if ! grep -q "/usr/local/bin" "$CONFIG_FILE" 2>/dev/null; then
      echo 'export PATH="/usr/local/bin:$PATH"' >> "$CONFIG_FILE"
      echo -e "${GREEN}✔ Added /usr/local/bin to PATH in ${CONFIG_FILE}${NC}"
      source "$CONFIG_FILE"
    fi
  fi
}

install_homebrew() {
  if ! command -v brew &>/dev/null; then
    echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ensure_brew_on_path
  else
    echo -e "${GREEN}✔ Homebrew is already installed.${NC}"
  fi
}

# ---------- JAVA ENV (only persist when version matches) ----------

remove_java_env_block() {
  sed -i '' '/# >>> dev-setup java >>>/,/# <<< dev-setup java <<</d' "$CONFIG_FILE" 2>/dev/null || true
}

persist_and_export_java_home_if_matches() {
  local jhome="$1"
  local required_major="$2"
  if [[ ! -x "$jhome/bin/java" ]]; then return 1; fi
  local out
  out=$("$jhome/bin/java" -version 2>&1 || true)
  if echo "$out" | grep -qE "version \"${required_major}(\.|\")"; then
    remove_java_env_block
    {
      echo "# >>> dev-setup java >>>"
      echo "export JAVA_HOME=\"$jhome\""
      echo 'export PATH="$JAVA_HOME/bin:$PATH"'
      echo "# <<< dev-setup java <<<"
    } >> "$CONFIG_FILE"
    export JAVA_HOME="$jhome"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo -e "${GREEN}✔ JAVA_HOME set to: $JAVA_HOME${NC}"
    return 0
  fi
  return 1
}

resolve_java_home_for() {
  local major="$1"
  /usr/libexec/java_home -v "$major" 2>/dev/null || true
}

# ---------- JAVA INSTALLERS (25) ----------

brew_try_java25() {
  local formula="openjdk@${JAVA_TARGET_MAJOR}"
  if brew info "$formula" >/dev/null 2>&1; then
    echo -e "${CYAN}Installing ${formula} via Homebrew...${NC}"
    brew install "$formula" || return 1
  else
    echo -e "${YELLOW}${formula} not available. Trying 'openjdk' (latest) and checking if it's ${JAVA_TARGET_MAJOR}...${NC}"
    brew install openjdk || true
  fi

  local jhome
  jhome="$(resolve_java_home_for "$JAVA_TARGET_MAJOR")"
  if [[ -n "$jhome" ]] && persist_and_export_java_home_if_matches "$jhome" "$JAVA_TARGET_MAJOR"; then
    echo -e "${GREEN}✔ Java ${JAVA_TARGET_MAJOR} available via Homebrew.${NC}"
    return 0
  fi
  return 1
}

adoptium_download_and_install() {
  local major="$1"       # 25
  local release="$2"     # ga or ea
  local arch
  if [[ "$(uname -m)" == "arm64" ]]; then arch="aarch64"; else arch="x64"; fi
  local api="https://api.adoptium.net/v3/assets/latest/${major}/${release}?architecture=${arch}&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os=mac"

  local tmp="/tmp/adoptium_${major}_${release}_${arch}_$$.json"
  echo -e "${CYAN}Querying Adoptium ${major} (${release})...${NC}"
  if ! curl -fsSL "$api" -o "$tmp"; then
    echo -e "${RED}❌ Failed to query Adoptium API (${release}).${NC}"
    rm -f "$tmp"
    return 1
  fi

  local link
  link=$(tr -d '\n' < "$tmp" | sed -n 's/.*"link":"\([^"]*\.pkg\)".*/\1/p' | head -n1)
  rm -f "$tmp"

  if [[ -z "$link" ]]; then
    echo -e "${YELLOW}No PKG link found for ${major} (${release}).${NC}"
    return 1
  fi

  local pkg="/tmp/temurin${major}-${arch}-${release}.pkg"
  echo -e "${CYAN}Downloading:${NC} $link"
  if ! curl -fsSL -o "$pkg" "$link"; then
    echo -e "${RED}❌ Download failed.${NC}"
    return 1
  fi

  echo -e "${CYAN}Installing PKG (sudo may prompt)...${NC}"
  if ! sudo installer -pkg "$pkg" -target /; then
    echo -e "${RED}❌ PKG install failed.${NC}"
    return 1
  fi

  local jhome="/Library/Java/JavaVirtualMachines/temurin-${major}.jdk/Contents/Home"
  if persist_and_export_java_home_if_matches "$jhome" "$major"; then
    echo -e "${GREEN}✔ Java ${major} installed via Adoptium (${release}).${NC}"
    return 0
  fi

  echo -e "${RED}❌ Java ${major} verification failed at $jhome.${NC}"
  return 1
}

openjdk_ea_from_jdk_java_net() {
  local major="$1"  # 25
  local arch
  if [[ "$(uname -m)" == "arm64" ]]; then arch="aarch64"; else arch="x64"; fi

  local page="/tmp/jdk_${major}_$$.html"
  echo -e "${CYAN}Trying OpenJDK EA page (jdk.java.net/${major})...${NC}"
  if ! curl -fsSL "https://jdk.java.net/${major}/" -o "$page"; then
    echo -e "${RED}❌ Unable to fetch jdk.java.net page.${NC}"
    rm -f "$page"
    return 1
  fi

  local tarurl
  tarurl=$(grep -Eo 'https?://[^"]*macos.*('"$arch"'|macosx).*\.tar\.gz' "$page" | head -n1)
  rm -f "$page"

  if [[ -z "$tarurl" ]]; then
    echo -e "${YELLOW}No macOS ${arch} tarball link found on jdk.java.net/${major}.${NC}"
    return 1
  fi

  local tar="/tmp/openjdk${major}-${arch}.tar.gz"
  echo -e "${CYAN}Downloading:${NC} $tarurl"
  if ! curl -fsSL -o "$tar" "$tarurl"; then
    echo -e "${RED}❌ Download failed.${NC}"
    return 1
  fi

  echo -e "${CYAN}Extracting to /Library/Java/JavaVirtualMachines (sudo may prompt)...${NC}"
  sudo mkdir -p /Library/Java/JavaVirtualMachines
  if ! sudo tar -xzf "$tar" -C /Library/Java/JavaVirtualMachines; then
    echo -e "${RED}❌ Extract failed.${NC}"
    return 1
  fi

  local jhome=""
  jhome=$(ls -d /Library/Java/JavaVirtualMachines/jdk-${major}*.jdk/Contents/Home 2>/dev/null | head -n1)
  if [[ -z "$jhome" ]]; then
    jhome=$(ls -d /Library/Java/JavaVirtualMachines/jdk-${major}*/Contents/Home 2>/dev/null | head -n1)
  fi

  if [[ -n "$jhome" ]] && persist_and_export_java_home_if_matches "$jhome" "$major"; then
    echo -e "${GREEN}✔ Java ${major} installed from OpenJDK EA tarball.${NC}"
    return 0
  fi

  echo -e "${RED}❌ Could not verify Java ${major} after tarball extraction.${NC}"
  return 1
}

install_java25() {
  echo -e "${CYAN}Installing Java ${JAVA_TARGET_MAJOR}...${NC}"
  remove_java_env_block

  if brew_try_java25; then
    echo -n "${GREEN}Current java: ${NC}"; "$JAVA_HOME/bin/java" -version 2>&1 | head -n1
    return 0
  else
    echo -e "${YELLOW}Homebrew route did not yield Java ${JAVA_TARGET_MAJOR}.${NC}"
  fi

  if adoptium_download_and_install "$JAVA_TARGET_MAJOR" "ga"; then
    echo -n "${GREEN}Current java: ${NC}"; "$JAVA_HOME/bin/java" -version 2>&1 | head -n1
    return 0
  fi
  echo -e "${YELLOW}Adoptium GA not available. Trying EA...${NC}"
  if adoptium_download_and_install "$JAVA_TARGET_MAJOR" "ea"; then
    echo -n "${GREEN}Current java: ${NC}"; "$JAVA_HOME/bin/java" -version 2>&1 | head -n1
    return 0
  fi

  echo -e "${YELLOW}Adoptium EA not available. Trying OpenJDK EA (jdk.java.net)...${NC}"
  if openjdk_ea_from_jdk_java_net "$JAVA_TARGET_MAJOR"; then
    echo -n "${GREEN}Current java: ${NC}"; "$JAVA_HOME/bin/java" -version 2>&1 | head -n1
    return 0
  fi

  echo -e "${RED}❌ Unable to install Java ${JAVA_TARGET_MAJOR}.${NC}"
  exit 1
}

# ---------- COMMON PACKAGE HELPERS ----------

uninstall_if_exists() {
  local package="$1"
  if brew list --formula | grep -q "^${package}\$" 2>/dev/null || brew list --cask | grep -q "^${package}\$" 2>/dev/null; then
    echo -e "${RED}Removing previous version of ${package}...${NC}"
    brew uninstall --force "$package" >/dev/null || true
  else
    echo -e "${YELLOW}No previous version of ${package} found.${NC}"
  fi
}

add_to_env_path() {
  local path="$1"
  if ! grep -q "$path" "$CONFIG_FILE" 2>/dev/null; then
    echo "export PATH=\$PATH:$path" >> "$CONFIG_FILE"
    echo -e "${GREEN}✔ Added $path to PATH in $CONFIG_FILE${NC}"
    source "$CONFIG_FILE"
  else
    echo -e "${YELLOW}Path $path is already in the environment variables.${NC}"
  fi
}

# ---------- kubectl version helper (no --short) ----------

get_kubectl_version() {
  if ! command -v kubectl &>/dev/null; then return 1; fi
  local ver

  # Best: JSONPath (widely supported)
  ver="$(kubectl version --client -o=jsonpath='{.clientVersion.gitVersion}' 2>/dev/null)"
  if [[ -n "$ver" && "$ver" != "{.clientVersion.gitVersion}" ]]; then
    echo "Client Version: $ver"
    return 0
  fi

  # JSON fallback
  ver="$(kubectl version --client -o=json 2>/dev/null | tr -d '\r' | grep -Eo '\"gitVersion\" *: *\"v[^"]+\"' | head -n1 | sed -E 's/.*\"(v[^"]+)\"/\1/')"
  if [[ -n "$ver" ]]; then
    echo "Client Version: $ver"
    return 0
  fi

  # YAML fallback
  ver="$(kubectl version --client -o=yaml 2>/dev/null | grep -E '^gitVersion:' | head -n1 | awk '{print $2}')"
  if [[ -n "$ver" ]]; then
    echo "Client Version: $ver"
    return 0
  fi

  # Last resort: plain banner (avoid stderr errors)
  ver="$(kubectl version --client 2>/dev/null | tr -d '\r' | head -n2)"
  if [[ -n "$ver" ]]; then
    echo "$ver"
    return 0
  fi

  return 1
}

install_maven() {
  uninstall_if_exists "maven"
  echo -e "${CYAN}Installing Maven...${NC}"
  brew install maven
  add_to_env_path "$(brew --prefix maven)/bin"
}

install_git() {
  uninstall_if_exists "git"
  echo -e "${CYAN}Installing Git...${NC}"
  brew install git
  add_to_env_path "$(brew --prefix git)/bin"
}

install_docker() {
  uninstall_if_exists "docker"
  echo -e "${CYAN}Installing Docker (Desktop)...${NC}"
  brew install --cask docker
  add_to_env_path "/Applications/Docker.app/Contents/Resources/bin"
  echo -e "${YELLOW}Tip:${NC} Start Docker Desktop once so the Docker engine/CLI are ready."
}

install_kubectl() {
  uninstall_if_exists "kubernetes-cli"
  echo -e "${CYAN}Installing kubectl...${NC}"
  brew install kubernetes-cli
  add_to_env_path "$(brew --prefix)/bin"
  local kver
  kver="$(get_kubectl_version)"
  if [[ -n "$kver" ]]; then
    echo -e "${GREEN}✔ kubectl: ${kver}${NC}"
  else
    echo -e "${YELLOW}kubectl installed, but version not resolved (open a new shell or re-run Verify).${NC}"
  fi
}

install_minikube() {
  uninstall_if_exists "minikube"
  echo -e "${CYAN}Installing Minikube...${NC}"
  brew install minikube
  add_to_env_path "$(brew --prefix)/bin"
  if command -v docker &>/dev/null; then
    echo -e "${YELLOW}Configuring Minikube to use the Docker driver by default...${NC}"
    minikube config set driver docker >/dev/null 2>&1 || true
  fi
  echo -e "${GREEN}✔ Minikube installed. Try: 'minikube start'${NC}"
}

install_kubernetes_stack() {
  install_kubectl
  install_minikube
}

# ---------- JAVA INFO (nice verify output) ----------

print_java_info() {
  if ! command -v java &>/dev/null; then
    echo "java:     not found"
    return
  fi
  local out verline rtline channel build release_date today
  out="$(java -version 2>&1)"
  verline="$(echo "$out" | sed -n '1p')"
  rtline="$(echo "$out" | sed -n '2p')"
  channel="GA"; echo "$out" | grep -qi 'ea' && channel="EA"
  release_date="$(echo "$verline" | awk '{print $4}' | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || true)"
  build="$(echo "$rtline" | sed -n 's/.*(build \([^)]*\)).*/\1/p')"

  echo "java:     $verline"
  [[ -n "$build" ]] && echo "          runtime build: $build"
  echo "          channel: $channel"
  if [[ -n "$release_date" ]]; then
    today="$(date +%Y-%m-%d)"
    if [[ "$release_date" > "$today" ]]; then
      echo "          note: $release_date is the official GA release date from the JDK version string (future is normal for EA)."
    else
      echo "          GA date: $release_date"
    fi
  fi
}

# ---------- VERIFY ----------

verify_installs() {
  [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

  echo -e "${CYAN}--- Versions ---${NC}"
  print_java_info

  if command -v mvn &>/dev/null; then
    echo -n "maven:    "; mvn -v | head -n1
  else
    echo "maven:    not found"
  fi

  if command -v git &>/dev/null; then
    echo -n "git:      "; git --version
  else
    echo "git:      not found"
  fi

  if command -v docker &>/dev/null; then
    echo -n "docker:   "; docker --version
  else
    echo "docker:   not found"
  fi

  if command -v kubectl &>/dev/null; then
    local kver; kver="$(get_kubectl_version)"
    if [[ -n "$kver" ]]; then
      echo "kubectl:  $kver"
    else
      echo "kubectl:  installed (version not resolved)"
    fi
  else
    echo "kubectl:  not found  — run menu option 6, or: brew install kubernetes-cli"
  fi

  if command -v minikube &>/dev/null; then
    echo -n "minikube: "; minikube version | head -n1
  else
    echo "minikube: not found  — run menu option 6, or: brew install minikube"
  fi

  echo -e "${CYAN}----------------${NC}"
  read -rp "Press Enter to continue..."
}

# ---------- FLOWS ----------

install_all() {
  install_homebrew
  install_java25
  install_maven
  install_git
  install_docker
  install_kubernetes_stack
}

# ---------- MAIN ----------

ensure_macos
ensure_brew_on_path

while true; do
  print_header
  echo -e "${YELLOW}Please choose an option from the menu:${NC}"
  echo -e "${GREEN}1${NC} - Install All (Java ${JAVA_TARGET_MAJOR}, Maven, Git, Docker, Kubernetes/kubectl, Minikube)"
  echo -e "${GREEN}2${NC} - Install Java ${JAVA_TARGET_MAJOR}"
  echo -e "${GREEN}3${NC} - Install Maven"
  echo -e "${GREEN}4${NC} - Install Docker"
  echo -e "${GREEN}5${NC} - Install Git"
  echo -e "${GREEN}6${NC} - Install Kubernetes (kubectl + Minikube)"
  echo -e "${GREEN}7${NC} - Verify installs"
  echo -e "${GREEN}8${NC} - Exit"
  echo -e "---------------------------------------------"
  read -r -p "$(echo -e ${CYAN}Enter your choice: ${NC})" choice

  case "$choice" in
    1) install_all ;;
    2) install_homebrew; install_java25 ;;
    3) install_homebrew; install_maven ;;
    4) install_homebrew; install_docker ;;
    5) install_homebrew; install_git ;;
    6) install_homebrew; install_kubernetes_stack ;;
    7) verify_installs ;;
    8) echo -e "${GREEN}✔ Exiting program.${NC}"; exit 0 ;;
    *) echo -e "${RED}✘ Invalid option. Please try again.${NC}"; sleep 2 ;;
  esac
done
