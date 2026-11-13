--!strict
-- V2-04: 15 receitas de preparação TANGÍVEL sobre os três veículos piloto.
-- Cada OS mantém índice no servidor; nenhum client pode avançar etapa ou escolher defeito.
-- O plano de minijogo/nota e o ledger da V1 continuam como única autoridade financeira.
local Catalog = require(script.Parent.Catalog)
local Rules = {}
Rules.MaxDistance = 7.5
Rules.HoldDuration = 0.65

-- Componentes devem coincidir exatamente com o contrato da V2-03.
-- "Open" indica um painel aberto; "Detached" indica uma roda retirada.
-- "Mounted"/"Closed" permitem inspeção exterior sem desmontagem.
local recipes: { [string]: any } = {
    FlatTire = { Family="Tires", Steps={
        {Id="FindPuncture", Name="Localizar o furo", Area="WheelFL", State="Detached", Tool="Calibrador"},
        {Id="PreparePatch", Name="Limpar e preparar o remendo", Area="WheelFL", State="Detached", Tool="Kit de remendo", UsesPart=true},
        {Id="VerifyValve", Name="Verificar válvula e pressão", Area="WheelFL", State="Detached", Tool="Manômetro"},
    }},
    WornTire = { Family="Tires", Steps={
        {Id="SupportTire", Name="Posicionar cavalete de segurança", Area="WheelFL", State="Mounted", Tool="Macaco", GrantsSupport=true},
        {Id="RemoveWornRubber", Name="Inspecionar pneu desgastado", Area="WheelFL", State="Detached", Tool="Desmontadora"},
        {Id="FitNewTire", Name="Preparar a montagem do novo pneu", Area="WheelFL", State="Detached", Tool="Montadora", UsesPart=true},
    }},
    WeakBattery = { Family="Electrical", Steps={
        {Id="MeasureBattery", Name="Medir a tensão da bateria", Area="Hood", State="Open", Tool="Multímetro"},
        {Id="SecureTerminals", Name="Isolar os terminais", Area="Hood", State="Open", Tool="Chave isolada"},
        {Id="FitBattery", Name="Preparar bateria nova", Area="Hood", State="Open", Tool="Suporte de bateria", UsesPart=true},
    }},
    LooseSuspension = { Family="Suspension", Steps={
        {Id="SupportSuspension", Name="Apoiar o conjunto da suspensão", Area="WheelFL", State="Mounted", Tool="Cavalete", GrantsSupport=true},
        {Id="InspectBushing", Name="Examinar bucha e folga", Area="WheelFL", State="Detached", Tool="Alavanca de inspeção"},
        {Id="TorqueSuspension", Name="Reapertar fixações", Area="WheelFL", State="Detached", Tool="Torquímetro", UsesPart=true},
    }},
    EngineMisfire = { Family="Engine", Steps={
        {Id="ConnectScanner", Name="Conectar scanner OBD", Area="Hood", State="Open", Tool="Scanner"},
        {Id="InspectCoils", Name="Conferir velas e bobinas", Area="Hood", State="Open", Tool="Chave de vela"},
        {Id="PrepareIgnition", Name="Preparar correção de ignição", Area="Hood", State="Open", Tool="Kit de ignição", UsesPart=true},
    }},
    ElectricalFault = { Family="Electrical", Steps={
        {Id="TraceHarness", Name="Rastrear chicote e alimentação", Area="Hood", State="Open", Tool="Multímetro"},
        {Id="IsolateCircuit", Name="Isolar circuito defeituoso", Area="Hood", State="Open", Tool="Ponta de prova"},
        {Id="ReplaceFuse", Name="Preparar fusível correto", Area="Hood", State="Open", Tool="Extrator", UsesPart=true},
    }},
    Dent = { Family="Bodywork", Steps={
        {Id="MarkDent", Name="Marcar área do amassado", Area="DoorLeft", State="Closed", Tool="Luz de inspeção"},
        {Id="PositionPuller", Name="Posicionar ventosa de repuxo", Area="DoorLeft", State="Closed", Tool="Martelo de inércia"},
        {Id="CheckReflection", Name="Conferir reflexo da superfície", Area="DoorLeft", State="Closed", Tool="Régua de luz"},
    }},
    BodyDamage = { Family="Bodywork", Steps={
        {Id="AssessGap", Name="Medir folga da carroceria", Area="DoorLeft", State="Closed", Tool="Paquímetro"},
        {Id="AlignPanel", Name="Posicionar ferramenta de tração", Area="DoorLeft", State="Closed", Tool="Repuxadeira"},
        {Id="CheckStructure", Name="Verificar pontos de fixação", Area="DoorLeft", State="Closed", Tool="Calibre", UsesPart=true},
    }},
    PaintJob = { Family="Bodywork", Steps={
        {Id="SandFinish", Name="Lixar e preparar a pintura", Area="DoorRight", State="Closed", Tool="Lixadeira"},
        {Id="MaskEdges", Name="Isolar borrachas e frisos", Area="DoorRight", State="Closed", Tool="Fita de mascaramento", UsesPart=true},
        {Id="CheckPrimer", Name="Conferir aplicação do primer", Area="DoorRight", State="Closed", Tool="Pistola de pintura"},
    }},
    WheelImbalance = { Family="Tires", Steps={
        {Id="InspectWeights", Name="Localizar contrapesos existentes", Area="WheelFL", State="Mounted", Tool="Inspeção visual"},
        {Id="MarkWeight", Name="Marcar ponto de contrapeso", Area="WheelFL", State="Mounted", Tool="Balanceadora"},
        {Id="AttachWeight", Name="Preparar massa de balanceamento", Area="WheelFL", State="Mounted", Tool="Contrapesos", UsesPart=true},
    }},
    Misalignment = { Family="Suspension", Steps={
        {Id="ReadToe", Name="Medir convergência", Area="WheelFL", State="Mounted", Tool="Alinhador"},
        {Id="AdjustTieRod", Name="Regular terminal da direção", Area="WheelFL", State="Mounted", Tool="Chave de direção"},
        {Id="VerifyCamber", Name="Verificar cambagem", Area="WheelFL", State="Mounted", Tool="Alinhador"},
    }},
    BrakeWear = { Family="Suspension", Steps={
        {Id="SupportBrakes", Name="Apoiar a dianteira", Area="WheelFL", State="Mounted", Tool="Cavalete", GrantsSupport=true},
        {Id="InspectCaliper", Name="Examinar pinça de freio", Area="WheelFL", State="Detached", Tool="Chave de pinça"},
        {Id="PreparePads", Name="Preparar pastilhas novas", Area="WheelFL", State="Detached", Tool="Recuador de pistão", UsesPart=true},
    }},
    BrokenArm = { Family="Suspension", Steps={
        {Id="SupportArm", Name="Apoiar conjunto inferior", Area="WheelFL", State="Mounted", Tool="Macaco", GrantsSupport=true},
        {Id="InspectMount", Name="Verificar fixações do braço", Area="WheelFL", State="Detached", Tool="Chave de impacto"},
        {Id="PrepareNewArm", Name="Preparar novo braço de suspensão", Area="WheelFL", State="Detached", Tool="Prensa de buchas", UsesPart=true},
    }},
    EngineOverhaul = { Family="Engine", Steps={
        {Id="CheckCompression", Name="Medir compressão dos cilindros", Area="Hood", State="Open", Tool="Compressímetro"},
        {Id="InspectBlock", Name="Inspecionar bloco e juntas", Area="Hood", State="Open", Tool="Calibrador de folgas"},
        {Id="StageEngineKit", Name="Preparar kit de retífica", Area="Hood", State="Open", Tool="Bancada de motor", UsesPart=true},
    }},
    Overheating = { Family="Engine", Steps={
        {Id="PressureTest", Name="Testar pressão do arrefecimento", Area="Hood", State="Open", Tool="Bomba de pressão"},
        {Id="CheckRadiator", Name="Inspecionar mangueiras e radiador", Area="Hood", State="Open", Tool="Lanterna"},
        {Id="PrepareCoolant", Name="Separar aditivo de arrefecimento", Area="Hood", State="Open", Tool="Funil", UsesPart=true},
    }},
}
Rules.Recipes = recipes

local areaStates = {
    Hood={Open=true,Closed=true}, DoorLeft={Open=true,Closed=true},
    DoorRight={Open=true,Closed=true}, Trunk={Open=true,Closed=true},
    WheelFL={Mounted=true,Detached=true}, WheelFR={Mounted=true,Detached=true},
    WheelRL={Mounted=true,Detached=true}, WheelRR={Mounted=true,Detached=true},
}

function Rules.ValidateCatalog(): { string }
    local errors, count = {}, 0
    for defectId, defect in pairs(Catalog.Defects) do
        local r = recipes[defectId]
        if not r then
            table.insert(errors, "Sem procedimento V2 para: "..defectId)
        else
            count += 1
            local seen = {}
            if type(r.Steps)~="table" or #r.Steps<2 or #r.Steps>5
                or r.Family ~= defect.Specialization then
                table.insert(errors, "Receita incompatível: "..defectId)
            else
                for _,step in ipairs(r.Steps) do
                    if type(step.Id)~="string" or seen[step.Id]
                        or not areaStates[step.Area] or not areaStates[step.Area][step.State]
                        or type(step.Name)~="string" or type(step.Tool)~="string" then
                        table.insert(errors, "Etapa inválida: "..defectId)
                    end
                    seen[step.Id]=true
                end
            end
        end
    end
    if count~=15 then table.insert(errors,"Esperados 15 procedimentos, encontrados "..count) end
    for defectId in pairs(recipes) do
        if Catalog.Defects[defectId]==nil then table.insert(errors,"Defeito sem catálogo: "..defectId) end
    end
    return errors
end

function Rules.Current(defectId: any, index: any): any?
    if type(defectId)~="string" or type(index)~="number" or index%1~=0 then return nil end
    local recipe=recipes[defectId]
    return recipe and recipe.Steps[index] or nil
end

function Rules.Ready(defectId: any, index: any, pilotId: any): boolean
    if type(pilotId)~="string" then return true end
    local recipe=type(defectId)=="string" and recipes[defectId]
    if not recipe then return false end
    return type(index)=="number" and index%1==0 and index>#recipe.Steps
end

function Rules.HasWheelProcedure(defectId: any): boolean
    return defectId=="WornTire" or defectId=="LooseSuspension"
        or defectId=="BrakeWear" or defectId=="BrokenArm" or defectId=="FlatTire"
end

function Rules.Public(defectId: any, index: any, pilotId: any): any?
    if type(pilotId)~="string" then return nil end
    local recipe=type(defectId)=="string" and recipes[defectId]
    if not recipe then return nil end
    local step=Rules.Current(defectId,index)
    return {
        Family=recipe.Family, Total=#recipe.Steps,
        Completed=type(index)=="number" and math.clamp(index-1,0,#recipe.Steps) or 0,
        Ready=Rules.Ready(defectId,index,pilotId),
        StepName=step and step.Name or "Preparação física concluída",
        Area=step and step.Area or "",
        Tool=step and step.Tool or "",
    }
end

export type Context = {
    Parked: boolean, Authorized: boolean, Diagnosed: boolean, JobActive: boolean,
    RepairBusy: boolean, NpcBusy: boolean, EquipmentReady: boolean,
    PartsReady: boolean, States: { [string]: string },
}

function Rules.Advance(defectId: any, index: any, supplied: any, ctx: Context): (number?, string)
    local step=Rules.Current(defectId,index)
    if not step or type(supplied)~="string" or supplied~=step.Id then
        return nil, "Etapa desconhecida, repetida ou fora de ordem."
    end
    if not ctx.Authorized or not ctx.Parked or not ctx.JobActive or not ctx.Diagnosed then
        return nil, "Veículo não está pronto ou jogador não autorizado."
    end
    if ctx.RepairBusy or ctx.NpcBusy then
        return nil, "Outra operação já está em andamento."
    end
    if not ctx.EquipmentReady then return nil,"Instale o equipamento necessário antes de preparar o serviço." end
    if step.UsesPart and not ctx.PartsReady then
        return nil,"Faltam peças no estoque: compre-as na Loja de Autopeças."
    end
    if type(ctx.States)~="table" or ctx.States[step.Area]~=step.State then
        return nil, step.State=="Open" and "Abra o componente indicado."
            or step.State=="Detached" and "Retire a roda indicada."
            or "Recoloque/feche o componente indicado."
    end
    return index+1, "Etapa concluída: "..step.Name.."."
end

return Rules
