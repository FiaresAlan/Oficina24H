# Oficina 24H

Simulador social de oficina mecânica para Roblox: o jogador atende clientes, diagnostica o defeito, prepara peças e equipamentos, repara com um minijogo e evolui a oficina. Servidor autoritativo, persistência em DataStore e interface em português.

**Status:** MVP (P0) completo no código e testado no Studio, **ainda não pronto para lançar**. Faltam testes com jogadores reais e celular, medição de desempenho e confirmação de licenças. Veja `docs/AUDITORIA_P0.md` (seção 8) e `docs/PROGRESSO.md`.

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
4. Testes: rode `tools/RunAllTests.luau` no modo Edit (639 verificações).

## O que não está aqui

- Pacotes brutos de modelos 3D e builds do place (`.rbxl`).
- Sprites do HUD e imagens de referência: licença a confirmar.
- Chaves de API e segredos: ficam fora do repositório.
