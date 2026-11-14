-- V2-11: autorização, spam, movimento e checkpoints puramente no servidor.
local R=require(game.ReplicatedStorage.Shared.V2DriveRules)
local report={}
local function check(n,v)table.insert(report,(v and "PASS " or "FAIL ")..n)end
local permitted={
    Owner=true,Active=true,VehicleName="Hatch amarelo",PilotId="Hatch",
    Parked=true,Repairing=false,Delegated=false,EmployeeBusy=false,
    ComponentsClosed=true,SupportRaised=false,Near=true,
    CharacterReady=true,OtherSession=false,JobSession=false,
}
check("Hatch piloto possui OS e assento autorizáveis",R.CanLaunch(permitted))
check("não permite sedan/picape ou modelo inventado",
    not R.PilotEligible("Sedã azul","Sedan")
    and not R.PilotEligible("Picape antiga","Pickup")
    and not R.PilotEligible("Hatch amarelo","Sedan"))
local failCtx={"Owner","Active","Parked","ComponentsClosed","Near","CharacterReady"}
for _,key in ipairs(failCtx) do
    local clone=table.clone(permitted)
    clone[key]=false
    local accepted=R.CanLaunch(clone)
    check("bloqueia lançamento sem "..key,not accepted)
end
for _,key in ipairs({"Repairing","Delegated","EmployeeBusy",
    "SupportRaised","OtherSession","JobSession"}) do
    local clone=table.clone(permitted)
    clone[key]=true
    local allowed=R.CanLaunch(clone)
    check("bloqueia sessão ocupada/concorrente "..key,not allowed)
end
check("proíbe motorista de outra conta no banco",
    R.PermittedOccupant(100,100)
    and not R.PermittedOccupant(100,101)
    and not R.PermittedOccupant(0,0))
local gas,angle=R.Controls(4,-8)
check("input clamped, torque/ângulo no servidor",
    gas==-R.MotorAngularSpeed
    and angle==R.SteerAngle)
local reverse,turn=R.Controls(-1,0.5)
check("ré limitada e esterço proporcional",
    reverse<0 and math.abs(reverse)<gas and turn==R.SteerAngle/2)
local nan=0/0
local noGas,noTurn=R.Controls(nan,math.huge)
check("NaN e Infinity não aceleram",noGas==0 and noTurn==0)
local origin=Vector3.new(0,4,0)
local ok=R.AssessMotion(origin,origin,Vector3.new(4,4,0),
    Vector3.new(25,0,0),0.2)
check("movimento plausível observado pelo servidor",ok)
local tooFast=R.AssessMotion(origin,origin,Vector3.new(3,4,0),
    Vector3.new(200,0,0),.2)
check("velocidade absurda é rejeitada",not tooFast)
local teleport=R.AssessMotion(origin,origin,Vector3.new(175,4,0),
    Vector3.new(5,0,0),.2)
check("teleporte instantâneo é rejeitado",not teleport)
local far=R.AssessMotion(origin,Vector3.new(255,4,0),
    Vector3.new(270,4,0),Vector3.zero,.4)
check("raio da oficina é limite",not far)
local falling=R.AssessMotion(origin,origin,
    Vector3.new(0,-40,0),Vector3.new(0,-20,0),.2)
check("queda vertical insegura é rejeitada",not falling)
local floating=R.AssessMotion(origin,origin,
    Vector3.new(0,70,0),Vector3.zero,.2)
check("altura incompatível é rejeitada",not floating)
local invalid=R.AssessMotion(origin,origin,
    Vector3.new(nan,1,2),Vector3.zero,.2)
check("coordenadas NaN não passam pelo servidor",not invalid)
local negativeTime=R.AssessMotion(origin,origin,origin,Vector3.zero,-1)
check("tempo inválido não permite movimento",not negativeTime)
local state=R.CheckpointState()
local coords={
    Vector3.new(10,3,0),Vector3.new(30,3,0),
    Vector3.new(45,3,0),Vector3.new(0,3,0),
}
check("checkpoint fora de ordem é ignorado",
    not R.Advance(state,coords,1,coords[2]) and state.Passed==0)
check("primeira passagem observada no servidor é aceita",
    R.Advance(state,coords,2,coords[1]) and state.Passed==1)
check("spam no mesmo instante não avança",
    not R.Advance(state,coords,2,coords[2]) and state.Passed==1)
check("checkpoint em altura forjada é rejeitado",
    not R.Advance(state,coords,4,coords[2]+Vector3.new(0,100,0)))
check("sequência real completa termina sem dinheiro",
    R.Advance(state,coords,5,coords[2])
    and R.Advance(state,coords,7,coords[3])
    and R.Advance(state,coords,9,coords[4])
    and state.Done and state.Passed==4
    and state.Index==5 and state.Reward==nil)
check("replay da rota completa não ganha nada",
    not R.Advance(state,coords,20,coords[4]) and state.Passed==4)
check("configuração limita 150 segundos, velocidade e alcance",
    R.MaximumSeconds==150 and R.MaxSpeed<=55 and R.MaxRadius<=300)
return table.concat(report,"\n")
