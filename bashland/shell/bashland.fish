#
# bashland.fish
# Main file that is sourced onto our path for fish.
#

#
# Checks if an element is present in an array.
#
# @param The element to check if present
# @param the array to check in
# @return 0 if present 1 otherwise
#
function contains_element --argument-names element array
    for e in $array
        [ "$e" = "$element" ] && return 0
    end

    return 1
end

function __bl_path_add --argument-names item
    if [ -d "$item" ] && not contains_element "$item" "$PATH"
        set -x PATH "$item" "$PATH"
    end
end

function __bl_interactive
  fish -c "bl -i"
end

# Avoid duplicate inclusion
if [ "$__bl_imported" = "defined" ]
    __bl_path_add "$HOME/.bashland/bin"
else
    set -Ux __bl_imported "defined"
    set -Ux BL_HOME_DIRECTORY "$HOME/.bashland/"

    source "$BL_HOME_DIRECTORY/deps/fish/functions/__bl_check_bashland_installation.fish"
    bind \cb __bl_interactive
end

function __bl_preexec --on-event fish_preexec
    set -g __BL_PWD "$PWD"
    set -g __BL_SAVE_COMMAND "$argv[1]"
end

function __bl_precmd --on-event fish_prompt
    set -x __BL_EXIT_STATUS $status

    if [ -e "$BL_HOME_DIRECTORY/response.bl" ]
        set -l cmd (head -n 1 "$BL_HOME_DIRECTORY/response.bl")
        rm "$BL_HOME_DIRECTORY/response.bl"
        echo $cmd
    end

    if [ -n "$BL_HOME_DIRECTORY" ]
        set -g bashland_dir "$BL_HOME_DIRECTORY"
    else
        set -g bashland_dir "~/.bashland"
    end

    set -x working_directory "$__BL_PWD"
    set -x cmd "$__BL_SAVE_COMMAND"
    set -x process_id $fish_pid

    if [ -n "$__BL_SAVE_COMMAND" ]
        set -e __BL_SAVE_COMMAND
    else
        return 0
    end

    if [ -e "$bashland_dir" ]
        fish -c '__bl_process_command "$cmd" "$working_directory" "$process_id" &' >> "$bashland_dir"/log.txt 2>&1
    end
end

#
# Send our command to the server if everything
# looks good.
#
function __bl_process_command --argument-names cmd dir pid
    set -x bl_command (string trim $cmd)

    # sanity check
    if [ -z "$bl_command" ]
        return 0
    end

    # ensure that bashland is installed
    if not type "bashland" > /dev/null 2>&1
        return 0
    end

    set -x working_directory "$dir"
    set -x process_id "$pid"

    # This is non-standard across systems. As GNU and BSD Date convert epochs
    # differently, use python for cross-system compatibility.
    set -l process_start_stamp (env LC_ALL=C ps -p $fish_pid -o lstart=)

    set -x process_start (bashland util parsedate "$process_start_stamp")
    set -x exit_status "$__BL_EXIT_STATUS"

    fish -c 'bashland save "$bl_command" "$working_directory" "$process_id" "$process_start" "$exit_status" &'
end
