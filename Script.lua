local Players       = game:GetService("Players")
local workspace     = game:GetService("Workspace")
local VIM           = game:GetService("VirtualInputManager")
local UIS           = game:GetService("UserInputService")
local RunService    = game:GetService("RunService")
local Lighting      = game:GetService("Lighting")
local LocalPlayer   = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════════
--  LINORIA BOILERPLATE (UPDATED URL)
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
--  ORE ESP (OPTIMIZED FOR 240 FPS WITH NAMES)
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
--  INITIALIZATION & CYCLE HANDLING
-- ══════════════════════════════════════════════════════════════════════════════
local function setupOreConnections(placedOre)
	for _, desc in placedOre:GetDescendants() do
		if desc:IsA("BasePart") then addOreESP(desc) end
	end

	track(placedOre.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then addOreESP(desc) end
	end))
	track(placedOre.DescendantRemoving:Connect(function(desc)
		removeOreESP(desc)
	end))
	
	local lastDistanceCheck = 0

	track(RunService.RenderStepped:Connect(function()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		
		local now = os.clock()
		local shouldUpdateDistance = false
		if now - lastDistanceCheck > 0.3 then
			shouldUpdateDistance = true
			lastDistanceCheck = now
		end
		
		for part, data in pairs(oreAdornments) do
			if part and part.Parent and hrp then
				if shouldUpdateDistance then
					local dist = (hrp.Position - part.Position).Magnitude
					data.inRange = dist <= maxEspDistance
					
					if data.box then data.box.Visible = oreESPEnabled and data.inRange end
					if data.billboard then data.billboard.Visible = nameESPEnabled and data.inRange end
				end
				
				if showTracers and data.inRange and oreESPEnabled then
					local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
					if onScreen then
						data.tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
						data.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
						data.tracer.Visible = true
					else
						data.tracer.Visible = false
					end
				else
					if data.tracer.Visible then data.tracer.Visible = false end
				end
			else
				if data.box then data.box.Visible = false end
				if data.billboard then data.billboard.Visible = false end
				if data.tracer.Visible then data.tracer.Visible = false end
			end
		end
	end))
end

local existingPlacedOre = workspace:FindFirstChild("PlacedOre")
if existingPlacedOre then
	setupOreConnections(existingPlacedOre)
else
	task.spawn(function()
		local placedOre = workspace:WaitForChild("PlacedOre", 60)
		if placedOre then setupOreConnections(placedOre) end
	end)
end
