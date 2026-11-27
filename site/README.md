# Site de apresentação — Tormentalia

Site estático do jogo **Tormentalia**, feito em HTML, CSS e JavaScript puros.
Sem build, sem CDN, sem dependências externas. Cinco páginas, todas abertas na mesma
janela (nada de `target="_blank"`). O jogo está em **beta** (selo visível no site).

## Como abrir

Sirva a pasta localmente (não abra os HTMLs via `file://`, pois o navegador
bloqueia fontes e o envio ao Firestore):

```bash
# Node (sem dependências extras)
npm start

# ou Python
python -m http.server 8080
```

Depois acesse <http://localhost:8080>.

> Os downloads (`downloads/*.zip` e `downloads/*.apk`) são binários grandes e ficam fora do
> versionamento (ver `.gitignore`). Eles precisam existir localmente para os botões funcionarem.

## Estrutura

```
site/
├── index.html              Início (hero, jogo, multiplayer, documentação,
│                           galeria de screenshots, downloads)
├── manual.html             Manual em 6 capítulos (abas) + glossário
├── cartas.html             Galeria das 32 cartas (filtro, busca, modal)
├── avatares.html           Taylor, Marx e Mayo (habilidades e desbloqueio)
├── sugestoes.html          Formulário de sugestões (Firebase via REST)
├── css/style.css           Identidade visual dark fantasy + responsividade
├── js/cards-data.js        Dados das 32 cartas + 4 classes (extraídos do motor)
├── js/app.js               Nav por página, abas, filtros, modal, lightbox, menu
├── js/firebase-config.js   Configuração do projeto Firebase (tormentalia-db8d9)
├── js/firebase.js          Adaptador REST do Firestore (sem SDK/CDN)
├── firestore.rules         Regras de segurança do Firestore
├── firebase.json           Configuração do Firebase CLI
├── server.js               Servidor estático local (npm start)
├── assets/
│   ├── fonts/              VCR_OSD_MONO.ttf
│   └── img/
│       ├── brand/          logo, marca, mão, og-cover, favicon
│       ├── cards/          32 cartas em WebP
│       ├── avatares/       Taylor, Marx, Mayo (640px)
│       └── screens/        4 screenshots 1280×720 (arena, lobby, sala, mesa)
└── downloads/              APK, ZIP Windows, LEIA-ME e hashes
```

## Páginas

| Arquivo          | Conteúdo                                                          |
| ---------------- | ----------------------------------------------------------------- |
| `index.html`     | Hero, features, números, multiplayer, documentação, galeria, baixar |
| `manual.html`    | 6 capítulos em abas (ARIA tablist, setas do teclado) + glossário   |
| `cartas.html`    | Filtro por classe, busca sem acentos, carta aleatória, modal       |
| `avatares.html`  | Os 3 avatares jogáveis, habilidades e como ganhar moedas           |
| `sugestoes.html` | Sugestões de melhorias (preparado para Firebase)                   |

Os links da navegação levam entre as páginas pelo arquivo (`manual.html`,
`cartas.html`, `avatares.html`) ou por âncora (`index.html#multiplayer`). No índice,
a âncora `#inicio` mantém o scroll spy — e o link ativo — corretos.

## Recursos

- **Manual interativo** em 6 capítulos com abas (ARIA tablist, setas do teclado) + glossário;
  `manual.html#avatares` já abre no capítulo certo.
- **Galeria das 32 cartas** com filtro por classe, busca sem acentos, carta aleatória e
  modal de detalhes (Escape, setas ←/→, foco preso no diálogo).
- **Lightbox** de screenshots com navegação por teclado.
- **Partículas** no hero via canvas, desativadas em `prefers-reduced-motion`.
- **Responsivo** em 1100 / 900 / 760 / 560 px, com menu mobile.
- **Beta**: selo BETA no hero, nas páginas de documento e no rodapé.
- **Acessível**: skip link, foco visível, `aria-live` no status da galeria, `alt` descritivos.

## Sugestões e Firebase

O formulário envia as sugestões para o projeto **tormentalia-db8d9** usando a
**API REST do Firestore** (`js/firebase.js`), sem SDK e sem CDN.

1. A configuração pública já está em `js/firebase-config.js`.
2. Publique as regras de `firestore.rules` (elas permitem apenas `create` em
   `sugestoes/{doc}`, com validação de campos e tamanho):

   ```bash
   npx firebase-tools login
   npx firebase-tools deploy --only firestore:rules
   ```

   Ou copie o conteúdo de `firestore.rules` em **Firestore → Regras** no Console
   do Firebase e clique em **Publicar**.
3. Sirva o site por `http://localhost:8080` (`npm start`) — abrir via `file://`
   quebra o carregamento de fontes e pode bloquear o envio.

## Manutenção

- Para trocar os binários de download, atualize `downloads/` e os hashes SHA-256 em
  `downloads/LEIA-ME.txt` e `downloads/windows-zip-info.txt`.
- Os dados das cartas vivem em `js/cards-data.js`. Se o jogo mudar, regenere o dump do motor
  e atualize esse arquivo.
- O CSS é compartilhado entre as 5 páginas: ao mexer em um seletor, confira as cinco.

Nada deste diretório altera o código do jogo em si.
