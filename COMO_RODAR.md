# 🎮 Como Rodar o Jogo "O Caro Deus Mercado"

## Pré-requisitos

1. **Node.js** instalado (versão 16+)
2. **Expo CLI** instalado:
   ```bash
   npm install -g expo-cli
   ```
3. **App Expo** no celular (para testar no celular)

---

## Instalação

1. Abra o terminal na pasta do projeto:
   ```bash
   cd "D:\Programação\React Native\OCaroDeusMercado"
   ```

2. Instale as dependências:
   ```bash
   npm install
   ```

3. Inicie o projeto:
   ```bash
   npm start
   ```

---

## Rodar

### No Computador (Web)
```bash
npm run web
```
Ou pressione `w` no terminal após `npm start`.

### No Celular (Recomendado)
1. Abra o app **Expo** no celular
2. Escaneie o QR Code que aparece no terminal
3. O jogo abrirá no celular!

### No Emulador
```bash
npm run android  # Para Android
npm run ios      # Para iOS (apenas Mac)
```

---

## Estrutura do Projeto

```
OCaroDeusMercado/
├── App.js                    # Arquivo principal
├── package.json              # Dependências
├── src/
│   ├── cards/
│   │   └── cartas.js         # Dados de todas as cartas
│   ├── components/
│   │   └── Carta.js          # Componente visual da carta
│   ├── game/
│   │   └── logicaJogo.js     # Regras e mecânicas do jogo
│   ├── screens/
│   │   ├── TelaInicial.js    # Menu principal
│   │   └── TelaJogo.js       # Tela do jogo
│   ├── utils/
│   │   └── helpers.js        # Funções auxiliares
│   └── assets/
│       ├── sprites/          # Imagens pixel art
│       └── images/           # Outras imagens
```

---

## Como Jogar

### Início do Jogo
- Você começa com **R$ 20** e **7 cartas**
- 3 oponentes IA jogam contra você

### Durante o Turno
1. **Selecione uma carta** da sua mão (toque nela)
2. Opcionalmente, **selecione uma carta bônus** para combinar
3. Toque em **"Jogar Carta"** para usar
4. Ou toque em **"Passar Turno"** para descartar e comprar

### Regras Importantes
- Cartas verdes = ganho de dinheiro
- Cartas vermelhas = perda de dinheiro
- Cartas amarelas = bônus (não podem ser jogadas sozinhas)
- Carta roxa = coringa (efeito aleatório)
- Número no canto = chance de falha (%)

### Fim do Jogo
- **Turno 10**: quem tiver mais dinheiro vence
- **Eliminação**: se todos os outros falirem, você vence
- **Falência**: saldo 0 + saldo de emergência perdido = eliminado

---

## Solução de Problemas

### "Erro ao instalar dependências"
```bash
rm -rf node_modules
npm install
```

### "Expo não conecta"
- Verifique se o celular está na mesma rede Wi-Fi
- Ou use o modo tunnel: `npm start -- --tunnel`

### "Tela preta"
- Delete o cache: `expo start -c`

---

## Personalização

### Adicionar novas cartas
Edite `src/cards/cartas.js` e adicione novos objetos ao array `CARTAS_MEDIAS` ou `CARTAS_BONUS`.

### Mudar saldo inicial
Altere a constante `SALDO_INICIAL` em `src/game/logicaJogo.js`.

### Mudar número de turnos
Altere a constante `MAX_TURNOS` em `src/game/logicaJogo.js`.

---

*Projeto criado para Trabalho de Teoria Geral de Administração*