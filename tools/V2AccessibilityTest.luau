-- V2-15: acessibilidade persistente é cosmética e conservadora.
local R=require(game.ReplicatedStorage.Shared.V2AccessibilityRules)
local N=require(game.ReplicatedStorage.Shared.V2NeighborhoodRules)
local out={}
local function test(label,pass)table.insert(out,(pass and "PASS " or "FAIL ")..label)end
local defaults=R.New()
test("preferências de usuário novo são suaves e seguras",
    defaults.DriveHaptics and defaults.DriveSfx
    and defaults.LowDetail==false)
local updated,reason=R.Set(defaults,"DriveHaptics",false)
local changed=updated and R.Set(updated,"DriveSfx",false)
local lighter=changed and R.Set(changed,"LowDetail",true)
test("desligar vibração e som é preservado exatamente como false",
    lighter and lighter.DriveHaptics==false
    and lighter.DriveSfx==false and lighter.LowDetail==true)
test("sanitização de Save/Load preserva explicitamente os três toggles",
    (function()
        local c=R.Sanitize(lighter)
        return c.DriveHaptics==false and c.DriveSfx==false
            and c.LowDetail==true
    end)())
test("valores forjados não alteram o estado salvo",
    not R.Set(lighter,"Coins",true)
    and not R.Set(lighter,"DriveSfx","false")
    and not R.Set(lighter,"LowDetail",1))
test("perfil corrompido migra sem desbloquear ações financeiras",
    (function()
        local c=R.Sanitize({DriveSfx="0",DriveHaptics="0",
            LowDetail="coins",Coins=999999,Rewards=true})
        return c.DriveSfx and c.DriveHaptics
            and c.LowDetail==false and c.Coins==nil
    end)())
local standard=N.Budget(false,60,1)
local reduced=N.Budget(false,60,1,true)
local mobile=N.Budget(true,30,1,true)
test("modo leve reduz NPCs e carros sem mudar gameplay da OS",
    reduced.Pedestrian<=2 and reduced.Vehicle<=1
    and reduced.Total<standard.Total
    and mobile.Total<=reduced.Total)
test("padrão preserva comportamento da V2-07",
    standard.Pedestrian==N.MaxPedestrians
    and standard.Vehicle==N.MaxVehicles)
return table.concat(out,"\n")
