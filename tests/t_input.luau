local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()
local io = ImGui.GetIO()
local function near(a, b) return math.abs(a - b) <= 1e-6 end

assert(ImPlot.GetInputMap().Pan == 0 and ImPlot.GetInputMap().Select == 1, "default input map")
ImPlot.MapInputReverse(); assert(ImPlot.GetInputMap().Pan == 1, "reverse map")
ImPlot.MapInputDefault()

local frame, done = 0, false
local lim, pos, size
local start, after_pan, after_zoom
local link = { 0 }
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    if pos then
        local cx, cy = pos.x + size.x * 0.5, pos.y + size.y * 0.5
        -- left drag: press, move right/down by 40px, release
        if frame == 10 then io:AddMousePosEvent(cx, cy)
        elseif frame == 11 then io:AddMouseButtonEvent(0, true)
        elseif frame >= 12 and frame <= 15 then io:AddMousePosEvent(cx + (frame - 11) * 10, cy + (frame - 11) * 10)
        elseif frame == 16 then io:AddMouseButtonEvent(0, false)
        -- wheel zoom in
        elseif frame == 20 then io:AddMouseWheelEvent(0, 1)
        -- double click refits
        elseif frame == 40 or frame == 42 then io:AddMouseButtonEvent(0, true)
        elseif frame == 41 or frame == 43 then io:AddMouseButtonEvent(0, false)
        end
    end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(500, 400), G.ImGuiCond.Always)
    ImGui.Begin("Plots")
    if frame == 1 then ImPlot.SetNextAxesLimits(0, 10, 0, 10) end
    if ImPlot.BeginPlot("Input##p", ImVec2(-1, -1)) then
        ImPlot.SetupAxisLinks(ImPlot.ImAxis.X1, link, nil)
        -- fake data extents [2, 4] so a fit is observable
        local plot = ImPlot.internal.GetCurrentPlot()
        for _, i in { ImPlot.ImAxis.X1, ImPlot.ImAxis.Y1 } do
            plot.Axes[i]:ExtendFit(2); plot.Axes[i]:ExtendFit(4)
        end
        lim = ImPlot.GetPlotLimits()
        pos, size = ImPlot.GetPlotPos(), ImPlot.GetPlotSize()
        ImPlot.EndPlot()
    end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 9 then
        start = { lim.X.Min, lim.X.Max, lim.Y.Min, lim.Y.Max }
        assert(start[1] == 0 and start[2] == 10, "SetNextAxesLimits")
    elseif frame == 18 then
        after_pan = { lim.X.Min, lim.X.Max, lim.Y.Min, lim.Y.Max }
        -- dragged right -> x shifts left; dragged down -> y shifts up
        assert(after_pan[1] < start[1] and after_pan[2] < start[2], "pan x")
        assert(after_pan[3] > start[3] and after_pan[4] > start[4], "pan y")
        assert(math.abs((after_pan[2] - after_pan[1]) - 10) < 1e-6, "pan keeps range")
        assert(link[1] == after_pan[1], "link pushed")
    elseif frame == 25 then
        after_zoom = { lim.X.Min, lim.X.Max, lim.Y.Min, lim.Y.Max }
        assert(after_zoom[2] - after_zoom[1] < 10 - 1e-3, "zoom x shrinks")
        assert(after_zoom[4] - after_zoom[3] < 10 - 1e-3, "zoom y shrinks")
    elseif frame == 50 then
        assert(near(lim.X.Min, 2) and near(lim.X.Max, 4), "double click refit x")
        assert(near(lim.Y.Min, 2) and near(lim.Y.Max, 4), "double click refit y")
        done = true
        ImPlot.DestroyContext()
        print("OK")
    end
end)
