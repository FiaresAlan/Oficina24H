--!strict
-- V2-07: rotas ambientais da cidade e limites puros, sem criar colisores
-- nem interferir em pedidos, rivais ou carros conduzidos pelo servidor.
local Rules={}
Rules.MaxPedestrians=6
Rules.MaxVehicles=3
Rules.MaxActive=9
Rules.MaxPooled=12
Rules.ClientTickSeconds=0.09
Rules.RefreshSeconds=1.35
Rules.DeliverySeconds=14

-- Corredores existentes em BuildCity (rua z=0, calçadas z=+-25;
-- rua lateral x=220). Evitar as entradas em x[-250,50] z~+-80.
-- Trajeto = visual; não é nova malha de navegação nem rua autoritativa.
Rules.Routes={
    {Id="veh_west_n",Kind="Vehicle",From=Vector3.new(-440,0,-8),To=Vector3.new(180,0,-8),Speed=24},
    {Id="veh_east_n",Kind="Vehicle",From=Vector3.new(255,0,-8),To=Vector3.new(445,0,-8),Speed=21},
    {Id="veh_west_s",Kind="Vehicle",From=Vector3.new(182,0,8),To=Vector3.new(-440,0,8),Speed=24},
    {Id="veh_east_s",Kind="Vehicle",From=Vector3.new(445,0,8),To=Vector3.new(260,0,8),Speed=21},
    {Id="veh_side_a",Kind="Vehicle",From=Vector3.new(210,0,48),To=Vector3.new(210,0,275),Speed=18},
    {Id="veh_side_b",Kind="Vehicle",From=Vector3.new(230,0,275),To=Vector3.new(230,0,48),Speed=18},
    {Id="ped_n_west",Kind="Pedestrian",From=Vector3.new(-425,0,-26),To=Vector3.new(-280,0,-26),Speed=4.5},
    {Id="ped_n_center",Kind="Pedestrian",From=Vector3.new(-264,0,-27),To=Vector3.new(182,0,-27),Speed=4.2},
    {Id="ped_n_east",Kind="Pedestrian",From=Vector3.new(260,0,-26),To=Vector3.new(432,0,-26),Speed=4.4},
    {Id="ped_s_west",Kind="Pedestrian",From=Vector3.new(-430,0,26),To=Vector3.new(-270,0,26),Speed=4.6},
    {Id="ped_s_center",Kind="Pedestrian",From=Vector3.new(-255,0,27),To=Vector3.new(181,0,27),Speed=4.1},
    {Id="ped_s_east",Kind="Pedestrian",From=Vector3.new(260,0,27),To=Vector3.new(430,0,27),Speed=4.4},
    {Id="ped_side_e",Kind="Pedestrian",From=Vector3.new(246,0,43),To=Vector3.new(246,0,279),Speed=4.3},
    {Id="ped_side_w",Kind="Pedestrian",From=Vector3.new(194,0,45),To=Vector3.new(194,0,280),Speed=4.3},
    {Id="ped_store",Kind="Pedestrian",From=Vector3.new(108,0,-39),To=Vector3.new(166,0,-39),Speed=3.9},
}
Rules.Courier={Id="courier",Kind="Courier",
    From=Vector3.new(133,0,-58),To=Vector3.new(130,0,-29),Speed=3.8}

local function planar(v: Vector3): Vector3
    return Vector3.new(v.X,0,v.Z)
end

function Rules.Length(route: any): number
    if type(route)~="table" or typeof(route.From)~="Vector3"
        or typeof(route.To)~="Vector3" then return 0 end
    return (planar(route.To)-planar(route.From)).Magnitude
end

function Rules.Distance(route: any,position: any): number
    if typeof(position)~="Vector3" then return math.huge end
    local len=Rules.Length(route)
    if len<0.05 then return math.huge end
    local a,b=planar(route.From),planar(route.To)
    local projection=math.clamp((planar(position)-a):Dot(b-a)/(len*len),0,1)
    return (a+(b-a)*projection-planar(position)).Magnitude
end

-- A animação é monotônica dentro de cada ciclo. Fora do segmento a entidade
-- é reutilizada. Não dá meia-volta instantaneamente na pista.
function Rules.Position(route: any,clock: any,offset: any): (Vector3?,Vector3?)
    local length=Rules.Length(route)
    if length<2 or type(clock)~="number" or clock~=clock
        or clock==math.huge or clock==-math.huge
        or type(offset)~="number" or offset~=offset or offset==math.huge then
        return nil,nil
    end
    local speed=type(route.Speed)=="number" and math.clamp(route.Speed,1,35) or 4
    local ratio=((math.max(0,clock)*speed+offset)%length)/length
    local p=route.From:Lerp(route.To,ratio)
    return p, (route.To-route.From).Unit
end

function Rules.Budget(touch: boolean,fps: number,players: number): any
    local slow=type(fps)~="number" or fps~=fps or fps<36
    local busy=type(players)=="number" and players>=7
    local ped=touch and 3 or Rules.MaxPedestrians
    local car=touch and 1 or Rules.MaxVehicles
    if slow then ped=math.max(1,math.floor(ped/2));car=1 end
    if busy then ped=math.max(1,math.floor(ped/2));car=math.max(1,math.floor(car/2)) end
    return {
        Pedestrian=ped,Vehicle=car,Total=ped+car,
        Range=touch and 145 or 210,
        Tick=slow and 0.18 or Rules.ClientTickSeconds,
    }
end

function Rules.Select(position: Vector3,budget: any,opts: any?): { any }
    local result,candidates={},{}
    local range=type(budget)=="table" and budget.Range or 0
    if range<=0 then return result end
    for _,route in ipairs(Rules.Routes) do
        local distance=Rules.Distance(route,position)
        if distance<=range then
            table.insert(candidates,{Route=route,Distance=distance})
        end
    end
    table.sort(candidates,function(a,b)
        if a.Distance~=b.Distance then return a.Distance<b.Distance end
        return a.Route.Id<b.Route.Id
    end)
    local counts={Vehicle=0,Pedestrian=0}
    for _,candidate in ipairs(candidates) do
        local route=candidate.Route
        local limit=budget[route.Kind] or 0
        if counts[route.Kind]<limit then
            table.insert(result,route)
            counts[route.Kind]+=1
        end
    end
    return result
end

function Rules.Validate(): {string}
    local errs,ids={},{}
    for _,r in ipairs(Rules.Routes) do
        if type(r.Id)~="string" or ids[r.Id] then
            table.insert(errs,"id repetido ou ausente")
        end
        ids[r.Id]=true
        if r.Kind~="Vehicle" and r.Kind~="Pedestrian" then
            table.insert(errs,"categoria inválida: "..tostring(r.Id))
        end
        if Rules.Length(r)<35 or type(r.Speed)~="number" or r.Speed<=0 then
            table.insert(errs,"trajeto inválido: "..tostring(r.Id))
        end
        if r.From.Z*r.To.Z<0 or
            (r.Kind=="Vehicle" and math.abs(r.From.Z)>280) then
            table.insert(errs,"cruza faixa perigosa: "..tostring(r.Id))
        end
    end
    if #Rules.Routes<12 then table.insert(errs,"faltam trajetos ambientais") end
    return errs
end

return Rules
