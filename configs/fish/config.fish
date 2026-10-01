zoxide init fish | source

abbr -a ff fastfetch

function fish_greeting
    ~/.config/fish/torii-greeting.sh
end

# Added by Antigravity CLI installer
set -gx PATH "/home/eternal_whisker/.local/bin" $PATH

# Start ssh-agent if one isn't running
if not pgrep -u "$USER" ssh-agent >/dev/null
    eval (ssh-agent -c) >/dev/null
end

# Load the environment from the running agent
set -l agent_socket (find "$HOME/.ssh/agent" -type s 2>/dev/null | head -n1)

if test -n "$agent_socket"
    set -gx SSH_AUTH_SOCK "$agent_socket"
end

function obs
    ssh-add -l >/dev/null 2>&1; or ssh-add ~/.ssh/id_ed25519; or return

    cd "$HOME/development/IITM/IIT-M"; or return

    # Launch through Hyprland so Obsidian outlives this terminal (ghostty kills
    # everything in a surface's cgroup scope on close, setsid included), and hand
    # it the agent socket so the vault's git sync can use the unlocked key.
    if set -q HYPRLAND_INSTANCE_SIGNATURE
        hyprctl eval "hl.dispatch(hl.dsp.exec_cmd(\"cd '$PWD' && SSH_AUTH_SOCK='$SSH_AUTH_SOCK' obsidian .\"))" >/dev/null
    else
        setsid -f obsidian . >/dev/null 2>&1
    end
end
