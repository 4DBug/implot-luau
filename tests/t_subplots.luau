local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()
local io = ImGui.GetIO()

local xs, ys = {}, {}
for i = 1, 50 do xs[i] = i; ys[i] = math.sin(i * 0.2) end
local rows, cols = { 1, 2 }, { 1, 1 }
local flags = bit32.bor(ImPlot.ImPlotSubplotFlags.ShareItems, ImPlot.ImPlotSubplotFlags.LinkAllX)

local frame, done = 0, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(600, 700), G.ImGuiCond.Always)
    ImGui.Begin("Subplots")
    local dl = ImGui.GetWindowDrawList()
    local cells = 0
    if ImPlot.BeginSubplots("My Subplots", 2, 2, ImVec2(-1, 250), flags, rows, cols) then
        for i = 1, 4 do
            if ImPlot.BeginPlot("##p" .. i) then
                local before = dl.VtxBuffer.Size
                ImPlot.PlotLine("sin", xs, ys, #xs)
                assert(dl.VtxBuffer.Size > before, "subplot " .. i .. " added vertices")
                ImPlot.EndPlot()
                cells += 1
            end
        end
        ImPlot.EndSubplots()
    end
    assert(cells == 4, "all 4 subplots began")
    local aligned = 0
    -- smoke: aligned plots, legend popup, drag/drop target
    if ImPlot.BeginAlignedPlots("AlignGroup") then
        for i = 1, 2 do
            if ImPlot.BeginPlot("##a" .. i, ImVec2(-1, 150), ImPlot.ImPlotFlags.Crosshairs + ImPlot.ImPlotFlags.Equal) then
                ImPlot.PlotLine("cos", xs, ys, #xs)
                aligned += 1
                if ImPlot.BeginLegendPopup("cos") then ImPlot.EndLegendPopup() end
                if ImPlot.BeginDragDropTargetPlot() then ImPlot.EndDragDropTarget() end
                ImPlot.EndPlot()
            end
        end
        ImPlot.EndAlignedPlots()
    end
    assert(aligned == 2, "aligned plots began")
    ImGui.End()

    ImGui.SetNextWindowPos(ImVec2(620, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(500, 600), G.ImGuiCond.Always)
    ImGui.Begin("Style")
    ImPlot.ShowStyleEditor()
    ImPlot.ShowUserGuide()
    ImGui.End()

    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 10 then
        done = true
        ImPlot.DestroyContext()
        print("OK")
    end
end)
