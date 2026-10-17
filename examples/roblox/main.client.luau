local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot = require(RS:WaitForChild("ImPlot"))(G)
local ImGui = G.ImGui

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
RunService.RenderStepped:Connect(function()
	G.ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	-- ImPlot example goes here
	ImGui.Render()
	G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
