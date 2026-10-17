local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()
local io = ImGui.GetIO()

local N = 20
local xs, ys, err, err2, bits, szs = table.create(N), table.create(N), table.create(N), table.create(N), table.create(N), table.create(N)
for i = 1, N do
    xs[i] = i - 1
    ys[i] = math.sin(i * 0.3) * 3 + 4
    err[i] = 0.5
    err2[i] = 0.25
    bits[i] = (i // 3) % 2
    szs[i] = 0.3
end

-- each case: draw function, optional check run after the 10th plotted frame (nil -> must add vertices)
local cases = {
    { function() ImPlot.PlotErrorBars("err", xs, ys, err, N) end },
    { function() ImPlot.PlotErrorBars("err", xs, ys, err, err2, N, { Flags = ImPlot.ImPlotErrorBarsFlags.Horizontal }) end },
    { function() ImPlot.PlotStems("stems", ys) end },
    { function() ImPlot.PlotStems("stems", xs, ys, N, 1, { Flags = ImPlot.ImPlotStemsFlags.Horizontal }) end },
    { function() ImPlot.PlotInfLines("inf", { 1, 3, 5 }) end },
    { function() ImPlot.PlotInfLines("inf", { 1, 3, 5 }, { Flags = ImPlot.ImPlotInfLinesFlags.Horizontal }) end },
    { function() ImPlot.PlotText("hello", 0.5, 0.5) end },
    { function() ImPlot.PlotText("hello", 0.5, 0.5, ImVec2(5, 5), { Flags = ImPlot.ImPlotTextFlags.Vertical }) end },
    { function() ImPlot.PlotDigital("digital", xs, bits, N) end },
    { function() ImPlot.PlotDigitalG("digital", function(i) return i, bits[i + 1] end, nil, N) end },
    { function() ImPlot.PlotBubbles("bubbles", ys, szs) end },
    { function() ImPlot.PlotBubbles("bubbles", xs, ys, szs, N) end },
    { function() ImPlot.PlotDummy("dummy") end, true },
}

local ci, frame, base, done = 1, 0, 0, false
local dummy_ok = false
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
    if ImPlot.BeginPlot("Misc##" .. ci, ImVec2(-1, -1)) then
        if frame > 1 then c[1]() end
        if c[2] and frame == 11 then
            local plot = ImPlot.internal.GetCurrentPlot()
            dummy_ok = plot.Items:GetLegendCount() == 1 and plot.Items:GetLegendLabel(0) == "dummy"
        end
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
        if c[2] then
            assert(dummy_ok, "PlotDummy legend entry exists")
        else
            assert(n > base + 16, "case " .. ci .. " adds vertices: " .. base .. " -> " .. n)
        end
        assert(ImPlot.internal.GetCurrentPlot() == nil)
        ci += 1
        frame = 0
        if ci > #cases then
            done = true
            ImPlot.DestroyContext()
            print("OK")
        end
    end
end)
