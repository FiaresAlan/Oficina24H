-- Regressões dos encaixes customizados por veículo.
local Rules = require(game.ReplicatedStorage.Shared.RepairSocketRules)
local Prep = require(game.ReplicatedStorage.Shared.RepairPrepRules)
local results = {}
local function check(name, ok)
	table.insert(results, (ok and "PASS " or "FAIL ") .. name)
end

local car = Instance.new("Model")
local root = Instance.new("Part")
root.Name = "Raiz"
root.Anchored = true
root.CFrame = CFrame.new(20, 3, -10) * CFrame.Angles(0, math.rad(35), 0)
root.Parent = car
car.PrimaryPart = root

check("cinco nomes oficiais de sockets", Rules.Name("WheelBolts") == "OficinaSocket_WheelBolts"
	and Rules.Name("JackSupport") == "OficinaSocket_JackSupport"
	and Rules.Name("HoodRelease") == "OficinaSocket_HoodRelease"
	and Rules.Name("BatteryBracket") == "OficinaSocket_BatteryBracket"
	and Rules.Name("DrainPan") == "OficinaSocket_DrainPan")
check("socket desconhecido nao e aceito", Rules.Name("GrantCoins") == nil and Rules.Name(123) == nil)
local fallback = Prep.Offsets(8, 18, 5).WheelBolts
local cf, source = Rules.Resolve(car, root, "WheelBolts", fallback)
check("sem attachment, posicao relativa correta", (cf.Position - (root.CFrame * fallback)).Magnitude < 0.001)
check("sem attachment, origem sinalizada", source == "DimensionFallback")

local fake = Instance.new("Part")
fake.Name = "OficinaSocket_WheelBolts"
fake.Parent = car
local fakeFrame, fakeSource = Rules.Resolve(car, root, "WheelBolts", fallback)
check("part com nome igual nao substitui Attachment", fakeSource == "DimensionFallback"
	and (fakeFrame.Position - cf.Position).Magnitude < 0.001)
fake:Destroy()

local mount = Instance.new("Part")
mount.Name = "EngineBay"
mount.CFrame = root.CFrame * CFrame.new(-1, 1, -5)
mount.Parent = car
local attachment = Instance.new("Attachment")
attachment.Name = "OficinaSocket_WheelBolts"
attachment.CFrame = CFrame.new(0.2, 0.3, 0.4) * CFrame.Angles(0, 0, math.rad(20))
attachment.Parent = mount
local resolved, resolvedSource = Rules.Resolve(car, root, "WheelBolts", fallback)
check("attachment do carro tem prioridade", resolvedSource == "ModelAttachment")
check("posicao exata do attachment preservada", (resolved.Position - attachment.WorldPosition).Magnitude < 0.001)
check("rotacao do attachment preservada", resolved.LookVector:Dot(attachment.WorldCFrame.LookVector) > 0.999)
local other, otherSource = Rules.Resolve(car, root, "JackSupport", Prep.Offsets(8, 18, 5).JackSupport)
check("socket nao cadastrado ainda usa fallback", otherSource == "DimensionFallback")
check("attachment pertence ao carro correto", attachment:IsDescendantOf(car))
car:Destroy()
return table.concat(results, "\n")
