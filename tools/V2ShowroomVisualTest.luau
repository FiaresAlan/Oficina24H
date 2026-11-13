-- V2-10: aplicação visual em CLONES, sem scripts, colisão ou perda do original.
local V=require(game.ReplicatedStorage.Shared.V2ShowroomVisual)
local out={}
local function test(n,v)table.insert(out,(v and "PASS " or "FAIL ")..n)end
local original=Instance.new("Model")
local function piece(name,color,material)
    local p=Instance.new("Part")
    p.Name=name
    p.Size=Vector3.new(2,1,1)
    p.Color=color
    p.Material=material or Enum.Material.Metal
    p.Anchored=true
    p.CanCollide=false
    p.Parent=original
    return p
end
local base=piece("BodyPanel",Color3.fromRGB(110,140,170))
local wheel=piece("RimFL",Color3.fromRGB(90,90,92))
local rubber=piece("PneuFR",Color3.fromRGB(19,20,21))
local glass=piece("VidroFrente",Color3.fromRGB(150,188,201),Enum.Material.Glass)
local root=piece("Raiz",Color3.fromRGB(70,71,72))
local tagged=piece("SpecialBody",Color3.fromRGB(134,134,134))
tagged:SetAttribute("V2CosmeticRole","Ignore")
local untouched=base.Color
local copy=original:Clone()
V.Apply(copy,{Stage="Restored",Style="Blue",Finish="Gloss",Wheels="Sport"})
test("o asset fonte não foi alterado",base.Color==untouched)
test("pintura altera só corpo",copy.BodyPanel.Color~=base.Color
    and copy.Raiz.Color==root.Color and copy.VidroFrente.Color==glass.Color)
test("rodas esportivas mudam os aros não a borracha",
    copy.RimFL.Color~=wheel.Color and copy.PneuFR.Color==rubber.Color)
test("atributo Ignore preserva geometria especial",
    copy.SpecialBody.Color==tagged.Color)
test("acabamento brilhante altera reflexo do corpo",copy.BodyPanel.Reflectance>0)
local matte=original:Clone()
V.Apply(matte,{Stage="Restored",Style="Graphite",Finish="Matte",Wheels="Classic"})
test("fosco sem reflexo",matte.BodyPanel.Reflectance==0)
local damaged=original:Clone()
V.Apply(damaged,{Stage="Purchased",Style="Blue",Finish="Gloss",Wheels="Sport"})
test("antes do reparo corpo desgastado, vidro inalterado",
    damaged.BodyPanel.Color~=base.Color
    and damaged.VidroFrente.Color==glass.Color)
test("classificação de raiz, pneu, aro, vidro correta",
    V.Role(root)=="Ignore" and V.Role(rubber)=="Rubber"
    and V.Role(wheel)=="Rim" and V.Role(glass)=="Ignore")
copy:Destroy(); matte:Destroy(); damaged:Destroy(); original:Destroy()
return table.concat(out,"\n")
