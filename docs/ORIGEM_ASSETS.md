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
