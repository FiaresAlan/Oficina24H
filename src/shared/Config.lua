--!strict
local Config = {}

Config.DataStoreName = "Oficina24H_PlayerData_v1"
Config.AutoSaveSeconds = 120
Config.MaxPlots = 6
Config.InteractDistance = 22 -- studs até a caixa do veículo para diagnosticar/reparar
Config.StartingCoins = 250
Config.StartingReputation = 0
Config.MaxServiceSplitPercent = 80
Config.InviteTimeoutSeconds = 30
Config.JobRefreshSeconds = 45
Config.MaxOpenJobsPerWorkshop = 3
Config.CollabMaxSeconds = 180 -- colaborador que não conclui em 3 min perde a ordem (volta ao dono)
Config.OnboardingBonus = 40 -- moedas no 1º serviço concluído (paga uma vez; pular o guia não paga)
Config.InProgressMaxSeconds = 900 -- ordem aceita e esquecida: o cliente leva o carro após esse tempo (vaga liberada)
Config.CustomerPatienceSeconds = 300 -- cliente sem resposta vai embora
Config.ManualCustomerCooldownSeconds = 20 -- intervalo mínimo entre pedidos manuais de cliente (anti-farm)
Config.AdvertisingCost = 15 -- custo dos panfletos (botão "Receber cliente")
Config.CustomerArrivalSeconds = 12 -- intervalo entre levas de clientes do bairro (ajustado após medir ~1 cliente/100 s com 20 s)
Config.CustomersPerWorkshopPerTick = 0.7 -- clientes por oficina em cada leva (arredonda para cima, mínimo 1)
Config.CustomerArrivalPoint = Vector3.new(330, 0, 0) -- por onde os clientes entram no bairro (fim da rua principal)

-- Estações físicas (prompts): aceitar ordem só na TV da oficina, falar com o cliente só perto dele, comprar só na loja.
Config.StationDistance = 14 -- studs do jogador até a TV de ordens / prateleira do estoque
Config.TalkDistance = 10 -- ~3 m: conversar (diagnóstico) com o cliente
Config.ShopDistance = 40 -- studs até o prédio da Loja de Autopeças do bairro

-- Mochila: peças que o jogador carrega (para reparos fora da oficina no futuro); o resto fica na prateleira.
Config.BagCapacity = 12

-- Expansão da oficina: anexo com mais um box (Bay3). Preço por nível (índice = nível comprado).
Config.ExpansionCosts = { 1500 }

-- Funcionários (mecânicos NPC fixos): contratação + salário pago a cada PaydaySeconds; fazem o serviço sozinhos
-- (sem XP para o dono, qualidade menor). Sem moedas para o salário, o funcionário pede demissão.
Config.EmployeeHireCost = 300
Config.EmployeeSalary = 60
Config.PaydaySeconds = 300
Config.MaxEmployees = 2
Config.EmployeeWorkSeconds = 40 -- tempo que um funcionário leva em um serviço
Config.EmployeeQuality = 72 -- qualidade (%) do serviço feito por funcionário

-- Oficinas rivais (NPC) ocupam lotes livres para o bairro não parecer vazio; sempre sobra lote para quem entra.
Config.RivalMax = 3
Config.RivalKeepFreePlots = 2

return Config
