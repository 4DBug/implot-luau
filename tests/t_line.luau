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

local N = 1000
local xs, ys = table.create(N), table.create(N)
local ymin, ymax = math.huge, -math.huge
for i = 1, N do
    xs[i] = (i - 1) * 0.01
    ys[i] = math.sin(i * 0.02) * 3 + 1
    ymin = math.min(ymin, ys[i]); ymax = math.max(ymax, ys[i])
end

local frame, done = 0, false
local vtx = {}
local lim, legend_rect, line_item, scatter_item
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    if legend_rect then
        -- click the first legend entry (the line)
        local h = ImGui.GetTextLineHeight()
        local cx, cy = legend_rect.Min.x + 5 + h * 0.5, legend_rect.Min.y + 5 + h * 0.5
        if frame == 20 then io:AddMousePosEvent(cx, cy)
        elseif frame == 22 then io:AddMouseButtonEvent(0, true)
        elseif frame == 24 then io:AddMouseButtonEvent(0, false)
        end
    end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(500, 400), G.ImGuiCond.Always)
    ImGui.Begin("Plots")
    if frame == 5 then ImPlot.SetNextAxesToFit() end
    if ImPlot.BeginPlot("Line##p", ImVec2(-1, -1)) then
        if frame >= 5 then
            ImPlot.SetNextLineStyle(nil, 2)
            ImPlot.PlotLine("line", xs, ys, N)
            ImPlot.SetNextMarkerStyle(ImPlot.ImPlotMarker.Square, 3)
            ImPlot.PlotScatter("scatter", ys, N, 0.01, 0, { Offset = 0 })
            line_item = ImPlot.internal.GetItem("line")
            scatter_item = ImPlot.internal.GetItem("scatter")
        end
        lim = ImPlot.GetPlotLimits()
        local plot = ImPlot.internal.GetCurrentPlot()
        ImPlot.EndPlot()
        if frame >= 6 then legend_rect = plot.Items.Legend.Rect end
    end
    local dl = ImGui.GetWindowDrawList()
    ImGui.End()
    ImGui.Render()
    vtx[frame] = dl.VtxBuffer.Size
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 10 then
        -- 999 line segments * 4 verts + 1000 square markers * 4 verts
        assert(vtx[10] - vtx[4] >= 999 * 4 + N * 4, "vertex count grows: " .. vtx[4] .. " -> " .. vtx[10])
        assert(near(lim.X.Min, 0) and near(lim.X.Max, (N - 1) * 0.01), "fit x " .. lim.X.Min .. " " .. lim.X.Max)
        assert(near(lim.Y.Min, ymin) and near(lim.Y.Max, ymax), "fit y " .. lim.Y.Min .. " " .. lim.Y.Max)
        assert(line_item and line_item.Show and scatter_item.Show, "items shown")
        assert(line_item.Color ~= scatter_item.Color, "colormap advances")
        assert(scatter_item.Marker == ImPlot.ImPlotMarker.Square, "marker override")
        assert(ImPlot.internal.GetCurrentPlot() == nil)
    elseif frame == 30 then
        assert(not line_item.Show, "legend click hides line")
        assert(scatter_item.Show, "scatter still shown")
        assert(vtx[10] - vtx[30] >= 999 * 4 - 100, "vertex count drops: " .. vtx[10] .. " -> " .. vtx[30])
        done = true
        ImPlot.DestroyContext()
        print("OK")
    end
end)
