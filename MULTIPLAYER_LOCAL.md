# 🌐 Multiplayer Local - Tormentalia

## 📱 Como Funciona

### Conceito
Um jogador cria a sala usando o roteador do celular (Wi-Fi Hotspot), e outros jogadores se conectam para jogar juntos, sem precisar de internet.

### Fluxo Passo a Passo

#### Para quem cria a sala:
1. Abre o jogo
2. Clica em "Criar Sala"
3. Liga o hotspot do celular automaticamente (ou pede para ligar)
4. Define o nome da sala e número de jogadores
5. Espera outros jogadores entrarem
6. Começa o jogo quando todos estiverem prontos

#### Para quem entra:
1. Abre o jogo
2. Clica em "Entrar em Sala"
3. Conecta ao Wi-Fi do celular criador
4. Procura salas disponíveis
5. Entra na sala
6. Espera o criador começar

---

## 🔧 Técnicos

### Conexão
- **Método:** Wi-Fi Hotspot (Access Point)
- **Protocolo:** TCP/UDP via sockets
- **Biblioteca sugerida:** `react-native-tcp-socket` ou `expo-network`

### Limitações
| Recurso | Limite |
|---------|--------|
| Máximo de jogadores | 4 |
| Distância máxima | ~10 metros (mesmo cômodo) |
| Velocidade | Depende do celular "servidor" |
| Latência | ~50-200ms (aceitável) |

### Arquitetura
```
Jogador 1 (Criador)
    ↓ hotspot
Jogador 2 ─────────┐
Jogador 3 ─────────┤
Jogador 4 ─────────┘
```

O celular do Jogador 1 funciona como:
- **Servidor:** processa a lógica do jogo
- **Cliente:** mostra a interface para ele

Os outros celulares são apenas:
- **Clientes:** enviam ações, recebem estado do jogo

---

## 📋 Regras Específicas do Multiplayer

### Turnos
- Jogadores jogam em ordem aleatória (definida no início)
- Cada jogador tem 30 segundos para jogar sua vez
- Se não jogar a tempo, perde o turno automaticamente

### Comunicação
- Estado do jogo é enviado a cada jogada
- Cartas da mão são privadas (só o jogador vê)
- Saldo e turnos são públicos (todos veem)

### Sincronização
- Tudo é sincronizado pelo celular "servidor"
- Se um jogador desconectar, pode reconectar em 60 segundos
- Se não reconectar, é eliminado do jogo

---

## 🎯 Vantagens do Multiplayer Local

1. **Sem precisar de internet** - funciona em qualquer lugar
2. **Baixa latência** - conexão direta
3. **Fácil de usar** - só conectar no Wi-Fi
4. **Gratuito** - não precisa de servidores

## ❌ Desvantagens

1. **Distância limitada** - precisa estar perto
2. **Depende de um celular** - quem cria a sala não pode sair
3. **Máximo 4 jogadores** - limitação técnica
4. **Bateria** - o celular do "servidor" esquenta mais

---

## 🚀 Próximos Passos

### Fase 2 - Multiplayer Local
- [ ] Sistema de hotspots automáticos
- [ ] Descoberta de salas na rede
- [ ] Sincronização de estado
- [ ] Tratamento de desconexões

### Fase 3 - Multiplayer Online (Futuro)
- [ ] Servidor na nuvem
- [ ] Jogar com qualquer pessoa
- [ ] Rankings e estatísticas
- [ ] Salas públicas e privadas

---

*Documento técnico para implementação do multiplayer local*