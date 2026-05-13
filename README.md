Example:
```lua
return AutoScaledFrame({
		Size = UDim2.fromOffset(1500, 150),
		Position = Udim2.fromScale(0.5,0.5),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
    	MinSize = Vector2.new(1500, 150), -- I usually don't include MinSize!
		Name = "BottomBar",
		Children = {}
})
