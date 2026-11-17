#!/usr/bin/env fish

function __auto_venv --on-variable PWD
    status is-interactive; or return
    status is-command-substitution; and return

    if test -f ./.venv/bin/activate.fish
        if test "$VIRTUAL_ENV" != (pwd)/.venv
            type -q deactivate; and deactivate
            source ./.venv/bin/activate.fish
            set -g __auto_venv_active 1
        end
    else if set -q __auto_venv_active
        type -q deactivate; and deactivate
        set -e __auto_venv_active
    end
end

__auto_venv
