-- V2-11: auditoria do rig com assento real, quatro motores, direção,
-- sem scripts de asset. Só executa na suíte Edit do Roblox Studio.
local Vehicle=require(game.ServerScriptService.Server.VehicleService)
local Drive=require(game.ServerScriptService.Server.V2DriveService)
local out={}
local function test(n,v)table.insert(out,(v and "PASS " or "FAIL ")..n)end
local id="V2DriveRigAudit_"..tostring(math.random(10000,99999))
local fake=Instance.new("Model")
fake.Name="VeiculoOriginalNaoDestruir"
local root=Instance.new("Part")
root.Name="Raiz"
root.Size=Vector3.new(1,1,1)
root.CFrame=CFrame.new(3000,4,3000)
root.Anchored=true
root.Parent=fake
fake.PrimaryPart=root
fake.Parent=workspace
local actor={UserId=314159,DisplayName="Auditoria Piloto"}
local ok,rig,seat,chassis,motors,steering=pcall(function()
    return Drive._buildRigForTesting(fake,actor,id)
end)
test("rig piloto físico pode ser montado no Edit",ok and rig~=nil)
if ok and rig then
    test("assento real para teclado/gamepad/touch",
        seat:IsA("VehicleSeat") and seat:GetAttribute("V2DriveSeat")==true
        and rig:GetAttribute("OwnerUserId")==actor.UserId
        and rig:GetAttribute("JobId")==id)
    test("quatro rodas com motores HingeConstraint físicos",
        #motors==4 and #rig:GetDescendants()>15
        and (function()
            for _,motor in ipairs(motors) do
                if not motor:IsA("HingeConstraint")
                    or motor.ActuatorType~=Enum.ActuatorType.Motor
                    or not motor.Attachment0 or not motor.Attachment1 then return false end
            end
            return true
        end)())
    test("dois eixos dianteiros com servo de direção",
        #steering==2 and (function()
            for _,servo in ipairs(steering) do
                if servo.ActuatorType~=Enum.ActuatorType.Servo
                    or not servo.Attachment0 or not servo.Attachment1 then return false end
            end
            return true
        end)())
    local unanchored=true
    local noScripts=true
    local count=0
    for _,p in ipairs(rig:GetDescendants()) do
        if p:IsA("BasePart") then
            count+=1
            if p.Anchored then unanchored=false end
        elseif p:IsA("Script") or p:IsA("LocalScript")
            or p:IsA("ModuleScript") then noScripts=false end
    end
    test("nenhuma parte do carro dirigível é ancorada",count>=12 and unanchored)
    test("asset físico não possui scripts de terceiros",noScripts)
    test("assento não dirige automaticamente como NPC",seat.Torque==0)
    test("carro de teste não substitui OS",rig:GetAttribute("Earned")==nil
        and rig:GetAttribute("CustomerReward")==nil
        and fake.Parent==workspace)
    rig:Destroy()
else
    test("falha de montagem física exige correção Studio",false)
end
test("carro de origem permanece no lugar",fake.PrimaryPart==root
    and root.Anchored and root.Parent==fake)
fake:Destroy()
return table.concat(out,"\n")
