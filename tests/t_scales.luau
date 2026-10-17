local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local ImAxis, ImPlotScale, Cond = ImPlot.ImAxis, ImPlot.ImPlotScale, ImPlot.ImPlotCond

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot.CreateContext()
local I = ImPlot.internal

-- time utils
local t = I.MakeTime(2021, 2, 15, 13, 45, 30)
assert(I.FormatDateTime(t, I.ImPlotDateTimeSpec(I.ImPlotDateFmt.DayMoYr, I.ImPlotTimeFmt.HrMinS)) == "3/15/21 1:45:30pm", "FormatDateTime")
assert(I.FormatDate(t, I.ImPlotDateFmt.DayMoYr, true) == "2021-03-15", "iso date")
assert(I.FloorTime(t, I.ImPlotTimeUnit.Day).S == I.MakeTime(2021, 2, 15).S, "FloorTime")
assert(I.CeilTime(t, I.ImPlotTimeUnit.Mo).S == I.MakeTime(2021, 3, 1).S, "CeilTime")
assert(I.RoundTime(t, I.ImPlotTimeUnit.Hr).S == I.MakeTime(2021, 2, 15, 14).S, "RoundTime")
assert(I.MakeTime(1970).S == 0, "epoch")

local function labels(ax)
    local n, out = 0, {}
    for i = 1, ax.Ticker:TickCount() do
        local tk = ax.Ticker.Ticks[i]
        if tk.ShowLabel and tk.Text then n += 1; out[#out + 1] = tk.Text end
    end
    return n, out
end

local frame, done = 0, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.GetIO().DeltaTime = 1 / 60
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(600, 900), G.ImGuiCond.Always)
    ImGui.Begin("Plots")
    if ImPlot.BeginPlot("Log##p", ImVec2(-1, 280)) then
        ImPlot.SetupAxes("x", "y")
        ImPlot.SetupAxisScale(ImAxis.Y1, ImPlotScale.Log10)
        ImPlot.SetupAxesLimits(0, 1, 1, 1e6, Cond.Always)
        ImPlot.PlotLine("l", { 1, 10, 100 }, { 1, 1000, 1e6 })
        local ax = I.GetCurrentPlot().Axes[ImAxis.Y1]
        local majors = 0
        for i = 1, ax.Ticker:TickCount() do
            local tk = ax.Ticker.Ticks[i]
            if tk.Major then
                majors += 1
                local e = math.log10(tk.PlotPos)
                assert(math.abs(e - math.floor(e + 0.5)) < 1e-9, "log major at power of 10")
            end
        end
        assert(majors >= 2, "log majors")
        -- log transform: 1000 is the vertical midpoint
        local mid = ImPlot.PlotToPixels(0, 1000).y
        local p0, p1 = ImPlot.PlotToPixels(0, 1).y, ImPlot.PlotToPixels(0, 1e6).y
        assert(math.abs(mid - (p0 + p1) / 2) < 1, "log transform")
        ImPlot.EndPlot()
    end
    if ImPlot.BeginPlot("Time##p", ImVec2(-1, 280)) then
        ImPlot.SetupAxes("t", "y")
        ImPlot.SetupAxisScale(ImAxis.X1, ImPlotScale.Time)
        local t0 = I.MakeTime(2021, 0, 1).S
        ImPlot.SetupAxesLimits(t0, t0 + 86400, 0, 1, Cond.Always)
        local ax = I.GetCurrentPlot().Axes[ImAxis.X1]
        ImPlot.EndPlot()
        local n, out = labels(ax)
        assert(n >= 3, "time labels")
        local found = false
        for _, s in out do if s:find("1/1/21") then found = true end end
        assert(found, "time date label: " .. table.concat(out, ","))
    end
    if ImPlot.BeginPlot("Ticks##p", ImVec2(-1, 280)) then
        ImPlot.SetupAxes("x", "y")
        ImPlot.SetupAxisTicks(ImAxis.X1, { 0, 0.5, 1 }, 3, { "lo", "mid", "hi" }, false)
        ImPlot.SetupAxisTicks(ImAxis.Y1, 0, 1, 5, nil, false)
        ImPlot.SetupAxisFormat(ImAxis.Y1, function(v) return string.format("<%g>", v) end)
        ImPlot.SetupAxisLimitsConstraints(ImAxis.X1, 0, 1)
        ImPlot.SetupAxisZoomConstraints(ImAxis.X1, 0.5, 1)
        ImPlot.SetupAxesLimits(-5, 5, 0, 1, Cond.Always)
        local plot = I.GetCurrentPlot()
        ImPlot.EndPlot()
        local n, out = labels(plot.Axes[ImAxis.X1])
        assert(n == 3 and out[1] == "lo" and out[3] == "hi", "custom tick labels")
        assert(labels(plot.Axes[ImAxis.Y1]) == 5, "custom y tick count")
        local r = plot.Axes[ImAxis.X1].Range
        assert(r.Min >= 0 and r.Max <= 1, "limits constraints")
    end
    if ImPlot.BeginPlot("SymLog##p", ImVec2(-1, 200)) then
        ImPlot.SetupAxes("x", "y")
        ImPlot.SetupAxisScale(ImAxis.X1, ImPlotScale.SymLog)
        ImPlot.SetupAxesLimits(-100, 100, 0, 1, Cond.Always)
        assert(I.GetCurrentPlot().Axes[ImAxis.X1].Ticker:TickCount() == 0)
        ImPlot.EndPlot()
    end
    local dl = ImGui.GetWindowDrawList()
    ImGui.End()
    ImGui.Render()
    assert(dl.VtxBuffer.Size > 0, "draw list has vertices")
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 10 then
        done = true
        ImPlot.DestroyContext()
        print("OK")
    end
end)
