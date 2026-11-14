-- V2-11: rollback de um carro estacionado, sem alterar OS e sem
-- destruir NPCs, vagas, attachments nem flags visuais dos assets.
local Vehicle=require(game.ServerScriptService.Server.VehicleService)
local out={}
local function test(n,v)table.insert(out,(v and "PASS " or "FAIL ")..n)end
local jobsFolder=workspace:FindFirstChild("Plots")
local createdFolder=false
if not jobsFolder then
    jobsFolder=Instance.new("Folder")
    jobsFolder.Name="Plots"
    jobsFolder.Parent=workspace
    createdFolder=true
end
local jobId="QA_DRV_"..tostring(math.random(10000,99999))
local ownerId=79123456
local plot=Instance.new("Folder")
plot.Name="PlotV2DriverQA"
plot:SetAttribute("OwnerUserId",ownerId)
plot.Parent=jobsFolder
local bay=Instance.new("Part")
bay.Name="BayTest"
bay.Size=Vector3.new(10,1,20)
bay.Anchored=true
bay.CFrame=CFrame.new(2200,1,2200)
bay:SetAttribute("JobId",jobId)
bay.Parent=plot
local car=Instance.new("Model")
car.Name=jobId
local root=Instance.new("Part")
root.Name="Raiz"
root.Size=Vector3.new(1,1,1)
root.CFrame=CFrame.new(2200,3,2200)
root.Anchored=true
root.Transparency=0
root.Parent=car
car.PrimaryPart=root
local shell=Instance.new("Part")
shell.Name="Visual"
shell.Anchored=true
shell.Size=Vector3.new(7,3,15)
shell.CFrame=root.CFrame
shell.CanCollide=false
shell.CanTouch=true
shell.CanQuery=true
shell.Transparency=.1
shell.Parent=car
local hull=Instance.new("Part")
hull.Name="Casco"
hull.Size=Vector3.new(7,3,15)
hull.Anchored=true
hull.CFrame=root.CFrame
hull.CanCollide=true
hull.Transparency=1
hull.Parent=car
car:SetAttribute("OwnerUserId",ownerId)
car:SetAttribute("JobId",jobId)
car:SetAttribute("BayName",bay.Name)
car:SetAttribute("V2PilotId","Hatch")
car:SetAttribute("Estacionado",true)
car:SetAttribute("Reparando",false)
car.Parent=workspace
test("registro de carro só para teste Edit",Vehicle._qaRegisterDriveCar(jobId,car))
local invalid=Vehicle.SuspendForDrive(jobId,ownerId+1)
test("não suspende veículo de outro jogador",invalid==nil
    and car:GetAttribute("Estacionado")==true and hull.CanCollide)
local original=car:GetPivot()
local paused,whichBay=Vehicle.SuspendForDrive(jobId,ownerId)
test("carro correto suspenso no mesmo box",paused==car and whichBay==bay
    and bay:GetAttribute("JobId")==jobId and not Vehicle.IsParked(jobId))
test("original some e desativa todas as colisões enquanto o clone dirige",
    root.Transparency==1 and shell.Transparency==1 and hull.Transparency==1
    and not root.CanCollide and not shell.CanCollide and not hull.CanCollide
    and not shell.CanTouch and not shell.CanQuery)
local second=Vehicle.SuspendForDrive(jobId,ownerId)
test("replay da suspensão não altera slot nem reconfigura o carro",
    second==nil and bay:GetAttribute("JobId")==jobId)
Vehicle.ResumeFromDrive(jobId)
test("rollback devolve todos os materiais e propriedades originais",
    Vehicle.IsParked(jobId)
    and root.Transparency==0 and shell.Transparency==.1
    and hull.Transparency==1 and hull.CanCollide
    and shell.CanTouch and shell.CanQuery)
test("volta no CFrame exato, não clona Job/OS",car:GetPivot()==original
    and bay:GetAttribute("JobId")==jobId
    and car:GetAttribute("JobId")==jobId)
Vehicle.ResumeFromDrive(jobId)
test("segundo rollback é idempotente",Vehicle.IsParked(jobId)
    and shell.Transparency==.1 and hull.CanCollide)
car:SetAttribute("V2SupportPlaced",true)
local supported=Vehicle.SuspendForDrive(jobId,ownerId)
test("elevador erguido impede saída",supported==nil)
car:SetAttribute("V2SupportPlaced",false)
car:SetAttribute("V2State_WheelFL","Detached")
local dismantled=Vehicle.SuspendForDrive(jobId,ownerId)
test("roda desmontada impede saída",dismantled==nil)
car:SetAttribute("V2State_WheelFL","Mounted")
local again=Vehicle.SuspendForDrive(jobId,ownerId)
test("pode iniciar outro ciclo depois de fechar o carro",again==car)
Vehicle._qaClearDriveCar(jobId)
test("limpeza Edit não deixa carro travado",Vehicle.IsParked(jobId)==false
    and hull.CanCollide and shell.Transparency==.1)
car:Destroy();plot:Destroy()
if createdFolder then jobsFolder:Destroy() end
return table.concat(out,"\n")
