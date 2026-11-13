--!strict
-- V2-01: detalhe visual responsivo, somente local; servidor nao perde colisao nem fisica.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Budget = require(ReplicatedStorage.Shared.V2VisualBudgetRules)
local localPlayer = Players.LocalPlayer

local function updateModel(model: Model, distance: number)
    local touch = UserInputService.TouchEnabled
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") then
            local level = item:GetAttribute("V2DetailLevel")
            if type(level) == "string" and Budget.DetailLevels[level] then
                item.LocalTransparencyModifier = Budget.Show(level, distance, touch) and 0 or 1
            end
        elseif item:IsA("ParticleEmitter") then
            local level = item:GetAttribute("V2DetailLevel")
            if type(level) == "string" and Budget.DetailLevels[level] then
                item.Enabled = Budget.Show(level, distance, touch)
            end
        end
    end
end

task.spawn(function()
    while localPlayer.Parent do
        local camera = workspace.CurrentCamera
        local position = camera and camera.CFrame.Position
        if position then
            for _, folderName in ipairs({"Vehicles", "Arrivals"}) do
                local folder = workspace:FindFirstChild(folderName)
                if folder then
                    for _, model in ipairs(folder:GetChildren()) do
                        if model:IsA("Model") and model:GetAttribute("V2PilotId") ~= nil then
                            local primary = model.PrimaryPart
                            if primary then
                                updateModel(model, (primary.Position - position).Magnitude)
                            end
                        end
                    end
                end
            end
        end
        task.wait(1.2) -- somente tres arquétipos e sem RenderStepped
    end
end)
