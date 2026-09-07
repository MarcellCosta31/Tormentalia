# 🎮 O Caro Deus Mercado - Plano do Jogo

## 📋 Resumo do Conceito

Jogo de cartas mobile com temática de administração empresarial, onde jogadores controlam CEOs que devem acumular mais capital que os rivais ao final de 10 turnos, ou falir todas as empresas concorrentes antes disso. Estilo pixel art com mecânicas simples mas estratégicas.

---

## 🎯 Objetivo do Jogo

**Condições de Vitória (uma delas):**
1. **Maior saldo ao final do turno 10** - quando o jogo acabar, quem tiver mais dinheiro vence
2. **Falir todas as outras empresas** - eliminar todos os rivais antes do turno 10

**Condição de Derrota:**
- Perder todo o saldo (chegar a R$ 0) E perder o saldo de emergência de R$ 5
- **Ou** ser o único Eliminado quando o jogo acabar no turno 10

---

## 🃏 Sistema de Cartas

### Baralho Total: ~50 cartas

**Tipos de Cartas:**

1. **Cartas Medidas** (~30 cartas)
   - Efeitos positivos: ganhar dinheiro, buffs
   - Efeitos negativos: debuffs em oponentes, perda de dinheiro
   - Exemplos:
     - "Venda de Produtos": +R$ 10
     - "Propaganda": +R$ 5
     - "Mult trabalhista": -R$ 8
     - "Concorrente ataca": -R$ 5 no oponente
     - "Crise econômica": -R$ 3 para todos

2. **Cartas Bônus (Deus Mercado)** (~15 cartas)
   - Reduzem risco ou potencializam cartas medidas
   - **NUNCA podem ser jogadas sozinhas**
   - Exemplos:
     - "Investidor Anjo": remove risco da próxima carta
     - "Consultor": +50% do efeito da carta medida
     - "Seguro": protege contra efeito negativo

3. **Cartas Coringa** (1 por jogo)
   - Efeito aleatório poderoso (bom ou ruim)
   - Pode ser jogada sozinha

---

## 🔄 Fluxo do Turno

### Início do Jogo:
- Cada jogador começa com **R$ 20**
- Cada jogador recebe **7 cartas** aleatórias

### Durante o Turno:
1. **Jogar cartas** (opcional):
   - Pode jogar 1 carta medida (sozinha ou com 1 carta bônus)
   - Pode jogar 1 carta coringa
   - **NÃO pode jogar apenas carta bônus**

2. **Verificar risco**:
   - Se a carta medida tem risco, rolar dados (1-100)
   - Se número < risco → carta falha (efeito reverso ou nada)
   - Cartas bônus podem reduzir risco ou garantir sucesso

3. **Descartar e comprar**:
   - Descarta 1 carta da mão
   - Compra 1 carta do baralho

### Final do Turno:
1. **Deus Mercado age**:
   - Sorteia 1 carta aleatória do baralho
   - Aplica efeito para TODOS os jogadores

2. **Verificar saldo**:
   - Se saldo ≤ 0 → entra em "Saldo de Emergência" (R$ 5)
   - Se perder saldo de emergência → empresa falir (eliminado)

3. **Avançar turno** (máximo 10 turnos)

---

## 💰 Sistema Financeiro

| Evento | Valor |
|--------|-------|
| Saldo Inicial | R$ 20 |
| Saldo de Emergência | R$ 5 |
| Condição de Vitória | Maior saldo ao final do turno 10 |
| Turnos Máximos | 10 |

**Valores das cartas:** de R$ -15 a R$ +20 (fáceis de entender)

---

## 🎲 Mecânicas de Risco

Cada carta medida tem um valor de risco (0-100%):
- **Baixo risco (0-30%):** cartas básicas
- **Médio risco (30-60%):** cartas com bons retornos
- **Alto risco (60-90%):** cartas muito lucrativas

**Exemplo:**
- Carta "Investimento Arriscado": +R$ 25 com 70% de risco
- Se falhar: perde R$ 10 (efeito reverso)
- Com carta bônus "Consultor": risco reduz para 35%

---

## 🎨 Estilo Visual

**Pixel Art:**
- CEOs com sprites 16x16 ou 32x32
- Cartas com ilustrações pixel art
- Tabuleiro minimalista (fundo)
- Efeitos visuais para cartas (brilhos, partículas)

**Cores:**
- Verde (dinheiro, positivo)
- Vermelho (perda, negativo)
- Dourado (Deus Mercado, bônus)

---

## 📱 Interface Mobile

**Layout:**
- Topo: Saldo do jogador, turno atual, cartas dos oponentes
- Meio: Área de jogo (cartas jogadas)
- Baixo: Mão do jogador (scroll horizontal)
- Botões: "Jogar Carta", "Passar Turno", "Ver Regras"

**Animações:**
- Cartas sendo compradas/descartadas
- Efeitos visuais ao jogar cartas
- Animação do "Deus Mercado" no final do turno

---

## 🧠 Conceitos de Administração Demonstrados

1. **Gestão Financeira:** controle de fluxo de caixa
2. **Tomada de Decisão:** escolher cartas com base no risco
3. **Planejamento:** antecipar ações dos oponentes
4. **Liderança:** gerenciar crises (saldo de emergência)
5. **Concorrência:** estratégias para eliminar rivais
6. **Risco x Retorno:** mecânica central do jogo

---

## 🔧 Tecnologias Sugeridas

**Para Mobile:**
- React Native (já está no diretório)
- Expo (facilita desenvolvimento)
- Bibliotecas de pixel art: `react-native-pixi` ou `expo-gl`

**Modos de Jogo:**
- **Single Player (inicial):** Jogador vs IA
- **Multiplayer Local (futuro):** Conexão via Wi-Fi direto (roteador do celular)

**Estrutura:**
```
/src
  /components    # Componentes React Native
  /screens       # Telas do jogo
  /game          # Lógica do jogo
  /cards         # Dados das cartas
  /assets        # Sprites pixel art
```

---

## 🌐 Multiplayer Local (Fase 2)

**Como funciona:**
1. Um jogador cria a sala (serve como "servidor")
2. Liga o roteador do celular (Wi-Fi hotspot)
3. Outros jogadores se conectam ao Wi-Fi
4. Encontram a sala e entram no jogo

**Limitações:**
- Máximo 4 jogadores (para não sobrecarregar o celular)
- Todos devem estar na mesma rede Wi-Fi
- Velocidade depende do celular que cria a sala

**Fluxo:**
```
Jogador 1: Criar Sala → Liga hotspot → Espera jogadores
Jogador 2+: Entrar no Jogo → Conectar à Sala → Jogar
```

---

## 📅 Fases de Desenvolvimento

### Fase 1: Protótipo Single Player (2-3 semanas)
- [ ] Sistema de cartas básico
- [ ] Lógica de turnos
- [ ] IA básica para oponentes
- [ ] UI simples (sem pixel art ainda)

### Fase 2: Mecânicas Single Player (2 semanas)
- [ ] Sistema de risco
- [ ] Saldo de emergência
- [ ] Condições de vitória/derrota
- [ ] IA com dificuldades diferentes

### Fase 3: Visual (2-3 semanas)
- [ ] Criar sprites pixel art
- [ ] Animações de cartas
- [ ] Efeitos visuais

### Fase 4: Multiplayer Local (2-3 semanas)
- [ ] Sistema de criação de salas
- [ ] Conexão Wi-Fi hotspot
- [ ] Sincronização de jogadas
- [ ] Limites de jogadores

### Fase 5: Polimento (1 semana)
- [ ] Balanceamento de cartas
- [ ] Testes com jogadores
- [ ] Ajustes finais

---

## 📝 Regras Resumidas para Jogadores

1. **Comece com R$ 20** e 7 cartas
2. **Jogue cartas** para ganhar dinheiro
3. **Cuidado com o risco** - cartas podem falhar
4. **Use cartas bônus** para aumentar chances
5. **No final de cada turno**, o Deus Mercado aplica um efeito
6. **Se ficar sem dinheiro**, entre em saldo de emergência
7. **Ao final do turno 10**, o jogo acaba
8. **Quem tiver mais dinheiro vence** - ou quem eliminar todos os rivais antes

---

*Projeto para disciplina de Teoria Geral de Administração*
*Estilo: Pixel Art Mobile*