-- JSON puro-Lua (encode/decode) para as mensagens do multiplayer.
-- Suficiente para o protocolo da partida: chaves ausentes/nil caem fora,
-- tabelas com chaves 1..n viram array, o resto vira objeto; sem loadstring.
local J = {}

local concat = table.concat
local format = string.format

local ESCAPAR = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local LER_ESCAPES = {
  ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = "\b", f = "\f",
  n = "\n", r = "\r", t = "\t",
}

local function codificarTexto(s)
  return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
    return ESCAPAR[c] or format('\\u%04x', c:byte())
  end) .. '"'
end

local function codificarNumero(n)
  if n ~= n or n == math.huge or n == -math.huge then
    error("json: numero invalido (NaN/inf)", 3)
  end
  return format("%.14g", n)
end

local function ehArray(t)
  local n = #t
  if n == 0 then return next(t) == nil end
  local cont = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 or k > n then
      return false
    end
    cont = cont + 1
  end
  return cont == n
end

local function codificar(v, nivel)
  local tv = type(v)
  if tv == "nil" then error("json: nil nao serializavel", 3) end
  if tv == "boolean" then return v and "true" or "false" end
  if tv == "number" then return codificarNumero(v) end
  if tv == "string" then return codificarTexto(v) end
  if tv == "table" then
    nivel = (nivel or 0) + 1
    if nivel > 64 then error("json: tabela muito profunda", 3) end
    if ehArray(v) then
      local partes = {}
      for i = 1, #v do partes[i] = codificar(v[i], nivel) end
      return "[" .. concat(partes, ",") .. "]"
    end
    local partes = {}
    for k, val in pairs(v) do
      if val ~= nil then
        local chave
        if type(k) == "string" then
          chave = k
        elseif type(k) == "number" then
          chave = tostring(k)
        else
          error("json: chave de objeto invalida (" .. type(k) .. ")", 3)
        end
        partes[#partes + 1] = codificarTexto(chave) .. ":" .. codificar(val, nivel)
      end
    end
    return "{" .. concat(partes, ",") .. "}"
  end
  error("json: tipo nao suportado: " .. tv, 3)
end

function J.encode(v)
  return codificar(v, 0)
end

local function falha(msg, pos)
  error(format("json: %s (pos %d)", msg, pos or 0), 0)
end

local function pularEspacos(s, pos)
  return pos + #(s:match("^[ \t\r\n]*", pos) or "")
end

local function decodificarTexto(s, pos)
  local i = pos + 1
  local partes = {}
  while true do
    local c = s:sub(i, i)
    if c == "" then falha("string nao fechada", i) end
    if c == '"' then return concat(partes), i + 1 end
    if c == "\\" then
      local e = s:sub(i + 1, i + 1)
      if LER_ESCAPES[e] then
        partes[#partes + 1] = LER_ESCAPES[e]
        i = i + 2
      elseif e == "u" then
        local hex = s:sub(i + 2, i + 5)
        if not hex:match("^%x%x%x%x$") then falha("unicode invalido", i) end
        local cp = tonumber(hex, 16)
        if cp < 0x80 then
          partes[#partes + 1] = string.char(cp)
        elseif cp < 0x800 then
          partes[#partes + 1] = string.char(
            0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
        else
          partes[#partes + 1] = string.char(
            0xE0 + math.floor(cp / 4096),
            0x80 + math.floor(cp / 64) % 64,
            0x80 + cp % 64)
        end
        i = i + 6
      else
        falha("escape invalido: \\" .. e, i)
      end
    else
      partes[#partes + 1] = c
      i = i + 1
    end
  end
end

local function decodificarNumero(s, pos)
  local resto = s:sub(pos)
  if not resto:match("^[%-%d]") then falha("numero invalido", pos) end
  local tok = resto:match("^[%-%d%.eE%+]+")
  local n = tok and tonumber(tok)
  if not n or n ~= n or n == math.huge or n == -math.huge then
    falha("numero invalido: " .. tostring(tok), pos)
  end
  return n, pos + #tok
end

local decodificarValor

local function decodificarObjeto(s, pos)
  local obj = {}
  pos = pularEspacos(s, pos + 1)
  if s:sub(pos, pos) == "}" then return obj, pos + 1 end
  while true do
    pos = pularEspacos(s, pos)
    if s:sub(pos, pos) ~= '"' then falha("chave de objeto esperada", pos) end
    local chave, novaPos = decodificarTexto(s, pos)
    pos = pularEspacos(s, novaPos)
    if s:sub(pos, pos) ~= ":" then falha("':' esperado", pos) end
    pos = pularEspacos(s, pos + 1)
    local valor
    valor, pos = decodificarValor(s, pos)
    obj[chave] = valor
    pos = pularEspacos(s, pos)
    local c = s:sub(pos, pos)
    if c == "," then
      pos = pos + 1
    elseif c == "}" then
      return obj, pos + 1
    else
      falha("',' ou '}' esperado", pos)
    end
  end
end

local function decodificarArray(s, pos)
  local arr = {}
  pos = pularEspacos(s, pos + 1)
  if s:sub(pos, pos) == "]" then return arr, pos + 1 end
  while true do
    local valor
    valor, pos = decodificarValor(s, pos)
    arr[#arr + 1] = valor
    pos = pularEspacos(s, pos)
    local c = s:sub(pos, pos)
    if c == "," then
      pos = pos + 1
    elseif c == "]" then
      return arr, pos + 1
    else
      falha("',' ou ']' esperado", pos)
    end
  end
end

decodificarValor = function(s, pos)
  local c = s:sub(pos, pos)
  if c == "" then falha("entrada terminada inesperadamente", pos) end
  if c == "{" then return decodificarObjeto(s, pos) end
  if c == "[" then return decodificarArray(s, pos) end
  if c == '"' then return decodificarTexto(s, pos) end
  if s:sub(pos, pos + 3) == "true" then return true, pos + 4 end
  if s:sub(pos, pos + 4) == "false" then return false, pos + 5 end
  if s:sub(pos, pos + 3) == "null" then return nil, pos + 4 end
  if c == "-" or c:match("%d") then return decodificarNumero(s, pos) end
  falha("valor inesperado: " .. (c == "" and "<fim>" or c), pos)
end

function J.decode(s)
  if type(s) ~= "string" then error("json: entrada precisa ser string", 2) end
  local pos = pularEspacos(s, 1)
  local valor, novaPos = decodificarValor(s, pos)
  novaPos = pularEspacos(s, novaPos)
  if novaPos <= #s then falha("conteudo extra apos o valor", novaPos) end
  return valor
end

return J
