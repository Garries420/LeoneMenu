# Leone Menu updates

GitHub Pages serves the files in `main` under `/docs`. In Settings → Pages,
choose **Deploy from a branch**, then **main** and **/docs**. The feed is
available at https://garries420.github.io/LeoneMenu/ after deployment.

## Update alliance skins

Edit `docs/alliance-skins.html` on `main`. Update the IDs and increment
`leone-skins-version`. Leone Menu checks for skin updates on startup, on
reload, hourly, and when a player clicks **Check for updates** on Home.

## Update the menu

Advance the version in the Lua and release metadata, run the build and
validation tools, and commit the generated `LeoneMenu.lua` and
`leone-update.json` together under `docs/`. A Lua-only update uses the
current runtime protocol. Changes to bundled libraries or assets require a
new runtime protocol and a full ZIP.

If you need to restore the previous script, close GTA and copy
`moonloader/config/Leone Menu/LeoneMenu.previous.lua` over `moonloader/LeoneMenu.lua`.
