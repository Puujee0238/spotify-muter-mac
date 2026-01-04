#!/bin/zsh
set -euo pipefail

LABEL="com.github.puujee0238.spotifyadmuter.watcher"
BIN_DIR="$HOME/bin"
AS_FILE="$BIN_DIR/spotify_ad_muter.applescript"
WATCHER="$BIN_DIR/spotify-ad-muter-watcher.sh"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

UID_NUM="$(id -u)"
DOMAIN="gui/${UID_NUM}"

install_files() {
  mkdir -p "$BIN_DIR"
  mkdir -p "$HOME/Library/LaunchAgents"

  # 1) AppleScript muter
  cat > "$AS_FILE" <<'APPLESCRIPT'
-- spotify_ad_muter.applescript
-- Polls Spotify once per second.
-- If current item looks like an ad, set Spotify sound volume to 0.
-- When music resumes, restore the previous Spotify volume.

property savedVolume : missing value
property mutedForAd : false

on spotifyIsRunning()
	tell application "System Events"
		return (name of processes) contains "Spotify"
	end tell
end spotifyIsRunning

on isAdTrack(t)
	-- Best effort: ads often have an id like "spotify:ad:...."
	try
		set trackId to (id of t) as text
		if trackId contains "spotify:ad" then return true
	end try

	-- Fallback heuristics (can vary)
	try
		set n to (name of t) as text
		set a to (artist of t) as text
		if n is "Advertisement" then return true
		if a is "Spotify" then return true
	end try

	return false
end isAdTrack

on run
	repeat
		if my spotifyIsRunning() then
			try
				tell application "Spotify"
					if player state is playing then
						set t to current track
						set adNow to my isAdTrack(t)

						if adNow then
							if mutedForAd is false then
								set savedVolume to sound volume
								set sound volume to 0
								set mutedForAd to true
							end if
						else
							if mutedForAd is true then
								if savedVolume is not missing value then
									set sound volume to savedVolume
								end if
								set mutedForAd to false
							end if
						end if
					else
						if mutedForAd is true then
							if savedVolume is not missing value then
								set sound volume to savedVolume
							end if
							set mutedForAd to false
						end if
					end if
				end tell
			end try
		end if

		delay 1
	end repeat
end run
APPLESCRIPT

  # 2) Watcher (starts muter only when Spotify is running; restarts if killed)
  cat > "$WATCHER" <<'SH'
#!/bin/zsh
set -u

MUTER="$HOME/bin/spotify_ad_muter.applescript"
muter_pid=""

while true; do
  if /usr/bin/pgrep -x "Spotify" >/dev/null 2>&1; then
    # Ensure muter is running while Spotify is running
    if [[ -z "$muter_pid" ]] || ! /bin/kill -0 "$muter_pid" >/dev/null 2>&1; then
      /usr/bin/osascript "$MUTER" &
      muter_pid=$!
    fi
  else
    # Stop muter when Spotify is not running
    if [[ -n "$muter_pid" ]] && /bin/kill -0 "$muter_pid" >/dev/null 2>&1; then
      /bin/kill "$muter_pid" >/dev/null 2>&1
    fi
    muter_pid=""
  fi

  sleep 2
done
SH

  chmod +x "$WATCHER"

  # 3) LaunchAgent plist
  cat > "$PLIST" <<PLISTXML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>${WATCHER}</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/tmp/spotifyadmuter-watcher.out</string>

  <key>StandardErrorPath</key>
  <string>/tmp/spotifyadmuter-watcher.err</string>
</dict>
</plist>
PLISTXML
}

load_agent() {
  # Unload if already loaded (ignore errors)
  /bin/launchctl bootout "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true

  /bin/launchctl bootstrap "$DOMAIN" "$PLIST"
  /bin/launchctl enable "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
  /bin/launchctl kickstart -k "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
}

uninstall_all() {
  /bin/launchctl bootout "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true
  rm -f "$PLIST" "$WATCHER" "$AS_FILE"
  echo "Uninstalled: $LABEL"
}
is_service_running() {
  launchctl print gui/$(id -u)/com.github.puujee0238.spotifyadmuter.watcher | head
}

case "${1:-install}" in
  install)
    install_files
    load_agent
    echo "Installed and started: $LABEL"
    echo ""
    echo "Logs (if needed):"
    echo "  tail -n 50 /tmp/spotifyadmuter-watcher.out"
    echo "  tail -n 50 /tmp/spotifyadmuter-watcher.err"
    echo ""
    echo "Important: macOS may prompt for permissions."
    echo "System Settings -> Privacy & Security -> Automation: allow your terminal/osascript to control Spotify."
    ;;
  uninstall)
    uninstall_all
    ;;
  check)
    if is_service_running >/dev/null 2>&1; then
      echo "Service is running:"
      is_service_running
    else
      echo "Service is not running."
    fi
    ;;
  *)
    echo "Usage: $0 [install|uninstall]"
    exit 2
    ;;
esac