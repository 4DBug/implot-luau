local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

local frame, done = 0, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.GetIO().DeltaTime = 1 / 60
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(500, 400), G.ImGuiCond.Always)
    ImGui.Begin("Plots")
    if ImPlot.BeginPlot("My Plot##p", ImVec2(-1, -1)) then
        ImPlot.SetupAxes("x label", "y label")
        ImPlot.SetupAxisFormat(ImPlot.ImAxis.Y1, "%.2f")
        ImPlot.SetupAxesLimits(0, 10, -1, 1, ImPlot.ImPlotCond.Always)
        local lim = ImPlot.GetPlotLimits()
        assert(lim.X.Min == 0 and lim.X.Max == 10 and lim.Y.Min == -1 and lim.Y.Max == 1, "limits")
        local pos, size = ImPlot.GetPlotPos(), ImPlot.GetPlotSize()
        assert(size.x > 100 and size.y > 100, "plot size")
        -- corners map to the plot rect (y axis points up)
        local p0 = ImPlot.PlotToPixels(0, -1)
        assert(near(p0.x, pos.x) and near(p0.y, pos.y + size.y), "PlotToPixels min corner")
        local p = ImPlot.PlotToPixels(ImPlot.ImPlotPoint(3.25, 0.5))
        local q = ImPlot.PixelsToPlot(p)
        assert(near(q.x, 3.25, 1e-4) and near(q.y, 0.5, 1e-4), "round trip")
        assert(type(ImPlot.IsPlotHovered()) == "boolean")
        local ax = ImPlot.internal.GetCurrentPlot().Axes[ImPlot.ImAxis.Y1]
        assert(ax.Ticker:TickCount() > 0 and ax.Ticker.Ticks[1].Text:find("%.%d%d$"), "y tick format")
        ImPlot.EndPlot()
    end
    local dl = ImGui.GetWindowDrawList()
    ImGui.End()
    ImGui.Render()
    assert(dl.VtxBuffer.Size > 0, "draw list has vertices")
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 30 then
        done = true
        ImPlot.DestroyContext()
        print("OK")
    end
end)
