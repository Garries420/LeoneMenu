# Leone Menu updates

GitHub Pages serves the files in `main` under `/docs`. In Settings → Pages,
choose **Deploy from a branch**, then **main** and **/docs**. The feed is
available at https://garries420.github.io/LeoneMenu/ after deployment.

## Update alliance skins

Edit the IDs in `github-ready/alliance-skins.html` and run
`python tools/publish_skins.py`. It stamps the HTML with the current Swedish
date and time, creates a dated HTML file, and updates `skins/latest.json`.
Publish the generated `alliance-skins.html` and `skins/` files under `docs/`.
The menu checks this feed on startup, on reload, hourly, and from Home.

## Update the menu

1. Advance the menu version in `release.json`, `src/main.lua`, and `src/core/Updates.lua`.
2. Run `python tools/build.py --rar` with WinRAR installed to generate the full archive and update feed.
3. Create a GitHub release at the matching `v` tag and upload the complete `Leone Menu V<version>.rar` as its install asset.
4. After the release is visible, publish the generated `LeoneMenu.lua` and `leone-update-v2.json` together under `docs/`.

The in-game updater downloads only the Lua and installs it for the next GTA
launch. Checks wait until the startup overlay finishes. The running Lua and
renderer remain loaded until the player closes GTA. The generated Lua
checks the packaged library and resource files before normal startup. If the
player needs the full package, it opens the required update dialog once for
that package. The independent alliance HTML is excluded from the package
check. Keep `runtime` at 5 while the bundled files are unchanged. New builds
verify the files directly. The retired `leone-update.json` feed must remain
absent; versions predating the restart-safe updater require a manual install.

To restore the previous script, close GTA and copy
`moonloader/config/Leone Menu/LeoneMenu.previous.lua` over `moonloader/LeoneMenu.lua`.
