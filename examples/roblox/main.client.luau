-- Live sine wave (scrolling buffer) + ImPlot / ImGui demo windows.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
require(RS:WaitForChild("ImPlotDemo"))(G, ImPlot)
local ImGui = G.ImGui

local MaxPoints = 500
local Xs, Ys = table.create(MaxPoints, 0), table.create(MaxPoints, 0)
local Count, Offset, Time = 0, 0, 0
local Frequency = 1
local ShowImPlotDemo, ShowImGuiDemo = true, false

local function AddPoint(X, Y)
	if Count < MaxPoints then
		Count += 1
		Xs[Count], Ys[Count] = X, Y
	else
		Xs[Offset + 1], Ys[Offset + 1] = X, Y
		Offset = (Offset + 1) % MaxPoints
	end
end

local StartClock = os.clock()

local function RenderDemo()
	Time = os.clock() - StartClock
	AddPoint(Time, math.sin(Time * Frequency * 2 * math.pi))

	ImGui.SetNextWindowSize(G.ImVec2(600, 400), G.ImGuiCond.FirstUseEver)
	ImGui.Begin("Live Sine")
	_, ShowImPlotDemo = ImGui.Checkbox("ImPlot Demo", ShowImPlotDemo)
	ImGui.SameLine()
	_, ShowImGuiDemo = ImGui.Checkbox("ImGui Demo", ShowImGuiDemo)
	Frequency = ImGui.SliderFloat("Frequency", Frequency, 0.1, 5)
	if ImPlot.BeginPlot("##Sine", G.ImVec2(-1, -1)) then
		ImPlot.SetupAxisLimits(ImPlot.ImAxis.X1, Time - 10, Time, G.ImGuiCond.Always)
		ImPlot.SetupAxisLimits(ImPlot.ImAxis.Y1, -1.1, 1.1)
		-- ring buffer: Offset (0-based, in elements) via spec, as in the C++ ScrollingBuffer demo
		ImPlot.PlotLine("sin", Xs, Ys, Count, { Offset = Offset })
		ImPlot.EndPlot()
	end
	ImGui.End()

	if ShowImPlotDemo then
		ShowImPlotDemo = ImPlot.ShowDemoWindow(ShowImPlotDemo)
	end
	if ShowImGuiDemo then
		ShowImGuiDemo = ImGui.ShowDemoWindow(ShowImGuiDemo)
	end
end

ImGui.CreateContext()
ImPlot.CreateContext()
G.ImGui_ImplRoblox.Init() -- defaults to LocalPlayer.PlayerGui
RunService.RenderStepped:Connect(function()
	G.ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	RenderDemo()
	ImGui.Render()
	G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
