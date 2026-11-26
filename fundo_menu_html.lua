-- Fundo do menu portado do protótipo HTML "Tormentalia - Background do
-- Menu.html" (arte/menu). É o visual com redemoinho de tinta, centro escuro
-- e correntes de roxo, azul e laranja. Roda numa canvas reduzida e é
-- ampliado com filtro linear para ficar macio e leve.
local fundo = {}

local shader
local canvas
local BASE_W, BASE_H = 480, 270

-- Mesmos parâmetros do CONFIG do HTML. Podem ser ajustados sem mexer no
-- shader; o padrão deixa o roxo dominante e o centro escuro atrás da logo.
local CONFIG = {
  duracao = 16,
  direcao = 1,
  torcao = 1.6,
  distorcao = 1.0,
  azul = 1.0,
  laranja = 1.0,
  roxo = 1.0,
  centroEscuro = 0.7,
}

local CODIGO = [=[
extern vec2 uRes;
extern number uPhase, uDir, uTwist, uWarp, uBlue, uOrange, uPurple, uCenter;

const float TAU = 6.28318530718;

const vec3 PURPLE = vec3(0.208, 0.063, 0.369);
const vec3 BLUE   = vec3(0.027, 0.333, 0.651);
const vec3 ORANGE = vec3(1.000, 0.392, 0.122);
const vec3 VOID   = vec3(0.015, 0.006, 0.040);
const vec3 VIOLET = vec3(0.420, 0.180, 0.780);
const vec3 ELEC   = vec3(0.140, 0.480, 1.000);
const vec3 EMBER  = vec3(0.900, 0.170, 0.080);

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c);
}

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 frag = love_PixelCoord.xy;
  vec2 puv = (frag - 0.5 * uRes) / uRes.y;
  float r = length(puv);
  float ph = uPhase * TAU;

  // Redemoinho: rotação global (1 volta por loop) + torção no centro.
  float ang = -uDir * (ph + uTwist * exp(-r * 1.6));
  vec2 p = rot(ang) * puv * 2.4;

  // Domain warping: dobra o espaço várias vezes, como tinta líquida.
  for (int i = 0; i < 5; i++) {
    float fi = float(i) + 1.0;
    float k1 = 1.0 + mod(float(i), 2.0);
    float k2 = 2.0 - mod(float(i), 2.0);
    p += uWarp * (0.75 / fi) * vec2(
      sin(p.y * (1.0 + 0.35 * fi) + ph * k1 + fi * 1.7),
      cos(p.x * (1.0 + 0.30 * fi) - ph * k2 + fi * 2.3)
    );
  }

  // Campos de tinta.
  float n1 = 0.5 + 0.5 * sin(p.x * 1.10 + sin(p.y * 1.30 - ph) * 1.5);
  float n2 = 0.5 + 0.5 * sin(p.y * 1.40 + cos(p.x * 0.90 + ph) * 1.6 + 2.0);
  float n3 = 0.5 + 0.5 * sin((p.x + p.y) * 1.20
    + sin(p.x * 1.70 - 2.0 * ph) * 1.2);

  // Roxo domina: da escuridão ao roxo, com toques violeta.
  vec3 col = mix(VOID, PURPLE * uPurple, smoothstep(0.05, 0.75, n1));
  col = mix(col, VIOLET * 0.55 * uPurple,
    smoothstep(0.78, 1.0, n1 * n3) * 0.6);

  // Correntes azuis atravessando o roxo.
  float stream = smoothstep(0.52, 0.92, n2) * (0.35 + 0.65 * n3);
  vec3 blue = mix(BLUE, ELEC, smoothstep(0.80, 1.0, n2));
  col = mix(col, blue, clamp(stream * 0.85 * uBlue, 0.0, 1.0));

  // Laranja: veios finos + manchas raras.
  float vein = pow(1.0 - abs(n3 * 2.0 - 1.0), 9.0);
  float blob = smoothstep(0.86, 1.0, n1 * n2 + 0.12 * sin(ph + p.x));
  float heat = clamp(vein * 0.8 + blob, 0.0, 1.0) * uOrange;
  col = mix(col, mix(EMBER, ORANGE, smoothstep(0.3, 1.0, heat)), heat * 0.9);
  col += ORANGE * pow(heat, 3.0) * 0.18;

  // Profundidade: regiões quase pretas entre as manchas.
  col *= 0.40 + 0.60 * smoothstep(0.10, 0.70, n1 * 0.6 + n2 * 0.4);

  // Composição: centro escuro/calmo, bordas intensas e vinheta.
  float edge = smoothstep(0.05, 0.85, r);
  col *= mix(1.0 - 0.88 * uCenter, 1.0, edge);
  col *= 1.0 + 0.25 * smoothstep(0.55, 1.0, r);
  col *= 1.0 - 0.45 * smoothstep(0.95, 1.45, r);

  // Dithering anti-banding.
  col += (hash(frag.xy) - 0.5) / 255.0;
  return vec4(col, 1.0);
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

function fundo.desenhar(x, y, w, h)
  if not preparar() then
    love.graphics.setColor(0.055, 0.023, 0.059, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.208, 0.063, 0.369, 0.85)
    love.graphics.rectangle("fill", x, y + h * 0.35, w, h * 0.65)
    love.graphics.setColor(1.0, 0.392, 0.122, 0.25)
    love.graphics.circle("fill", x + w * 0.18, y + h * 0.72,
      math.min(w, h) * 0.55)
    return
  end

  local fase = (love.timer.getTime() / CONFIG.duracao) % 1

  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setShader(shader)
  shader:send("uRes", { BASE_W, BASE_H })
  shader:send("uPhase", fase)
  shader:send("uDir", CONFIG.direcao)
  shader:send("uTwist", CONFIG.torcao)
  shader:send("uWarp", CONFIG.distorcao)
  shader:send("uBlue", CONFIG.azul)
  shader:send("uOrange", CONFIG.laranja)
  shader:send("uPurple", CONFIG.roxo)
  shader:send("uCenter", CONFIG.centroEscuro)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, BASE_W, BASE_H)
  love.graphics.setShader()
  love.graphics.setCanvas()
  love.graphics.pop()

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, x, y, 0, w / BASE_W, h / BASE_H)
end

function fundo.nome()
  return "TORMENTALIA (HTML)"
end

return fundo
