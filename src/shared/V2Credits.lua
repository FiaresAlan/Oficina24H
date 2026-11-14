--!strict
-- V2-15: créditos visíveis ao jogador com base em ORIGEM_ASSETS.md.
-- Não substitui verificação da licença de cada asset no Creator Hub.
local R={}
R.Entries={
    {Group="Veículos",Name="Semi-Realistic Car Pack",
        Author="SubXero_X",Source="Roblox Creator Store · 9432856072"},
    {Group="Veículos",Name="MG3 / Hatch amarelo",
        Author="xriaou",Source="Roblox Creator Store · 1396376221"},
    {Group="Veículos",Name="Fiat Punto 2009–2012",
        Author="Mirosyaplayer",Source="Roblox Creator Store · 107224308331830"},
    {Group="Veículos",Name="Honda Civic Realistic Car",
        Author="Kubston9868",Source="Roblox Creator Store · 9747931348"},
    {Group="Veículos",Name="Land Rover Evoque Couple",
        Author="crowxfflies",Source="Roblox Creator Store · 12424932349"},
    {Group="Veículos",Name="2017 Chevrolet Traverse",
        Author="CharlieKins2323",Source="Roblox Creator Store · 15161873096"},
    {Group="Veículos",Name="ND Cars (RAV4 / Izoa)",
        Author="JemuelCorsino",Source="Roblox Creator Store · 11537579368"},
    {Group="Veículos",Name="2011 Jeep Wrangler",
        Author="7elts",Source="Roblox Creator Store · 6934203358"},
    {Group="Cidade",Name="Town Streets / Houses / City",
        Author="Shuriken Studio",Source="shuriken.studio · licença própria; não redistribuir GLBs"},
    {Group="Cidade",Name="Low Poly City",
        Author="ORKQN",Source="CGTrader · #4359726 · royalty-free"},
    {Group="Oficina",Name="Car Repair Garage and MOT Workshop",
        Author="3DAssets.dev",Source="3dassets.dev · CC0 declarado"},
    {Group="Áudio",Name="Efeitos industriais e ambiente",
        Author="ProSoundEffects / criadores da Roblox Creator Store",
        Source="Roblox Creator Store · IDs em SoundIds.lua"},
    {Group="Áudio",Name="Músicas de ambiente",
        Author="APM Music",Source="Roblox Creator Store · IDs em SoundIds.lua"},
}
R.Pending={
    "Sprites do HUD/painéis: provar autoria e licenças das imagens de referência.",
    "Pacote de ícones cedido por terceiro: obter autorização escrita antes de publicar.",
    "Modelo esportivo fornecido pelo proprietário: origem/licença não comprovadas.",
    "Modelos com logotipos comerciais: revisar moderação e direitos antes de publicar.",
    "Arquivos CC BY 4.0: se algum retornar ao jogo, exibir crédito individual do autor e link original.",
}
function R.Validate():{string}
    local errors,seen={},{}
    for _,entry in ipairs(R.Entries) do
        if type(entry.Name)~="string" or entry.Name==""
            or type(entry.Author)~="string" or entry.Author==""
            or type(entry.Source)~="string" or entry.Source=="" then
            table.insert(errors,"Ator/autor/fonte ausentes.")
        end
        local id=entry.Group..":"..entry.Name
        if seen[id] then table.insert(errors,"Crédito duplicado: "..id) end
        seen[id]=true
    end
    return errors
end
return R
