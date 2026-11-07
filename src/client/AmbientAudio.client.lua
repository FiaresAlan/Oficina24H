--!strict
-- Som ambiente e música (só no cliente):
--   * na rua: ambiente de cidade de dia + cidade pequena; dentro de um prédio (algo acima da cabeça, ex.: telhado da
--     oficina): ambiente de galpão industrial. Troca com fade suave.
--   * música de fundo baixa (APM Music licenciada: funk, hip-hop, chill), em ordem embaralhada, com botão ♪ para
--     ligar/desligar (a escolha fica salva no atributo do jogador durante a sessão).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundIds = require(ReplicatedStorage.Shared.SoundIds)

local player = Players.LocalPlayer

local function loop(id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s:SetAttribute("Alvo", volume)
	s.Parent = SoundService
	s:Play()
	return s
end

local city = loop(SoundIds.CityAmbience, 0.22)
local town = loop(SoundIds.TownAmbience, 0.12)
local workshop = loop(SoundIds.WorkshopAmbience, 0.3)

local function fade(s: Sound, to: number)
	TweenService:Create(s, TweenInfo.new(1.2), { Volume = to }):Play()
end

-- Dentro de um prédio = há um telhado/teto até 25 studs acima da cabeça.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local indoors: boolean? = nil
task.spawn(function()
	while true do
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			params.FilterDescendantsInstances = { character }
			local hit = workspace:Raycast(head.Position, Vector3.new(0, 25, 0), params)
			local inside = hit ~= nil and hit.Instance.Transparency < 0.9
			if inside ~= indoors then
				indoors = inside
				fade(city, inside and 0.05 or (city:GetAttribute("Alvo") :: number))
				fade(town, inside and 0 or (town:GetAttribute("Alvo") :: number))
				fade(workshop, inside and (workshop:GetAttribute("Alvo") :: number) or 0)
			end
		end
		task.wait(0.5)
	end
end)

-- Música ------------------------------------------------------------------------------------------------------------
local MUSIC_VOLUME = 0.18
local music = Instance.new("Sound")
music.Name = "Musica"
music.Volume = MUSIC_VOLUME
music.Parent = SoundService
local playlist = table.clone(SoundIds.Music)
local index = 0
local enabled = true

local function shuffle()
	for i = #playlist, 2, -1 do
		local j = math.random(1, i)
		playlist[i], playlist[j] = playlist[j], playlist[i]
	end
end
shuffle()

local function nextTrack()
	if not enabled then
		return
	end
	index += 1
	if index > #playlist then
		index = 1
		shuffle()
	end
	music.SoundId = playlist[index]
	music.TimePosition = 0
	music:Play()
end
music.Ended:Connect(function()
	task.wait(2)
	nextTrack()
end)
task.delay(3, nextTrack)

-- Botão ♪ (canto de cima, ao lado dos ícones do HUD)
local gui = Instance.new("ScreenGui")
gui.Name = "Musica"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")
local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(1, 0)
button.Position = UDim2.new(1, -168, 0, 70)
button.Size = UDim2.fromOffset(44, 44)
button.BackgroundColor3 = Color3.fromRGB(16, 24, 44)
button.TextColor3 = Color3.fromRGB(255, 196, 40)
button.Font = Enum.Font.GothamBlack
button.TextSize = 24
button.Text = "♪"
button.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 196, 40)
stroke.Thickness = 1.5
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = button
button.Activated:Connect(function()
	enabled = not enabled
	player:SetAttribute("MusicaLigada", enabled)
	button.TextTransparency = enabled and 0 or 0.6
	stroke.Transparency = enabled and 0 or 0.6
	if enabled then
		nextTrack()
	else
		music:Stop()
	end
end)
