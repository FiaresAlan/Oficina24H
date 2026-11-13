# GUIA ÚNICO DE ASSETS — OFICINA 24H V2

**Versão:** 1.0 · 13/11/2026. **Status:** documentação, sem autorização para baixar/importar assets ou implementar gameplay V2.

Fonte principal: [Checklist Mestre V2 — Issue #26](https://github.com/FiaresAlan/Oficina24H/issues/26). Referências: [guia V1](GUIA_UNICO_ASSETS_V1.md), [autoria V1](ORIGEM_ASSETS.md), [direção V2](DIRECAO_JOGO_V2_2026-11-13.md).

## 1. Não baixar duas vezes

Os cinco pacotes **já baixados pelo proprietário na V1** são:
- `Car Repair Garage and MOT Workshop.glb` — ferramentas, máquinas, elevador, recepção.
- `CGTrader — Low Poly City/` — biblioteca de cenário, visual a aprovar.
- `Shuriken Town Streets & Park v1/` — rua e mobiliário.
- `Shuriken Houses/` — residências.
- `Shuriken City/` — edifícios e cidade.

Não baixá-los novamente. A existência dos arquivos no computador **não significa** que estejam no Studio. Claude Code está homologando a V1; antes de qualquer importação V2, obter inventário e backup do **place original**, preservar rua, modelos normalizados e licenças. Os 21 carros e 11 equipamentos do catálogo V1 permanecem especificados no [guia V1](GUIA_UNICO_ASSETS_V1.md).

**Direção visual:** estilizado com materiais e mecânica críveis, sem migrar para low-poly puro nem trocar os carros atuais de uma vez. Primeiro validar apenas três arquétipos: hatch, sedã e picape.

## 2. Catálogo — asset, origem exata, licença e necessidade

| ID | O que é / aplicação | Onde obter ou localizar | Licença / custo | Situação | Fases |
|---|---|---|---|---|---|
| V2-A01 | **Três carros piloto** com capô/portas/rodas, versões intacta e desgastada: hatch, sedã e picape | **Reusar catálogo V1** em `ServerStorage.Assets.Veiculos`; conferir [tabela de 21 nomes/IDs](GUIA_UNICO_ASSETS_V1.md) | Autoria e permissões de cada carro devem ser conferidas | **Reaproveitar; nenhum download obrigatório** | 01,03,04,11 |
| V2-A02 | **Máquinas e ferramentas:** elevador, guincho, cavaletes, scanner, torno/bancada, balanceadora, desmontadora, macaco, rodas, compressor, torquímetro | [Car Repair Garage and MOT Workshop](https://3dassets.dev/packs/car-repair-garage-and-mot-workshop) · [manifest de GLBs individuais](https://3dassets.dev/api/v1/packs/car-repair-garage-and-mot-workshop) | **CC0**, gratuito/comercial | **Pack já baixado V1**, extrair só as peças necessárias | 02–06 |
| V2-A03 | **Componentes mecânicos separáveis:** bloco e cabeçote do motor, bateria/terminais, alternador, velas, disco/pinça, amortecedor, radiador, bomba, rodas, pneus, fiação | [Survivor Vehicle Maintenance](https://3dassets.dev/packs/survivor-vehicle-maintenance) · [manifest de GLBs individuais](https://3dassets.dev/api/v1/packs/survivor-vehicle-maintenance) | **CC0**, gratuito/comercial; 62 modelos no pack | **NOVO — não baixado; candidato principal V2**, selecionar componentes por serviço | 03–04 |
| V2-A04 | Balcão, assentos, quadro de chaves, calendário, prateleira/estoque, decoração de recepção | **Mesmo pack V2-A02**, não baixar outro | CC0 | **Reusar V1** | 02,05,08 |
| V2-A05 | Ruas, calçadas, casas, postes, lojas, mobiliário, cenografia | [Shuriken Town Streets](https://shuriken.studio/kits/town-streets), [Houses](https://shuriken.studio/kits/houses), [City](https://shuriken.studio/kits/city) | Gratuito em jogos comerciais; **proibida redistribuição dos arquivos avulsos** | **Já baixado V1**; não refazer bairro aprovado | 07 |
| V2-A06 | Materiais PBR: asfalto, concreto, metal pintado, borracha, desgaste, ferrugem, tecido/couro | [Poly Haven — texturas](https://polyhaven.com/textures) · [licença](https://polyhaven.com/license) | **CC0**, gratuito/comercial | **NOVO opcional**, apenas materiais aprovados | 01,03,04,09,10 |
| V2-A07 | Iluminação/HDRI para testes de Blender (não substitui Lighting do Roblox) | [Poly Haven — HDRIs](https://polyhaven.com/hdris) | CC0 | Opcional; não é requisito de download | 01 |
| V2-A08 | Clientes/mecânicos R15, roupas e variações visuais | **Rigs já usados na V1**, `ServerStorage.Assets.Clientes`; Roblox Rig Builder oficial se faltar | Regras/autoria da Roblox e permissões dos avatares | **Reusar; nenhum pack externo necessário** | 05,07 |
| V2-A09 | Carros leves e peças separadas para protótipos de tráfego/dirigibilidade | [Shuriken Town Vehicles](https://shuriken.studio/kits/town-vehicles) | Gratuito comercial sob licença Shuriken | **NOVO opcional**. Estética low-poly: usar só se passar no teste visual, não substituir os carros V1 por padrão | 07,11 |
| V2-A10 | Sons de painel, confirmação de compra, botão e menu | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) e [UI Audio](https://kenney.nl/assets/ui-audio) | **CC0**, gratuito | Opcional; comparar com sons atuais | 02,06,08 |
| V2-A11 | Impacto/contato de ferramentas e peças | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) + IDs existentes em `src/shared/SoundIds.lua` | Kenney CC0; direitos de áudios Roblox devem ser auditados separadamente | Opcional; mecânica precisa de qualidade sonora coerente | 03,04 |
| V2-A12 | Ícones de negócio: fila, margem, estoque, funcionário, caixa, contrato | [Lucide](https://lucide.dev/icons/) · [licença](https://lucide.dev/license), ou ícones próprios | ISC/MIT conforme o ícone; incluir notices obrigatórios | Opcional; parte da arte do HUD V1 tem autoria pendente | 02,08 |
| V2-A13 | Superfícies de dano, pintura, roda nova/usada, peças restauradas | Criar **variantes próprias no Blender** a partir de V2-A01/A03 | Herda a licença dos modelos de origem | Não precisa de nova compra ou download | 03,04,09,10 |
| V2-A14 | Interior dirigível, volante e sinais do test-drive | Reaproveitar carro piloto e rua existentes; HUD/sinais por código | Herdar as fontes originais | **Sem novo pack obrigatório** | 11–13 |
| V2-A15 | Frota/contratos e showroom | Reaproveitar catálogo V1; variantes limitadas | Herdar as fontes originais | **Sem download obrigatório** | 09,10,14 |

**Fontes verificadas em 13/11/2026:** 3DAssets.dev publica os dois packs indicados em CC0 com GLBs individuais/manifestos; Poly Haven usa CC0; Kenney marca os pacotes de áudio indicados como CC0; Shuriken permite jogos comerciais, mas proíbe redistribuição dos GLBs avulsos; Lucide possui obrigação de notices sob licenças ISC/MIT. Verificar novamente a licença ao baixar.

## 3. Novo pack principal: componentes mecânicos, não carros novos

**V2-A03 — [Survivor Vehicle Maintenance](https://3dassets.dev/packs/survivor-vehicle-maintenance)**, 62 GLBs CC0.

Peças prioritárias no primeiro slice:
- Motor: `Engine Block`, `Cylinder Head`, `Ignition Coil`, `Spark Plug` e `Alternator`.
- Eletricidade: `Vehicle Battery`, `Battery Tray`, `Battery Terminal Clamp`, `Wiring Harness`.
- Freios/suspensão: `Brake Disc Hub`, `Brake Caliper`, `Coil Spring Strut`.
- Arrefecimento: `Radiator Core`, `Radiator Fan`, `Expansion Reservoir`, `Water Pump`.
- Rodas: selecionar uma roda/pneu compatível com a escala do carro piloto.

**Como baixar:** abrir a página acima, clicar em `Download pack` ou usar os links específicos do [manifest](https://3dassets.dev/api/v1/packs/survivor-vehicle-maintenance). **Não** inserir todos os 62 modelos na rua: extrair os selecionados e padronizar material/escala no Blender. O visual original é "survival/weathered" e pode exigir retexturização para combinar com a V2.

**Primeira prioridade após o OK:** somente um conjunto de sete peças — `V2_EngineBlock`, `V2_Battery`, `V2_BrakeDisc`, `V2_BrakeCaliper`, `V2_CoilStrut`, `V2_Radiator` e `V2_Wheel`. Depois selecionar outras de acordo com os 15 serviços.

## 4. Estrutura PROPOSTA no Studio

```text
ServerStorage
└─ Assets
   ├─ Veiculos/           # 21 carros V1 (NÃO RENOMEAR)
   ├─ Clientes/           # NPCs R15 V1
   ├─ Equipamentos/       # Eq_* V1 e fallback
   ├─ Cenario/            # cenário V1 preservado
   └─ V2/                # CAMINHO AINDA NÃO USADO POR CÓDIGO
      ├─ Componentes/
      │  ├─ Motor/
      │  ├─ Eletrica/
      │  ├─ Freios/
      │  ├─ Suspensao/
      │  ├─ Arrefecimento/
      │  └─ Rodas/
      ├─ Ferramentas/
      ├─ Recepcao/
      ├─ Variantes/
      ├─ Pilotos/
      └─ Bairro/
```

**Importante:** `Assets.V2` ainda é apenas organização sugerida. O loader V2 precisa ser implementado antes que o jogo utilize esses caminhos. Rojo sincroniza os scripts, **não os GLBs presentes no place**. Não colocar GLBs de terceiros no GitHub público quando a licença proibir redistribuição.

### Pivôs e attachments
- Preservar `PrimaryPart = Raiz`, `Casco`, `Largura`, `Comprimento`, `Altura` e `Motorista` nos carros V1.
- Preservar `OficinaSocket_<StepId>` da V1 (ex.: `OficinaSocket_WheelBolts`). Evitar criar sockets duplicados para a mesma etapa.
- **Proposta futura**: `V2Pivot_Hood`, `V2Pivot_DoorLeft`, `V2Pivot_DoorRight`, `V2Pivot_Trunk` e pontos de roda `V2Pivot_WheelFL/FR/RL/RR`. Esses nomes **não estão implementados**; serão contratados na V2-03 e só então configurados.

## 5. Matriz dos sistemas mecânicos

| Família de serviço | Componentes mínimos a mostrar | Origem |
|---|---|---|
| Pneu, roda, alinhamento | Roda removível, parafusos, pneu em estados íntegro/desgastado, elevador, alinhador | A01 + A02 + A03 |
| Bateria/alternador/elétrica | Capô articulado, bateria, terminais, alternador e scanner, painel com alerta | A01 + A02 + A03 |
| Arrefecimento | Radiador, mangueira, bomba, reservatório e vapor leve | A01 + A03 |
| Motor/ignição | Capô, bloco, bobina/velas, ferramenta e peças substituídas | A01 + A02 + A03 |
| Freios/suspensão | Disco, pinça, amortecedor/mola, elevador e roda | A01 + A02 + A03 |
| Lataria/pintura | Capô/porta/painel, amassado, tinta/material, acabamento | A01 + A02 + A06/A13 |
| Gestão | Balcão, quadro, prateleiras, computador, máquinas, caixa, upgrades | A02 + A04 + A12 |

Os **15 serviços** mantêm regras de negócio e reparo da V1. A V2 adiciona **representação física apropriada**, não substitui a segurança das transações por efeitos visuais.

## 6. Licenças e riscos

- **3DAssets.dev A02/A03:** CC0. Salvar URL/versão e data da obtenção.
- **Poly Haven:** CC0. Texturas menores e atlas quando possível, evitando exagerar na memória mobile.
- **Kenney:** CC0 nos três pacotes indicados.
- **Shuriken:** gratuito para uso em jogos, inclusive comerciais, **não redistribuir modelos isolados ou packs**. [Licença oficial](https://shuriken.studio/legal/models).
- **Lucide:** ISC/MIT, preservar avisos de direitos/licença nos arquivos exigidos. Não tratar como CC0.
- **Carros de Creator Store/Sketchfab:** comprovar direitos por modelo, revisar marcas/logos e placas. O `Veiculo_VIP_Corvette` tem licença pendente na V1: não publicar sem regularizar/substituir.
- **Decals/HUD V1:** imagens recortadas de referência têm licença comercial pendente; substituir por artes próprias ou comprovadamente autorizadas.
- **Áudio Roblox:** um ID em `SoundIds.lua` não garante permissão de reprodução para o jogo; confirmar titular e uso no Creator Hub.
- **Modelos de terceiros:** retirar `Script`, `LocalScript` e `ModuleScript` embutidos; fazer inspeção manual antes de mover para Workspace.

## 7. Procedimento de importação e aceite

1. Fazer backup do **place original** com rua aprovada.
2. Consultar o inventário real da V1 do Claude; **não baixar o que já existe**.
3. Para cada novo GLB: conferir licença, autoria, tamanho, escala, normals, malha, material, pivô; importar primeiro no Blender/Studio. [Especificações Roblox](https://create.roblox.com/docs/art/modeling/specifications) · [Importador](https://create.roblox.com/docs/studio/importer).
4. Normalizar componentes para o carro piloto: encaixe visual, Attachment, animação, colisões, pivot e estados danificado/reparado. Evitar centenas de partes físicas ativas.
5. Registrar a origem no manifesto: nome final, URL, titular, licença/versão, data, formato, transformação, pasta, responsável, ID Roblox, situação.
6. Executar `RunAllTests`, `StudioPlaceAudit` e futuros testes V2 com **assets reais**; não marcar aprovado sem evidencia.
7. Conferir touch/gamepad, StreamingEnabled, FPS/memória, licença e áudio; o cliente e o servidor não podem depender de URL externa de GLB em runtime.

## 8. O que baixar AGORA?

**Nada durante esta fase documental.**

Depois do OK e do início da engenharia, o único download adicional recomendado como primeira prioridade é o **A03 Survivor Vehicle Maintenance**, quando V2-03 requerer componentes. Texturas, áudio e ícones são opcionais e serão escolhidos conforme o estilo aprovado. V1 mantém a prioridade de homologação pelo Claude Code; não sobrescrever o place da V1.
