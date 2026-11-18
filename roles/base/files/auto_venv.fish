#!/usr/bin/env fish

function __auto_venv --on-variable PWD
    status is-interactive; or return
    status is-command-substitution; and return

    set -l dir $PWD
    while not test -f $dir/.venv/bin/activate.fish
        if test "$dir" = /
            set dir ""
            break
        end
        set dir (path dirname $dir)
    end

    if test -n "$dir"
        if test "$VIRTUAL_ENV" != $dir/.venv
            type -q deactivate; and deactivate
            source $dir/.venv/bin/activate.fish
            set -g __auto_venv_active 1
        end
    else if set -q __auto_venv_active
        type -q deactivate; and deactivate
        set -e __auto_venv_active
    end
end

__auto_venv
