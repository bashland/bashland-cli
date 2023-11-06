#
# bashland.sh
# Main file that is sourced onto our path for Bash.
#

# Avoid duplicate inclusion
if [[ "$__bl_imported" == "defined" ]]; then
    __bl_path_add "$HOME/.bashland/bin"
    return 0
fi

__bl_imported="defined"

export BL_HOME_DIRECTORY="$HOME/.bashland/"

BL_DEPS_DIRECTORY=${BL_DEPS_DIRECTORY:=$BL_HOME_DIRECTORY/deps}

__bl_setup_bashland() {

    # check that we're using bash and that all our
    # dependencies are satisfied.
    if [[ -n $BASH_VERSION ]] && \
       [[ -f $BL_DEPS_DIRECTORY/lib-bashland.sh ]] && \
       [[ -f $BL_DEPS_DIRECTORY/bash-preexec.sh ]]; then

        # Pull in our libs
        source "$BL_DEPS_DIRECTORY/lib-bashland.sh"
        source "$BL_DEPS_DIRECTORY/bash-preexec.sh"

        # Hook bashland into preexec and precmd.
        __bl_hook_bashland

        # Install our tab completion
        source "$BL_DEPS_DIRECTORY/bashland_completion_handler.sh"
    fi
}

__bl_hook_bashland() {

    if [ -t 1 ]; then
        # Alias to bind Ctrl + B
        bind '"\C-b":"\C-ubl -i\n"'
    fi

    # Hook into preexec and precmd functions
    if ! contains_element __bl_preexec "${preexec_functions[@]}"; then
        preexec_functions+=(__bl_preexec)
    fi

    if ! contains_element __bl_precmd "${precmd_functions[@]}"; then
        # Order seems to matter here due to the fork at the end of __bl_precmd
        precmd_functions+=(__bl_bash_precmd)
        precmd_functions+=(__bl_precmd)
    fi
}

__bl_bash_precmd() {
    if [[ -e $BL_HOME_DIRECTORY/response.bl ]]; then
        local command=$(head -n 1 "$BL_HOME_DIRECTORY/response.bl")
        rm "$BL_HOME_DIRECTORY/response.bl"
        history -s "$command"
        # Save that we're executing this command again by calling bashland's
        # preexec and precmd functions
        __bl_preexec "$command"
        echo "$command"
        eval "$command"
        __bl_precmd
     fi;
}

__bl_setup_bashland
