--!strict
-- V2-05: navegação de mecânicos com cancelamento, 2 recálculos e SEM teleporte.
-- Uma falha de rota interrompe o serviço e libera a OS; jamais cria pagamento.
local PathfindingService=game:GetService("PathfindingService")
local Nav={}
Nav.MaxRetries=2
Nav.Reach=3.2
Nav.MaxWait=35

-- Destinos foram construídos em coordenadas de SOLO, mas HumanoidRootPart
-- caminha 2-4 studs acima do chão. Medir XY/Z faria uma rota válida falhar.
function Nav.HorizontalDistance(a: Vector3,b: Vector3): number
    return (Vector3.new(a.X,0,a.Z)-Vector3.new(b.X,0,b.Z)).Magnitude
end

local function alive(npc: Model, valid: () -> boolean): boolean
    return npc.Parent~=nil and npc.PrimaryPart~=nil and valid()
end

local function leg(npc: Model, dest: Vector3, valid: () -> boolean): boolean
    local humanoid=npc:FindFirstChildOfClass("Humanoid")
    local root=npc.PrimaryPart
    if not humanoid or not root or not root:IsA("BasePart") then return false end
    local maxWait=math.clamp(Nav.HorizontalDistance(root.Position,dest)/9+4,4,Nav.MaxWait)
    local start=os.clock()
    local lastProgress=start
    local best=math.huge
    humanoid:MoveTo(dest)
    while alive(npc,valid) and os.clock()-start<maxWait do
        local remaining=Nav.HorizontalDistance(root.Position,dest)
        if remaining<=Nav.Reach then humanoid:Move(Vector3.zero);return true end
        if remaining<best-0.3 then
            best=remaining
            lastProgress=os.clock()
        elseif os.clock()-lastProgress>3.5 then break end
        task.wait(0.15)
    end
    humanoid:Move(Vector3.zero)
    return false
end

function Nav.Travel(npc: Model, dest: Vector3, animator: any, valid: () -> boolean): boolean
    if typeof(dest)~="Vector3" or not alive(npc,valid) then return false end
    if animator then animator.Walk() end
    local humanoid=npc:FindFirstChildOfClass("Humanoid")
    local reached=false
    for attempt=1,Nav.MaxRetries+1 do
        if not alive(npc,valid) then break end
        local root=npc.PrimaryPart
        if Nav.HorizontalDistance(root.Position,dest)<=Nav.Reach then reached=true;break end
        local ok,path=pcall(function()
            local p=PathfindingService:CreatePath({
                AgentRadius=2,AgentHeight=5,AgentCanJump=false,
                WaypointSpacing=4,
            })
            p:ComputeAsync(root.Position,dest)
            return p
        end)
        if not alive(npc,valid) then break end
        local points={}
        if ok and path and path.Status==Enum.PathStatus.Success then
            for _,waypoint in ipairs(path:GetWaypoints()) do
                table.insert(points,waypoint.Position)
            end
        elseif Nav.HorizontalDistance(root.Position,dest)<=12 then
            -- Travessia direta curta para lugares com navmesh não calculada.
            points={dest}
        else
            break -- sem teleporte por paredes ou cruzando a rua
        end
        local complete=true
        for _,point in ipairs(points) do
            if not leg(npc,point,valid) then complete=false;break end
        end
        if complete and alive(npc,valid) and
            Nav.HorizontalDistance(npc.PrimaryPart.Position,dest)<=Nav.Reach then
            reached=true;break
        end
        -- na falha de caminho, recomeça do ponto real em que ficou
    end
    if humanoid then humanoid:Move(Vector3.zero) end
    if animator then animator.Idle() end
    return reached and alive(npc,valid)
end

return Nav
