# Origem dos assets — Oficina 24H

Registro exigido pelo Product Master Document v2.0 (checklist de lançamento). Atualizado em 2026-11-06. Itens marcados **A CONFIRMAR** não têm prova de licença no repositório: não publicar antes de resolver.

| Asset | Onde está | Origem | Condição | Situação |
|---|---|---|---|---|
| 3 carros (Sedã, Compacto, Hatch) | `ServerStorage/Assets/Veiculos` | GLB CC0 da Grab3D, importados via Open Cloud | CC0 (conferido na página do provedor durante a pesquisa) | OK |
| 3 clientes NPC (Homem30, Homem60, Mulher28) | `ServerStorage/Assets/Customers` | Gerados pelo assistente 3D do Roblox Studio (`generate_avatar`) | Conteúdo gerado dentro da plataforma, sujeito aos termos do Roblox | OK (guardar o prompt: está no nome original dos modelos, no histórico da sessão) |
| 14 modelos de peças | `src/shared/PartModels.lua` | Procedurais (código do projeto) | Próprio | OK |
| Equipamentos, prédio, lotes, cenário | `tools/Build*.luau`, `WorkshopBuilding.luau`, `Layout.lua` | Procedurais (código do projeto) | Próprio | OK |
| Sprites do HUD (25) e dos painéis (46) | decals enviados via Open Cloud; ids em `src/shared/HudAssets.lua` | Recortados de imagens de referência fornecidas pelo Product Owner | **A CONFIRMAR** a autoria/licença das imagens de referência | Pendente |
| Pacote de ícones UI | `C:\Users\Administrador\Desktop\Roblox Claude Work\UI Icon Pack` (fora do repositório) | Cedido ao Product Owner por um amigo, que declarou tê-los feito à mão | Autorização verbal do Product Owner; só Rank/Keys têm licença CC0 escrita | **A CONFIRMAR** por escrito antes de publicar |
| Fontes | Oswald e Builder Sans | Fontes da própria plataforma Roblox | Uso permitido na plataforma | OK |
| Animações dos clientes (caminhada e espera) | `src/shared/NpcAnimations.lua` (ids `99232109851461` e `114394899846985`) | Geradas pelo assistente 3D do Roblox Studio (`generate_animation`), publicadas na conta do Product Owner | Conteúdo gerado dentro da plataforma, sujeito aos termos do Roblox | OK |
| Áudio | — | Não há áudio no jogo | — | Sem pendência |
| Skills fwjelaa (ferramentas) | fora do repositório | Biblioteca cedida ao Product Owner | Não entram no jogo publicado | OK |

Regra do projeto: nenhum asset novo entra sem uma linha nesta tabela.

## Renovação visual — veículos SEM MARCA (2026-11-07)

Pedido do Product Owner: **nenhuma marca de carro no jogo** (emblemas, logotipos, placas, letreiros) e **nada com QR code**. O Roblox moderou a conta ao receber um carro cujo arquivo trazia uma textura com bandeira e texto; por isso toda textura é inspecionada.

Fonte: biblioteca `carros` do Product Owner (`C:\Users\Administrador\Documents\carros-main`, 532 modelos do Sketchfab), licença declarada **CC Attribution (CC BY 4.0)**: uso comercial e modificação permitidos, **crédito ao autor obrigatório** quando exibido publicamente. Modelos CC BY-SA não foram usados. O jogo ainda **não tem tela de créditos**: criar antes de publicar (pendência).

Tratamento (skill fwjelaa-asset-import; scripts em `pipeline/`): escala real, frente em +Y, malhas unidas por material, polígonos reduzidos a 0,7–12 mil, texturas ≤ 1024 em JPEG, cores lisas viram mini-textura (o importador do Roblox ignora cor sem textura), emblemas e placas removidos (peça apagada, faces apagadas ou textura preenchida), placas substituídas por uma genérica fictícia, GLB sem compressão meshopt. Colisão desligada, scripts embutidos apagados no place. Verificação: vistas ortográficas de frente, traseira e lado de cada carro e de TODAS as texturas, por inspeção visual (não há OCR/QR automático instalado).

| Nome no jogo | Arquivo | Modelo original | Autor | Obra original | Triângulos | Asset Roblox |
|---|---|---|---|---|---|---|
| Hatch compacto | Veiculo_Hatch_A | Chevrolet Celta | RATODDY | https://sketchfab.com/3d-models/e6ed28ade18247b6957010933ce518e0 | ~7k | 90553873817327 |
| Hatch azul | Veiculo_Hatch_B | Ford Fiesta | 🇷🇴シRuletăシ🇷🇴 | https://sketchfab.com/3d-models/f3a9d5d1fc9142d297f8d3c4d9b91431 | ~10k | 114192399819009 |
| Hatch híbrido | Veiculo_Hatch_C | Toyota Prius | Doz3 | https://sketchfab.com/3d-models/04eaf6b288cc466785365b7d985e3b29 | ~12k | 77078324020441 |
| Hatch esportivo | Veiculo_Hatch_D | Toyota Yaris | DisneyCars | https://sketchfab.com/3d-models/44cb958908b94aa5aad0d856994f35a3 | ~10k | 91485794531897 |
| Sedã executivo | Veiculo_Sedan_A | Honda City | dewa | https://sketchfab.com/3d-models/75671276d4da476294202a5dc050a99e | ~11k | 115553911287715 |
| Sedã clássico | Veiculo_Sedan_B | Genérico Sedã anos 80 | Daniel Zhabotinsky | https://sketchfab.com/3d-models/e2678da920cc4be68dbc193727919ffb | ~12k | 122549635884536 |
| Compacto retrô | Veiculo_Sedan_C | Genérico Europeu anos 80 | Henry VIII | https://sketchfab.com/3d-models/af108d4773df4722a62420f65dd5b8fe | ~12k | 125687519955378 |
| Sedã médio | Veiculo_Sedan_D | Genérico Sedã 2005 | Han66st | https://sketchfab.com/3d-models/5d370d67172041dbae7d6f112255fdd9 | ~12k | 82437500588226 |
| Jipe 4x4 | Veiculo_SUV_A | Jeep Wrangler | Thcyrax | https://sketchfab.com/3d-models/5c090410ea544b72a6d265d1ede55795 | ~6k | 125726620610064 |
| SUV premium | Veiculo_SUV_B | Land Rover Range Rover Velar | Mona x Supercars | https://sketchfab.com/3d-models/494c03e056674423a8ca2e2af0c01eef | ~12k | 133678647291823 |
| Picape cabine estendida | Veiculo_Picape_A | Dodge Dakota | HypePerformance | https://sketchfab.com/3d-models/3d8563df156f453cbd525557e9cddb59 | ~3k | 111385777955845 |
| Picape antiga | Veiculo_Picape_B | Chevrolet Low Poly | ROH3D | https://sketchfab.com/3d-models/none-679354c151984747bb74310ec5af8995 | ~12k | 87596434598303 |
| Picape de fazenda | Veiculo_Picape_C | Ford Model Pickup | Batuhan13 | https://sketchfab.com/3d-models/none-3a50bbf9a3724cfeab7c1f9c89c0aa83 | ~12k | 93610719711106 |
| Caminhonete de carga | Veiculo_Picape_D | Suzuki Carry Pickup | by__Rx | https://sketchfab.com/3d-models/none-e1654a399b9d448a9a7ce200410ac91d | ~12k | 138771217123552 |

Os nomes de marca e modelo originais aparecem **só neste registro de origem**, nunca no jogo (o jogo usa nomes genéricos).

**Reprovados na inspeção visual (não usados):** Cruze (modelo de carro batido), Cobalt (rodas com textura errada), BMW X1 (buracos no teto após a redução), Strada/Versa do acervo (são outros carros), Audi A6/A8, CR-V, Toro, Ram, L200, Hilux, Frontier, S10, EcoSport, Voyage, 405, Prius com logotipo preso à malha, Punto: nenhum conseguiu ficar 100% sem marca sem estragar o modelo. **Limitação documentada:** só 2 SUVs sem marca ficaram bons (a meta era 4), e há 4 hatch, 4 sedã e 4 picape.

**Enviados antes e substituídos (8, sem uso, ficam no inventário do Product Owner; a API não arquiva `Model`):** 73553489026893, 125536273864529, 101982680140098, 100395099012806, 116070769072534, 132652716980467, 103181809818137, 127475407354448 (carros com marca/placa; o Roblox moderou a conta nesse lote). **Sugestão:** o Product Owner pode apagá-los em create.roblox.com > Inventário.

## Pacote de oficina (3DAssets.dev) — baixado, ainda NÃO integrado

https://3dassets.dev/packs/car-repair-garage-and-mot-workshop: página declara **CC0**; 55 GLB (36 MB) em `_assets_work/downloads/3dassets_garage` (fora do repositório). Inclui elevadores, bancadas, compressor, balanceadora, desmontadora, carrinhos de ferramenta, módulos de parede e portão. Registrar a licença de cada modelo usado.

## Kit de bairro (Shuriken Studio — Town Streets & Park) — baixado, ainda NÃO integrado

https://shuriken.studio/kits/town-streets: 32 GLB (1,3 MB). **Licença do próprio kit (LICENSE.txt):** pode usar em jogos (comercial ou não), modificar e vender projetos com os modelos dentro, sem crédito; **proibido** distribuir os modelos soltos ou em pacote/biblioteca (inclusive Creator Store e repositório público): os GLB ficam fora do GitHub. Os modelos foram feitos com IA e o autor não promete proteção por direitos autorais. Contém: estrada, calçada, estacionamento, rotatória, ponto de ônibus, postes, posto de combustível, lava-rápido, strip mall, loja de shopping, prefeitura, fórum, biblioteca e parques.

## Kenney City Kit (Roads, Suburban, Commercial) — NÃO baixado

Páginas conferidas (CC0). O download fica atrás de um botão da página, sem link direto: pendente, só se o Shuriken não bastar.

## Props do bairro, mobiliário urbano e equipamentos (2026-11-07)

Todos tratados no Blender (`pipeline/blender_process_prop.py`), enviados ao Roblox sem moderação e guardados em `ServerStorage/Assets` (`Cenario`, `Equipamentos`, `Oficina`). Os arquivos originais ficam em `_assets_work` (fora do repositório). Nenhum asset tem marca de carro, logotipo legível, placa real ou QR code (inspeção visual das prévias).

| Fonte | Licença declarada | Usado | Onde |
|---|---|---|---|
| Shuriken Studio — Town Streets & Park (https://shuriken.studio/kits/town-streets) | Licença própria "free model license": uso em jogos permitido, comercial ou não, sem crédito; **proibido redistribuir os modelos** (inclui GitHub e Creator Store) | postes, ponto de ônibus, lava-rápido, posto, galeria, estacionamento, mobiliário, jardineiras, boas-vindas | `Workspace.Bairro` |
| Shuriken Studio — Houses (https://shuriken.studio/kits/houses) | idem | 8 casas e a garagem | `Workspace.Bairro.Residencial` |
| Shuriken Studio — City (https://shuriken.studio/kits/city) | idem | semáforo, caçamba, praça, máquina, telefone, outdoor, café, mercadinho, banca, prédio | `Workspace.Bairro` |
| Shuriken Studio — Shops and Restaurants (https://shuriken.studio/kits/shops-and-restaurants) | idem | baixado, **não usado** | — |
| 3DAssets.dev — Car Repair Garage and MOT Workshop (https://3dassets.dev/packs/car-repair-garage-and-mot-workshop) | **CC0** (declarado na página) | 11 equipamentos e 20 objetos de oficina (pilha de pneus, placa, extintor, lixeira, elevador, carrinho, etc.) | `EquipmentModels` e `WorkshopSkin` |

Os modelos do Shuriken foram feitos com IA e o autor não promete proteção por direitos autorais nem exclusividade.
Ids dos 57 assets enviados: `pipeline/prop_ids.json` (e dos 14 veículos: `pipeline/asset_ids.json`).
