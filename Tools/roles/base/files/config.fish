#!/usr/bin/env fish

if status is-interactive
    set -gx EDITOR vim
    fish_add_path $HOME/.local/bin
    fish_add_path $HOME/go/bin
end
