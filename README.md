# implot-luau

Immediate-mode 2D plotting for imgui-luau (Roblox / LÖVE).

Luau port of [ImPlot](https://github.com/epezent/implot) for [imgui-luau](https://git.bug.tools/bug/imgui-luau) ([GitHub](https://github.com/4DBug/imgui-luau)).
Mirrors: [git.bug.tools](https://git.bug.tools/bug/implot-luau) / [GitHub](https://github.com/4DBug/implot-luau).

**Status: work in progress.**

```lua
local G = require(ReplicatedStorage.ImGui)
local ImPlot = require(ReplicatedStorage.ImPlot)(G)
```

## Development

```sh
git clone --recursive https://git.bug.tools/bug/implot-luau.git
bash tools/test.sh   # tests/t_*.luau in the core's Roblox mock
```

Upstream source (pinned) is in `tools/upstream/`; port-specific comments are tagged `[Port]`.

## License

MIT, see LICENSE (upstream copyright kept).
