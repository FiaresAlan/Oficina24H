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

return Config
