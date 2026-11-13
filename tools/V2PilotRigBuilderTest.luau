local R=require(game:GetService("ReplicatedStorage").Shared.V2PilotRigBuilder)
local P=require(game:GetService("ReplicatedStorage").Shared.V2VehiclePilotRules)
local out={}
local function check(name,ok) table.insert(out,(ok and "PASS " or "FAIL ")..name) end
local m=Instance.new("Model")
local root=Instance.new("Part") root.Name="Raiz" root.Anchored=true root.Parent=m m.PrimaryPart=root
m:SetAttribute("Largura",8) m:SetAttribute("Comprimento",16) m:SetAttribute("Altura",4)
check("nao altera veiculo comum",R.Attach(m,"SUV familiar")==false and m:GetAttribute("V2PilotId")==nil)
local ok,n=R.Attach(m,"Hatch amarelo")
check("gera todos os oito pivots",ok and n==#P.Pivots)
check("detecta piloto",m:GetAttribute("V2PilotId")=="Hatch")
check("idempotente, nao duplica",select(2,R.Attach(m,"Hatch amarelo"))==0)
local cf=P.Resolve(m,"V2Pivot_Hood")
check("pivo 3D valido",cf~=nil and cf.Position.Y>root.Position.Y)
check("nao gera Model extra",#m:GetChildren()==1)
m:Destroy()
return table.concat(out,"\n")
