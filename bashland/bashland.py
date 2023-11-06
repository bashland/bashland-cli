#!/usr/bin/python
from __future__ import print_function
from time import *
import click
import traceback
import dateutil.parser
import sys
import os
import io

from .model import CommandForm
from . import rest_client
from . import bashland_setup
from . import bashland_globals
from .bashland_globals import BL_FILTER, BL_HOME, BL_SAVE_COMMANDS
from .bashland_globals import write_to_config_file
from .version import version_str
import shutil
import requests
import subprocess
from . import shell_utils
import re
from .view.status import *

from builtins import str as text


def print_version(ctx, param, value):
    if not value or ctx.resilient_parsing:
        return
    click.echo(version_str)
    ctx.exit()


CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])


@click.group(context_settings=CONTEXT_SETTINGS)
@click.option('-V',
              '--version',
              default=False,
              is_flag=True,
              callback=print_version,
              help='Display version',
              expose_value=False,
              is_eager=True)
def bashland():
    """BashLand command line client"""
    pass


@bashland.command()
def version():
    """Display version"""
    click.echo(version_str)


@bashland.command()
@click.option("-g",
              "--global",
              "is_global",
              default=False,
              is_flag=True,
              help="Turn off saving commands for all sessions.")
def off(is_global):
    """Turn off saving commands to BashLand. Applies for this current session."""
    if is_global:
        write_to_config_file('save_commands', 'False')
    else:
        f = io.open(BL_HOME + '/script.bh', 'w+', encoding='utf-8')
        print(text("export BL_SAVE_COMMANDS='False'"), file=f)


@bashland.command()
@click.option('-l',
              "--local",
              help="Turn on saving commands for only this session.",
              is_flag=True)
def on(local):
    """Turn on saving commands to BashLand. Applies globally."""
    f = io.open(BL_HOME + '/script.bh', 'w+', encoding='utf-8')

    if local:
        print(text("export BL_SAVE_COMMANDS='True'"), file=f)
    else:
        print(text("unset BL_SAVE_COMMANDS"), file=f)
        write_to_config_file('save_commands', 'True')


@bashland.command()
@click.argument('command', type=str)
@click.argument('path', type=click.Path(exists=True))
@click.argument('pid', type=int)
@click.argument('process_start_time', type=int)
@click.argument('exit_status', type=int)
def save(command, path, pid, process_start_time, exit_status):
    """Save a command to BashLand"""
    pid_start_time = unix_time_to_epoc_millis(process_start_time)
    command = command.strip()

    # Check if we have commands saving turned on
    if not bashland_globals.BL_SAVE_COMMANDS:
        return

    # Check if we should ignore this command.
    if "#ignore" in command:
        return

    # Check if we should filter this command.
    bl_filter = bashland_globals.BL_FILTER
    if bl_filter and re.findall(bl_filter, command):
        return

    # Check that we have an auth token.
    if bashland_globals.BL_AUTH() == "":
        print("No auth token found. Run 'bashland setup' to login.")
        return

    command = CommandForm(command, path, exit_status, pid, pid_start_time)
    rest_client.save_command(command)


@bashland.command()
def setup():
    """Run BashLand user and system setup"""
    bashland_setup.main()


@bashland.command()
def status():
    """Stats for this session and user"""
    # Get our user and session information from our context
    (ppid, start_time) = shell_utils.get_session_information()
    status_view = rest_client.get_status_view(ppid, start_time)
    if status_view:
        click.echo(build_status_view(status_view))


@bashland.command()
@click.pass_context
def help(ctx):
    """Show this message and exit"""
    click.echo(ctx.parent.get_help())

# Dynamic help text containing the BL_FILTER variable.
filtered_text = "BL_FILTER={0}".format(
    BL_FILTER) if BL_FILTER else "BL_FILTER \
is unset."

filter_help_text = """Check if a command is filtered from bashland. Filtering
is configured via a regex exported as BL_FILTER.
\n
{0}""".format(filtered_text)


@bashland.command(help=filter_help_text)
@click.argument('command', type=str)
@click.option('-r',
              '--regex',
              default=BL_FILTER,
              help='Regex to filter against')
def filter(command, regex):

    # Check if the regex we receive is valid
    if not bashland_globals.is_valid_regex(regex):
        click.secho("Regex {0} is invalid".format(regex), fg='red')
        return

    v = re.findall(regex, command)
    click.echo(filtered_text)
    if v and regex:
        matched = [str(s) for s in set(v)]
        output = click.style("{0} \nIs Filtered. Matched ".format(command),
                             fg='yellow') + click.style(
                                 str(matched), fg='red')
        click.echo(output)
    else:
        click.echo("{0} \nIs Unfiltered".format(command))


@bashland.command()
@click.argument('version', type=str, default='')
def update(version):
    """Update your BashLand installation"""

    if version != '':
        github = "https://github.com/rcaloras/bashland-client/archive/{0}.tar.gz".format(
            version)
        response = requests.get(github)
        if response.status_code != 200:
            click.echo("Invalid version number {0}".format(version))
            sys.exit(1)

    query_param = '?version={0}'.format(version) if version else ''
    url = 'https://bash.land/setup' + query_param
    response = requests.get(url, stream=True)
    filename = 'update-bashland.sh'
    with open(filename, 'wb') as out_file:
        shutil.copyfileobj(response.raw, out_file)

    shell_command = "bash -e {0} {1}".format(filename, version)
    subprocess.call(shell_command, shell=True)
    os.remove(filename)


@bashland.group()
def util():
    """Misc utils used by BashLand"""
    pass


@util.command()
def update_system_info():
    """Updates system info for BashLand"""
    result = bashland_setup.update_system_info()
    # Exit code based on if our update call was successful
    sys.exit(0) if result != None else sys.exit(1)


@util.command()
@click.argument('date_string', type=str)
def parsedate(date_string):
    """date string to seconds since the unix epoch"""
    try:
        date = dateutil.parser.parse(date_string)
        unix_time = int(mktime(date.timetuple()))
        click.echo(unix_time)
    except Exception as e:
        # Should really log an error here
        click.echo(0)


def unix_time_to_epoc_millis(unix_time):
    return int(unix_time) * 1000


def main():
    try:
        bashland()
    except Exception as e:
        formatted = traceback.format_exc(e)
        click.echo("Oops, looks like an exception occured: " + str(e))
        sys.exit(1)
