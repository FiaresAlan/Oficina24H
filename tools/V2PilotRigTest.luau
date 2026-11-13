-- V2-01: modelos falsos em memoria, nao altera place.
local Rules = require(game:GetService("ReplicatedStorage").Shared.V2VehiclePilotRules)
local out={}
local function test(name,ok) table.insert(out,(ok and "PASS " or "FAIL ")..name) end
test("3 modelos catalogo", #Rules.Pilots==3 and #Rules.ValidateCatalog()==0)
local car=Instance.new("Model")
local root=Instance.new("Part") root.Name="Raiz" root.Anchored=true root.Parent=car car.PrimaryPart=root
local hull=Instance.new("Part") hull.Name="Casco" hull.CanCollide=true hull.Parent=car
local weld=Instance.new("WeldConstraint") weld.Part0=root weld.Part1=hull weld.Parent=root
car:SetAttribute("Largura",8) car:SetAttribute("Comprimento",16)
car:SetAttribute("Altura",4) car:SetAttribute("Motorista",Vector3.new(0,2,0))
local err,warn=Rules.Inspect(car)
test("pivot pendente e aviso, nao erro", #err==0 and #warn>0)
test("nao inventa pivot", Rules.Resolve(car,"V2Pivot_Hood")==nil)
local pivot=Instance.new("Attachment") pivot.Name="V2Pivot_Hood" pivot.Parent=root
err=Rules.Inspect(car)
test("pivot real aceito", #err==0 and Rules.Resolve(car,"V2Pivot_Hood")==pivot.WorldCFrame)
local extra=Instance.new("Attachment") extra.Name="V2Pivot_Hood" extra.Parent=hull
err=Rules.Inspect(car)
test("pivot duplicado rejeitado",#err>0)
extra:Destroy() pivot.Parent=car
err=Rules.Inspect(car)
test("pivot sem BasePart rejeitado",#err>0)
test("pivot desconhecido retorna nil",Rules.Resolve(car,"V2Pivot_DoesNotExist")==nil)
car:Destroy()
return table.concat(out,"\n")
