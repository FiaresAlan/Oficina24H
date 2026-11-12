# Oficina 24H

Simulador social de oficina mecânica para Roblox: o jogador atende clientes, diagnostica o defeito, prepara peças e equipamentos, repara com um minijogo e evolui a oficina. Servidor autoritativo, persistência em DataStore e interface em português.

## Acompanhamento do projeto

**[CHECKLIST MESTRE — 14 fases, status e PRs (Issue #15)](https://github.com/FiaresAlan/Oficina24H/issues/15)**

A Issue #15 é o painel único de check-ins. Lá estão as caixas `[x]` para código e documentação registrados e `[ ]` para execução de testes, validação no Studio e merge. O arquivo `docs/PROGRESSO.md` permanece como histórico detalhado.

**Status das mudanças recentes (A1–B4):** código versionado em branches e PRs abertos, **ainda não homologado no Roblox Studio nem integrado à `main`**. O registro de testes do MVP original não valida estas mudanças. O projeto ainda não está pronto para publicação.

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
4. Testes: rode `tools/RunAllTests.luau` no modo Edit. A branch de trabalho possui **225 verificações novas escritas**, ainda sem execução confirmada no Studio nesta sequência; confira a Issue #15.

## O que não está aqui

- Pacotes brutos de modelos 3D e builds do place (`.rbxl`).
- Sprites do HUD e imagens de referência: licença a confirmar.
- Chaves de API e segredos: ficam fora do repositório.
