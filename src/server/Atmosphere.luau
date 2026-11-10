-- The look of the sky and light: soft haze, gentle glow, warm colors, and
-- enough night light that the town is never pitch black.
-- (Street lamps turn on at night on each player's screen; see CityLights.)
-- Also: a helper for 3D sounds placed in the world.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Atmosphere = {}

local function ensure(className, name)
	local inst = Lighting:FindFirstChild(name) or Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

function Atmosphere.apply()
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 70, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 126, 138)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	local air = ensure("Atmosphere", "BayanAtmosphere")
	air.Density = 0.28
	air.Offset = 0.2
	air.Color = Color3.fromRGB(205, 218, 232)
	air.Decay = Color3.fromRGB(110, 120, 140)
	air.Glare = 0.2
	air.Haze = 1.2

	local bloom = ensure("BloomEffect", "BayanBloom")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6

	local color = ensure("ColorCorrectionEffect", "BayanColor")
	color.Saturation = 0.1
	color.Contrast = 0.05
	color.TintColor = Color3.fromRGB(255, 249, 240)

	local rays = ensure("SunRaysEffect", "BayanSunRays")
	rays.Intensity = 0.05
	rays.Spread = 0.6
end

-- A looping 3D sound on a part (heard nearby only). Does nothing if the
-- sound's id in Config.Sounds is empty.
function Atmosphere.loopSound(part, soundName, volume, distance)
	local id = Config.Sounds[soundName]
	if not part or not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = soundName
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = volume or 0.4
	sound.RollOffMaxDistance = distance or 40
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = part
	sound:Play()
	return sound
end

-- A one-time 3D sound on a part.
function Atmosphere.playAt(part, soundName, volume)
	local id = Config.Sounds[soundName]
	if not part or not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.RollOffMaxDistance = 50
	sound.PlayOnRemove = true
	sound.Parent = part
	sound:Destroy() -- PlayOnRemove plays it once, then it is gone
end

return Atmosphere
