--!strict
-- V2-07: publica SOMENTE três avatares aprovados, sem scripts externos,
-- para clone visual local. Não cria Humanoid nem NPC ambiental no servidor.
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local AssetSafetyRules=require(ReplicatedStorage.Shared.AssetSafetyRules)
local VisualBudget=require(ReplicatedStorage.Shared.V2VisualBudgetRules)
local Service={}
Service.MaxTemplates=3
Service.MaxPartsPerTemplate=80

function Service.Publish(): number
    local previous=ReplicatedStorage:FindFirstChild("V2PedestrianPreviews")
    if previous then previous:Destroy() end
    local folder=Instance.new("Folder")
    folder.Name="V2PedestrianPreviews"
    local assets=ServerStorage:FindFirstChild("Assets")
    local source=assets and assets:FindFirstChild("Clientes")
    local models={}
    for _,child in ipairs(source and source:GetChildren() or {}) do
        if child:IsA("Model") and child.PrimaryPart
            and child:FindFirstChildOfClass("Humanoid") then
            table.insert(models,child)
        end
    end
    table.sort(models,function(a,b)return a.Name<b.Name end)
    local count=0
    for _,template in ipairs(models) do
        if count>=Service.MaxTemplates then break end
        local parts=0
        for _,node in ipairs(template:GetDescendants()) do
            if node:IsA("BasePart") then parts+=1 end
        end
        local accepted=VisualBudget.PreflightTemplate(template,"Ambient")
        if accepted and parts<=Service.MaxPartsPerTemplate then
            local copy=template:Clone()
            AssetSafetyRules.StripScripts(copy)
            copy.Name="Ped_"..(count+1)
            copy:SetAttribute("V2AmbientOnly",true)
            -- Não replicar prompts de cliente nem interações de NPC real.
            for _,node in ipairs(copy:GetDescendants()) do
                if node:IsA("ProximityPrompt") or node:IsA("ClickDetector")
                    or node:IsA("TouchTransmitter") then
                    node:Destroy()
                elseif node:IsA("BasePart") then
                    node.CanCollide=false
                    node.CanTouch=false
                    node.CanQuery=false
                    node.Massless=true
                end
            end
            copy.Parent=folder
            count+=1
        end
    end
    folder:SetAttribute("TemplateCount",count)
    folder.Parent=ReplicatedStorage
    return count
end

return Service
