local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
require(RS:WaitForChild("ImPlotDemo"))(G, ImPlot)
local ImGui = G.ImGui

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()
local io = ImGui.GetIO()

-- force every DemoHeader open, and select one tab per phase
local TreeNodeEx, BeginTabItem = ImGui.TreeNodeEx, ImGui.BeginTabItem
ImGui.TreeNodeEx = function(label, ...)
    ImGui.SetNextItemOpen(true)
    return TreeNodeEx(label, ...)
end
local tabs = { "Plots", "Subplots", "Axes", "Tools", "Custom", "Config", "Help" }
local tab, seen = 1, {}
ImGui.BeginTabItem = function(label, p_open, flags)
    if label == tabs[tab] then flags = bit32.bor(flags or 0, G.ImGuiTabItemFlags.SetSelected) end
    local r = BeginTabItem(label, p_open, flags)
    if r then seen[label] = true end
    return r
end

local BeginPlot, plotted = ImPlot.BeginPlot, {}
ImPlot.BeginPlot = function(title, ...)
    local r = BeginPlot(title, ...)
    if r then plotted[title] = true end
    return r
end

local frame, done = 0, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    tab = math.floor((frame - 1) / 14) % #tabs + 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io.DisplaySize = G.ImVec2(1000, 30000)
    ImGui.NewFrame()
    -- tall window so every open demo is visible (clipped plots return false from BeginPlot)
    if frame > 1 then ImGui.SetWindowSize("ImPlot Demo", G.ImVec2(900, 30000)) end
    assert(ImPlot.ShowDemoWindow(true) == true)
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 100 then
        done = true
        for _, t in tabs do assert(seen[t], "tab never opened: " .. t) end
        -- every ported Plots/Axes/Config demo submitted its plot
        for _, p in { "Line Plots", "Stock Prices", "Shaded Plots", "Scatter Plot", "Bubble Plot", "##Scrolling", "##Rolling",
            "Stairstep Plot", "Bar Plot", "Bar Group", "PolitiFact: Who Lies More?", "##ErrorBars", "Stem Plots", "##Infinite",
            "##Pie1", "##Pie2", "##Heatmap1", "##Heatmap2", "##Histograms", "##Hist2D", "##Digital", "##image", "Preview",
            "##MarkerStyles", "##NaNValues", "Colorful Lines", "Colorful Shaded Plots", "Colorful Scatter", "Colorful Bubbles",
            "Colorful Stairstep Plot", "Colorful Bar Plot", "Colorful Stem Plots", "Colorful Infinite Lines", "Log Plot",
            "SymLog Plot", "##Time", "Sqrt", "Multi-Axis Plot", "Plot A", "Plot B", "##AxisConstraints", "##EqualAxes",
            "##DataFitting" } do
            assert(plotted[p], "plot never began: " .. p)
        end
        ImPlot.DestroyContext()
        print("OK")
    end
end)
