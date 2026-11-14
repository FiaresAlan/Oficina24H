--!strict
-- V2-11: UX da condução piloto. Câmera e entrada WASD/setas,
-- gamepad e touch. Cliente NÃO envia posição, velocidade nem crédito.
-- A física, autorização, tempo e progresso são propriedade do servidor.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("OficinaRemotes")
local driveInput=remotes:WaitForChild("DriveInput") :: RemoteEvent
local Store=require(script.Parent.UI.Store)

local currentSeat: VehicleSeat?=nil
local currentJob: string?=nil
local inputConnection: RBXScriptConnection?=nil
local characterConnection: RBXScriptConnection?=nil
local hud: ScreenGui?=nil
local prevCameraSubject: Instance?=nil
local prevCameraType: Enum.CameraType?=nil
local prevFov: number?=nil
local touchState={Forward=false,Backward=false,Left=false,Right=false}
local touchPresses: {[InputObject]: string}={}
local touchEndConnection: RBXScriptConnection?=nil

local function hudForDrive(): (ScreenGui,TextLabel)
    local gui=Instance.new("ScreenGui")
    gui.Name="V2PilotDriveHUD"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=false
    gui.DisplayOrder=12
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local frame=Instance.new("Frame")
    frame.Name="DriveStatus"
    frame.AnchorPoint=Vector2.new(.5,0)
    frame.Position=UDim2.new(.5,0,0,12)
    frame.Size=UDim2.new(0,280,0,72)
    frame.BorderSizePixel=0
    frame.BackgroundColor3=Color3.fromRGB(20,30,42)
    frame.BackgroundTransparency=.20
    frame.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,12)
    corner.Parent=frame
    local label=Instance.new("TextLabel")
    label.Name="SpeedAndCheckpoints"
    label.Size=UDim2.new(1,-18,1,-10)
    label.Position=UDim2.fromOffset(9,5)
    label.BackgroundTransparency=1
    label.TextColor3=Color3.fromRGB(243,248,255)
    label.Font=Enum.Font.GothamBold
    label.TextSize=17
    label.TextWrapped=true
    label.Text="TEST-DRIVE · aguarde o servidor"
    label.Parent=frame
    gui.Parent=player:WaitForChild("PlayerGui")
    return gui,label
end

local function stop()
    if inputConnection then inputConnection:Disconnect() end
    inputConnection=nil
    if touchEndConnection then touchEndConnection:Disconnect() end
    touchEndConnection=nil
    table.clear(touchPresses)
    for key in pairs(touchState) do touchState[key]=false end
    if currentSeat and currentJob then
        driveInput:FireServer(currentJob,0,0)
    end
    currentSeat=nil
    currentJob=nil
    CAS:UnbindAction("V2DriveReturn")
    if hud then hud:Destroy() end
    hud=nil
    local camera=workspace.CurrentCamera
    if camera then
        if prevCameraSubject and prevCameraSubject.Parent then
            camera.CameraSubject=prevCameraSubject
        elseif player.Character then
            local humanoid=player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then camera.CameraSubject=humanoid end
        end
        camera.CameraType=prevCameraType or Enum.CameraType.Custom
        camera.FieldOfView=prevFov or 70
    end
    prevCameraSubject=nil
    prevCameraType=nil
    prevFov=nil
end

local function readInput(seat: VehicleSeat): (number,number)
    -- Native Seat controla gamepad e touch. O fallback do teclado independe
    -- da replicação de ThrottleFloat/SteerFloat para o servidor.
    local throttle=seat.ThrottleFloat
    local steer=seat.SteerFloat
    if UIS.KeyboardEnabled then
        local forward=UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up)
        local backward=UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down)
        local left=UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left)
        local right=UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right)
        if forward or backward then throttle=(forward and 1 or 0)-(backward and 1 or 0) end
        if left or right then steer=(right and 1 or 0)-(left and 1 or 0) end
    end
    if UIS.GamepadEnabled then
        for _,state in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
            if state.KeyCode==Enum.KeyCode.Thumbstick1 and math.abs(state.Position.X)>.1 then
                steer=state.Position.X
            elseif state.KeyCode==Enum.KeyCode.ButtonR2 and state.Position.Z>.1 then
                throttle=state.Position.Z
            elseif state.KeyCode==Enum.KeyCode.ButtonL2 and state.Position.Z>.1 then
                throttle=-state.Position.Z
            end
        end
    end
    if UIS.TouchEnabled then
        if touchState.Forward or touchState.Backward then
            throttle=(touchState.Forward and 1 or 0)-(touchState.Backward and 1 or 0)
        end
        if touchState.Left or touchState.Right then
            steer=(touchState.Right and 1 or 0)-(touchState.Left and 1 or 0)
        end
    end
    return math.clamp(throttle,-1,1),math.clamp(steer,-1,1)
end

local function start(seat: VehicleSeat)
    local rig=seat.Parent
    local jobId=rig and rig:GetAttribute("JobId")
    local ownerId=rig and rig:GetAttribute("OwnerUserId")
    if not rig or not rig:IsA("Model") or rig:GetAttribute("V2Drive")~=true
        or type(jobId)~="string" or ownerId~=player.UserId then return end
    if currentSeat==seat then return end
    stop()
    currentSeat=seat
    currentJob=jobId
    local camera=workspace.CurrentCamera
    if camera then
        prevCameraSubject=camera.CameraSubject
        prevCameraType=camera.CameraType
        prevFov=camera.FieldOfView
        camera.CameraType=Enum.CameraType.Custom
        camera.CameraSubject=seat
        camera.FieldOfView=76
    end
    local newGui,label=hudForDrive()
    hud=newGui
    -- Botões de toque próprios, sem bloquear centro da tela nem esperar
    -- que o controlador padrão do VehicleSeat tenha UI do jogo instalada.
    if UIS.TouchEnabled then
        local function touchButton(name: string,title: string,x: number,y: number)
            local button=Instance.new("TextButton")
            button.Name="DriveTouch_"..name
            button.AnchorPoint=Vector2.new(.5,.5)
            button.Position=UDim2.fromScale(x,y)
            button.Size=UDim2.fromOffset(58,58)
            button.BackgroundColor3=Color3.fromRGB(23,42,62)
            button.BackgroundTransparency=.19
            button.TextColor3=Color3.fromRGB(245,250,255)
            button.Font=Enum.Font.GothamBold
            button.TextSize=28
            button.Text=title
            button.Parent=newGui
            local round=Instance.new("UICorner")
            round.CornerRadius=UDim.new(0,14)
            round.Parent=button
            button.InputBegan:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.Touch
                    or input.UserInputType==Enum.UserInputType.MouseButton1 then
                    touchPresses[input]=name
                    touchState[name]=true
                end
            end)
            button.InputEnded:Connect(function(input)
                if touchPresses[input]==name then
                    touchPresses[input]=nil
                    touchState[name]=false
                end
            end)
        end
        touchButton("Left","◀",.69,.82)
        touchButton("Right","▶",.79,.82)
        touchButton("Forward","▲",.89,.71)
        touchButton("Backward","▼",.89,.84)
        touchEndConnection=UIS.InputEnded:Connect(function(input)
            local key=touchPresses[input]
            if key then
                touchPresses[input]=nil
                touchState[key]=false
            end
        end)
    end
    CAS:BindAction("V2DriveReturn",function(_,state)
        if state==Enum.UserInputState.Begin and currentJob then
            Store.Act("DriveCar",{JobId=currentJob,Mode="Return"})
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end,true,Enum.KeyCode.Backspace,Enum.KeyCode.ButtonB)
    CAS:SetTitle("V2DriveReturn","BOX")
    CAS:SetPosition("V2DriveReturn",UDim2.fromScale(.77,.66))
    local elapsed=0
    inputConnection=RunService.Heartbeat:Connect(function(dt)
        if currentSeat~=seat or not seat.Parent or not rig.Parent then
            stop()
            return
        end
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.SeatPart~=seat then
            stop()
            return
        end
        elapsed+=dt
        if elapsed<.10 then return end
        elapsed=0
        local throttle,steer=readInput(seat)
        driveInput:FireServer(jobId,throttle,steer)
        local chassis=rig.PrimaryPart
        local studsPerSecond=chassis and chassis.AssemblyLinearVelocity.Magnitude or 0
        local passed=rig:GetAttribute("Checkpoints") or 0
        local routeDone=rig:GetAttribute("RouteDone")==true
        label.Text=string.format("HATCH PILOTO · %d studs/s\nCHECKPOINTS %d/4%s · VOLTAR: BOX",
            math.floor(studsPerSecond+0.5),passed,routeDone and " · ROTA OK" or "")
    end)
end

local function listen(character: Model)
    if characterConnection then characterConnection:Disconnect() end
    local humanoid=character:WaitForChild("Humanoid",10)
    if not humanoid or not humanoid:IsA("Humanoid") then return end
    characterConnection=humanoid.Seated:Connect(function(active,seat)
        if active and seat and seat:IsA("VehicleSeat")
            and seat:GetAttribute("V2DriveSeat")==true then
            start(seat)
        elseif currentSeat then
            stop()
        end
    end)
    if humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat")
        and humanoid.SeatPart:GetAttribute("V2DriveSeat")==true then
        start(humanoid.SeatPart)
    end
end

player.CharacterAdded:Connect(function(character)
    stop()
    task.spawn(listen,character)
end)
if player.Character then task.spawn(listen,player.Character) end
