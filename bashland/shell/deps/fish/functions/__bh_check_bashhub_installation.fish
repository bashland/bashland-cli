#
# __bl_check_bashland_installation.fish
# Should only be sourced once following installation.
#

# Small function to check our Bashland installation.
function __bl_check_bashland_installation
    set -l ret 0
    set -l config_path "$BL_HOME_DIRECTORY/config"
    if not [ -f "$config_path" ]
        echo "Missing Bashland config file. Please run 'bashland setup' to generate one."
        set ret 2
    else if not grep -Fq "access_token" "$config_path"
        echo "Missing Bashland access token. Please run 'bashland setup' to re-login."
        set ret 3
    else if not grep -Fq "system_name" "$config_path"
        echo "Missing system name. Please run 'bashland setup' to re-login."
        set ret 4
    else if grep -Fq "save_commands = False" "$config_path"
        echo "Bashland is currently disabled. Run 'bashland on' to re-enable."
        set ret 5
    end

    return $ret
end

__bl_check_bashland_installation
