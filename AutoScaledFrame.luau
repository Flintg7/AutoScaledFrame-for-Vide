--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local useViewportSize = require(ReplicatedStorage.Shared.Client.UI.Utils.useViewportSize)

local STUDIO_SIZE = Vector2.new(1500, 803)

export type AutoScaledFrameProps = {
	ScaleFactor: number?,
	MinSize: Vector2?,
	Size: UDim2,
	Position: UDim2?,
	Rotation: number?,
	AnchorPoint: Vector2?,
	BackgroundTransparency: number?,
	ZIndex: number?,
	Children: { Instance? },
	Name: string?
}

return function(props: AutoScaledFrameProps)
	local screenSize = useViewportSize() -- Get Screen Size
	local minSize = props.MinSize or Vector2.zero
	local scaleFactor = props.ScaleFactor or 1
	local scaleBinding = vide.source(scaleFactor)

	local minScale = vide.derive(function()
		return math.max(minSize.X / props.Size.X.Offset, minSize.Y / props.Size.Y.Offset)
	end)

	vide.effect(function()
		local newScale = scaleFactor * math.min(screenSize().X / STUDIO_SIZE.X, screenSize().Y / STUDIO_SIZE.Y)
		scaleBinding(math.max(newScale, minScale()))
	end)

	return vide.create("Frame", {
		Name = props.Name or "Frame",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Rotation = props.Rotation or 0,
		ZIndex = props.ZIndex or 1,
		BackgroundTransparency = props.BackgroundTransparency or 1,

		vide.action(function(instance)
			if props.action then
				props.action(instance)
			end
		end),

		vide.create("UIScale", {
			Scale = scaleBinding,
		}),
		unpack(props.Children or {}),
	})
end
