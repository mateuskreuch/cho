function love.conf(love)
   love.window.width = 450
   love.window.height = 800
   love.window.resizable = true
   love.window.vsync = true
   love.window.fullscreen = false
	love.window.msaa = 8

   love.modules.physics = false
   love.modules.video = false
   love.modules.touch = false
end