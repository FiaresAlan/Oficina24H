# Arquitetura técnica — Oficina 24H

## Princípios

1. **Servidor autoritativo:** dinheiro, XP, defeitos, requisitos, pagamentos e contratação são decididos no servidor.
2. **Cliente como apresentação:** a UI solicita ações e exibe o resultado; não calcula recompensas.
3. **Configuração central:** serviços, defeitos, habilidades e equipamentos ficam em módulos compartilhados.
4. **Progressão pessoal:** XP e habilidades pertencem ao jogador.
5. **Propriedade da oficina:** equipamentos e capacidade pertencem à oficina.
6. **Separação de domínio:** dados do jogador, ordens de serviço e colaboração devem ser módulos independentes à medida que o projeto crescer.

## Estrutura Rojo

```text
Oficina24H/
├── default.project.json
├── README.md
├── docs/
│   ├── 01_VISAO_DO_JOGO.md
│   ├── 02_ARQUITETURA_TECNICA.md
│   └── 03_PROMPT_DE_REPASSE.md
└── src/
    ├── shared/
    │   ├── Config.lua
    │   └── Catalog.lua
    ├── server/
    │   ├── Main.server.lua
    │   ├── DataService.lua
    │   └── WorkshopService.lua
    └── client/
        └── Main.client.lua
```

## Fluxo de uma ordem

```text
Servidor cria ordem
       ↓
Cliente solicita snapshot
       ↓
Jogador aceita ordem
       ↓
Servidor valida oficina e estado
       ↓
Jogador diagnostica
       ↓
Servidor revela defeito e calcula requisito
       ↓
Jogador conclui serviço
       ↓
Servidor valida habilidade + equipamento
       ↓
Servidor paga moedas, reputação e XP
       ↓
Dados são salvos
```

## Segurança

Nunca confiar no cliente para:
- valor de pagamento;
- quantidade de XP;
- nível de habilidade;
- propriedade da oficina;
- defeito verdadeiro;
- equipamento instalado;
- percentual de divisão;
- identidade do profissional convidado.

Validar:
- tipo e tamanho dos argumentos;
- distância do jogador até a oficina/veículo quando o mapa existir;
- estado da ordem;
- propriedade/participação na ordem;
- rate limit por ação;
- requisitos no servidor.

O código-base valida estado, elegibilidade e valores no servidor. A validação espacial deve ser adicionada quando os modelos 3D forem conectados.

## Persistência

O protótipo salva moedas, reputação e XP por especialização com DataStoreService. Oficinas e ordens de serviço são temporárias nesta primeira versão. Equipamentos persistentes devem ser adicionados com migração de schema antes de abrir o jogo ao público.

Habilitar `Game Settings > Security > Enable Studio Access to API Services` apenas em ambiente de teste apropriado. Não usar o mesmo DataStore de produção para testes destrutivos.

## Testes obrigatórios

- jogador novo recebe dados padrão;
- reconexão mantém moedas e XP;
- jogador não conclui ordem sem habilidade;
- jogador não conclui ordem sem equipamento;
- ordem concluída não pode ser paga duas vezes;
- jogador não aceita ordem pertencente a outra oficina sem permissão;
- convite não pode pagar mais de 100% do serviço;
- jogador não consegue aceitar o próprio convite;
- NPC não concede XP ao proprietário;
- serviço concluído por funcionário concede XP ao funcionário;
- duas sessões simultâneas não duplicam recompensa.

## Próximas etapas técnicas

1. Implementar modelos de oficina/terreno no mapa.
2. Conectar ordens a veículos NPC físicos.
3. Criar interação de diagnóstico com pistas visuais/sonoras.
4. Criar ferramentas e animações de reparo.
5. Adicionar inventário de peças.
6. Persistir equipamentos e upgrades.
7. Evoluir convites para ofertas negociáveis e contratos temporários.
8. Adicionar telemetria de onboarding e conclusão do primeiro serviço.
