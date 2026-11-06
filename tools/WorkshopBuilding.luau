-- Constrói o prédio da oficina com INTERIOR ACESSÍVEL (Parts), no fundo do lote, fachada voltada para a rua.
-- Uso: local model = require(WorkshopBuilding).Build(plot, accentColor) -> Model "Oficina" (Parent = plot).
-- Espaço local do prédio: origem no centro da base do lote ao nível do piso; +X lateral; +Z em direção ao fundo.
-- Prédio ocupa x[-21,21], z[6,34], altura 14. Portas: porta de pessoa (x -8..-3), portão da oficina (x -1..21, aberto).
-- As 2 vagas dos carros ficam DENTRO do prédio, sob o portão (ver shared/Layout).
local Layout = require(game:GetService("ReplicatedStorage").Shared.Layout:Clone())
local WorkshopBuilding = {}

local WALL = Color3.fromRGB(176, 170, 158)
local WALL_DARK = Color3.fromRGB(88, 92, 100)
local FLOOR = Color3.fromRGB(112, 114, 118)
local ROOF = Color3.fromRGB(62, 64, 70)
local WOOD = Color3.fromRGB(120, 88, 58)
local STEEL = Color3.fromRGB(150, 154, 162)
local DARK = Color3.fromRGB(38, 40, 46)
local RED = Color3.fromRGB(190, 45, 45)
local GLASS = Color3.fromRGB(150, 205, 235)

function WorkshopBuilding.Build(plot: Instance, accent: Color3): Model
	local base = plot:FindFirstChild("Base") :: BasePart
	local side = plot:GetAttribute("Side") :: number
	local floorY = base.Position.Y + base.Size.Y / 2
	local root = CFrame.new(base.Position.X, floorY, base.Position.Z) * CFrame.Angles(0, side == -1 and math.pi or 0, 0)

	local model = Instance.new("Model")
	model.Name = "Oficina"

	-- Caixa alinhada aos eixos locais, definida por faixas [x0,x1] [y0,y1] [z0,z1].
	local function box(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, material: Enum.Material?, parent: Instance?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
		p.CFrame = root * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		p.Anchored = true
		p.Color = color
		p.Material = material or Enum.Material.Concrete
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent or model
		return p
	end
	local function glass(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
		local p = box(name, x0, x1, y0, y1, z0, z1, GLASS, Enum.Material.Glass)
		p.Transparency = 0.55
		p.CanCollide = true
		return p
	end
	-- Cilindro com eixo vertical local (Part Cylinder tem eixo em X: gira 90 graus em Z).
	local function cylinder(name: string, cx: number, cy: number, cz: number, radius: number, height: number, color: Color3, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(height, radius * 2, radius * 2)
		p.CFrame = root * CFrame.new(cx, cy, cz) * CFrame.Angles(0, 0, math.rad(90))
		p.Anchored = true
		p.Color = color
		p.Material = material or Enum.Material.Metal
		p.Parent = model
		return p
	end

	local H = 14
	-- Piso interno
	box("Piso", -21, 21, 0, 0.3, 6, 34, FLOOR, Enum.Material.Concrete)
	box("FaixaPiso", -21, 21, 0.3, 0.36, 8, 9, accent, Enum.Material.Neon).CanCollide = false

	-- Parede frontal (z 6..7) com janela, porta de pessoa e portão da oficina
	local FZ0, FZ1 = 6, 7
	box("FrenteA", -21, -18, 0, H, FZ0, FZ1, WALL)
	box("JanelaBaixo", -18, -10, 0, 4, FZ0, FZ1, WALL)
	box("JanelaCima", -18, -10, 8, H, FZ0, FZ1, WALL)
	glass("JanelaVidro", -18, -10, 4, 8, 6.4, 6.6)
	box("FrenteB", -10, -8, 0, H, FZ0, FZ1, WALL)
	box("PortaVerga", -8, -3, 9, H, FZ0, FZ1, WALL)
	box("FrenteC", -3, -1, 0, H, FZ0, FZ1, WALL)
	box("PortaoVerga", -1, 21, 11, H, FZ0, FZ1, WALL)
	-- Rolo do portão enrolado acima da abertura e batentes
	box("PortaoRolo", -1, 21, 10.2, 11, 5.6, 6.9, STEEL, Enum.Material.Metal).CanCollide = false
	box("BatentePorta", -8, -7.6, 0, 9, 5.6, 7, DARK, Enum.Material.Metal)
	box("BatentePorta", -3.4, -3, 0, 9, 5.6, 7, DARK, Enum.Material.Metal)
	-- Faixa luminosa na cor do lote sobre a fachada
	box("Faixa", -21, 21, 12.2, 13.2, 5.7, 6, accent, Enum.Material.Neon).CanCollide = false
	-- Rodapé escuro externo
	box("Rodape", -21, 21, 0, 1.2, 5.8, 6, WALL_DARK)

	-- Parede do fundo e laterais
	box("Fundo", -21, 21, 0, H, 33, 34, WALL)
	box("LateralDir", 20, 21, 0, H, 7, 33, WALL)
	-- Lateral esquerda com janela (z 14..22)
	box("LateralEsqA", -21, -20, 0, H, 7, 14, WALL)
	box("LateralEsqB", -21, -20, 0, H, 22, 33, WALL)
	box("LateralEsqBaixo", -21, -20, 0, 4, 14, 22, WALL)
	box("LateralEsqCima", -21, -20, 9, H, 14, 22, WALL)
	glass("LateralEsqVidro", -20.6, -20.4, 4, 9, 14, 22)

	-- Teto com beiral
	box("Teto", -22.5, 22.5, H, H + 1, 4.5, 35.5, ROOF, Enum.Material.Concrete)
	box("TetoPlatibanda", -22.5, 22.5, H + 1, H + 1.6, 4.5, 5.1, WALL_DARK, Enum.Material.Concrete)

	-- Luminárias (barras de LED com luz real)
	for _, lx in ipairs({ -10, 10 }) do
		for _, lz in ipairs({ 14, 26 }) do
			local bar = box("Luminaria", lx - 4, lx + 4, H - 0.5, H - 0.1, lz - 0.4, lz + 0.4, Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
			bar.CanCollide = false
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color, light.Shadows = 26, 0.9, Color3.fromRGB(255, 244, 220), false
			light.Parent = bar
		end
	end

	-- Recepção: balcão, computador e banco de espera (lado esquerdo, perto da janela)
	box("BalcaoCorpo", -18, -8, 0, 3.4, 10, 12.4, WOOD, Enum.Material.Wood)
	box("BalcaoTampo", -18.3, -7.7, 3.4, 3.7, 9.7, 12.7, DARK, Enum.Material.SmoothPlastic)
	box("Monitor", -14, -11.5, 3.7, 5.4, 11.2, 11.5, DARK, Enum.Material.SmoothPlastic)
	local screen = box("Tela", -13.8, -11.7, 3.9, 5.2, 11.0, 11.2, Color3.fromRGB(80, 150, 255), Enum.Material.Neon)
	screen.CanCollide = false
	box("BancoAssento", -19, -13, 1.2, 1.8, 16, 18, WOOD, Enum.Material.Wood)
	box("BancoEncosto", -19, -13, 1.8, 3.6, 17.6, 18, WOOD, Enum.Material.Wood)
	for _, bx in ipairs({ -18.6, -13.4 }) do
		box("BancoPerna", bx - 0.2, bx + 0.2, 0, 1.2, 16.2, 17.8, DARK, Enum.Material.Metal)
	end
	-- Máquina de café
	box("CafeCorpo", -19.4, -17.2, 3.7, 5.9, 10.6, 11.9, DARK, Enum.Material.SmoothPlastic)
	box("CafeLuz", -18.8, -17.8, 5.0, 5.3, 10.5, 10.6, Color3.fromRGB(255, 170, 60), Enum.Material.Neon).CanCollide = false

	-- Estantes de peças ao longo do fundo
	for _, sx in ipairs({ -15, -5, 5 }) do
		for _, ux in ipairs({ sx - 3.5, sx + 3.5 }) do
			box("Montante", ux - 0.2, ux + 0.2, 0, 8, 31, 33, STEEL, Enum.Material.Metal)
		end
		for level = 0, 3 do
			local y = 1.2 + level * 2
			box("Prateleira", sx - 3.7, sx + 3.7, y, y + 0.25, 31, 33, Color3.fromRGB(70, 110, 190), Enum.Material.Metal)
			-- caixas coloridas deterministas por estante/nível
			for k = 0, 3 do
				local seed = (sx * 7 + level * 13 + k * 5) % 5
				local colors = { RED, Color3.fromRGB(235, 185, 40), Color3.fromRGB(80, 150, 255), Color3.fromRGB(90, 200, 130), Color3.fromRGB(230, 230, 235) }
				local bx = sx - 3 + k * 1.9
				box("Caixa", bx - 0.7, bx + 0.7, y + 0.25, y + 1.5 + (seed % 2) * 0.3, 31.3, 32.7, colors[seed + 1], Enum.Material.Plastic)
			end
		end
	end

	-- Bancada de trabalho com morsa e painel de ferramentas (lado direito, fundo)
	box("BancadaTampo", 11, 19, 3.2, 3.6, 29, 32.5, WOOD, Enum.Material.Wood)
	for _, bx in ipairs({ 11.3, 18.7 }) do
		box("BancadaPerna", bx - 0.25, bx + 0.25, 0, 3.2, 29.3, 32.2, STEEL, Enum.Material.Metal)
	end
	box("BancadaGaveteiro", 11.5, 14, 0.4, 3.2, 29.4, 32.1, RED, Enum.Material.Metal)
	box("MorsaBase", 16, 17.4, 3.6, 4.3, 29.6, 30.8, DARK, Enum.Material.Metal)
	box("MorsaGarra", 16.2, 17.2, 4.3, 5, 29.8, 30.6, STEEL, Enum.Material.Metal)
	box("PainelFerramentas", 11, 19, 5, 9.5, 32.7, 33, WALL_DARK, Enum.Material.Metal)
	local toolColors = { RED, Color3.fromRGB(235, 185, 40), Color3.fromRGB(80, 150, 255), STEEL, Color3.fromRGB(90, 200, 130) }
	for i = 0, 6 do
		local tx = 11.8 + i * 1.05
		box("Ferramenta", tx - 0.2, tx + 0.2, 5.6 + (i % 3) * 0.9, 7.4 + (i % 3) * 0.9, 32.45, 32.7, toolColors[(i % 5) + 1], Enum.Material.Metal).CanCollide = false
	end

	-- Carrinho de ferramentas, extintor e relógio
	box("CarrinhoCorpo", 7.3, 10.8, 0.8, 3.4, 28, 30, RED, Enum.Material.Metal)
	box("CarrinhoTampo", 7.2, 10.9, 3.4, 3.6, 27.9, 30.1, DARK, Enum.Material.Metal)
	for _, wx in ipairs({ 7.7, 10.4 }) do
		for _, wz in ipairs({ 28.3, 29.7 }) do
			cylinder("CarrinhoRoda", wx, 0.4, wz, 0.4, 0.35, DARK, Enum.Material.Rubber)
		end
	end
	cylinder("Extintor", -19.3, 1.6, 8.5, 0.5, 3.2, RED, Enum.Material.Metal)
	box("ExtintorBico", -19.5, -19.1, 3.1, 3.5, 8.1, 8.5, DARK, Enum.Material.Metal)
	local clock = cylinder("Relogio", 0, 11, 32.8, 1.2, 0.3, Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic)
	clock.CFrame = root * CFrame.new(0, 11, 32.8) * CFrame.Angles(0, math.rad(90), 0)
	box("RelogioPonteiroH", -0.08, 0.08, 11, 11.7, 32.6, 32.7, DARK, Enum.Material.Metal).CanCollide = false
	box("RelogioPonteiroM", 0, 0.8, 10.95, 11.05, 32.6, 32.7, DARK, Enum.Material.Metal).CanCollide = false

	-- Quadro de preços na fachada (voltado para a rua): texto atualizado pelo servidor quando o dono muda o preço
	local board = box("QuadroPrecos", -17.5, -10.5, 8.4, 12, 5.5, 5.8, DARK, Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PriceGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "PriceText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = accent
	label.Text = "OFICINA\nLIVRE"
	label.Parent = gui

	-- Vagas dos carros: reposiciona os marcadores Bay1/Bay2 do lote para dentro do prédio (marcador fino sobre o piso).
	for index, bay in ipairs(Layout.Bays) do
		local marker = plot:FindFirstChild("Bay" .. index) :: BasePart?
		if marker then
			marker.Size = Vector3.new(bay.w, 0.1, bay.d)
			marker.CFrame = root * CFrame.new(bay.x, 0.35, bay.z)
			marker.Color = Color3.fromRGB(70, 130, 200)
			marker.Transparency = 0.35
		end
	end

	model:SetAttribute("Interior", true)
	model.Parent = plot
	return model
end

return WorkshopBuilding
