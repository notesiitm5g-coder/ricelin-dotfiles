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

    obsidian . >/dev/null 2>&1 &
end
