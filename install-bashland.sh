#!/bin/bash -e
##
# http://www.gnu.org/s/hello/manual/autoconf/Portable-Shell.html
#
# The only shell it won't ever work on is cmd.exe.

set -e

bash_profile_hook='
### Bashland Installation.
### This Should be at the EOF. https://bash.land/docs
if [ -f ~/.bashland/bashland.sh ]; then
    source ~/.bashland/bashland.sh
fi
'
zsh_profile_hook='
### Bashland Installation
if [ -f ~/.bashland/bashland.zsh ]; then
    source ~/.bashland/bashland.zsh
fi
'
fish_config_hook='
### Bashland Installation
if [ -f "$HOME/.bashland/bashland.fish" ]
    source "$HOME/.bashland/bashland.fish"
end
'

bash_config_source='
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
'

PYTHON_VERSION_COMMAND='
import sys
if (3, 6, 0) < sys.version_info < (3, 12, 0):
  sys.exit(0)
elif (2, 7, 8) < sys.version_info < (3,0):
  sys.exit(0)
else:
  sys.exit(-1)'

# Prefer Python 3 versions over Python 2
PYTHON_VERSION_ARRAY=(
    "/usr/bin/python3"
    "python3"
    "python3.11"
    "python3.10"
    "python3.9"
    "python3.8"
    "python3.7"
    "python3.6"
    "python"
    "python2.7"
    "python27"
    "python2"
)

bashland_config=~/.bashland/config
backup_config=~/.bashland.config.backup
zshprofile=~/.zshrc
fish_config="${XDG_CONFIG_HOME:-~/.config}/fish/config.fish"

# Optional parameter to specify a github branch
# to pull from.
github_branch=${1:-'0.0.17'}

install_bashland() {
    check_dependencies
    check_already_installed
    setup_bashland_files
}

get_and_check_python_version() {

    for python_version in "${PYTHON_VERSION_ARRAY[@]}"; do
        if type "$python_version" &> /dev/null; then
            if "$python_version" -c "$PYTHON_VERSION_COMMAND"; then
                echo "$python_version"
                return 0
            fi
        fi

     done
     return 1
}

# Boostrap virtualenv via zipapp
# Details https://virtualenv.pypa.io/en/latest/installation.html#via-zipapp
download_and_install_env() {
    local python_command=$(get_and_check_python_version)
    if [[ -z "$python_command" ]]; then
        die "\n Sorry you need to have python 3.6-3.11 or 2.7.9+ installed. Please install it and rerun this script." 1
    fi

    # Set to whatever python interpreter you want for your first environment
    PYTHON=$(which $python_command)
    echo "Using Python path $PYTHON"

    VERSION=20.10.0
    VERSION_URL="https://github.com/pypa/get-virtualenv/raw/$VERSION/public/virtualenv.pyz"
    # Alternatively use latest url for most recent that should be 2.7-3.9+
    LATEST_URL="https://bootstrap.pypa.io/virtualenv/2.7/virtualenv.pyz"
    curl -OL  $VERSION_URL
    # Create the first "bootstrap" environment.
    $PYTHON virtualenv.pyz -q env
    rm virtualenv.pyz
}

check_dependencies() {
    if [ -z "$(get_and_check_python_version)" ]; then
        die "\n Sorry can't seem to find a version of python 3.6-3.11 or 2.7.9+ installed" 1
    fi

    if [ ! -e $bashprofile ]; then
        die "\n Sorry, Bashland only supports bash or zsh. Your defualt shell is $SHELL." 1
    fi;
}

check_already_installed() {
    if [ -e ~/.bashland ]; then
        echo -e "\nLooks like Bashland is already installed.
        \nLets go ahead and update it.\n"

        # Copy our user credentials so we don't have to ask you for them again.
        if [ -e "$bashland_config" ]; then
            cp "$bashland_config" "$backup_config"
        fi

        rm -r ~/.bashland
    fi
}

install_hooks_for_zsh() {
    # If we're using zsh, install our zsh hooks
    if [ ! -e ~/.zshrc ]; then
        die "No zshfile (.zshrc could be found)" 1
    fi

    # Add our file to our bashprofile if it doesn't exist yet
    if grep -q "source ~/.bashland/bashland.zsh" "$zshprofile"
    then
        :
    else
        echo "$zsh_profile_hook" >> "$zshprofile"
    fi

}

install_hooks_for_fish() {
    if [ ! -e $fish_config ]; then
        die "No fish config cound be found" 1
    fi

    if grep -q "source ~/.bashland/bashland.fish" "$fish_config"
    then
        :
    else
        echo "$fish_config_hook" >> "$fish_config"
    fi
}


# Create two config files .bashrc and .bash_profile since
# OS X and Linux shells use them diffferently. Source .bashrc
# from .bash_profile and everything should work the same now.
generate_bash_config_file() {
    touch ~/.bashrc
    touch ~/.bash_profile
    echo "$bash_config_source" >> ~/.bash_profile
    echo "Created ~/.bash_profile and ~/.bashrc"
}


install_hooks_for_bash() {
    local bashprofile=$(find_users_bash_file)


    # If we don't have a bash profile ask if we should generate one.
    if [ -z "$bashprofile" ]; then
        echo "Couldn't find a bash confg file."

        while true; do
            read -p "Would you like to generate one? (y/n): " yn
            case $yn in
                [Yy]* ) generate_bash_config_file; bashprofile="$HOME/.bashrc"; break;;
                [Nn]* ) break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    # Have to have this. Error out otherwise.
    if [ -z "$bashprofile" ]; then
        die "No bashfile (e.g. .profile, .bashrc, etc) could be found." 1
    fi

    # Add our file to our bashprofile if it doesn't exist yet
    if grep -q "source ~/.bashland/bashland.sh" $bashprofile
    then
        :
    else
        echo "$bash_profile_hook" >> $bashprofile
    fi

}

install_hooks_for_shell() {
    if [ -n "$ZSH_VERSION" ] || [ -f ~/.zshrc ]; then
        install_hooks_for_zsh
    elif [ -n $fish_config ] && [ -e $fish_config ]; then
        install_hooks_for_fish
    elif [ -n $bashprofile ]; then
        install_hooks_for_bash
    else
        die "\n Bashland only supports bash, fish, or zsh. Your default shell is $SHELL." 1
    fi
}


setup_bashland_files() {

    mkdir -p ~/.bashland
    cd ~/.bashland
    download_and_install_env

    # Grab the code from master off github.
    echo "Pulling down bashland-cli from ${github_branch} branch"
    curl -sL https://github.com/bashland/bashland-cli/archive/refs/tags/v${github_branch}.tar.gz -o client.tar.gz
    tar -xf client.tar.gz
    cd bashland-cli*

    # Copy over our dependencies.
    cp -r bashland/shell/deps ~/.bashland/

    # Copy over our bashland sh and zsh files.
    cp bashland/shell/bashland.* ~/.bashland/

    install_hooks_for_shell

    # install our packages. bashland and dependencies.
    echo "Pulling down a few dependencies...(this may take a moment)"
    ../env/bin/pip -qq install .

    # Check if we already have a config. If not run setup.
    if [ -e $backup_config ]; then
        cp "$backup_config" "$bashland_config"
        rm "$backup_config"

        if ! ../env/bin/bashland util update_system_info; then
            # Run setup if we run into any issues updating our system info
            ../env/bin/bashland setup
        fi
    else
        # Setup our config file
        ../env/bin/bashland setup
    fi

    # Wire up our bin directory
    mkdir -p ~/.bashland/bin
    ln -sf ../env/bin/bashland ~/.bashland/bin/bashland
    ln -sf ../env/bin/bl ~/.bashland/bin/bl

    # Clean up what we downloaded
    cd ~/.bashland
    rm client.tar.gz
    rm -r bashland-cli*

    # Make sure our config is only readable to us.
    chmod 600 "$bashland_config"
    chmod 700 ~/.bashland

    if [ -e "$bashland_config" ]; then
        echo "Restart your terminal. \nRun 'bl' and enjoy your command from everywhere!"
    else
        echo "Please run 'bashland setup' after restarting your terminal session."
    fi
}

#
# Find a users active bash file based on
# which looks the largest. The idea being the
# largest is probably the one they actively use.
#
find_users_bash_file() {

    bash_file_array=( ~/.bash_profile ~/.bashrc ~/.profile)

    local largest_file_size=0
    for file in "${bash_file_array[@]}"
    do
        if [ -e $file ]; then
            # Get our file size.
            local file_size=$(wc -c "$file" | awk '{print $1}')

            if [ $file_size -gt $largest_file_size ]; then
                local largest_file_size=$file_size
                local largest_file=$file
            fi
        fi
     done

    # If we found the largest file, return it
    if [ -n "$largest_file" ]; then
        echo $largest_file
        return 0
    fi
}

die() {
    echo "$1" >&2
    exit "${2:-1}"  # Exit with the provided status or default to 1
}

# Run our install so long as we're not in test.
if [[ -z "$bashland_install_test" ]]; then
    install_bashland
fi;
