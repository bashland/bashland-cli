_bashland_completion() {
    COMPREPLY=( $( env COMP_WORDS="${COMP_WORDS[*]}" \
                   COMP_CWORD=$COMP_CWORD \
                   _BASHLAND_COMPLETE=complete $1 ) )
    return 0
}

complete -F _bashland_completion -o default bashland;
