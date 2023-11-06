#
# lib-bashland.sh
# This file should contain the common bashland
# shell functions between bash and zsh
#

__bl_path_add() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="${PATH:+"$PATH:"}$1"
    fi
}

#
# Checks if an element is present in an array.
#
# @param The element to check if present
# @param the array to check in
# @return 0 if present 1 otherwise
#
contains_element() {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# Make sure our bin directory is on our path
__bl_path_add "$HOME/.bashland/bin"

#
# Function to be run by our preexec hook.
#
# Saves the directory this command is being executed in to track (cd-ing), and
# sets a variable so we know that a command was just executed and should be
# saved.
#
# GLOBALS:
#   __BL_PWD The directory this command is being executed in
#   __BL_SAVE_COMMAND The command that is being executed and to be saved.
#
# Arguments:
#  $1 The command just entered, about to be executed.
#
__bl_preexec() {
    __BL_PWD="$PWD"
    __BL_SAVE_COMMAND="$1"
}

__bl_precmd() {

    # Set this initially to properly catch the exit status.
    __BL_EXIT_STATUS="$?"

    local bashland_dir
    bashland_dir=${BL_HOME_DIRECTORY:=~/.bashland}

    local command="$__BL_SAVE_COMMAND"

    # Check if we need to process a command. If so, unset it as it will be
    # processed and saved.
    if [[ -n "$__BL_SAVE_COMMAND" ]]; then
        unset __BL_SAVE_COMMAND
    else
        return 0
    fi

    if [[ -e "$bashland_dir" ]]; then
        (__bl_process_command "$command"&) >> "$bashland_dir"/log.txt 2>&1
    fi;
}

#
# Send our command to the server if everything
# looks good.
#
# @param A trimmed command from the command line
#
__bl_process_command() {

    local bl_command
    bl_command=$(__bl_trim_whitespace "$1")

    # Sanity empty check
    if [[ -z "$bl_command" ]]; then
        return 0;
    fi;

    # Check to make sure bashland is still installed. Otherwise, this will
    # simply fail and spam the user that files dont exist.
    if ! type "bashland" &> /dev/null; then
        return 0;
    fi;

    local process_id=$$

    # This is non-standard across systems. GNU Date and BSD Date
    # both convert to epoch differently. Using python for cross system
    # compatibility.
    local process_start_stamp
    process_start_stamp=$(LC_ALL=C ps -p $$ -o lstart=)

    local process_start=$(bashland util parsedate "$process_start_stamp")
    local working_directory="$__BL_PWD"
    local exit_status="$__BL_EXIT_STATUS"

    (bashland save "$bl_command" "$working_directory" \
    "$process_id" "$process_start" "$exit_status"&)
}

# Small function to check our bashland installation.
# It's added to our precmd functions. On its initial run
# it removes itself from the precmd function array.
# This means it runs exactly once.
__bl_check_bashland_installation() {
    local ret
    ret=0
    if [[ -n "$BASH_VERSION" && -n "$__bp_enable_subshells" && "$(trap)" != *"__bp_preexec_invoke_exec"* ]]; then
        echo "bashland's preexec hook is being overriden and is not saving commands. Please resolve what may be holding the DEBUG trap."
        ret=1
    elif [[ ! -f "$BL_HOME_DIRECTORY/config" ]]; then
        echo "Missing bashland config file. Please run 'bashland setup' to generate one."
        ret=2
    elif ! grep -Fq "access_token" "$BL_HOME_DIRECTORY/config"; then
        echo "Missing bashland access token. Please run 'bashland setup' to re-login."
        ret=3
    elif ! grep -Fq "system_name" "$BL_HOME_DIRECTORY/config"; then
        echo "Missing system name. Please run 'bashland setup' to re-login."
        ret=4
    elif grep -Fq "save_commands = False" "$BL_HOME_DIRECTORY/config"; then
        echo "bashland is currently disabled. Run 'bashland on' to re-enable."
        ret=5
    fi;

    # Remove from precmd_functions so it only runs once when the session starts.
    local delete
    delete=(__bl_check_bashland_installation)
    precmd_functions=( "${precmd_functions[@]/$delete}" )

    return $ret
}

# Allows bashland to manipulate session state by
# manipulating variables when invoked by precmd.
__bl_precmd_run_script() {
    if [[ -e $BL_HOME_DIRECTORY/script.bl ]]; then
        local command
        command=$(head -n 1 "$BL_HOME_DIRECTORY/script.bl")
        rm "$BL_HOME_DIRECTORY/script.bl"
        eval "$command"
     fi;
}

# Check our bashland installation when the session starts.
precmd_functions+=(__bl_check_bashland_installation)
precmd_functions+=(__bl_precmd_run_script)

__bl_trim_whitespace() {
    local var=$@
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}
