# implot-luau

Immediate-mode 2D plotting for imgui-luau (Roblox / LÖVE).

Luau port of [ImPlot](https://github.com/epezent/implot) for [imgui-luau](https://git.bug.tools/bug/imgui-luau) ([GitHub](https://github.com/4DBug/imgui-luau)).
Mirrors: [git.bug.tools](https://git.bug.tools/bug/implot-luau) / [GitHub](https://github.com/4DBug/implot-luau).

**Status:** near-complete port of ImPlot (all plot types, axes/scales, subplots, legends, drag tools, styles/colormaps) and the full ImPlot demo (`ImPlotDemo.lua`).

## Usage

```lua
local G = require(ReplicatedStorage.ImGui)
local ImPlot = require(ReplicatedStorage.ImPlot)(G)
require(ReplicatedStorage.ImPlotDemo)(G, ImPlot) -- optional, adds ImPlot.ShowDemoWindow
local ImGui = G.ImGui

ImGui.CreateContext()
ImPlot.CreateContext()

-- each frame, between ImGui.NewFrame() and ImGui.Render():
ImGui.Begin("My Window")
if ImPlot.BeginPlot("My Plot") then
	ImPlot.PlotLine("sin", Xs, Ys)          -- or PlotLine(label, Values[, Count, XScale, X0])
	ImPlot.EndPlot()
end
ImGui.End()
ImPlot.ShowDemoWindow(true)
```

Full LocalScript: `examples/roblox/main.client.luau` (live scrolling sine wave + demo windows).

## API differences from C++

- **Pointer args become return values.** Values are passed in and the new values returned, e.g.
  `x, y, modified, clicked, hovered, held = ImPlot.DragPoint(id, x, y, col, radius, flags)`,
  `value, modified, clicked, hovered, held = ImPlot.DragLineX(id, value, ...)`,
  `p_open = ImPlot.ShowDemoWindow(p_open)` (same for `ShowMetricsWindow`).
- **Overloads are dispatched at runtime** on argument types: `PlotLine(label, xs, ys[, count, spec])` vs
  `PlotLine(label, values[, count, xscale, x0, spec])`; getter variants keep the `G` suffix (`PlotLineG(label, fn, data, count, spec)`, `fn(idx, data) -> x, y`).
- **Arrays are 1-based Luau tables.** `Count` defaults to the table length. `Offset` and `Stride` (set via spec) are
  counted in **elements**, not bytes; `Offset` is 0-based like C++ (ring-buffer index).
- **Specs** may be `nil`, a plain table (`{ LineColor = ..., Offset = ... }`) or an `ImPlotSpec`.
- **`SetNextLineStyle` / `SetNextFillStyle` / `SetNextMarkerStyle` / `SetNextErrorBarStyle`** (obsolete upstream) are
  kept for compatibility and applied on top of the spec of the next plot item.
- Enums are tables (`ImPlot.ImAxis.X1`, `G.ImGuiCond.Always`, ...).
- Port-specific deviations are tagged `[Port]` in the source.

## TODO

- Upstream TODOs carried over as-is (e.g. per-style `AxisBg*`/`AxisTick` colors, half-locked axis ranges, tick-count heuristics).
- No LÖVE example yet (only `examples/roblox`).
- Performance tuning for very large datasets.

## Development

```sh
git clone --recursive https://git.bug.tools/bug/implot-luau.git
bash tools/test.sh   # tests/t_*.luau in the core's Roblox mock
```

Upstream source (pinned) is in `tools/upstream/`; port-specific comments are tagged `[Port]`.

## License

MIT, see LICENSE (upstream copyright kept).
