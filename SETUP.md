# Leone Menu release feed

The repository is private. The tester ZIP contains the installed MoonLoader
files and a short readme. The `leone-updates` branch holds only the three updater
files and `.nojekyll`.

For automatic downloads, enable GitHub Pages under Settings > Pages. Choose
Deploy from a branch, select `leone-updates`, and select `/(root)`. This makes the
files in that branch publicly readable and keeps the repository private.
GitHub Pages on a private personal repository requires GitHub Pro.
The feed address is https://garries420.github.io/LeoneMenu/.

For a skin-list update, edit only `alliance-skins.html` on `leone-updates`. Change
the IDs and increment `leone-skins-version`. Installed menus check on startup,
on reload, manually from Home, and hourly. A menu release is unnecessary.

For a menu update, advance the Lua and package versions and run the build and
validation tools. Commit the generated `LeoneMenu.lua` and `leone-update.json`
together on `leone-updates`. Runtime protocol 5 allows a Lua-only update. A
change to bundled libraries or assets requires a new protocol and a full ZIP.

On failure the updater retains the installed menu or saved skin list. For a
manual menu rollback, close GTA and copy
`moonloader/config/Leone Menu/LeoneMenu.previous.lua` over `moonloader/LeoneMenu.lua`.
