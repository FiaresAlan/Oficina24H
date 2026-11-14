-- V2-15: inventário VIVO em Studio Edit/Play. Não tenta habilitar
-- StreamingEnabled em runtime nem declara licenças/testes aprovados.
-- O checklist de beta exige revisão manual dos avisos WARN.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local Budget=require(ReplicatedStorage.Shared.V2VisualBudgetRules)
local Scenario=require(ReplicatedStorage.Shared.V2DriveScenarioRules)
local SoundIds=require(ReplicatedStorage.Shared.SoundIds)
local out={}
local function check(name,ok)
    table.insert(out,(ok and "PASS " or "FAIL ")..name)
end
local function warning(name)
    table.insert(out,"WARN "..name)
end
check("V2-15: rodar auditoria exclusivamente no Roblox Studio",
    RunService:IsStudio())
check("V2-12/13: gate diagnóstico/qualidade continua DESLIGADO",
    Scenario.LiveEnabled==false)
local streaming=Workspace.StreamingEnabled==true
if not streaming then
    warning("StreamingEnabled desativado: habilitar na propriedade do Workspace no Studio ANTES do beta.")
else
    check("StreamingEnabled configurado no place",streaming)
end
local root=ServerStorage:FindFirstChild("Assets")
if not root then
    warning("ServerStorage.Assets ainda não importado; usar guia único de assets/Creator Hub.")
else
    local named,templates,skipped=0,0,0
    local scripted=0
    for _,folder in ipairs(root:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            for _,asset in ipairs(folder:GetChildren()) do
                if asset:IsA("Model") then
                    named+=1
                    local ok=Budget.PreflightTemplate(asset,"Drive")
                        or Budget.PreflightTemplate(asset,"Ambient")
                    if ok then templates+=1 else skipped+=1 end
                    for _,node in ipairs(asset:GetDescendants()) do
                        if node:IsA("Script") or node:IsA("LocalScript")
                            or node:IsA("ModuleScript") then
                            scripted+=1
                        end
                    end
                end
            end
        end
    end
    check("inventário de assets inspecionado sem executar scripts externos",named>=0)
    warning(string.format("Asset audit: %d modelos, %d no limite de prévia, %d excedentes (fallback).",
        named,templates,skipped))
    if scripted>0 then
        warning(string.format("%d script(s) em modelos fonte; exigir StripScripts antes de inserir no jogo.",scripted))
    end
end
local previews=ReplicatedStorage:FindFirstChild("V2PedestrianPreviews")
if previews then
    for _,preview in ipairs(previews:GetDescendants()) do
        check("preview ambiente sem Script/LocalScript/ModuleScript",not (
            preview:IsA("Script") or preview:IsA("LocalScript")
            or preview:IsA("ModuleScript")))
    end
end
local drive=Workspace:FindFirstChild("V2DriveCars")
local rigs=0
if drive then
    for _,m in ipairs(drive:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("V2Drive")==true then
            rigs+=1
            for _,part in ipairs(m:GetDescendants()) do
                if part:IsA("BasePart") and part.Massless
                    and part.Name~="DriveChassis" then
                    -- Peças cosméticas não devem colidir nem gerar Touched.
                    check("visual do Hatch não recebe colisão física direta",
                        part.CanCollide==false and part.CanTouch==false)
                end
            end
        end
    end
end
check("orçamento de física servidor respeitado",
    rigs<=Budget.MaxConcurrentDriveRigs)
local sounds=0
local function inspectSounds(values:any)
    for _,v in pairs(values) do
        if type(v)=="table" then inspectSounds(v)
        elseif type(v)=="string" then
            sounds+=1
            if not string.match(v,"^rbxassetid://%d+$") then
                check("asset de áudio usa ID Roblox válido",false)
            end
        end
    end
end
inspectSounds(SoundIds)
check("fontes sonoras possuem IDs Roblox estruturados",sounds>=7)
warning("Licenças/uso dos áudios e malhas externas EXIGEM conferência manual na conta Creator Hub.")
warning("Não é teste de FPS real, torque, colisão, DataStore online, autoplay de áudio, touch ou gamepad.")
return table.concat(out,"\n")
