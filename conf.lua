function love.conf(love)
   love.window.title = "Cho"
   love.window.width = 500
   love.window.height = 500
   love.window.resizable = true
   love.window.vsync = true
   love.window.fullscreen = false

   love.modules.physics = false
   love.modules.video = false
   love.modules.audio = false
   love.modules.sound = false
   love.modules.keyboard = false
end