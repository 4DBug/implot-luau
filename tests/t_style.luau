local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)

-- context create/destroy
assert(ImPlot.GetCurrentContext() == nil)
local ctx = ImPlot.CreateContext()
assert(ImPlot.GetCurrentContext() == ctx)

-- enums
assert(ImPlot.ImPlotFlags.CanvasOnly == 55)
assert(ImPlot.ImPlotAxisFlags.Lock == 49152)
assert(ImPlot.ImPlotMarker.None == -2 and ImPlot.ImPlotMarker.COUNT == 12)
assert(ImPlot.ImPlotLocation.SouthEast == 10)

-- push/pop style var
local style = ImPlot.GetStyle()
assert(style.PlotBorderSize == 1 and style.PlotPadding.x == 10)
ImPlot.PushStyleVar(ImPlot.ImPlotStyleVar.PlotBorderSize, 3)
ImPlot.PushStyleVar(ImPlot.ImPlotStyleVar.PlotPadding, G.ImVec2(1, 2))
assert(style.PlotBorderSize == 3 and style.PlotPadding.y == 2)
ImPlot.PopStyleVar(2)
assert(style.PlotBorderSize == 1 and style.PlotPadding.x == 10 and style.PlotPadding.y == 10)

-- push/pop style color
ImPlot.PushStyleColor(ImPlot.ImPlotCol.Selection, G.IM_COL32(255, 0, 0, 255))
assert(ImPlot.GetStyleColorU32(ImPlot.ImPlotCol.Selection) == G.IM_COL32(255, 0, 0, 255))
ImPlot.PopStyleColor()
assert(ImPlot.GetStyleColorU32(ImPlot.ImPlotCol.Selection) == G.IM_COL32(255, 255, 0, 255))
ImPlot.StyleColorsDark(); ImPlot.StyleColorsLight(); ImPlot.StyleColorsClassic(); ImPlot.StyleColorsAuto()

-- colormaps
assert(ImPlot.GetColormapCount() == 16)
assert(ImPlot.GetColormapName(ImPlot.ImPlotColormap.Viridis) == "Viridis")
assert(ImPlot.GetColormapIndex("Greys") == 15 and ImPlot.GetColormapIndex("nope") == -1)
assert(ImPlot.GetColormapSize() == 10)
assert(ImPlot.GetColormapColorU32(0) == G.IM_COL32(76, 114, 176, 255))
assert(ImPlot.GetColormapColorU32(11) == G.IM_COL32(221, 132, 82, 255)) -- wraps
local c = ImPlot.GetColormapColor(1, ImPlot.ImPlotColormap.Dark)
assert(math.abs(c.x - 55/255) < 1e-6 and math.abs(c.z - 184/255) < 1e-6 and c.w == 1)
ImPlot.PushColormap("Jet")
assert(ImPlot.GetColormapSize() == 11)
assert(ImPlot.SampleColormapU32(0) == G.IM_COL32(0, 0, 170, 255))
assert(ImPlot.SampleColormapU32(1) == G.IM_COL32(255, 0, 0, 255))
ImPlot.PopColormap()
assert(ImPlot.GetStyle().Colormap == ImPlot.ImPlotColormap.Deep)
-- Greys midpoint: idx = (int)(255*0.5+0.5) = 128 -> ImMixU32(white, black, 128) = (255*128)>>8 = 127 per channel
assert(ImPlot.SampleColormapU32(0.5, ImPlot.ImPlotColormap.Greys) == G.IM_COL32(127, 127, 127, 255))

ImPlot.DestroyContext()
assert(ImPlot.GetCurrentContext() == nil)
print("OK")
