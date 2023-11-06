#
# bashland.zsh
# Main file that is sourced onto our path for Zsh.
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

    # check that we're using zsh and that all our
    # dependencies are satisfied.
    if [[ -n $ZSH_VERSION ]] && [[ -f $BL_DEPS_DIRECTORY/lib-bashland.sh ]]; then

        # Pull in our library.
        source $BL_DEPS_DIRECTORY/lib-bashland.sh

        # Hook bashland into preexec and precmd.
        __bl_hook_bashland

        # Install our tab completion.
        autoload compinit && compinit
        autoload bashcompinit && bashcompinit
        source $BL_DEPS_DIRECTORY/bashland_completion_handler.sh

        # Turn on Bash style comments. Otherwise zsh tries to execute #some-comment.
        setopt interactivecomments

    fi
}

__bl_hook_bashland() {

    # Bind ctrl + b to bh -i
    bindkey -s '^b' "bh -i\n"

    # Hook into preexec and precmd functions if they're not already
    # present there.
    if ! contains_element __bl_preexec $preexec_functions; then
        preexec_functions+=(__bl_preexec)
    fi

    if ! contains_element __bl_precmd  $precmd_functions; then
        precmd_functions+=(__bl_zsh_precmd)
        precmd_functions+=(__bl_precmd)
    fi
}

__bl_zsh_precmd() {
    if [[ -e $BL_HOME_DIRECTORY/response.bh ]]; then
        local COMMAND="`head -n 1 $BL_HOME_DIRECTORY/response.bh`"
        rm $BL_HOME_DIRECTORY/response.bh
        print -z $COMMAND
    fi;
}

__bl_setup_bashland
