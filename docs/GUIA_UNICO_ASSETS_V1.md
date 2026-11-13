# GUIA ÚNICO DE ASSETS — OFICINA 24H (V1)

**Versão:** 1.0 — 13/11/2026. **Objetivo:** dizer exatamente o que conferir, de onde conseguir e em qual pasta deixar, sem downloads desnecessários.

> **ANTES DE BAIXAR:** abra seu *place original* da Oficina 24H no Roblox Studio. **Não crie um place vazio e não substitua sua rua.** Os GLB brutos não estão no GitHub; muitos assets já foram carregados no seu Studio/Creator Hub segundo o histórico do projeto. Esta lista é o inventário selecionado, **não** prova de que os modelos estão presentes no seu computador. Baixe/insira **somente o que estiver faltando**. Em caso de dúvida, rode `StudioPlaceAudit` (instruções ao final).

## 1. O lugar certo dos modelos no Studio

No **Explorer**, confirme esta estrutura no place original:

```text
ServerStorage
└─ Assets
   ├─ Veiculos       ← 21 Models, nomes exatamente como a tabela abaixo (obrigatório)
   ├─ Clientes       ← NPCs R15 com Humanoid, PrimaryPart e atributo Genero (obrigatório)
   ├─ Equipamentos   ← 11 Models Eq_* (opcional: existe fallback por código)
   ├─ Cenario        ← modelos de casas, ruas, lojas e cidade (usados por scripts de montagem)
   └─ Props          ← Cone opcional, se usado pelo cenário
```

A rua e as oficinas aparecem no **Workspace** quando o mundo está montado. **Não** coloque os carros de cliente em Workspace permanente: `VehicleService` os clona de `ServerStorage.Assets.Veiculos`. `Rojo` sincroniza os scripts, **não** os modelos que ficam no place.

## 2. Carros — os 21 nomes que o jogo exige

**Status:** já constam como selecionados/importados nos documentos históricos. **Se não faltarem no Studio, NÃO baixe de novo.**  
**Origem:** Creator Store da Roblox, onde eram oferecidos gratuitamente conforme histórico em `docs/ORIGEM_ASSETS.md`; **a disponibilidade/preço atual de cada item não foi verificada individualmente**. Abra pelo ID na Toolbox > Creator Store > Modelos, confirme `Get Model`/gratuito e direitos de uso antes de inserir.

| Carro no jogo | Nome EXATO no Explorer | Asset de origem (ID) |
|---|---|---|
| Hatch amarelo | `Veiculo_Hatch_MG3` | `1396376221` |
| Hatch preto | `Veiculo_Hatch_Punto` | `107224308331830` |
| Clássico japonês | `Veiculo_Hatch_AE86` | `9432856072` |
| Sedã azul | `Veiculo_Sedan_Civic` | `9747931348` |
| Sedã branco | `Veiculo_Sedan_Camry` | `9432856072` |
| Clássico rabo-de-peixe | `Veiculo_Sedan_Fury` | `9432856072` |
| SUV familiar | `Veiculo_SUV_Traverse` | `15161873096` |
| SUV preto | `Veiculo_SUV_Evoque` | `12424932349` |
| SUV compacto | `Veiculo_SUV_RAV4` | `11537579368` |
| Crossover | `Veiculo_SUV_Izoa` | `11537579368` |
| Jipe | `Veiculo_SUV_Wrangler` | `6934203358` |
| Picape antiga | `Veiculo_Picape_S10` | `9432856072` |
| Picape esportiva | `Veiculo_Picape_454` | `9432856072` |
| Picape de trabalho | `Veiculo_Picape_C1500` | `9432856072` |
| Picape vermelha | `Veiculo_Picape_K1500` | `9432856072` |
| Esportivo turbo | `Veiculo_VIP_Supra` | `9432856072` |
| Esportivo de pista | `Veiculo_VIP_Skyline` | `9432856072` |
| Muscle car V8 | `Veiculo_VIP_Charger` | `9432856072` |
| Muscle car laranja | `Veiculo_VIP_Hellcat` | `9432856072` |
| Esportivo drift | `Veiculo_VIP_Silvia` | `9432856072` |
| Esportivo vermelho | `Veiculo_VIP_Corvette` | `103666878891556` (licença pendente) |

**Como usar:** o ID identifica o pacote/modelo de origem, **não necessariamente o modelo final pronto**. Alguns carros saem do **mesmo pacote** `9432856072`: insira esse pacote **uma vez**, extraia os veículos necessários, remova scripts e padronize os nomes da tabela. Não deixe o pacote inteiro dentro de `Veiculos`.

**Padrão obrigatório dos carros:** Model com `PrimaryPart` `Raiz` (na base do carro), frente = LookVector de `Raiz`; partes soldadas, scripts de terceiros removidos, `Casco` para colisão e atributos de dimensão/motorista. Os arquivos originais **não** possuem necessariamente esses padrões; o place existente já recebeu normalização segundo o histórico. Para recuperar modelo perdido, reimportar o original bruto não basta: é necessário repetir essa normalização.

**Atenção ao `Veiculo_VIP_Corvette`:** o ID pertence a um modelo do acervo anteriormente fornecido pelo proprietário. **Não** é um download gratuito de licença confirmada. Sem comprovante da origem/uso comercial, substituir por um veículo genérico com licença verificável antes de publicar. Há risco semelhante de marcas/logotipos nos modelos vindos da Creator Store.

## 3. NPCs — não precisa comprar ou baixar pacote externo

**Pasta:** `ServerStorage.Assets.Clientes`.  
**Origem:** avatares/pacotes oficiais e gratuitos da própria Roblox, registrados no inventário anterior. Já preparados no place original: Casey, Dennis, Denny, John, Kenneth, Man, Oakley, Oliver, Cindy, Claire, Lin, Lindsey, Linlin, Serena, Skyler, Summer, Woman.

Se algum modelo estiver ausente, use um **rig R15 oficial da Roblox** e salve como `Model` na pasta `Clientes`. Cada um precisa de `Humanoid`, `PrimaryPart` e atributo `Genero = "M"` ou `"F"`. Não baixe NPCs externos com scripts de movimento próprios. Animações estão ligadas no código `src/shared/NpcAnimations.lua`; confirme permissões no teste.

## 4. Equipamentos de oficina — fonte CC0 realmente gratuita

**Fonte verificada:** [Car Repair Garage and MOT Workshop — 3DAssets.dev](https://3dassets.dev/packs/car-repair-garage-and-mot-workshop). **CC0**; atualmente o site lista **54 modelos GLB**, que podem ser baixados individualmente ou em uma cena única. O histórico da Oficina já contém 11 modelos tratados e IDs publicados no inventário.

**Pasta:** `ServerStorage.Assets.Equipamentos`, com estes 11 nomes. Se os modelos já estiverem presentes, **não baixe**. Se estiver faltando um, há **fallback 3D feito por código** em `src/server/EquipmentModels.lua`, então a oficina continua funcionando sem compra/asset externo.

| Equipamento | Nome EXATO | Asset já carregado (ID do histórico) |
|---|---|---|
| AlignmentRig | `Eq_AlignmentRig` | `101123043132851` |
| Balancer | `Eq_Balancer` | `96425876369572` |
| BasicToolset | `Eq_BasicToolset` | `71841035338431` |
| BodyworkKit | `Eq_BodyworkKit` | `119599798763539` |
| Compressor | `Eq_Compressor` | `108600676828047` |
| ElectricalBench | `Eq_ElectricalBench` | `78080365689495` |
| EngineBench | `Eq_EngineBench` | `73755557419223` |
| Jack | `Eq_Jack` | `132507180901002` |
| Scanner | `Eq_Scanner` | `92303952689536` |
| SuspensionLift | `Eq_SuspensionLift` | `135418201960430` |
| TireMachine | `Eq_TireMachine` | `77629064640188` |

**Se quiser reinserir um equipamento:** no pack CC0, escolha peça equivalente (baú/carrinho de ferramentas, macaco, desmontadora, scanner, bancada, elevador, balanceadora, compressor, ferramenta de funilaria). A peça precisa virar um `Model` com seu nome `Eq_*` e `PrimaryPart`; **não** colocar o kit inteiro como um só `Model` esperando que o jogo reconheça 11 máquinas.

## 5. Bairro/rua — preservar o que já existe

**Se a rua já aparece no Studio e você gosta dela, não baixe nem reconstrua nada.** Os pacotes listados abaixo são **fontes de recuperação** em caso de modelo ausente:

| Asset | Link gratuito ou origem | Onde deixar |
|---|---|---|
| Ruas, calçadas, pontos e estacionamento | [Shuriken Town Streets & Park](https://shuriken.studio/kits/town-streets) — gratuito | Modelos tratados no `ServerStorage.Assets.Cenario`, montagem pelo pipeline do projeto |
| Casas e garagens | [Shuriken Houses](https://shuriken.studio/kits/houses) — conferir download | `ServerStorage.Assets.Cenario` |
| Comércio/semáforos/mobiliário | [Shuriken City](https://shuriken.studio/kits/city) — conferir download | `ServerStorage.Assets.Cenario` |
| 24 peças de cidade `Cid_*` | 24 IDs no [inventário já enviado](../pipeline/city_ids.json) | `ServerStorage.Assets.Cenario`, com nome idêntico ao JSON |
| Props de casas, oficinas e rua | IDs no [inventário já enviado](../pipeline/prop_ids.json) | `ServerStorage.Assets.Cenario` e `Equipamentos` para `Eq_*` |
| Cidade separada ORKQN (se realmente faltar) | [CGTrader — Low Poly City](https://www.cgtrader.com/free-3d-models/exterior/cityscape/low-poly-city-low-poly-assets-3d-model), acervo histórico do proprietário | Converter/separar pelo pipeline e colocar `Cid_*` em `Cenario` |

**Importante:** licença do Shuriken permite uso gratuito em jogos, inclusive comerciais, mas **proíbe redistribuir os arquivos soltos ou em pacotes**. Não enviar GLBs do Shuriken ao repositório público. Confira [licença oficial](https://shuriken.studio/legal/models). A cidade CGTrader exige verificar a licença do download na conta original antes de republicar.

**Lista exata de 24 modelos Cid do mapa** (ID já enviado para a conta, não download novo):
`Cid_Apartamentos` — 111925378392327 · `Cid_Banco` — 137447573893526 · `Cid_Bloco` — 107009084830635 · `Cid_Casa_Terraco` — 93886672525454 · `Cid_Comercial_Longo` — 136861186059995 · `Cid_Curvo` — 97897770221687 · `Cid_Escritorio` — 119523743797673 · `Cid_Esquina_Redonda` — 98273831548574 · `Cid_Fabrica` — 131151550382603 · `Cid_Galpao` — 119817054483083 · `Cid_Loja_Baixa` — 86929557284503 · `Cid_Loja_Pequena` — 106035035749751 · `Cid_Lojas_Fileira` — 80683423174299 · `Cid_Mercado` — 91495296658721 · `Cid_Pilotis` — 120224937917820 · `Cid_Pinheiro` — 97205175209297 · `Cid_Posto` — 136242044048939 · `Cid_Predio_Largo` — 75701276759366 · `Cid_Predio_Vertical` — 71620381200902 · `Cid_PredioAlto` — 135289436323368 · `Cid_PredioEstreito` — 75282697843367 · `Cid_Sobrado` — 107032816516585 · `Cid_Torre_Fina` — 127235981361633 · `Cid_Torre_Torcida` — 100572703590121

**Demais props selecionados, caso precise localizar algum ID:**  
- **Casa:** `Casa_Duplex` 94575509486213 · `Casa_Familia` 124672567154593 · `Casa_Garagem` 92876464047891 · `Casa_Inicial` 94133403277200 · `Casa_Sobrado` 139402928376955 · `Casa_Terrea` 73789234175881 · `Casa_Villa` 112040133895082
- **Loja:** `Loja_Banca` 86731856660799 · `Loja_Cafe` 118805167094607 · `Loja_Esquina` 81459293307961 · `Loja_Estacionamento` 82887359392279 · `Loja_Galeria` 75769774688262 · `Loja_LavaRapido` 106901432619289 · `Loja_Posto` 95834082983745
- **Of:** `Of_Bancada` 107603361742457 · `Of_BancoEspera` 80824704079411 · `Of_Barril` 134279731667083 · `Of_Cafe` 73101082482805 · `Of_CaixaOleo` 83023078538134 · `Of_CarrinhoFerramenta` 93226683529285 · `Of_Elevador` 139247960173527 · `Of_Extintor` 115673760509187 · `Of_Galao` 132394074695387 · `Of_KitMedico` 84770430006691 · `Of_LavaPecas` 132527270903098 · `Of_Lixeira` 97497301612186 · `Of_PilhaPneus` 137388028219109 · `Of_PisoMolhado` 111832784582273 · `Of_Placa` 134682385342598 · `Of_Portao` 118512347338877 · `Of_Prateleira` 130555437341911 · `Of_QuadroChaves` 116991527267369 · `Of_Recepcao` 100128521556988 · `Of_Relogio` 101031269853069
- **Rua:** `Rua_Boasvindas` 82605445291319 · `Rua_Cacamba` 88753979250444 · `Rua_Jardineira` 83347295785876 · `Rua_Maquina` 77604519022284 · `Rua_Mobiliario` 106684060345621 · `Rua_Outdoor` 137697974167551 · `Rua_PontoOnibus` 116002453785755 · `Rua_Poste` 80480689353882 · `Rua_Praca` 114836641509499 · `Rua_Semaforo` 70393929266054 · `Rua_Telefone` 97449090777157
- **Predio:** `Predio_Apartamentos` 71275103609394

## 6. Áudio, sprites e partes de reparo

- **Sons/músicas:** já identificados por IDs Roblox em `src/shared/SoundIds.lua`; **nenhum download manual necessário**. Se um áudio não tocar, confirmar permissões/autor no Creator Hub.
- **HUD/sprites:** IDs em `src/shared/HudAssets.lua`; **não baixar pacotes extras**. **Pendência de publicação:** parte dos recortes veio de imagens de referência e a autoria/licença comercial não está comprovada. Devemos recriar/substituir com arte própria ou licenciada antes do lançamento.
- **Peças de motor/estoque:** `src/shared/PartModels.lua` produz muitos visuais procedurais; não exige GLB separado para cada componente. Os modelos mecânicos interativos definitivos ainda precisam passar por QA dos sockets.
- **Cones/mobiliário:** scripts montam o cenário. `ServerStorage.Assets.Props.Cone` é opcional; faltando, `BuildScenery` pode simplesmente omitir cones.

## 7. Como importar, se algo realmente faltar (simples)

1. Abra o **place original** e faça uma cópia de segurança.
2. Explorer → `ServerStorage` → `Assets` → abra a pasta correta.
3. **Modelo da Creator Store:** na Toolbox/Creator Store pesquise o **ID de origem** da tabela; confira se ainda é gratuito, obtenha o modelo e arraste para o Studio. Remova todos os `Script`, `LocalScript` e `ModuleScript` que vierem no pacote. Renomeie exatamente como o guia e mova para a pasta certa.
4. **GLB gratuito (3DAssets/Shuriken):** baixe do link oficial → Studio → **File > Import** → selecione .glb → confira escala e orientação → mova o `Model` ao local correto e defina `PrimaryPart`.
5. **Não execute** `BuildWorld`, `BuildNeighborhood` ou `BuildCity` sobre sua rua atual sem backup: esses scripts podem reconstruir partes do mapa e substituir a decoração.
6. Sincronize os scripts com **Rojo**. Os modelos permanecem no Studio (não vão para a pasta `src/` do GitHub).
7. Execute `tools/StudioPlaceAudit.luau` em Studio: ele mostra **quais dos 21 carros estão ausentes**, se há NPC válido e se scripts não confiáveis foram importados dentro de `Assets`. Rode `tools/RunAllTests.luau` depois, para verificar o conjunto de código.

## 8. O que você realmente deve baixar AGORA

**Se o place original já contém `Veiculos`, `Clientes`, `Equipamentos` e `Cenario` completos: nada.**

**Se faltarem modelos:**
1. Carro da tabela que aparecer como **ausente** no `StudioPlaceAudit` → inserir pelo ID de origem correspondente.
2. NPC se a pasta `Clientes` estiver vazia → usar rig/avatar oficial Roblox, sem comprar pack.
3. Equipamento com nome `Eq_*` ausente → opcional, por existir fallback; [3DAssets.dev CC0](https://3dassets.dev/packs/car-repair-garage-and-mot-workshop).
4. Decoração do bairro ausente → **opcional**, [Shuriken](https://shuriken.studio/kits/town-streets), mas não refazer a rua aprovada.
5. HUD, áudio, peças procedurais e scripts: nenhum download necessário, apenas verificação de licença/permissão.

**Pendências que não posso confirmar sem Studio:** quais modelos estão instalados no seu place atual; se todos têm `PrimaryPart`/orientação/pivôs corretos; permissão real de cada áudio/asset; autenticidade/licença dos sprites e do Corvette. Não vou declarar isso “instalado/validado” antes de inspecionar.

**Fonte técnica da importação:** https://create.roblox.com/docs/studio/importer  
**Inventário detalhado e autoria:** [ORIGEM_ASSETS.md](ORIGEM_ASSETS.md)
