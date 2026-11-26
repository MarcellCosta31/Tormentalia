local MODO_TESTE = os.getenv("JOGO_TESTE") == "1"

function love.conf(t)
  t.identity = "tormentalia"
  t.version = "11.5"

  t.window.title = "Tormentalia"
  t.window.width = 1280
  t.window.height = 720
  -- Tamanho de janela por variavel de ambiente: serve para capturas em
  -- proporcoes largas (ex.: 1600x720 de celular 20:9) e para testar o
  -- preenchimento das barras do letterbox fora do aparelho.
  local jw = tonumber(os.getenv("JOGO_JANELA_W"))
  local jh = tonumber(os.getenv("JOGO_JANELA_H"))
  if jw and jh and jw > 0 and jh > 0 then
    t.window.width = jw
    t.window.height = jh
  end
  -- No Android (LOVE 11.4+), resizable=true deixa o sensor virar o jogo
  -- para a vertical; travado, o aparelho so aceita paisagem. No desktop
  -- a interface ja se adapta por escala (letterbox), entao nao perde nada.
  t.window.resizable = false
  t.window.minwidth = 640
  t.window.minheight = 360
  t.window.vsync = 1
  t.window.msaa = 0
  t.window.highdpi = true

  if MODO_TESTE then
    t.window.visible = false
    t.window.width = 320
    t.window.height = 200
    t.window.vsync = 0
  end

  t.modules.joystick = false
  t.modules.physics = false
  t.modules.touch = true
  t.modules.mouse = true
  t.modules.video = false
end
