-- C31 / G1: modelos sintéticos validam a auditoria sem alterar o place real.
local Rules = require(game:GetService("ReplicatedStorage").Shared.AssetIntegrityRules)
local report = {}
local function check(label, condition)
	table.insert(report, (condition and "PASS " or "FAIL ") .. label)
end
local car = Instance.new("Model")
local root = Instance.new("Part")
root.Name = "Raiz"
root.Anchored = true
root.Parent = car
car.PrimaryPart = root
local hull = Instance.new("Part")
hull.Name = "Casco"
hull.Anchored = false
hull.CanCollide = true
hull.Parent = car
local weld = Instance.new("WeldConstraint")
weld.Part0 = root
weld.Part1 = hull
weld.Parent = root
car:SetAttribute("Largura", 8)
car:SetAttribute("Comprimento", 18)
car:SetAttribute("Altura", 5)
car:SetAttribute("Motorista", Vector3.new(-1.5, 1.5, 0))
local errors, warnings = Rules.Vehicle(car)
check("carro normalizado nao apresenta erros", #errors == 0)
check("fallback de sockets eh apenas aviso", #warnings == 1)

local socket = Instance.new("Attachment")
socket.Name = "OficinaSocket_WheelBolts"
socket.Parent = root
errors = Rules.Vehicle(car)
check("socket valido e opcional", #errors == 0)
local duplicate = Instance.new("Attachment")
duplicate.Name = "OficinaSocket_WheelBolts"
duplicate.Parent = hull
errors = Rules.Vehicle(car)
check("socket duplicado reprova", #errors > 0)
duplicate:Destroy()

root.Name = "PivoErrado"
errors = Rules.Vehicle(car)
check("raiz errada reprova", #errors > 0)
root.Name = "Raiz"
car:SetAttribute("Comprimento", 0 / 0)
errors = Rules.Vehicle(car)
check("dimensao NaN reprova", #errors > 0)
car:SetAttribute("Comprimento", 18)
hull.Anchored = true
errors = Rules.Vehicle(car)
check("peca solta ancorada reprova", #errors > 0)
hull.Anchored = false
hull.CanCollide = false
errors = Rules.Vehicle(car)
check("casco sem colisao reprova", #errors > 0)

local npc = Instance.new("Model")
local humanoid = Instance.new("Humanoid")
humanoid.RigType = Enum.HumanoidRigType.R15
humanoid.Parent = npc
local npcRoot = Instance.new("Part")
npcRoot.Name = "HumanoidRootPart"
npcRoot.Parent = npc
npc.PrimaryPart = npcRoot
npc:SetAttribute("Genero", "F")
check("cliente R15 e com genero valido", #Rules.Customer(npc) == 0)
npc:SetAttribute("Genero", "X")
check("cliente com genero invalido reprova", #Rules.Customer(npc) > 0)
npc:SetAttribute("Genero", "F")
npc.PrimaryPart = nil
check("cliente sem raiz principal reprova", #Rules.Customer(npc) > 0)

local equipment = Instance.new("Model")
check("equipamento sem PrimaryPart reprova", #Rules.Equipment(equipment) > 0)
local base = Instance.new("Part")
base.Parent = equipment
equipment.PrimaryPart = base
check("equipamento com PrimaryPart valido", #Rules.Equipment(equipment) == 0)
check("carro ausente reprova", #Rules.Vehicle(nil) > 0)
car:Destroy()
npc:Destroy()
equipment:Destroy()
return table.concat(report, "\n")
