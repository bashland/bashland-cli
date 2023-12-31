#!/usr/bin/python
#
# Python version of install bashland
#

import os
import sys
import shutil
from pkg_resources import resource_exists, resource_filename


def check_already_installed(home_dir):
    installed = os.path.isdir(home_dir + "/.bashland")
    if installed:
        raise RuntimeError("Looks like bashland is already installed. " + \
                "rm -r ~/.bashland to install again.")


def setup_bashland_files(home_dir):
    bashland_dir = home_dir + '.bashland/'
    # move .sh files to appropriate place.
    exists = resource_exists(__name__, 'bashland/shell')
    if exists:
        shell_scripts = resource_filename(__name__, 'bashland/shell')
        # Should create our bashland directory and copy our files there.
        shutil.copytree(shell_scripts, bashland_dir)

        # Add our file to our bash config if it's not present
        bash_config = find_users_bash_config(home_dir)
        with open(bash_config, "a+") as config:
            source_hook = "source ~/.bashland/bashland.sh"
            if source_hook not in config.read():
                config.write(source_hook)

    else:
        raise RuntimeError("Couldn't install bashland files in " + bashland_dir)


def find_users_bash_config(home_dir):
    bash_files = ["/.bashrc", "/.bash_profile", "/.profile"]
    for file in bash_files:
        if os.path.isfile(home_dir + file):
            return home_dir + file

    raise RuntimeError("Bummer looks, like we couldn't find a bash profile file. " + \
            "Do you have a ~/.profile or ~/.bashhrc?")


def main():
    try:
        print("Installing needed scripts")
        # Get our home directory from
        home = os.environ["HOME"] + '/'
        find_users_bash_config(home)
        check_already_installed(home)
        setup_bashland_files(home)
    except Exception as err:
        sys.stderr.write('Setup Error:\n%s\n' % str(err))
        sys.exit(1)


if __name__ == "__main__":
    main()
