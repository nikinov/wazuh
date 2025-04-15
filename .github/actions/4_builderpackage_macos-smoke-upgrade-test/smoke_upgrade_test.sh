#!/bin/bash

# 1. Check if wazuh-agent is installed, if it remove it.
# 2. Get the wazuh-agent old-version
# 3. Install the wazuh-agent old version
# 4. Check that the installation was successful
# 5. Upgrade: Using the builder package upgrade the old version.
# 6. Check that upgrade it was succesful


# Input:
old_package_url=$1
upgrade_version=$2
new_pkg=$3

user="${SUDO_USER:-$USER}"


# url="https://packages.wazuh.com/4.x/macos/wazuh-agent-4.10.1-1.intel64.pkg"
# new_pkg_url="wazuh/packages/macos/output/*agent*pkg"

ossec_path="/Library/Ossec"
wazuh_control="$ossec_path/bin/wazuh-control"
check_files_path="/Users/$user/wazuh/.github/actions/check_files"


log_info() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2
}

is_wazuh_agent_installed() {
  if [ -d "$ossec_path" ]; then
    return 0 
  else
    return 1 
  fi
}

get_wazuh_version(){
    if [ -f "$wazuh_control" ]; then
        echo "$($wazuh_control info -v)"
    fi
}

download_pkg(){
    local url=$1
    curl --output-dir /tmp -O "$url" && echo "/tmp/$(basename $url)" || exit 1
}

uninstall_agent(){
    log_info "Uninstalling wazuh-agent"
    launchctl unload /Library/LaunchDaemons/com.wazuh.agent.plist
    /bin/rm -r "$ossec_path"
    /bin/rm -f /Library/LaunchDaemons/com.wazuh.agent.plist
    /bin/rm -rf /Library/StartupItems/WAZUH
    /usr/bin/dscl . -delete "/Users/wazuh"
    /usr/bin/dscl . -delete "/Groups/wazuh"
    /usr/sbin/pkgutil --forget com.wazuh.pkg.wazuh-agent
}

install_agent(){
    local pkg_file=$1
        
    echo "WAZUH_MANAGER='1.1.1.1'" > /tmp/wazuh_envs && installer -pkg $pkg_file -target / | tee -a '/tmp/installer.log'
    launchctl load /Library/LaunchDaemons/com.wazuh.agent.plist
    if grep -q "The install was successful" "/tmp/installer.log"; then
        echo "Installation successfully."
    else
        log_error "The installation could not be completed. The package will not be uploaded.";
        exit 1;
    fi
}

check_files(){
    if [ "$(uname -m)" == "intel64" ]; then
        echo "Check-file test implementation pending for intel64 arch"
    else
        $wazuh_control stop || true

        echo "Running check_files.py (base comparison)"
        python3 $check_files_path/check_files.py -f "$check_files_path/macos_agent_base.csv" --wazuh_gid -1 --wazuh_uid -1 --directory "$ossec_path"

        echo "Running check_files.py (actual state dump)"
        python3 $check_files_path -b 'macos_actual_state.csv' --wazuh_gid -1 --wazuh_uid -1 --directory "$ossec_path"

        echo "Environment CSV"
        cat 'macos_actual_state.csv'
    fi
}


start_wazuh_agent(){
    $wazuh_control start
}

main(){
    if [ -z "$old_package_url" ]; then
        echo "Error: Missing package URL. Usage: $0 <package_url> <expected_version_upgrade>"
        exit 1
    fi
    
    if [ -z "$new_pkg" ]; then
        echo "Error: Missing expected upgrade version. Usage: $0 <package_url> <expected_version_upgrade>"
        exit 1
    fi

    local old_version=$(download_pkg $old_package_url)

    if is_wazuh_agent_installed; then
        version_installed=$(get_wazuh_version)
        log_info "Version already installed: $version_installed"
        uninstall_agent
    fi    
    
    install_agent $old_version
    version_installed=$(get_wazuh_version)
    log_info "Installed old version $version_installed"
    start_wazuh_agent

    log_info "Performe upgrade"
    install_agent $new_pkg
    version_installed=$(get_wazuh_version)
    log_info "Installed new version $version_installed"

    check_files
    
}

main