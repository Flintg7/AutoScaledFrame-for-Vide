local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)

return function()
	local value = vide.source(workspace.CurrentCamera.ViewportSize)
	
	local conn

	vide.effect(function()
		conn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			value(workspace.CurrentCamera.ViewportSize)
		end)
	end)
	
	vide.cleanup(function()
		if conn then
			conn:Disconnect()
		end
	end)

	return value
end
