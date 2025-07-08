local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

type SizerProps = {
	Size: UDim2,
	StartingScale: number?,
	AspectRatio: number?,
	MinSize: Vector2?,
}

local screenScale = Fusion.Computed(function()
	local screenSize = MainGuiController.props.screenSize:get() -- do this urself idk
	return Vector2.new(screenSize.X / 1521, screenSize.Y / 803)
end)

return function(props: SizerProps)
	local startingScale = props.StartingScale or 1
	local minSize = props.MinSize or Vector2.new(0, 0)
	local minScale = math.max(minSize.X / props.Size.X.Offset, minSize.Y / props.Size.Y.Offset)
	return {
		Fusion.New("UIScale")({
			Scale = Fusion.Computed(function()
				return math.max(startingScale * math.min(screenScale:get().X, screenScale:get().Y), minScale)
			end),
		}),
	}
end
