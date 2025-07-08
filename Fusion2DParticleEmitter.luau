local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

type NumSequence = NumberSequence | number | nil
type NumRange = NumberRange | number | nil

type ParticleEmitter2DProps = {
	Name: string?,
	Color: ColorSequence | Color3 | nil,
	Speed: NumRange,
	Rotation: NumRange,
	RotSpeed: NumRange,
	Size: NumSequence,
	Transparency: NumSequence,
	Squash: NumSequence,
	Acceleration: Vector2?,
	Lifetime: NumRange,
	SpreadAngle: number?,
	Rate: number?,
	Image: string?,
	EmissionDirection: Enum.NormalId | nil,
	Enabled: Fusion.CanBeState<boolean>?,
	FlipbookLayout: Enum.ParticleFlipbookLayout?,
	FlipbookMode: Enum.ParticleFlipbookMode?,
	FlipbookFrameRate: number?,
	FlipbookSize: Vector2?,
	OffsetX: NumRange?,
	OffsetY: NumRange?,
	Drag: number?,
	ZIndex: number?,
}

type ParticleEmitter2dConstants = {
	Image: string,
	Color: ColorSequence,
	Size: NumberSequence,
	Transparency: NumberSequence,
	Squash: NumberSequence,
	Acceleration: Vector2,
	EmissionDirection: Enum.NormalId,
	FlipbookLayout: Enum.ParticleFlipbookLayout,
	FlipbookMode: Enum.ParticleFlipbookMode,
	FlipbookFrameRate: number,
	FlipbookSize: Vector2,
	Drag: number,
	ZIndex: number,
}

type ParticleProps = {
	Parent: Fusion.Value<Instance?>,
	Speed: number,
	Rotation: number,
	RotSpeed: number,
	Lifetime: number,
	SpreadAngle: number,
	OffsetX: number,
	OffsetY: number,
	Completed: () -> (),
}

type FrameProps = {
	Size: Fusion.CanBeState<UDim2>?,
	SizeConstraint: Enum.SizeConstraint?,
	Position: Fusion.CanBeState<UDim2>?,
	AnchorPoint: Vector2?,
	Visible: Fusion.CanBeState<boolean>?,
	Enabled: Fusion.CanBeState<boolean>?,
	ZIndex: number?,
}

local DEFAULTS = {
	Name = "ParticleEmitter2D",
	Color = ColorSequence.new(Color3.new(1, 1, 1)),
	Speed = NumberRange.new(1),
	Size = NumberSequence.new(1),
	Rotation = NumberRange.new(0),
	RotSpeed = NumberRange.new(0),
	Transparency = NumberSequence.new(0),
	Squash = NumberSequence.new(0),
	Acceleration = Vector2.new(0, 0),
	Lifetime = NumberRange.new(1),
	SpreadAngle = 0,
	Rate = 1,
	Image = "rbxasset://textures/particles/sparkles_main.dds",
	EmissionDirection = Enum.NormalId.Top,
	Enabled = Fusion.Value(true),
	ZIndex = 1,
	FlipbookLayout = Enum.ParticleFlipbookLayout.None,
	FlipbookMode = Enum.ParticleFlipbookMode.Loop,
	FlipbookSize = Vector2.new(1024, 1024),
	FlipbookFrameRate = 30,
	Drag = 0,
	OffsetX = NumberRange.new(0),
	OffsetY = NumberRange.new(0),
}

local Observer = Fusion.Observer

local function GetValue(value: any): any
	if typeof(value) == "table" and value.kind then
		return value:get()
	else
		return value
	end
end

local function GetRandomValueInRange(value: any): number
	value = GetValue(value)
	if typeof(value) == "number" then
		return value
	else
		return math.random(value.Min * 1000, value.Max * 1000) / 1000
	end
end

local function EvalNumberSequence(sequence: NumberSequence, time: number)
	-- If time is 0 or 1, return the first or last value respectively
	if time == 0 then
		return sequence.Keypoints[1].Value
	elseif time >= 1 then
		return sequence.Keypoints[#sequence.Keypoints].Value
	end

	-- Otherwise, step through each sequential pair of keypoints
	for i = 1, #sequence.Keypoints - 1 do
		local currKeypoint = sequence.Keypoints[i]
		local nextKeypoint = sequence.Keypoints[i + 1]
		if time >= currKeypoint.Time and time < nextKeypoint.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (time - currKeypoint.Time) / (nextKeypoint.Time - currKeypoint.Time)
			-- Return the value between the points using alpha
			return currKeypoint.Value + (nextKeypoint.Value - currKeypoint.Value) * alpha
		end
	end

	warn("NumberSequence: Time is out of bounds")
	return sequence.Keypoints[#sequence.Keypoints].Value
end

local function EvalColorSequence(sequence: any, time: number)
	sequence = GetValue(sequence) :: ColorSequence
	-- If time is 0 or 1, return the first or last value respectively
	if time == 0 then
		return sequence.Keypoints[1].Value
	elseif time >= 1 then
		return sequence.Keypoints[#sequence.Keypoints].Value
	end

	-- Otherwise, step through each sequential pair of keypoints
	for i = 1, #sequence.Keypoints - 1 do
		local thisKeypoint = sequence.Keypoints[i]
		local nextKeypoint = sequence.Keypoints[i + 1]
		if time >= thisKeypoint.Time and time < nextKeypoint.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (time - thisKeypoint.Time) / (nextKeypoint.Time - thisKeypoint.Time)
			-- Evaluate the real value between the points using alpha
			return Color3.new(
				(nextKeypoint.Value.R - thisKeypoint.Value.R) * alpha + thisKeypoint.Value.R,
				(nextKeypoint.Value.G - thisKeypoint.Value.G) * alpha + thisKeypoint.Value.G,
				(nextKeypoint.Value.B - thisKeypoint.Value.B) * alpha + thisKeypoint.Value.B
			)
		end
	end

	warn("ColorSequence: Time is out of bounds")
	return sequence.Keypoints[#sequence.Keypoints].Value
end

local FlipbookLayoutToFrameCount = {
	[Enum.ParticleFlipbookLayout.None] = 1,
	[Enum.ParticleFlipbookLayout.Grid2x2] = 4,
	[Enum.ParticleFlipbookLayout.Grid4x4] = 16,
	[Enum.ParticleFlipbookLayout.Grid8x8] = 64,
}

local function Particle(t: Fusion.Value<number>, constants: ParticleEmitter2dConstants, props: ParticleProps)
	local position = Fusion.Value(UDim2.fromScale(0.5, 0.5))
	local rotation = Fusion.Value(props.Rotation)
	local frame = Fusion.Value(1)
	local numFrames = FlipbookLayoutToFrameCount[constants.FlipbookLayout] or 1
	local frameRate = constants.FlipbookFrameRate

	local imageRectSize = constants.FlipbookSize / math.sqrt(numFrames)
	if constants.FlipbookLayout == Enum.ParticleFlipbookLayout.None then
		imageRectSize = Vector2.new(0, 0)
	end

	if constants.FlipbookMode == Enum.ParticleFlipbookMode.OneShot then
		frameRate = numFrames / props.Lifetime
	end

	local lifeTime = props.Lifetime
	local speed = props.Speed
	local spreadAngle = props.SpreadAngle
	local rotation_o = props.Rotation
	local rotSpeed = props.RotSpeed
	local offset_x = props.OffsetX
	local offset_y = props.OffsetY

	local function updateFlipbook()
		if constants.FlipbookLayout == Enum.ParticleFlipbookLayout.None then
			return
		end

		if constants.FlipbookMode == Enum.ParticleFlipbookMode.PingPong then
			local currentFrame = math.floor(frameRate * t:get()) % (numFrames * 2) + 1
			if currentFrame > numFrames then
				frame:set(numFrames * 2 - currentFrame + 1)
			else
				frame:set(currentFrame)
			end
		elseif constants.FlipbookMode == Enum.ParticleFlipbookMode.Random then
			local currentFrame = math.floor(frameRate * t:get()) % numFrames + 1
			if currentFrame ~= frame:get() then
				frame:set(math.random(1, numFrames))
			end
		else
			frame:set(math.floor(frameRate * t:get()) % numFrames + 1)
		end
	end

	local update = Fusion.Observer(t):onChange(function()
		updateFlipbook()
		local acceleration = constants.Acceleration
		local n = t:get()
		local x = math.cos(math.rad(rotation_o + spreadAngle)) * speed * n + acceleration.Y * n ^ 2 / 2
		local y = math.sin(math.rad(rotation_o + spreadAngle)) * speed * n + acceleration.X * n ^ 2 / 2
		local rot = rotation_o + rotSpeed * n

		if n >= lifeTime then
			props.Completed()
			return
		end

		position:set(UDim2.fromScale(-y + 0.5 + offset_x, -x + 0.5 + offset_y))
		rotation:set(rot)
	end)

	return Fusion.New("ImageLabel")({
		Name = "Particle",
		Parent = props.Parent,
		BackgroundTransparency = 1,
		Image = constants.Image,
		ImageColor3 = Fusion.Computed(function()
			return EvalColorSequence(constants.Color, t:get() / lifeTime)
		end),
		ImageTransparency = Fusion.Computed(function()
			return EvalNumberSequence(constants.Transparency, t:get() / lifeTime)
		end),
		Size = Fusion.Computed(function()
			local size = EvalNumberSequence(constants.Size, t:get() / lifeTime)
			local squash = 1.45 ^ EvalNumberSequence(constants.Squash, t:get() / lifeTime)
			return UDim2.fromScale(size, size * squash)
		end),
		ImageRectSize = imageRectSize,
		ImageRectOffset = Fusion.Computed(function()
			local x = frame:get() % (numFrames ^ 0.5)
			local y = frame:get() // (numFrames ^ 0.5)
			return Vector2.new(x * imageRectSize.X, y * imageRectSize.Y)
		end),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		[Fusion.Cleanup] = update,
	})
end

local function initEmitter(
	emitterProperties: ParticleEmitter2DProps | ParticleEmitter,
	frameProps: FrameProps,
	hydratedProps: ParticleEmitter2DProps?
): ParticleEmitter2DProps
	local props = emitterProperties
	if typeof(emitterProperties) == "Instance" then
		local newProps = {}
		for key, default in DEFAULTS do
			if key == "Image" then
				newProps[key] = props.Texture or default
			elseif key == "Acceleration" then
				newProps[key] = Vector2.new(props.Acceleration.X or 0, props.Acceleration.Y or 0)
			elseif key == "SpreadAngle" then
				newProps[key] = props.SpreadAngle.X or 0
			elseif key == "FlipbookSize" then
				newProps[key] = props:GetAttribute("FlipbookSize") or default
			elseif key == "OffsetX" or key == "OffsetY" then
				newProps[key] = props:GetAttribute(key) or default
			elseif key ~= "ZIndex" and key ~= "FlipbookFrameRate" then
				newProps[key] = if props[key] ~= nil then props[key] else default
			end
		end
		newProps.Enabled = frameProps.Enabled
		props = newProps
	end

	for key, value in DEFAULTS do
		if hydratedProps and hydratedProps[key] ~= nil then
			props[key] = hydratedProps[key]
		elseif props[key] == nil then
			props[key] = value
		end
	end

	return props
end

return function(
	emitterProperties: ParticleEmitter2DProps | ParticleEmitter,
	frameProps: FrameProps,
	hydratedProps: ParticleEmitter2DProps?
)
	local updateConn: RBXScriptConnection?
	local enabledChangedConn: Fusion.Observer
	local Emitter = Fusion.Value(nil)

	local props = initEmitter(emitterProperties, frameProps, hydratedProps)
	local constants: ParticleEmitter2dConstants = {
		Image = props.Image,
		Color = props.Color,
		Size = props.Size,
		Transparency = props.Transparency,
		Squash = props.Squash,
		Acceleration = props.Acceleration,
		EmissionDirection = props.EmissionDirection,
		FlipbookLayout = props.FlipbookLayout,
		FlipbookMode = props.FlipbookMode,
		FlipbookFrameRate = props.FlipbookFrameRate,
		FlipbookSize = props.FlipbookSize,
		Drag = props.Drag,
		ZIndex = props.ZIndex,
	}

	local particles = {}
	local spawnTimer = 0
	local spreadAngle = props.SpreadAngle :: number

	local function emit()
		local t = Fusion.Value(0)
		local particle

		particle = Particle(t, constants, {
			Parent = Emitter,
			Speed = GetRandomValueInRange(props.Speed),
			Rotation = GetRandomValueInRange(props.Rotation),
			RotSpeed = GetRandomValueInRange(props.RotSpeed),
			Lifetime = GetRandomValueInRange(props.Lifetime),
			OffsetX = GetRandomValueInRange(props.OffsetX),
			OffsetY = GetRandomValueInRange(props.OffsetY),
			SpreadAngle = if spreadAngle == 0 then 0 else (math.random() - 0.5) * spreadAngle,
			Completed = function()
				for i, v in ipairs(particles) do
					if v.instance == particle then
						v.instance:Destroy()
						table.remove(particles, i)
						break
					end
				end
			end,
		})

		table.insert(particles, {
			instance = particle,
			t = t,
		})
	end

	local function update(dt: number)
		if GetValue(props.Enabled) then
			spawnTimer -= dt
			if spawnTimer <= 0 then
				emit()
				spawnTimer = 1 / GetValue(props.Rate)
			end
		elseif #particles == 0 then
			if updateConn then
				updateConn:Disconnect()
				updateConn = nil
			end
			return
		end

		for _, particle in particles do
			particle.t:set(particle.t:get() + dt)
		end
	end

	local function enable()
		if not updateConn then
			updateConn = RunService.Heartbeat:Connect(update)
		end
	end

	if typeof(props.Enabled) ~= "boolean" then
		enabledChangedConn = Observer(props.Enabled):onChange(function()
			if GetValue(props.Enabled) then
				enable()
			end
		end)
	end

	if GetValue(props.Enabled) then
		enable()
	end

	local function emitN(n: number)
		for _ = 1, n do
			emit()
		end
		enable()
	end

	frameProps.Enabled = nil
	return Fusion.New("Frame")({
		[Fusion.Ref] = Emitter,
		Name = props.Name,
		BackgroundTransparency = 1,
		Size = frameProps.Size,
		SizeConstraint = frameProps.SizeConstraint,
		Position = frameProps.Position,
		AnchorPoint = frameProps.AnchorPoint,
		Visible = frameProps.Visible,
		ZIndex = frameProps.ZIndex,
		[Fusion.Cleanup] = {
			updateConn,
			enabledChangedConn,
			particles,
			frameProps[Fusion.Cleanup],
		},
	}),
		emitN
end
