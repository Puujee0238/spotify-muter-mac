# Spotify Ad Muter (macOS)

A small macOS LaunchAgent + AppleScript that watches Spotify and mutes Spotify audio when the currently playing item appears to be an advertisement. When a normal track resumes, it restores the previous Spotify volume.

> Disclaimer / Terms: Muting or bypassing ads may violate Spotify’s Terms of Service. This project is provided for educational purposes. Use at your own risk.

## How it works

- A **watcher** (`spotify-ad-muter-watcher.sh`) runs in the background (via `launchd`).
- The watcher checks whether the Spotify process is running.
- When Spotify is running, it starts an **AppleScript muter** (`spotify_ad_muter.applescript`) using `osascript`.
- The AppleScript polls Spotify playback state and attempts to classify the current item as a **track** or an **ad**:

  - Best-effort check: track `id` contains `spotify:ad`
  - Fallback heuristics: track name is `Advertisement` or artist is `Spotify`
- On ad detection: sets Spotify `sound volume` to `0`.
- On track detection: restores Spotify volume to the value it had before the ad.

## Requirements

- macOS (tested conceptually on modern macOS; should work on Ventura/Sonoma/Sequoia)
- Spotify desktop app
- Permission for automation (macOS will prompt)

## Repo layout (suggested)

```

.

├── install_spotify_ad_muter.sh

├── README.md

└── (installed locally by script)

    ~/bin/spotify_ad_muter.applescript

    ~/bin/spotify-ad-muter-watcher.sh

    ~/Library/LaunchAgents/com.github.puujee0238.spotifyadmuter.watcher.plist

```

## Install

Clone the repo and run the installer:

```bash

chmod +x install_spotify_ad_muter.sh

./install_spotify_ad_muter.sh install

```

This will:

- create `~/bin` scripts
- create a LaunchAgent plist in `~/Library/LaunchAgents`
- load/start the LaunchAgent

### Uninstall

```bash

./install_spotify_ad_muter.sh uninstall

```

## Usage

After installation, the watcher runs automatically in the background:

- Spotify closed → muter is not running
- Spotify opened → muter starts within ~2 seconds
- If the muter is killed while Spotify is running → watcher restarts it within ~2 seconds
- If the watcher is killed → `launchd` restarts it (KeepAlive)

## Verifying it’s running

Check LaunchAgent status:

```bash

launchctl print gui/$(id -u)/com.github.puujee0238.spotifyadmuter.watcher | head

```

Check processes:

```bash

pgrep -fl "spotify-ad-muter-watcher|osascript.*spotify_ad_muter"

```

Logs (if enabled by the plist):

```bash

tail -n 50 /tmp/spotifyadmuter-watcher.out

tail -n 50 /tmp/spotifyadmuter-watcher.err

```

## macOS permissions (important)

The first time it tries to control Spotify, macOS may block it.

Check:

- **System Settings → Privacy & Security → Automation**

  - Allow your terminal app (Terminal / iTerm / etc.) or `osascript` to control **Spotify**
- If prompted, also check:

  - **System Settings → Privacy & Security → Accessibility**

If muting doesn’t work but the processes are running, it’s usually an Automation permission issue.

## Configuration

### Polling intervals

- Watcher checks Spotify every **2 seconds**
- AppleScript checks playback every **1 second**

You can change these in:

- `spotify-ad-muter-watcher.sh` (`sleep 2`)
- `spotify_ad_muter.applescript` (`delay 1`)

### Ad detection rules

Ad detection varies by region and Spotify changes. Current checks:

- `id` contains `spotify:ad` (best when available)
- `name` equals `Advertisement` (fallback)
- `artist` equals `Spotify` (fallback)

You can edit the `isAdTrack(t)` handler in `spotify_ad_muter.applescript`.

## Troubleshooting

### Nothing happens when ads play

1. Confirm Spotify is running:

   ```bash

   pgrep -x Spotify

   ```
2. Confirm the muter script is running:

   ```bash

   pgrep -fl "osascript.*spotify_ad_muter.applescript"

   ```
3. Check logs:

   ```bash

   tail -n 200 /tmp/spotifyadmuter-watcher.err

   ```
4. Re-check **Automation** permissions (most common issue).

### LaunchAgent not loading

Try reloading:

```bash

launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.github.puujee0238.spotifyadmuter.watcher.plist

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.github.puujee0238.spotifyadmuter.watcher.plist

launchctl kickstart -k gui/$(id -u)/com.github.puujee0238.spotifyadmuter.watcher

```

### I edited scripts but changes don’t apply

Restart the agent:

```bash

launchctl kickstart -k gui/$(id -u)/com.github.puujee0238.spotifyadmuter.watcher

```

## Security / Privacy notes

This project uses Apple Events automation to read Spotify playback metadata and set Spotify’s volume. It does not capture system audio. It does not transmit data over the network.

## License

Choose a license for your repo (examples: MIT, Apache-2.0). Add a `LICENSE` file accordingly.

## Contributing

Issues and pull requests are welcome—especially improvements to ad detection robustness and macOS compatibility.
