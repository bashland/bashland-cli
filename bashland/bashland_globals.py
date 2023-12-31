"""
This file should be used for declaring any global variables that need to be
pulled in from environment variables or are just used across multiple files.
"""

import os
import re
import time
import stat

# Support for Python 2 and 3
try:
    import configparser
    from configparser import NoSectionError, NoOptionError
except ImportError:
    import ConfigParser as configparser
    from ConfigParser import NoSectionError, NoOptionError

# Current time in milleseconds to use across app.
current_milli_time = lambda: int(round(time.time() * 1000))

BL_HOME = '~/.bashland' if 'HOME' not in list(os.environ.keys()) \
        else os.environ['HOME'] + '/.bashland'


def write_to_config_file(section, value):
    exists = os.path.exists(BL_HOME)
    file_path = BL_HOME + '/config'
    permissions = stat.S_IRUSR | stat.S_IWUSR
    if exists:
        config = configparser.ConfigParser()
        config.read(BL_HOME + '/config')
        # Add our section if it doesn't exist
        if not config.has_section("bashland"):
            config.add_section("bashland")

        config.set("bashland", section, value)
        with open(file_path, 'w') as config_file:
            config.write(config_file)
            os.chmod(file_path, permissions)
        return True
    else:
        print("Couldn't find bashland home directory. Sorry.")
        return False


def get_from_config(key, default=''):
    try:
        config = configparser.ConfigParser()
        config.read(BL_HOME + '/config')
        return config.get('bashland', key)
    except NoSectionError as error:
        return default
    except NoOptionError as error:
        return default

# Optional environment variable to configure for development
# export BL_URL='http://localhost:8080'
BL_URL = os.getenv('BL_URL', get_from_config('url', 'http://bash.land:8080'))

BL_SAVE_COMMANDS = os.getenv('BL_SAVE_COMMANDS', \
    get_from_config('save_commands')).lower() in ('true', 'yes', 't', 'on', '')

BL_SYSTEM_NAME = get_from_config("system_name")

# Check if debug mode is enabled
BL_DEBUG = os.getenv('BL_DEBUG', get_from_config("debug"))


# Get our token from the environment if one is present
# otherwise retrieve it from our config. Needs to
# be a function since we may change our token during setup
def BL_AUTH():
    return os.getenv('BL_ACCESS_TOKEN', get_from_config("access_token"))


def is_valid_regex(regex):
    try:
        re.compile(regex)
        return True
    except re.error:
        return False

def get_bl_filter():
    filter = os.getenv('BL_FILTER', get_from_config('filter'))
    return filter if is_valid_regex(filter) else '__invalid__'

BL_FILTER =  get_bl_filter()
