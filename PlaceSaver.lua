--[[
	Place Saver (Delta / executores com decompile + writefile)

	Salva o jogo inteiro (mapa, GUIs, modelos, efeitos, valores e scripts
	decompilados) em um arquivo .rbxlx que abre direto no Roblox Studio:

	    <NomeDoJogo> (<PlaceId>).rbxlx   -> pasta "workspace" do executor

	Modos:
	  "auto"    -> usa o saveinstance() do executor se existir (mais completo:
	               salva unions, terreno e meshes certinho); se falhar, usa o
	               salvador embutido deste script
	  "native"  -> só o saveinstance() do executor
	  "builtin" -> só o salvador embutido (Lua puro, funciona em qualquer
	               executor com writefile + decompile)

	Limitações do modo embutido: Terrain não é salvo, Unions podem aparecer
	vazias e alguns MeshParts podem ficar com tamanho errado (dados que o
	cliente não expõe). Scripts de servidor não existem no cliente, então
	aparecem só com um comentário.
]]

local CONFIG = {
	-- Nome do arquivo (vazio = "<NomeDoJogo> (<PlaceId>)")
	FileName = "",

	Mode = "auto", -- "auto" | "native" | "builtin"

	-- Serviços salvos (modo embutido)
	Services = {
		"Workspace",
		"Lighting",
		"ReplicatedFirst",
		"ReplicatedStorage",
		"StarterGui",
		"StarterPack",
		"StarterPlayer",
		"SoundService",
		"Teams",
		"MaterialService",
	},

	DecompileScripts = true, -- false = salva scripts vazios (bem mais rápido)
	DecompileTimeout = 10, -- segundos por script

	RemovePlayerCharacters = true, -- não salva os bonecos dos jogadores
	SkipCoreScripts = true, -- ignora PlayerModule, ChatScript, etc.
	IncludePlayerGui = true, -- GUIs que só existem no PlayerGui vão pro StarterGui
	IncludePlayerScripts = true, -- scripts do PlayerScripts vão pro StarterPlayerScripts
	IncludeNilInstances = true, -- scripts parentados a nil -> ReplicatedStorage._NilInstances
	IncludeLoadedModules = true, -- módulos carregados fora da árvore -> idem

	YieldEvery = 500, -- pausa a cada N instâncias para não travar o jogo
}

---------------------------------------------------------------------------
-- Funções do executor
---------------------------------------------------------------------------
local env = getgenv and getgenv() or _G
local decompile = env.decompile or decompile
local getscriptbytecode = env.getscriptbytecode or getscriptbytecode
local writefile = env.writefile or writefile
local getnilinstances = env.getnilinstances or getnilinstances
local getloadedmodules = env.getloadedmodules or getloadedmodules
local gethiddenproperty = env.gethiddenproperty or gethiddenproperty
local saveinstance = env.saveinstance or saveinstance

assert(writefile, "Executor sem suporte a writefile()")

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local function notify(text)
	print("[PlaceSaver] " .. text)
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
		Title = "Place Saver",
		Text = text,
		Duration = 5,
	})
end

local function sanitize(name)
	name = tostring(name):gsub('[<>:"/\\|%?%*%c]', "_"):gsub("^%s+", ""):gsub("%s+$", "")
	name = name:gsub("%.+$", "")
	if name == "" then
		name = "_"
	end
	return name
end

local gameName = "Game"
pcall(function()
	gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
end)

local FILE_NAME = CONFIG.FileName ~= "" and CONFIG.FileName
	or ("%s (%d)"):format(sanitize(gameName), game.PlaceId)

---------------------------------------------------------------------------
-- Modo nativo (saveinstance do executor)
---------------------------------------------------------------------------
local function tryNative()
	if not saveinstance then
		return false, "executor sem saveinstance()"
	end
	notify("Usando saveinstance() do executor...")
	local options = {
		FilePath = FILE_NAME,
		mode = "optimized",
		noscripts = not CONFIG.DecompileScripts,
		timeout = CONFIG.DecompileTimeout,
		DecompileTimeout = CONFIG.DecompileTimeout,
		NilInstances = CONFIG.IncludeNilInstances,
		RemovePlayerCharacters = CONFIG.RemovePlayerCharacters,
		IgnoreDefaultPlayerScripts = CONFIG.SkipCoreScripts,
		SavePlayers = false,
		ShowStatus = true,
	}
	local ok, err = pcall(saveinstance, options)
	if not ok then
		-- assinatura antiga: saveinstance(game, options)
		ok, err = pcall(saveinstance, game, options)
	end
	return ok, err
end

if CONFIG.Mode ~= "builtin" then
	local ok, err = tryNative()
	if ok then
		notify("Pronto! Salvo como " .. FILE_NAME .. " (.rbxlx / .rbxl)")
		return
	end
	if CONFIG.Mode == "native" then
		notify("saveinstance falhou: " .. tostring(err))
		return
	end
	warn("[PlaceSaver] saveinstance indisponível/falhou (" .. tostring(err) .. "), usando o modo embutido")
end

---------------------------------------------------------------------------
-- Propriedades salvas por classe (modo embutido)
--
-- Formato: "[!]Nome[:Tipo][=NomeNoXML]"
--   !     -> propriedade escondida (lida com gethiddenproperty)
--   Tipo  -> força o tipo no XML (int, int64, double, Content, Ref,
--            Color3uint8, OptionalCFrame); sem tipo = detecta pelo valor
--   =X    -> nome diferente no arquivo (ex.: BasePart.Size vira "size")
-- Propriedades que não existem na classe são ignoradas sozinhas.
---------------------------------------------------------------------------
local TEXT_PROPS = {
	"Text", "TextColor3", "TextSize", "TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment",
	"TextTransparency", "TextStrokeColor3", "TextStrokeTransparency", "TextTruncate", "RichText",
	"LineHeight", "MaxVisibleGraphemes:int", "FontFace",
}
local IMAGE_PROPS = {
	"Image:Content", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize",
	"ResampleMode", "ScaleType", "SliceCenter", "SliceScale", "TileSize",
}

local PROPS = {
	-- Scripts
	{ "BaseScript", { "Disabled", "RunContext" } },

	-- Valores (os específicos antes do genérico)
	{ "IntValue", { "Value:int64" } },
	{ "NumberValue", { "Value:double" } },
	{ "ObjectValue", { "Value:Ref" } },
	{ "ValueBase", { "Value" } },

	-- Partes
	{ "BasePart", {
		"Anchored", "CanCollide", "CanTouch", "CanQuery", "CastShadow", "Locked", "Massless",
		"CFrame", "Size=size", "Color:Color3uint8=Color3uint8", "Material",
		"MaterialVariant=MaterialVariantSerialized", "Transparency", "Reflectance", "CollisionGroup",
		"RootPriority:int", "PivotOffset", "CustomPhysicalProperties",
		"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface",
	} },
	{ "Part", { "Shape=shape" } },
	{ "TrussPart", { "Style" } },
	{ "MeshPart", {
		"MeshId:Content", "TextureID:Content", "DoubleSided", "RenderFidelity", "CollisionFidelity",
		"!InitialSize",
	} },
	{ "PartOperation", {
		"UsePartColor", "RenderFidelity", "CollisionFidelity", "SmoothingAngle",
		"!AssetId:Content", "!InitialSize",
	} },
	{ "SpawnLocation", { "Neutral", "TeamColor", "Duration:int", "AllowTeamChangeOnTouch", "Enabled" } },
	{ "Seat", { "Disabled" } },
	{ "VehicleSeat", { "Disabled", "MaxSpeed", "Torque", "TurnSpeed", "HeadsUpDisplay" } },

	-- Modelos / mundo
	{ "Model", {
		"PrimaryPart:Ref", "WorldPivot:OptionalCFrame=WorldPivotData", "LevelOfDetail", "ModelStreamingMode",
	} },
	{ "Workspace", { "Gravity", "FallenPartsDestroyHeight", "GlobalWind", "CurrentCamera:Ref" } },
	{ "Camera", { "CFrame", "Focus", "FieldOfView", "CameraType" } },
	{ "Attachment", { "CFrame", "Visible" } },
	{ "JointInstance", { "Part0:Ref", "Part1:Ref", "C0", "C1", "Enabled" } },
	{ "WeldConstraint", { "Part0:Ref=Part0Internal", "Part1:Ref=Part1Internal", "Enabled" } },
	{ "Constraint", {
		"Attachment0:Ref", "Attachment1:Ref", "Enabled", "Visible", "Color",
		-- Rope / Rod / Spring / Hinge / Align / etc.
		"Length", "Thickness", "Restitution", "Stiffness", "Damping", "FreeLength", "MaxForce", "MaxTorque",
		"ActuatorType", "AngularVelocity", "AngularSpeed", "MotorMaxTorque", "ServoMaxTorque", "TargetAngle",
		"LimitsEnabled", "LowerAngle", "UpperAngle", "Responsiveness", "RigidityEnabled", "Mode",
		"ReactionForceEnabled", "ReactionTorqueEnabled", "Velocity", "VectorVelocity", "Position",
		"RelativeTo", "ApplyAtCenterOfMass", "Force", "Torque", "LineDirection", "PrimaryAxisOnly",
	} },

	-- Personagem
	{ "Humanoid", {
		"DisplayName", "Health=Health_XML", "MaxHealth", "WalkSpeed", "JumpPower", "JumpHeight", "UseJumpPower",
		"HipHeight", "RigType", "AutoRotate", "AutoJumpEnabled", "DisplayDistanceType", "HealthDisplayType",
		"HealthDisplayDistance", "NameDisplayDistance", "NameOcclusion", "RequiresNeck", "BreakJointsOnDeath",
		"MaxSlopeAngle", "EvaluateStateMachine",
	} },
	{ "Shirt", { "ShirtTemplate:Content" } },
	{ "Pants", { "PantsTemplate:Content" } },
	{ "ShirtGraphic", { "Graphic:Content" } },
	{ "Clothing", { "Color3" } },
	{ "Accoutrement", { "AttachmentPoint" } },
	{ "BodyColors", {
		"HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3",
	} },
	{ "Animation", { "AnimationId:Content" } },
	{ "Tool", {
		"CanBeDropped", "Enabled", "Grip", "ManualActivationOnly", "RequiresHandle", "ToolTip",
	} },
	{ "BackpackItem", { "TextureId:Content" } },

	-- Visual / efeitos
	{ "Texture", { "StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV" } },
	{ "Decal", { "Texture:Content", "Color3", "Transparency", "Face", "ZIndex:int" } },
	{ "SpecialMesh", { "MeshType" } },
	{ "FileMesh", { "MeshId:Content", "TextureId:Content" } },
	{ "DataModelMesh", { "Scale", "Offset", "VertexColor" } },
	{ "Light", { "Brightness", "Color", "Enabled", "Shadows", "Range", "Angle", "Face" } },
	{ "ParticleEmitter", {
		"Acceleration", "Brightness", "Color", "Drag", "EmissionDirection", "Enabled", "FlipbookFramerate",
		"FlipbookLayout", "FlipbookMode", "Lifetime", "LightEmission", "LightInfluence", "LockedToPart",
		"Orientation", "Rate", "RotSpeed", "Rotation", "Shape", "ShapeInOut", "ShapePartial", "ShapeStyle",
		"Size", "Speed", "SpreadAngle", "Squash", "Texture:Content", "TimeScale", "Transparency",
		"VelocityInheritance", "ZOffset", "WindAffectsDrag",
	} },
	{ "Beam", {
		"Attachment0:Ref", "Attachment1:Ref", "Brightness", "Color", "CurveSize0", "CurveSize1", "Enabled",
		"FaceCamera", "LightEmission", "LightInfluence", "Segments:int", "Texture:Content", "TextureLength",
		"TextureMode", "TextureSpeed", "Transparency", "Width0", "Width1", "ZOffset",
	} },
	{ "Trail", {
		"Attachment0:Ref", "Attachment1:Ref", "Brightness", "Color", "Enabled", "FaceCamera", "Lifetime",
		"LightEmission", "LightInfluence", "MaxLength", "MinLength", "Texture:Content", "TextureLength",
		"TextureMode", "Transparency", "WidthScale",
	} },
	{ "Fire", { "Color", "SecondaryColor", "Enabled", "Heat=heat_xml", "Size=size_xml", "TimeScale" } },
	{ "Smoke", {
		"Color", "Enabled", "Opacity=opacity_xml", "RiseVelocity=riseVelocity_xml", "Size=size_xml", "TimeScale",
	} },
	{ "Sparkles", { "SparkleColor", "Enabled", "TimeScale" } },
	{ "Highlight", {
		"Adornee:Ref", "DepthMode", "Enabled", "FillColor", "FillTransparency", "OutlineColor", "OutlineTransparency",
	} },

	-- Interação
	{ "ProximityPrompt", {
		"ActionText", "ObjectText", "Enabled", "Exclusivity", "GamepadKeyCode", "HoldDuration", "KeyboardKeyCode",
		"MaxActivationDistance", "RequiresLineOfSight", "Style", "UIOffset", "ClickablePrompt",
	} },
	{ "ClickDetector", { "MaxActivationDistance", "CursorIcon:Content" } },

	-- Som
	{ "Sound", {
		"SoundId:Content", "Volume", "Looped", "PlaybackSpeed", "PlayOnRemove", "RollOffMaxDistance",
		"RollOffMinDistance", "RollOffMode", "SoundGroup:Ref",
	} },
	{ "SoundGroup", { "Volume" } },
	{ "SoundEffect", { "Enabled", "Priority:int" } },
	{ "SoundService", { "AmbientReverb", "DistanceFactor", "DopplerScale", "RolloffScale", "RespectFilteringEnabled" } },

	-- Iluminação
	{ "Lighting", {
		"Ambient", "Brightness", "ColorShift_Bottom", "ColorShift_Top", "EnvironmentDiffuseScale",
		"EnvironmentSpecularScale", "ExposureCompensation", "FogColor", "FogEnd", "FogStart",
		"GeographicLatitude", "GlobalShadows", "OutdoorAmbient", "ShadowSoftness", "TimeOfDay", "Technology",
	} },
	{ "Sky", {
		"SkyboxBk:Content", "SkyboxDn:Content", "SkyboxFt:Content", "SkyboxLf:Content", "SkyboxRt:Content",
		"SkyboxUp:Content", "SunTextureId:Content", "MoonTextureId:Content", "StarCount:int",
		"CelestialBodiesShown", "SunAngularSize", "MoonAngularSize", "SkyboxOrientation",
	} },
	{ "Atmosphere", { "Density", "Offset", "Color", "Decay", "Glare", "Haze" } },
	{ "Clouds", { "Cover", "Density", "Color", "Enabled" } },
	{ "PostEffect", {
		"Enabled", "Intensity", "Size", "Threshold", "Brightness", "Contrast", "Saturation", "TintColor",
		"Spread", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity",
	} },

	-- Jogadores / times
	{ "StarterPlayer", {
		"AutoJumpEnabled", "CameraMaxZoomDistance", "CameraMinZoomDistance", "CameraMode",
		"CharacterJumpHeight", "CharacterJumpPower", "CharacterMaxSlopeAngle", "CharacterUseJumpPower",
		"CharacterWalkSpeed", "DevCameraOcclusionMode", "DevComputerCameraMovementMode",
		"DevComputerMovementMode", "DevTouchCameraMovementMode", "DevTouchMovementMode",
		"EnableMouseLockOption", "HealthDisplayDistance", "LoadCharacterAppearance", "NameDisplayDistance",
		"UserEmotesEnabled",
	} },
	{ "Team", { "TeamColor", "AutoAssignable" } },

	-- GUI
	{ "LayerCollector", { "Enabled", "ResetOnSpawn", "ZIndexBehavior" } },
	{ "ScreenGui", {
		"DisplayOrder:int", "IgnoreGuiInset", "ScreenInsets", "ClipToDeviceSafeArea", "SafeAreaCompatibility",
	} },
	{ "SurfaceGuiBase", { "Adornee:Ref", "Face", "Active" } },
	{ "SurfaceGui", {
		"AlwaysOnTop", "Brightness", "CanvasSize", "ClipsDescendants", "LightInfluence", "PixelsPerStud",
		"SizingMode", "ZOffset", "MaxDistance",
	} },
	{ "BillboardGui", {
		"Adornee:Ref", "Active", "AlwaysOnTop", "Brightness", "ClipsDescendants", "DistanceLowerLimit",
		"DistanceUpperLimit", "ExtentsOffset", "ExtentsOffsetWorldSpace", "LightInfluence", "MaxDistance",
		"Size", "SizeOffset", "StudsOffset", "StudsOffsetWorldSpace",
	} },
	{ "GuiObject", {
		"Active", "AnchorPoint", "AutomaticSize", "BackgroundColor3", "BackgroundTransparency",
		"BorderColor3", "BorderMode", "BorderSizePixel:int", "ClipsDescendants", "Interactable",
		"LayoutOrder:int", "Position", "Rotation", "Selectable", "Size", "SizeConstraint", "Visible",
		"ZIndex:int",
	} },
	{ "TextLabel", TEXT_PROPS },
	{ "TextButton", TEXT_PROPS },
	{ "TextBox", TEXT_PROPS },
	{ "TextBox", {
		"PlaceholderText", "PlaceholderColor3", "ClearTextOnFocus", "MultiLine", "TextEditable", "ShowNativeInput",
	} },
	{ "GuiButton", { "AutoButtonColor", "Modal", "Selected", "Style" } },
	{ "ImageLabel", IMAGE_PROPS },
	{ "ImageButton", IMAGE_PROPS },
	{ "ImageButton", { "HoverImage:Content", "PressedImage:Content" } },
	{ "Frame", { "Style" } },
	{ "ScrollingFrame", {
		"AutomaticCanvasSize", "BottomImage:Content", "CanvasPosition", "CanvasSize", "ElasticBehavior",
		"HorizontalScrollBarInset", "MidImage:Content", "ScrollBarImageColor3", "ScrollBarImageTransparency",
		"ScrollBarThickness:int", "ScrollingDirection", "ScrollingEnabled", "TopImage:Content",
		"VerticalScrollBarInset", "VerticalScrollBarPosition",
	} },
	{ "ViewportFrame", {
		"Ambient", "LightColor", "LightDirection", "ImageColor3", "ImageTransparency", "CurrentCamera:Ref",
	} },
	{ "CanvasGroup", { "GroupColor3", "GroupTransparency" } },
	{ "VideoFrame", { "Video:Content", "Looped", "Volume" } },

	-- Componentes de UI
	{ "UICorner", { "CornerRadius" } },
	{ "UIStroke", { "ApplyStrokeMode", "Color", "Enabled", "LineJoinMode", "Thickness", "Transparency" } },
	{ "UIGradient", { "Color", "Enabled", "Offset", "Rotation", "Transparency" } },
	{ "UIPadding", { "PaddingBottom", "PaddingLeft", "PaddingRight", "PaddingTop" } },
	{ "UIGridStyleLayout", { "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder" } },
	{ "UIListLayout", { "Padding", "Wraps", "HorizontalFlex", "VerticalFlex", "ItemLineAlignment" } },
	{ "UIGridLayout", { "CellPadding", "CellSize", "FillDirectionMaxCells:int", "StartCorner" } },
	{ "UIPageLayout", {
		"Animated", "Circular", "EasingDirection", "EasingStyle", "GamepadInputEnabled", "Padding",
		"ScrollWheelInputEnabled", "TouchInputEnabled", "TweenTime",
	} },
	{ "UIAspectRatioConstraint", { "AspectRatio", "AspectType", "DominantAxis" } },
	{ "UISizeConstraint", { "MaxSize", "MinSize" } },
	{ "UITextSizeConstraint", { "MaxTextSize:int", "MinTextSize:int" } },
	{ "UIScale", { "Scale" } },
	{ "UIFlexItem", { "FlexMode", "GrowRatio", "ShrinkRatio", "ItemLineAlignment" } },
}

-- Classes que só existem em runtime / não podem ir para um arquivo
local SKIP_CLASSES = {
	Terrain = true,
	TouchTransmitter = true,
	Player = true,
	PlayerGui = true,
	PlayerScripts = true,
	Backpack = true,
}

local CORE_NAMES = {
	PlayerModule = true,
	ChatScript = true,
	BubbleChat = true,
	RbxCharacterSounds = true,
	PlayerScriptsLoader = true,
	Health = true,
	-- GUIs criadas pelo próprio Roblox
	TouchGui = true,
	Freecam = true,
	Chat = true,
	RbxCameraUI = true,
}

---------------------------------------------------------------------------
-- Leitura de propriedades
---------------------------------------------------------------------------
local function parseSpec(str)
	local hidden, name, typ, xml = str:match("^(!?)([%w_]+):?(%w*)=?([%w_]*)$")
	return {
		hidden = hidden == "!",
		name = name,
		type = typ ~= "" and typ or nil,
		xml = xml ~= "" and xml or name,
	}
end

for _, entry in ipairs(PROPS) do
	local parsed = {}
	for i, s in ipairs(entry[2]) do
		parsed[i] = parseSpec(s)
	end
	entry[2] = parsed
end

local specCache = {}
local function getSpecs(inst)
	local cls = inst.ClassName
	local cached = specCache[cls]
	if cached then
		return cached
	end
	local list, used = {}, { Name = true }
	for _, entry in ipairs(PROPS) do
		if inst:IsA(entry[1]) then
			for _, spec in ipairs(entry[2]) do
				if not used[spec.xml] then
					used[spec.xml] = true
					table.insert(list, spec)
				end
			end
		end
	end
	specCache[cls] = list
	return list
end

local function getProp(inst, name)
	return inst[name]
end

---------------------------------------------------------------------------
-- XML
---------------------------------------------------------------------------
local ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }

local function stripControl(s)
	return (s:gsub("%c", function(c)
		if c == "\t" or c == "\n" or c == "\r" then
			return c
		end
		return ""
	end))
end

local function esc(s)
	return (stripControl(tostring(s)):gsub("[&<>\"']", ESCAPES))
end

local function num(n, precise)
	if n ~= n then
		return "NAN"
	elseif n == math.huge then
		return "INF"
	elseif n == -math.huge then
		return "-INF"
	elseif n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	return string.format(precise and "%.17g" or "%.9g", n)
end

local function int(n)
	return string.format("%d", math.floor(n))
end

local function tag(t, name, inner)
	return "<" .. t .. ' name="' .. name .. '">' .. inner .. "</" .. t .. ">"
end

local function xyz(v)
	return "<X>" .. num(v.X) .. "</X><Y>" .. num(v.Y) .. "</Y><Z>" .. num(v.Z) .. "</Z>"
end

local function xy(v)
	return "<X>" .. num(v.X) .. "</X><Y>" .. num(v.Y) .. "</Y>"
end

local CF_KEYS = { "X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22" }
local function cframe(cf)
	local c = { cf:GetComponents() }
	local out = {}
	for i, k in ipairs(CF_KEYS) do
		out[i] = "<" .. k .. ">" .. num(c[i]) .. "</" .. k .. ">"
	end
	return table.concat(out)
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = bit32.extract(n, 18, 6) + 1
		local c2 = bit32.extract(n, 12, 6) + 1
		local c3 = bit32.extract(n, 6, 6) + 1
		local c4 = bit32.extract(n, 0, 6) + 1
		out[#out + 1] = B64:sub(c1, c1)
			.. B64:sub(c2, c2)
			.. (b and B64:sub(c3, c3) or "=")
			.. (c and B64:sub(c4, c4) or "=")
	end
	return table.concat(out)
end

local referents = {} -- Instance/nó virtual -> "RBXn"

local function serialize(spec, value)
	local t, xml, tv = spec.type, spec.xml, typeof(value)

	if tv == "Content" then -- novo tipo Content do Roblox
		value = value.Uri or ""
		tv = "string"
	end

	if t == "Ref" or tv == "Instance" then
		local ref = tv == "Instance" and referents[value] or "null"
		return tag("Ref", xml, ref)
	elseif t == "Content" then
		if tv ~= "string" then
			return nil
		end
		return tag("Content", xml, value == "" and "<null></null>" or ("<url>" .. esc(value) .. "</url>"))
	elseif t == "Color3uint8" and tv == "Color3" then
		local r = math.clamp(math.floor(value.R * 255 + 0.5), 0, 255)
		local g = math.clamp(math.floor(value.G * 255 + 0.5), 0, 255)
		local b = math.clamp(math.floor(value.B * 255 + 0.5), 0, 255)
		return tag("Color3uint8", xml, int(0xFF000000 + r * 65536 + g * 256 + b))
	elseif t == "OptionalCFrame" and tv == "CFrame" then
		return tag("OptionalCoordinateFrame", xml, "<CFrame>" .. cframe(value) .. "</CFrame>")
	elseif tv == "number" then
		if t == "int" or t == "int64" then
			return tag(t, xml, int(value))
		elseif t == "double" then
			return tag("double", xml, num(value, true))
		end
		return tag("float", xml, num(value))
	elseif tv == "string" then
		return tag("string", xml, esc(value))
	elseif tv == "boolean" then
		return tag("bool", xml, value and "true" or "false")
	elseif tv == "EnumItem" then
		return tag("token", xml, tostring(value.Value))
	elseif tv == "Vector3" then
		return tag("Vector3", xml, xyz(value))
	elseif tv == "Vector2" then
		return tag("Vector2", xml, xy(value))
	elseif tv == "CFrame" then
		return tag("CoordinateFrame", xml, cframe(value))
	elseif tv == "Color3" then
		return tag("Color3", xml, "<R>" .. num(value.R) .. "</R><G>" .. num(value.G) .. "</G><B>" .. num(value.B) .. "</B>")
	elseif tv == "BrickColor" then
		return tag("BrickColor", xml, tostring(value.Number))
	elseif tv == "UDim" then
		return tag("UDim", xml, "<S>" .. num(value.Scale) .. "</S><O>" .. int(value.Offset) .. "</O>")
	elseif tv == "UDim2" then
		return tag("UDim2", xml, "<XS>" .. num(value.X.Scale) .. "</XS><XO>" .. int(value.X.Offset)
			.. "</XO><YS>" .. num(value.Y.Scale) .. "</YS><YO>" .. int(value.Y.Offset) .. "</YO>")
	elseif tv == "NumberSequence" then
		local parts = {}
		for _, kp in ipairs(value.Keypoints) do
			parts[#parts + 1] = num(kp.Time) .. " " .. num(kp.Value) .. " " .. num(kp.Envelope) .. " "
		end
		return tag("NumberSequence", xml, table.concat(parts))
	elseif tv == "ColorSequence" then
		local parts = {}
		for _, kp in ipairs(value.Keypoints) do
			local c = kp.Value
			parts[#parts + 1] = num(kp.Time) .. " " .. num(c.R) .. " " .. num(c.G) .. " " .. num(c.B) .. " 0 "
		end
		return tag("ColorSequence", xml, table.concat(parts))
	elseif tv == "NumberRange" then
		return tag("NumberRange", xml, num(value.Min) .. " " .. num(value.Max) .. " ")
	elseif tv == "Rect" then
		return tag("Rect2D", xml, "<min>" .. xy(value.Min) .. "</min><max>" .. xy(value.Max) .. "</max>")
	elseif tv == "Font" then
		return tag("Font", xml, "<Family><url>" .. esc(value.Family) .. "</url></Family><Weight>"
			.. tostring(value.Weight.Value) .. "</Weight><Style>" .. value.Style.Name .. "</Style>")
	elseif tv == "PhysicalProperties" then
		return tag("PhysicalProperties", xml, "<CustomPhysics>true</CustomPhysics><Density>" .. num(value.Density)
			.. "</Density><Friction>" .. num(value.Friction) .. "</Friction><Elasticity>" .. num(value.Elasticity)
			.. "</Elasticity><FrictionWeight>" .. num(value.FrictionWeight) .. "</FrictionWeight><ElasticityWeight>"
			.. num(value.ElasticityWeight) .. "</ElasticityWeight>")
	elseif tv == "nil" and spec.name == "CustomPhysicalProperties" then
		return tag("PhysicalProperties", xml, "<CustomPhysics>false</CustomPhysics>")
	end
	return nil
end

-- Atributos no formato binário do Roblox (AttributesSerialize)
local function serializeAttributes(inst)
	local ok, attrs = pcall(inst.GetAttributes, inst)
	if not ok or next(attrs) == nil then
		return nil
	end
	local parts, count = {}, 0
	for key, v in pairs(attrs) do
		local tv, body = typeof(v), nil
		if tv == "string" then
			body = "\2" .. string.pack("<s4", v)
		elseif tv == "boolean" then
			body = "\3" .. (v and "\1" or "\0")
		elseif tv == "number" then
			body = "\6" .. string.pack("<d", v)
		elseif tv == "UDim" then
			body = "\9" .. string.pack("<fi4", v.Scale, v.Offset)
		elseif tv == "UDim2" then
			body = "\10" .. string.pack("<fi4fi4", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
		elseif tv == "BrickColor" then
			body = "\14" .. string.pack("<I4", v.Number)
		elseif tv == "Color3" then
			body = "\15" .. string.pack("<fff", v.R, v.G, v.B)
		elseif tv == "Vector2" then
			body = "\16" .. string.pack("<ff", v.X, v.Y)
		elseif tv == "Vector3" then
			body = "\17" .. string.pack("<fff", v.X, v.Y, v.Z)
		elseif tv == "NumberRange" then
			body = "\27" .. string.pack("<ff", v.Min, v.Max)
		end
		if body then
			count += 1
			parts[count] = string.pack("<s4", key) .. body
		end
	end
	if count == 0 then
		return nil
	end
	return tag("BinaryString", "AttributesSerialize", base64(string.pack("<I4", count) .. table.concat(parts)))
end

local function serializeTags(inst)
	local ok, tags = pcall(CollectionService.GetTags, CollectionService, inst)
	if not ok or #tags == 0 then
		return nil
	end
	return tag("BinaryString", "Tags", base64(table.concat(tags, "\0")))
end

---------------------------------------------------------------------------
-- Decompilação
---------------------------------------------------------------------------
local function decompileWithTimeout(scr)
	if not CONFIG.DecompileScripts or not decompile then
		return "-- decompile desativado / indisponível"
	end
	if getscriptbytecode then
		local ok, bc = pcall(getscriptbytecode, scr)
		if not ok or not bc or bc == "" then
			return "-- failed to get script bytecode"
		end
	end

	local result, done = nil, false
	task.spawn(function()
		local ok, src = pcall(decompile, scr)
		if ok and type(src) == "string" then
			result = src
		else
			result = "-- failed to decompile: " .. tostring(src)
		end
		done = true
	end)

	local start = os.clock()
	while not done do
		if os.clock() - start > CONFIG.DecompileTimeout then
			return "-- decompile timed out"
		end
		task.wait()
	end
	return result
end

---------------------------------------------------------------------------
-- Coleta da árvore
---------------------------------------------------------------------------
notify("Coletando instâncias...")

local savedSet = {}
local childrenOf = {}
local extras = {} -- pai -> instâncias extras para salvar dentro dele
local scripts = {}
local refCount = 0
local visited = 0

local function addExtra(parent, child)
	extras[parent] = extras[parent] or {}
	table.insert(extras[parent], child)
end

local function hasCoreAncestor(inst)
	local node = inst
	while node and node ~= game do
		if CORE_NAMES[node.Name] then
			return true
		end
		node = node.Parent
	end
	return false
end

local function shouldSkip(inst)
	if SKIP_CLASSES[inst.ClassName] then
		return true
	end
	if CONFIG.SkipCoreScripts and CORE_NAMES[inst.Name]
		and (inst:IsA("LuaSourceContainer") or inst:IsA("LayerCollector")) then
		return true
	end
	if CONFIG.RemovePlayerCharacters and inst:IsA("Model") and Players:GetPlayerFromCharacter(inst) then
		return true
	end
	return false
end

local function assignRef(node)
	refCount += 1
	referents[node] = "RBX" .. refCount
end

local function collect(inst)
	if savedSet[inst] then
		return false
	end
	local ok, skip = pcall(shouldSkip, inst)
	if not ok or skip then
		return false
	end
	savedSet[inst] = true
	assignRef(inst)
	if inst:IsA("LuaSourceContainer") then
		table.insert(scripts, inst)
	end

	local list = {}
	local okKids, kids = pcall(inst.GetChildren, inst)
	if okKids then
		for _, child in ipairs(kids) do
			if collect(child) then
				table.insert(list, child)
			end
		end
	end
	for _, child in ipairs(extras[inst] or {}) do
		if collect(child) then
			table.insert(list, child)
		end
	end
	childrenOf[inst] = list

	visited += 1
	if visited % CONFIG.YieldEvery == 0 then
		task.wait()
	end
	return true
end

local function childNames(parent)
	local names = {}
	for _, c in ipairs(parent:GetChildren()) do
		names[c.Name] = true
	end
	return names
end

-- Coisas do LocalPlayer que não existem na árvore "Starter*"
if LocalPlayer then
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if CONFIG.IncludePlayerGui and playerGui then
		local existing = childNames(StarterGui)
		for _, gui in ipairs(playerGui:GetChildren()) do
			if not existing[gui.Name] then
				addExtra(StarterGui, gui)
			end
		end
	end

	local playerScripts = LocalPlayer:FindFirstChildOfClass("PlayerScripts")
	local starterScripts = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
	if CONFIG.IncludePlayerScripts and playerScripts and starterScripts then
		local existing = childNames(starterScripts)
		for _, child in ipairs(playerScripts:GetChildren()) do
			if not existing[child.Name] then
				addExtra(starterScripts, child)
			end
		end
	end
end

local roots = {}
for _, serviceName in ipairs(CONFIG.Services) do
	local ok, service = pcall(game.GetService, game, serviceName)
	if ok and service and collect(service) then
		table.insert(roots, service)
	end
end

-- Scripts fora da árvore -> ReplicatedStorage._NilInstances
local nilFolder = { virtual = true, ClassName = "Folder", Name = "_NilInstances" }
local nilKids = {}

local function hasScripts(inst)
	return inst:IsA("LuaSourceContainer") or inst:FindFirstChildWhichIsA("LuaSourceContainer", true) ~= nil
end

if CONFIG.IncludeNilInstances and getnilinstances then
	local ok, list = pcall(getnilinstances)
	if ok then
		for _, inst in ipairs(list) do
			local okCheck, has = pcall(hasScripts, inst)
			if okCheck and has and not (CONFIG.SkipCoreScripts and hasCoreAncestor(inst)) and collect(inst) then
				table.insert(nilKids, inst)
			end
		end
	end
end

if CONFIG.IncludeLoadedModules and getloadedmodules then
	local coreContainers = {}
	for _, name in ipairs({ "CoreGui", "CorePackages" }) do
		local ok, service = pcall(game.GetService, game, name)
		if ok and service then
			table.insert(coreContainers, service)
		end
	end
	local ok, list = pcall(getloadedmodules)
	if ok then
		for _, mod in ipairs(list) do
			local isCoreModule = CONFIG.SkipCoreScripts and hasCoreAncestor(mod)
			for _, container in ipairs(coreContainers) do
				local okDesc, inside = pcall(mod.IsDescendantOf, mod, container)
				if okDesc and inside then
					isCoreModule = true
				end
			end
			if not savedSet[mod] and not isCoreModule and collect(mod) then
				table.insert(nilKids, mod)
			end
		end
	end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
if #nilKids > 0 and childrenOf[ReplicatedStorage] then
	assignRef(nilFolder)
	childrenOf[nilFolder] = nilKids
	table.insert(childrenOf[ReplicatedStorage], nilFolder)
end

notify(("%d instâncias, %d scripts. Decompilando..."):format(refCount, #scripts))

local sources = {}
local okCount, failCount = 0, 0
for i, scr in ipairs(scripts) do
	local src = decompileWithTimeout(scr)
	if src:find("^%-%- failed") or src:find("^%-%- decompile") then
		failCount += 1
	else
		okCount += 1
	end
	sources[scr] = src
	if i % 10 == 0 then
		print(("[PlaceSaver] scripts %d/%d"):format(i, #scripts))
		task.wait()
	end
end

---------------------------------------------------------------------------
-- Escrita do .rbxlx
---------------------------------------------------------------------------
notify("Montando o .rbxlx...")

local out, n = {}, 0
local function push(s)
	n += 1
	out[n] = s
end

local written = 0
local function writeItem(node)
	local isVirtual = type(node) == "table"
	push('<Item class="' .. node.ClassName .. '" referent="' .. referents[node] .. '"><Properties>')
	push(tag("string", "Name", esc(node.Name)))

	if not isVirtual then
		for _, spec in ipairs(getSpecs(node)) do
			local ok, value
			if spec.hidden then
				if gethiddenproperty then
					ok, value = pcall(gethiddenproperty, node, spec.name)
				end
			else
				ok, value = pcall(getProp, node, spec.name)
			end
			if ok then
				local okSer, s = pcall(serialize, spec, value)
				if okSer and s then
					push(s)
				end
			end
		end

		if node:IsA("LuaSourceContainer") then
			local src = stripControl(sources[node] or ""):gsub("]]>", "]]]]><![CDATA[>")
			push('<ProtectedString name="Source"><![CDATA[' .. src .. "]]></ProtectedString>")
		end

		local attrs = serializeAttributes(node)
		if attrs then
			push(attrs)
		end
		local tags = serializeTags(node)
		if tags then
			push(tags)
		end
	end

	push("</Properties>")
	for _, child in ipairs(childrenOf[node] or {}) do
		writeItem(child)
	end
	push("</Item>")

	written += 1
	if written % CONFIG.YieldEvery == 0 then
		task.wait()
	end
end

local startTime = os.clock()
push('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
	.. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
	.. 'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')
push("<External>null</External><External>nil</External>")
for _, root in ipairs(roots) do
	writeItem(root)
end
push("</roblox>")

local fileName = FILE_NAME .. ".rbxlx"
local okWrite, err = pcall(writefile, fileName, table.concat(out, "\n"))
if not okWrite then
	notify("Falha ao salvar: " .. tostring(err))
	return
end

notify(("Pronto! %s salvo (%d instâncias, %d scripts ok, %d falharam, %.1fs)"):format(
	fileName, written, okCount, failCount, os.clock() - startTime))
