local Players       = game:GetService("Players")
local workspace     = game:GetService("Workspace")
local VIM           = game:GetService("VirtualInputManager")
local UIS           = game:GetService("UserInputService")
local RunService    = game:GetService("RunService")
local Lighting      = game:GetService("Lighting")
local LocalPlayer   = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════════
--  LINORIA BOILERPLATE (LINK ESTÁVEL CORRIGIDO)
-- ══════════════════════════════════════════════════════════════════════════════
local repo = 'https://githubusercontent.com'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
	Title = 'Hamood vibecoding',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

local Tabs = {
	Ores = Window:AddTab('Ores'),
	Teleports = Window:AddTab('Teleports'),
	Misc = Window:AddTab('Misc'),
	Visuals = Window:AddTab('Visuals'),
	['UI Settings'] = Window:AddTab('UI Settings'),
}

Library:SetWatermark('Hamood vibecoding | Linoria')


-- ══════════════════════════════════════════════════════════════════════════════
--  CONNECTION REGISTRY / GLOBAL STATES
-- ══════════════════════════════════════════════════════════════════════════════
local connections = {}
local function track(conn) connections[#connections + 1] = conn end

local function disconnectAll()
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
end

local oreAdornments = {}
local oreESPEnabled = false
local showTracers = false
local nameESPEnabled = false
local maxEspDistance = 1000

local autoMineEnabled = false
local autoMineRange = 50
local autoMineDelay = 0.700

local OreESPGroup = Tabs.Ores:AddLeftGroupbox('ESP Settings')
local AutoMineGroup = Tabs.Ores:AddRightGroupbox('Auto Mine Settings')


-- ══════════════════════════════════════════════════════════════════════════════
--  ORE ESP & NAME ESP (OPTIMIZED FOR 240 FPS WITH NAMES)
-- ══════════════════════════════════════════════════════════════════════════════
local function addOreESP(part)
	if not part:IsA("BasePart") then return end
	if oreAdornments[part] then return end

	local color = part.Color
	local oreName = part.Parent:IsA("Model") and part.Parent.Name or part.Name

	-- Box Adornment
	local box = Instance.new("BoxHandleAdornment")
	box.Adornee             = part
	box.Size                = part.Size
	box.Color3              = color
	box.Transparency        = 0.5
	box.ZIndex              = 5
	box.AlwaysOnTop         = true
	box.Parent              = workspace.CurrentCamera
	box.Visible             = oreESPEnabled

	-- Tracer Line
	local tracer = Drawing.new("Line")
	tracer.Visible      = false
	tracer.Color        = color
	tracer.Thickness    = 1
	tracer.Transparency = 1

	-- Name ESP BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 30)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.ExtentsOffset = Vector3.new(0, 2, 0)
	billboard.Parent = workspace.CurrentCamera
	billboard.Visible = nameESPEnabled

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = oreName
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.TextSize = 14
	textLabel.Parent = billboard

	oreAdornments[part] = { box = box, tracer = tracer, billboard = billboard, inRange = true }
end

local function removeOreESP(part)
	local data = oreAdornments[part]
	if data then
		if data.box then data.box:Destroy() end
		if data.tracer then data.tracer:Remove() end
		if data.billboard then data.billboard:Destroy() end
		oreAdornments[part] = nil
	end
end

local function clearAllOreESP()
	for part in pairs(oreAdornments) do removeOreESP(part) end
end

OreESPGroup:AddToggle('OreESP', {
	Text = 'Show Ore ESP',
	Default = false,
	Tooltip = 'Highlights all ores in workspace',
	Callback = function(Value)
		oreESPEnabled = Value
		local placedOre = workspace:FindFirstChild("PlacedOre")
		if Value and not placedOre then return Library:Notify("PlacedOre folder not found.", 4) end
		
		for part, data in pairs(oreAdornments) do
			if data.box then data.box.Visible = Value end
		end
	end
})

OreESPGroup:AddToggle('OreNames', {
	Text = 'Show Ore Names',
	Default = false,
	Callback = function(Value)
		nameESPEnabled = Value
		for part, data in pairs(oreAdornments) do
			if data.billboard then data.billboard.Visible = Value end
		end
	end
})

OreESPGroup:AddToggle('OreTracers', {
	Text = 'Show Tracers',
	Default = false,
	Callback = function(Value) showTracers = Value end
})

OreESPGroup:AddSlider('MaxEspDistance', {
	Text = 'ESP Max Distance',
	Default = 1000,
	Min = 50,
	Max = 5000,
	Rounding = 0,
	Compact = false,
	Callback = function(Value) maxEspDistance = Value end
})


-- ══════════════════════════════════════════════════════════════════════════════
--  AUTO MINE LOGIC
-- ══════════════════════════════════════════════════════════════════════════════
AutoMineGroup:AddToggle('AutoMine', {
	Text = 'Enable Auto Mine',
	Default = false,
	Tooltip = 'Automatically breaks closest ore within 50 studs',
	Callback = function(Value) autoMineEnabled = Value end
})

AutoMineGroup:AddSlider('MineDelay', {
	Text = 'Mine Click Delay',
	Default = 0.700,
	Min = 0.700,
	Max = 10.0,
	Rounding = 3,
	Compact = false,
	Callback = function(Value) autoMineDelay = Value end
})

local function getClosestOre(hrp)
	local closestPart = nil
	local shortestDistance = autoMineRange
	
	for part, _ in pairs(oreAdornments) do
		if part and part.Parent then
			local distance = (hrp.Position - part.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				closestPart = part
			end
		end
	end
	return closestPart
end

task.spawn(function()
	while true do
		task.wait(autoMineDelay)
		
		if autoMineEnabled then
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			
			if hrp then
				local targetOre = getClosestOre(hrp)
				if targetOre then
					local currentTool = char:FindFirstChildOfClass("Tool")
					if currentTool then
						currentTool:Activate()
					else
						VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
						task.wait(0.05)
						VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
					end
				end
			end
		end
	end
end)


-- ══════════════════════════════════════════════════════════════════════════════
--  ABA MISC (MOVEMENT, UTILITIES & AUTO SELL)
-- ══════════════════════════════════════════════════════════════════════════════
local MiscMove = Tabs.Misc:AddLeftGroupbox('Movement')
local MiscUtils = Tabs.Misc:AddLeftGroupbox('Utilities')
local MiscSell = Tabs.Misc:AddRightGroupbox('Auto Sell')

local DEFAULT_SPEED = 16
local BOOST_SPEED   = 50
local walkBoostOn   = false
local infJumpOn     = false
local noclipOn      = false

local function applyWalkSpeed(speed)
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = speed end
end

track(LocalPlayer.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and walkBoostOn then hum.WalkSpeed = BOOST_SPEED end
end))

MiscMove:AddSlider('BoostSpeed', { Text = 'Boost WalkSpeed', Default = 50, Min = 16, Max = 250, Rounding = 0, Callback = function(v) BOOST_SPEED = v if walkBoostOn then applyWalkSpeed(BOOST_SPEED) end end })
MiscMove:AddToggle('WalkBoost', {
	Text = 'WalkSpeed Boost',
	Default = false,
	Callback = function(Value)
		walkBoostOn = Value
		applyWalkSpeed(Value and BOOST_SPEED or DEFAULT_SPEED)
	end
}):AddKeyPicker('WalkBoostKey', {
	Default = 'F1',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'WalkSpeed Boost'
})

MiscMove:AddToggle('InfJump', { Text = 'Infinite Jump', Default = false, Callback = function(v) infJumpOn = v end })
MiscMove:AddToggle('Noclip', { Text = 'Noclip', Default = false, Callback = function(v) noclipOn = v end })

track(UIS.JumpRequest:Connect(function()
	if infJumpOn then
		local char = LocalPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end
	end
end))

track(RunService.Stepped:Connect(function()
	if noclipOn then
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end
end))

MiscUtils:AddButton({
	Text = 'Refresh Cooldowns',
	Tooltip = 'Kills your character and teleports you back',
	Func = function()
		local char = LocalPlayer.Character
		if not char then return end
		local hrp, hum = char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local savedCFrame = hrp.CFrame
		local conn
		conn = LocalPlayer.CharacterAdded:Connect(function(newChar)
			conn:Disconnect()
			local newHRP = newChar:WaitForChild("HumanoidRootPart", 10)
			if newHRP then task.wait(0.2) newHRP.CFrame = savedCFrame end
		end)
		hum.Health = 0
	end
})


-- ══════════════════════════════════════════════════════════════════════════════
--  AUTO SELL LOGIC
-- ══════════════════════════════════════════════════════════════════════════════
local autoSellEnabled = false
local autoSellThread  = nil
local SELL_INTERVAL   = 60

local function getUnloader()
	local ok, result = pcall(function() return workspace.FactoryGridItemsClient.DSBuild3.DSBuild3.Unloader1 end)
	if ok and result then return result end
	
