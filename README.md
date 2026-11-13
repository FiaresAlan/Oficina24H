# Oficina 24H

Simulador social de oficina mecânica para Roblox: o jogador atende clientes, diagnostica o defeito, prepara peças e equipamentos, repara com um minijogo e evolui a oficina. Servidor autoritativo, persistência em DataStore e interface em português.

## Acompanhamento do projeto

**[CHECKLIST MESTRE V1 — desenvolvimento ativo, fases até C31 (Issue #15)](https://github.com/FiaresAlan/Oficina24H/issues/15)**

**[CHECKLIST MESTRE V2 — engenharia V2-00/01/02 na PR #27 (Issue #26)](https://github.com/FiaresAlan/Oficina24H/issues/26)**

**[Relatório de engenharia V2-00/01/02](docs/V2_RODADA_01_ENGENHARIA.md)** · **[Checklist Mestre V2 atualizado](docs/CHECK_LIST_MESTRE_V2.md)** · **[Guia de assets V2 — onde baixar, licenças e importação](docs/GUIA_UNICO_ASSETS_V2.md)**

**[Direção oficial do jogo V2](docs/DIRECAO_JOGO_V2_2026-11-13.md)** · **[Checklist completo V2](docs/CHECK_LIST_MESTRE_V2.md)** · **[Pesquisa de mercado V2](docs/PESQUISA_MERCADO_V2_2026-11-13.md)** · **[Auditoria do código C1–C17](docs/AUDITORIA_V2_BASE_CODIGO_2026-11-13.md)** · **[Test-drive futuro (especificação)](docs/PROPOSTA_TEST_DRIVE_V2_FUTURO.md)**

**Status da V2 nesta branch:** V2-00/01/02 e V2-03 foram implementadas em código na [PR #27](https://github.com/FiaresAlan/Oficina24H/pull/27). **A arte nativa dos três carros e os testes Roblox Studio continuam pendentes. V2-05 foi implementada em código; V2-06 foi implementada em código; V2-07 foi implementada em engenharia na branch; V2-08–16 ainda não foram implementadas.** [Guia de mecânica V2-03](docs/V2_FASE_03_COMPONENTES.md). [Matriz dos 15 serviços V2-04](docs/V2_FASE_04_15_SERVICOS.md). [Mecânicos NPC e supervisão V2-05](docs/V2_FASE_05_FUNCIONARIOS.md). [Expansões físicas e compras seguras V2-06](docs/V2_FASE_06_EXPANSOES.md). [Bairro vivo V2-07](docs/V2_FASE_07_BAIRRO_VIVO.md).

**[Portões finais da V1 — o que ainda falta para homologar](docs/PORTOES_FINALIZACAO_V1_2026-11-13.md)**

**[Guia único de assets V1 — o que baixar e onde colocar](docs/GUIA_UNICO_ASSETS_V1.md)** — 21 carros, 11 equipamentos, NPCs, cenário, sons e HUD. Pacotes CC0/CGTrader/Shuriken **já baixados pelo proprietário**, aguardando importação/configuração no Studio; conferir licenças e não refazer a rua existente.

**[Integração de engenharia na main](https://github.com/FiaresAlan/Oficina24H/tree/main)** — fases V1 A1–C31 integradas; C21 impede perder comprovantes de repasses pendentes, com liberação apenas após confirmação de salvamento do contratado. **Ainda exige validação no Studio antes de publicação.**

**[Build/CI de código](https://github.com/FiaresAlan/Oficina24H/actions/workflows/code-health.yml)** — valida mapeamento dos 15 defeitos e executa build Rojo a cada atualização. **CI verde não equivale a jogo testado no Studio.**

A Issue #15 é o histórico técnico V1; a Issue #26 acompanha apenas a implementação futura da V2. Lá estão as caixas `[x]` para código e documentação registrados e `[ ]` para execução de testes, validação no Studio e merge. O arquivo `docs/PROGRESSO.md` permanece como histórico detalhado.

**Status de desenvolvimento (A1–C31):** regras, HUD, diagnóstico e procedimentos de **15 serviços**, recibos, recuperação de créditos de contratados, arquivo privado de provas, monitoramento de pendências, upgrades físicos de ferramentas e mecânicos NPC com deslocamento estão na `main`. C18–C21 também acrescentam token durável no reparo timing, proteção de serviços NPC e retenção segura de provas de repasses colaborativos. C22 acrescenta reconciliação das provas de antigos trabalhadores, baseada exclusivamente em créditos e reivindicações realmente persistidos, com limite de leitura do DataStore. C23 registra comprovação privada de quitação do contratado **além dos 64 lançamentos do extrato**, protege contra crédito repetido após rotação e permite a C22 liberar provas antigas mesmo offline. C24 compacta quitações comprovadamente encerradas em **tombstones permanentes** (JobId + token) para abrir espaço nos 2048 comprovantes detalhados sem permitir pagamento repetido; a confirmação exige consulta persistida ao dono. C25 **bloqueia a recuperação automática baseada só no extrato antigo do dono**, sem identificação do mecânico, e mantém uma fila privada de auditoria por claim (schema v11). C26 corrige ordens fantasmas após a saída do dono da partida e registra uma suíte do pipeline completo de ações para os 15 serviços (plano → gestos → reconstrução do servidor → qualidade), ainda pendente de execução no Studio. C27 elimina o segundo cache obsoleto do snapshot e passa a invalidar a visão do jogador por geração após ações, prompts, melhorias compradas na oficina, avisos de progressão, avaliações e desconexão, com regressão em suíte Luau. C28 revalida a existência da ordem, o vínculo do colaborador e a porcentagem acertada após o salvamento da claim, antes de qualquer consumo de peças ou crédito do proprietário. C29 rastreia chegadas canceladas e carros de clientes que já estão saindo (tanto no meio-fio quanto no pátio) para evitar veículos/NPCs órfãos depois de uma desconexão. C30 remove scripts de terceiros das cópias de carros, NPCs, equipamentos e miniaturas antes de inserir em Workspace/ReplicatedStorage. C31 acrescenta auditoria de integridade dos 21 modelos, rigs R15, sockets, dimensões e colisão e testes isolados para preparar a importação de assets. **C30 e C31 tiveram CI de código aprovado; nenhum teste novo foi executado no Roblox Studio e nenhum portão G1–G5 foi homologado.** O pipeline automatizado executa contratos estáticos e build Rojo. **As suítes Luau da sequência recente ainda não foram executadas no Studio**, e testes de perfis reais, dois jogadores, latência, telas e assets permanecem pendentes. O MVP antigo não homologa as alterações atuais. A publicação exige arte, som, licenças, desempenho e QA reais.

## Ciclo do MVP

cliente chega de carro → conversa → diagnóstico (escolha entre 3 defeitos) → preparação (peças e equipamento) → reparo (minijogo "Apertar na hora certa") → avaliação → evolução.

A qualidade do reparo soma 6 fatores: precisão, erros, habilidade, equipamento, peça e diagnóstico.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `src/shared` | Regras puras e dados: catálogo, regras de reparo, diagnóstico, clientes, textos |
| `src/server` | Serviços do servidor: ordens, veículos, clientes NPC, chegada, dados, lotes |
| `src/client` | Interface (HUD, painéis, minijogo, diagnóstico, guia do 1º atendimento) |
| `tools` | Testes (`RunAllTests`) e construtores de cenário rodados no Studio |
| `docs` | Visão, arquitetura, plano, progresso, auditoria P0, origem dos assets |

## Como rodar

1. Instale as ferramentas: `rokit install` (Rojo 7.7.1).
2. `rojo serve default.project.json` e conecte pelo plugin do Rojo no Roblox Studio.
3. Os modelos 3D (carros, clientes) ficam em `ServerStorage/Assets` dentro do place e **não** estão neste repositório (veja `docs/ORIGEM_ASSETS.md`).
4. Testes: rode `tools/RunAllTests.luau` no modo Edit. O runner mostra **PASSOU/REPROVADO**, suites ausentes e avisos; `StudioPlaceAudit` verifica modelos e mundo. Os testes das etapas posteriores também precisam ser executados no Studio; CI verde por si só não valida gameplay, multiplayer ou DataStore real. Consulte a Issue #15.

## O que não está aqui

- Pacotes brutos de modelos 3D e builds do place (`.rbxl`).
- Sprites do HUD e imagens de referência: licença a confirmar.
- Chaves de API e segredos: ficam fora do repositório.
