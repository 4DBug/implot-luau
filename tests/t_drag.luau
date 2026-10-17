local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()
local io = ImGui.GetIO()

local frame, done = 0, false
local px, py = 5, 5 -- DragPoint
local lx = 2        -- DragLineX
local ly = 8        -- DragLineY
local rect = ImPlot.ImPlotRect(7, 9, 1, 2) -- clear of the point and line grab areas
local pt_pix, line_pix
local any_modified, line_modified = false, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    -- drag the point by +40px x / +40px y, then the line by +30px x
    if pt_pix then
        if frame == 10 then io:AddMousePosEvent(pt_pix.x, pt_pix.y)
        elseif frame == 11 then io:AddMouseButtonEvent(0, true)
        elseif frame >= 12 and frame <= 15 then io:AddMousePosEvent(pt_pix.x + (frame - 11) * 10, pt_pix.y + (frame - 11) * 10)
        elseif frame == 16 then io:AddMouseButtonEvent(0, false)
        elseif frame == 20 then io:AddMousePosEvent(line_pix, pt_pix.y - 60)
        elseif frame == 21 then io:AddMouseButtonEvent(0, true)
        elseif frame >= 22 and frame <= 24 then io:AddMousePosEvent(line_pix + (frame - 21) * 10, pt_pix.y - 60)
        elseif frame == 25 then io:AddMouseButtonEvent(0, false)
        end
    end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(500, 400), G.ImGuiCond.Always)
    ImGui.Begin("Plots")
    if ImPlot.BeginPlot("Drag##p", ImVec2(-1, -1)) then
        ImPlot.SetupAxesLimits(0, 10, 0, 10, ImPlot.ImPlotCond.Always)
        ImPlot.SetupMouseText(ImPlot.ImPlotLocation.North, ImPlot.ImPlotMouseTextFlags.ShowAlways)
        local m, m2
        px, py, m = ImPlot.DragPoint(0, px, py, ImVec4(1, 0, 0, 1), 6)
        any_modified = any_modified or m
        lx, m2 = ImPlot.DragLineX(1, lx, ImVec4(0, 1, 0, 1))
        line_modified = line_modified or m2
        ly = ImPlot.DragLineY(2, ly, ImVec4(0, 0, 1, 1))
        local _, _, hov = ImPlot.DragRect(3, rect, ImVec4(1, 1, 0, 1))
        assert(type(hov) == "boolean", "DragRect out_hovered")
        ImPlot.Annotation(px, py, ImVec4(0.2, 0.2, 0.2, 1), ImVec2(10, -10), true)
        ImPlot.Annotation(5, 5, ImVec4(0, 0, 0, 0), ImVec2(0, 0), false, "center %d", 5)
        ImPlot.TagX(lx, ImVec4(0, 1, 0, 1), true)
        ImPlot.TagY(ly, ImVec4(0, 0, 1, 1), "y=%.1f", ly)
        pt_pix = ImPlot.PlotToPixels(5, 5)
        if frame < 20 then line_pix = ImPlot.PlotToPixels(lx, 0).x end
        ImPlot.EndPlot()
    end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 9 then
        assert(px == 5 and py == 5 and lx == 2, "untouched before input")
    elseif frame == 18 then
        assert(any_modified, "DragPoint reported modified")
        assert(px > 5 and py < 5, "DragPoint moved (x right, y down)")
        assert(lx == 2, "line untouched by point drag")
    elseif frame == 30 then
        assert(line_modified, "DragLineX reported modified")
        assert(lx > 2, "DragLineX moved right")
        done = true
        ImPlot.DestroyContext()
        print("OK")
    end
end)
