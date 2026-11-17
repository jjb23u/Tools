#!/usr/bin/env fish

function work --description 'Clone into or jump to a workspace project by repo name'
    set -l ws "$HOME/workspace"
    if test (count $argv) -eq 0
        cd "$ws"
        return
    end
    set -l arg $argv[1]
    if string match -qr '://|@' -- "$arg"
        set -l name (basename "$arg" .git)
        test -d "$ws/$name"; or git clone "$arg" "$ws/$name"
        cd "$ws/$name"
    else
        cd "$ws/$arg"
    end
end
