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
local xs, ys, ys2 = table.create(N), table.create(N), table.create(N)
for i = 1, N do
    xs[i] = i - 1
    ys[i] = math.sin(i * 0.3) * 3 + 4
    ys2[i] = ys[i] - 2
end
local groups = { 1, 2, 3, 4, 2, 3, 1, -1, 3, 1, 2, 2 } -- 3 items x 4 groups
local labels = { "a", "b", "c" }

local cases = {
    function() ImPlot.PlotStairs("stairs", xs, ys, N) end,
    function() ImPlot.PlotStairs("stairs", ys, { Flags = ImPlot.ImPlotStairsFlags.PreStep + ImPlot.ImPlotStairsFlags.Shaded }) end,
    function() ImPlot.PlotShaded("shaded", ys, N, 0, 1, 0) end,
    function() ImPlot.PlotShaded("shaded", xs, ys, N, -math.huge) end,
    function() ImPlot.PlotShaded("shaded", xs, ys, ys2, N) end,
    function() ImPlot.PlotShadedG("shaded", function(i) return i, ys[i + 1] end, nil, function(i) return i, 0 end, nil, N) end,
    function() ImPlot.PlotBars("bars", ys, N, 0.5) end,
    function() ImPlot.PlotBars("bars", xs, ys, N, 0.5, { Flags = ImPlot.ImPlotBarsFlags.Horizontal }) end,
    function() ImPlot.PlotBarsG("bars", function(i) return i, ys[i + 1] end, nil, N, 0.5) end,
    function() ImPlot.PlotBarGroups(labels, groups, 3, 4, 0.67, 0) end,
    function() ImPlot.PlotBarGroups(labels, groups, 3, 4, 0.67, 0, { Flags = ImPlot.ImPlotBarGroupsFlags.Stacked }) end,
    function() ImPlot.PlotBarGroups(labels, groups, 3, 4, { Flags = ImPlot.ImPlotBarGroupsFlags.Horizontal + ImPlot.ImPlotBarGroupsFlags.Stacked }) end,
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
    if ImPlot.BeginPlot("Bars##" .. ci, ImVec2(-1, -1)) then
        if frame > 1 then cases[ci]() end
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
            ImPlot.DestroyContext()
            print("OK")
        end
    end
end)
