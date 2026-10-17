local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()
local io = ImGui.GetIO()

-- AddColormap (ImVec4 and ImU32 overloads)
local n0 = ImPlot.GetColormapCount()
local cm = ImPlot.AddColormap("MyCmap", { ImVec4(1, 0, 0, 1), ImVec4(0, 1, 0, 1), ImVec4(0, 0, 1, 1) }, 3, true)
assert(cm == n0 and ImPlot.GetColormapCount() == n0 + 1 and ImPlot.GetColormapIndex("MyCmap") == cm)
local c = ImPlot.GetColormapColor(1, cm)
assert(c.x == 0 and c.y == 1 and c.z == 0 and c.w == 1)
local cm2 = ImPlot.AddColormap("MyCmapU32", { G.IM_COL32(10, 20, 30, 255), G.IM_COL32(40, 50, 60, 255) }, 2, false)
assert(ImPlot.GetColormapColorU32(1, cm2) == G.IM_COL32(40, 50, 60, 255))

local t = ImPlot.internal.MakeTime(2024, 2, 15)
local level, frame, open = 0, 0, true
game:GetService("RunService").Stepped:Connect(function()
    if frame >= 10 then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    ImGui.NewFrame()
    open = ImPlot.ShowMetricsWindow(open)
    ImGui.Begin("Pickers")
    local _
    _, level, t = ImPlot.ShowDatePicker("date", level, t, t, nil)
    _, t = ImPlot.ShowTimePicker("time", t)
    if ImPlot.BeginPlot("P", ImVec2(200, 150)) then
        ImPlot.SetupAxisScale(ImPlot.ImAxis.X1, ImPlot.ImPlotScale.Time)
        ImPlot.PlotLine("l", { 1, 2, 3 })
        local axis = ImPlot.internal.GetCurrentPlot().Axes[ImPlot.ImAxis.X1]
        ImPlot.EndPlot()
        ImPlot.internal.ShowAxisContextMenu(axis, nil, true) -- time branch
        axis:SetRange(0, 86400)
        assert(axis.PickerTimeMax.S == 86400)
    end
    ImPlot.ShowAltLegend("P")
    ImPlot.ShowStyleEditor()
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 10 then
        assert(level == 0 and ImPlot.internal.GetYear(t) == 2024)
        ImPlot.DestroyContext()
        print("OK")
    end
end)
