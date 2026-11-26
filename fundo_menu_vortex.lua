-- Fundo animado do menu: um vórtice de tinta em roxo, laranja e azul,
-- inspirado no fundo do Balatro. O shader roda numa canvas pequena e o
-- resultado é ampliado com filtro linear: o desenho fica macio/fluido e o
-- custo por pixel cai bastante (importante em GPU integrada).
local fundo = {}

local shader
local canvas
local BASE_W, BASE_H = 400, 225

local CODIGO = [=[
extern number time;
extern vec2 resolucao;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float ruido(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 rot = mat2(0.80, 0.60, -0.60, 0.80);
  for (int i = 0; i < 4; i++) {
    v += a * ruido(p);
    p = rot * p * 1.92;
    a *= 0.48;
  }
  return v;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  // Em retangulos sem textura o `uv` fica constante; love_PixelCoord da a
  // posicao real do fragmento na canvas.
  vec2 tela = love_PixelCoord.xy / resolucao;
  vec2 p = (tela - 0.5) * vec2(resolucao.x / resolucao.y, 1.0) * 2.0;
  float r = length(p);
  float a = atan(p.y, p.x);
  float t = time * 0.10;

  // Espiral: o angulo gira mais perto do centro e ondula lentamente.
  a += 1.9 / (r + 0.42) - t * 1.25 + sin(r * 2.6 - t * 0.9) * 0.35;
  vec2 q = vec2(cos(a), sin(a)) * (r * 1.75 + 0.10);

  // Domain warping em duas camadas: a tinta escorre e se mistura em
  // manchas grandes (sem a granulacao de alta frequencia).
  vec2 w1 = vec2(fbm(q * 1.35 + vec2(t * 0.95, -t * 0.65)),
                 fbm(q * 1.35 + vec2(-t * 0.70, t * 0.80) + 4.7));
  vec2 w2 = vec2(fbm(q * 1.80 + w1 * 1.55 + vec2(t * 0.50, t * 0.30)),
                 fbm(q * 1.80 + w1 * 1.55 + vec2(-t * 0.35, -t * 0.55) + 8.3));
  float n = fbm(q * 2.05 + w2 * 1.75 + vec2(t * 0.22, -t * 0.16));

  // Faixas largas de marmore: seno de baixa frequencia para as camadas
  // de tinta acompanharem o giro.
  float faixas = 0.5 + 0.5 * sin(n * 6.5 + r * 3.2 - t * 1.5);
  n = mix(n, faixas, 0.24);
  n = smoothstep(0.12, 0.88, n);

  // Paleta saturada com transicoes largas e suaves.
  vec3 roxoE = vec3(0.08, 0.00, 0.16);
  vec3 roxo = vec3(0.48, 0.03, 0.72);
  vec3 magenta = vec3(0.82, 0.05, 0.50);
  vec3 laranja = vec3(1.00, 0.26, 0.02);
  vec3 ambar = vec3(1.00, 0.58, 0.08);
  vec3 azul = vec3(0.02, 0.14, 0.78);
  vec3 ciano = vec3(0.03, 0.55, 0.95);

  vec3 cor = mix(roxoE, roxo, smoothstep(0.00, 0.26, n));
  cor = mix(cor, magenta, smoothstep(0.22, 0.42, n) * 0.70);
  cor = mix(cor, laranja, smoothstep(0.38, 0.55, n));
  cor = mix(cor, ambar, smoothstep(0.52, 0.64, n) * 0.72);
  cor = mix(cor, azul, smoothstep(0.60, 0.78, n));
  cor = mix(cor, ciano, smoothstep(0.80, 0.95, n));

  // Brilho suave nos veios e sombra nas dobras: da volume de tinta.
  float brilho = pow(max(0.0, faixas - 0.58), 2.0);
  cor += brilho * vec3(0.30, 0.20, 0.16);
  cor *= 0.88 + 0.16 * n;

  // Vinheta suave para fechar a composicao sem apagar as cores.
  cor *= 1.0 - smoothstep(0.68, 1.65, r) * 0.30;
  cor = clamp(cor, 0.0, 1.0);

  return vec4(cor, 1.0);
}
]=]

local function preparar()
  if shader == false then return false end
  if shader then return true end

  local ok, s = pcall(love.graphics.newShader, CODIGO)
  if not ok then
    shader = false
    return false
  end

  shader = s
  canvas = love.graphics.newCanvas(BASE_W, BASE_H)
  canvas:setFilter("linear", "linear")
  return true
end

-- Desenha o fundo na área pedida (x, y, largura, altura). Em caso de shader
-- indisponível, cai num gradiente estático escuro para o menu continuar
-- legível em qualquer driver.
function fundo.desenhar(x, y, w, h)
  if not preparar() then
    love.graphics.setColor(0.07, 0.02, 0.12, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.55, 0.12, 0.05, 0.45)
    love.graphics.circle("fill", x + w * 0.72, y + h * 0.48,
      math.min(w, h) * 0.48)
    love.graphics.setColor(0.05, 0.16, 0.55, 0.45)
    love.graphics.circle("fill", x + w * 0.58, y + h * 0.62,
      math.min(w, h) * 0.36)
    return
  end

  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setShader(shader)
  shader:send("time", love.timer.getTime())
  shader:send("resolucao", { BASE_W, BASE_H })
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, BASE_W, BASE_H)
  love.graphics.setShader()
  love.graphics.setCanvas()
  love.graphics.pop()

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, x, y, 0, w / BASE_W, h / BASE_H)
end

function fundo.nome()
  return "VORTEX (ANTIGO)"
end

return fundo
