local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()
local io = ImGui.GetIO()

local N = 20
local xs, ys, heat = table.create(N), table.create(N), table.create(N)
for i = 1, N do
    xs[i] = math.sin(i * 0.7) * 2
    ys[i] = math.cos(i * 1.3) * 2
    heat[i] = i
end
-- known histogram input: 4 bins over [0, 4): counts 1, 2, 3, 1 -> max 3
local hist = { 0.5, 1.5, 1.5, 2.5, 2.5, 2.5, 3.5 }
local hist_max, hist_max_sturges, hist_max_cum
local labels = { "a", "b", "c" }
local pie = { 0.2, 0.3, 0.5 }

-- each case: draw function, optional check run after the 10th plotted frame (nil -> must add vertices)
local cases = {
    { function() ImPlot.PlotPieChart(labels, pie, 3, 0.5, 0.5, 0.4) end },
    { function() ImPlot.PlotPieChart(labels, { 1, 2, 3 }, 3, 0.5, 0.5, 0.4, function(v, d) return d .. v end, "v=", 0,
        { Flags = ImPlot.ImPlotPieChartFlags.Exploding }) end },
    { function() ImPlot.PlotHeatmap("heat", heat, 4, 5) end },
    { function() ImPlot.PlotHeatmap("heat", heat, 4, 5, 0, 20, false, nil, nil, { Flags = ImPlot.ImPlotHeatmapFlags.ColMajor }) end },
    { function() hist_max = ImPlot.PlotHistogram("hist", hist, nil, 4, 1.0, ImPlot.ImPlotRange(0, 4)) end },
    { function() hist_max_sturges = ImPlot.PlotHistogram("hist", hist) end },
    { function() hist_max_cum = ImPlot.PlotHistogram("hist", hist, nil, 4, 1.0, ImPlot.ImPlotRange(0, 4),
        { Flags = ImPlot.ImPlotHistogramFlags.Cumulative + ImPlot.ImPlotHistogramFlags.Horizontal }) end },
    { function() ImPlot.PlotHistogram2D("h2d", xs, ys) end },
    { function() ImPlot.PlotHistogram2D("h2d", xs, ys, N, ImPlot.ImPlotBin.Scott, 5, ImPlot.ImPlotRect(-2, 2, -2, 2)) end },
    { function() ImPlot.PlotImage("img", ImGui.GetIO().Fonts.TexRef, ImPlot.ImPlotPoint(0, 0), ImPlot.ImPlotPoint(1, 1)) end },
    -- widgets outside the plot
    { function()
        ImPlot.ColormapScale("scale", 0, 20, ImVec2(80, 150))
        ImPlot.ColormapScale("scale2", 20, 0, ImVec2(0, 150), "%.0f", ImPlot.ImPlotColormapScaleFlags.Opposite)
        ImPlot.ColormapButton("btn")
        local t, _ = ImPlot.ColormapSlider("slider", 0.5, ImVec4(0, 0, 0, 0))
        assert(t == 0.5)
        ImPlot.ColormapIcon(0)
    end, true },
}

local ci, frame, base, done = 1, 0, 0, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(500, 400), G.ImGuiCond.Always)
    ImGui.Begin("Plots")
    local c = cases[ci]
    if c[2] and frame > 1 then c[1]() end
    if ImPlot.BeginPlot("Misc##" .. ci, ImVec2(-1, -1)) then
        if not c[2] and frame > 1 then c[1]() end
        ImPlot.EndPlot()
    end
    local dl = ImGui.GetWindowDrawList()
    ImGui.End()
    ImGui.Render()
    local n = dl.VtxBuffer.Size
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 1 then
        base = n
    elseif frame == 11 then
        assert(n > base + 16, "case " .. ci .. " adds vertices: " .. base .. " -> " .. n)
        assert(ImPlot.internal.GetCurrentPlot() == nil)
        ci += 1
        frame = 0
        if ci > #cases then
            done = true
            assert(hist_max == 3, "PlotHistogram max bin count: " .. tostring(hist_max))
            assert(hist_max_sturges == 3, "PlotHistogram Sturges max: " .. tostring(hist_max_sturges))
            assert(hist_max_cum == 7, "PlotHistogram cumulative max: " .. tostring(hist_max_cum))
            ImPlot.DestroyContext()
            print("OK")
        end
    end
end)
