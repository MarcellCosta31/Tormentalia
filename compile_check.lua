-- Quick compile check
package.path = package.path .. ";.\\?.lua"
local ok, err = pcall(function()
  require "main"
end)
if ok then
  print("COMPILE_OK")
else
  print("COMPILE_FAIL: " .. tostring(err))
  os.exit(1)
end