local Nav=require(game:GetService("ServerScriptService").Server.V2StaffNavigator)
local reports={}
local function check(name,condition)
    table.insert(reports,(condition and "PASS " or "FAIL ")..name)
end
check("destino no solo e humanoide erguido contam como chegada",
    Nav.HorizontalDistance(Vector3.new(15,3.5,25),Vector3.new(15,0,25))<0.01)
check("distancia horizontal preserva alcance",
    math.abs(Nav.HorizontalDistance(Vector3.new(0,3,0),Vector3.new(3,0,4))-5)<0.01)
check("distancia negativa entre eixos e simetrica",
    Nav.HorizontalDistance(Vector3.new(-4,8,-6),Vector3.new(2,0,4))==
    Nav.HorizontalDistance(Vector3.new(2,0,4),Vector3.new(-4,8,-6)))
check("limites de rota conservadores",
    Nav.MaxRetries<=2 and Nav.MaxWait<=35 and Nav.Reach>=2 and Nav.Reach<=4)
return table.concat(reports,"\n")
