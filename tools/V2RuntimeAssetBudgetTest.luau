-- V2-15: validar modelos importados ANTES de Clone, preservando
-- fallback físico do Hatch. Este teste não roda física nem simula FPS.
local R=require(game.ReplicatedStorage.Shared.V2VisualBudgetRules)
local out={}
local function check(name,good)table.insert(out,(good and "PASS " or "FAIL ")..name)end
local function make(name)
    local model=Instance.new("Model")
    model.Name=name
    local root=Instance.new("Part")
    root.Name="Root"
    root.Size=Vector3.new(4,2,7)
    root.Anchored=true
    root.Parent=model
    model.PrimaryPart=root
    return model,root
end
local clean,base=make("SafeCar")
check("modelo piloto pequeno e visível autorizado",
    R.PreflightTemplate(clean,"Drive"))
check("modelo ambiente pequeno e visível autorizado",
    R.PreflightTemplate(clean,"Ambient"))
check("tipo inválido rejeitado",
    not R.PreflightTemplate(clean,"Reward")
    and not R.PreflightTemplate("model","Drive"))
check("nenhum servidor roda veículos físicos ilimitados",
    R.CanStartDrive(0)
    and R.CanStartDrive(R.MaxConcurrentDriveRigs-1)
    and not R.CanStartDrive(R.MaxConcurrentDriveRigs)
    and not R.CanStartDrive(-1))
local large,root=make("OversizedCar")
root.Size=Vector3.new(70,8,12)
check("escala exagerada rejeitada antes de cópia",
    not R.PreflightTemplate(large,"Drive"))
local heavy,heavyRoot=make("ManyParts")
for i=1,R.MaxDriveShellParts do
    local p=Instance.new("Part")
    p.Size=Vector3.new(.1,.1,.1)
    p.CFrame=CFrame.new(i*.03,0,0)
    p.Parent=heavy
end
check("95 peças adicionais excedem orçamento do piloto",
    not R.PreflightTemplate(heavy,"Drive"))
local scattered,scatRoot=make("ManyNodes")
for i=1,R.MaxDriveShellDescendants do
    local item=Instance.new("Attachment")
    item.Name="ConstraintAnchor_"..i
    item.Parent=scatRoot
end
check("instâncias sem física também entram no limite de memória",
    not R.PreflightTemplate(scattered,"Drive"))
local texture,textureRoot=make("ManyPBR")
for i=1,R.MaxDriveSurfaceAppearances+1 do
    local item=Instance.new("SurfaceAppearance")
    item.Name="PBR_"..i
    item.Parent=textureRoot
end
check("texturas de superfície excessivas são rejeitadas",
    not R.PreflightTemplate(texture,"Drive"))
local ambient,ambientRoot=make("HeavyWalkers")
for i=1,R.MaxAmbientTemplateDescendants do
    local item=Instance.new("Attachment")
    item.Parent=ambientRoot
end
check("NPC ambiente excessivo usa fallback sem clone",
    not R.PreflightTemplate(ambient,"Ambient"))
for _,m in ipairs({clean,large,heavy,scattered,texture,ambient}) do
    m:Destroy()
end
return table.concat(out,"\n")
