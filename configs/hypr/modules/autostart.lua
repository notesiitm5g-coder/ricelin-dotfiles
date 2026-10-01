hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/boot-monitors.sh")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/cliphist-watch.sh")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper.sh init")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/watchdog.sh pill")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/watchdog.sh lock")
    hl.exec_cmd("systemctl --user restart hypridle")
    -- warm the page cache so a user's first fastfetch run doesn't stall on cold pacman db reads
    hl.exec_cmd("fastfetch")
    hl.exec_cmd("hyprexpose --allow-mouse")
    -- Obsidian via fish's `obs`: a terminal asks for the SSH passphrase so the vault's
    -- git sync works, then opens the vault and closes (stays open if obs fails)
    hl.exec_cmd("ghostty --title=obsidian-sync -e fish -c 'obs; or read -P \"obs failed, press Enter \"'")
    -- Apple Music PWA, routed into the Music space (Super+A) and kept folded at login
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/start-hidden.sh music FFPWA-01KZKD9X83WGJHWE77TKGQK2WF firefoxpwa site launch 01KZKD9X83WGJHWE77TKGQK2WF")
end)
