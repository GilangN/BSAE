-- ==========================================
-- BREAK AND STEAL EGG - MASTER SKRIP (FULL + FEED FRIEND VARIANT)
-- ==========================================

if game.PlaceId ~= 114326934417838 then
	warn("Skrip ini hanya dapat dijalankan di map Break and Steal Egg!")
	return
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

pcall(function()
	if getgenv().ActiveBreakScriptCleanup then
		getgenv().ActiveBreakScriptCleanup()
	end
end)

local CONFIG_FILE = "BreakAndStealEgg_Config.json"

local settingsData = {
	Speed = 190,
	SpeedEnabled = false,
	AntiStuckEnabled = true,
	AntiRagdollEnabled = true,
	AuraEnabled = false,
	EspEnabled = false,
	MinEsp = 2e9,
	EspInputText = "2B",
	MinPickup = 0,
	AutoPickupNum = 0,
	AutoPickupSuf = "B",
	AutoBreakEnabled = false,
	AutoPickupEnabled = false,
	FeedFriendEnabled = false,
	AutoGemEnabled = false,
	AutoTpEnabled = false,
	SelectedBreakZoneName = "",
	NearestEggEnabled = false,
	RarityForcePickup = {},
	VariantCheckboxes = {Gold = false, Diamond = false, Lightning = false, Frozen = false, Angelic = false},
	VariantRarityCheckboxes = {}
}

local function loadSettings()
	if writefile and readfile and isfile and isfile(CONFIG_FILE) then
		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(CONFIG_FILE))
		end)
		if success and type(result) == "table" then
			for k, v in pairs(result) do
				settingsData[k] = v
			end
		end
	end
end

local function saveSettings()
	if writefile then
		pcall(function()
			local encoded = HttpService:JSONEncode(settingsData)
			writefile(CONFIG_FILE, encoded)
		end)
	end
end

loadSettings()

local autoBreakZoneEnabled = settingsData.AutoBreakEnabled or false
local autoPickupEnabled = settingsData.AutoPickupEnabled or false
local feedFriendEnabled = settingsData.FeedFriendEnabled or false
local autoGemEnabled = settingsData.AutoGemEnabled or false
local autoTpEnabled = settingsData.AutoTpEnabled or false
local antiStuckEnabled = settingsData.AntiStuckEnabled ~= false
local antiRagdollEnabled = settingsData.AntiRagdollEnabled ~= false
local auraEnabled = settingsData.AuraEnabled == true
local hasReceivedSpeedSignal = false
local espEnabled = settingsData.EspEnabled or false
local speedEnabled = settingsData.SpeedEnabled or false
local isTaskRunning = false
local isPickingUp = false
local isCollectingGem = false
local isProcessingPickup = false
local isProcessingFeedFriend = false
local isExecutingBaseSequenceActive = false

local autoBreakExecutionToken = 0
local autoPickupExecutionToken = 0
local feedFriendExecutionToken = 0
local autoGemExecutionToken = 0
local autoBreakTPToken = 0
local activeBreakThreadRunning = false
local isExecutingTPZone = false
local activeAutoPickupLoopRunning = false
local activeFeedFriendLoopRunning = false
local activeAutoGemLoopRunning = false
local lastGlobalTPTime = 0

local customSpeed = settingsData.Speed or 190
local minEspValue = settingsData.MinEsp or 2e9
local nearestEggEnabled = settingsData.NearestEggEnabled or false

local rarityList = {"Secret", "Celestial", "Inferno", "Void", "Omega", "Spectral", "Ethereal"}
local rarityForcePickup = settingsData.RarityForcePickup or {}
local variantCheckboxes = settingsData.VariantCheckboxes or {Gold = false, Diamond = false, Lightning = false, Frozen = false, Angelic = false}
local variantRarityCheckboxes = settingsData.VariantRarityCheckboxes or {}

local originalFogEnd = Lighting.FogEnd
local originalShadows = Lighting.GlobalShadows
local removedLightingEffects = {}
local auraConnection = nil
local antiRagdollConnection = nil

local function clearMapAuras(parent)
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Sparkles") or descendant:IsA("Highlight") or descendant:IsA("Beam") or descendant:IsA("Trail") then
			descendant:Destroy()
		end
	end
end

local function applyAuraRemoval(state)
	auraEnabled = state
	
	if state then
		removedLightingEffects = {}
		for _, v in ipairs(Lighting:GetChildren()) do
			if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then
				table.insert(removedLightingEffects, v)
				v.Parent = nil
			end
		end
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
		
		clearMapAuras(Workspace)
		pcall(function()
			clearMapAuras(ReplicatedStorage)
		end)

		if not auraConnection then
			auraConnection = Workspace.DescendantAdded:Connect(function(descendant)
				if auraEnabled then
					if descendant:IsA("ParticleEmitter") or descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Sparkles") or descendant:IsA("Highlight") or descendant:IsA("Beam") or descendant:IsA("Trail") then
						task.defer(function()
							if descendant and descendant.Parent then
								descendant:Destroy()
							end
						end)
					end
				end
			end)
		end
	else
		if auraConnection then
			auraConnection:Disconnect()
			auraConnection = nil
		end

		for _, v in ipairs(removedLightingEffects) do
			if v and v.Parent == nil then
				v.Parent = Lighting
			end
		end
		removedLightingEffects = {}
		Lighting.FogEnd = originalFogEnd
		Lighting.GlobalShadows = originalShadows
	end
end

local function parseValueToNumber(text)
	if not text then return 0 end
	local cleanStr = text:gsub("[%$,/s%s]", ""):upper()
	local numberPart = tonumber(cleanStr:match("[%d%.]+")) or 0
	local suffix = cleanStr:match("[KMBT]")
	if suffix == "K" then numberPart = numberPart * 1e3
	elseif suffix == "M" then numberPart = numberPart * 1e6
	elseif suffix == "B" then numberPart = numberPart * 1e9 
	elseif suffix == "T" then numberPart = numberPart * 1e12 end
	return numberPart
end

local minAutoPickupValue = settingsData.MinPickup
if not minAutoPickupValue or minAutoPickupValue == 0 then
	local num = settingsData.AutoPickupNum or 0
	local suf = (settingsData.AutoPickupSuf or "B"):upper()
	local mul = 1
	if suf == "K" then mul = 1e3 elseif suf == "M" then mul = 1e6 elseif suf == "B" then mul = 1e9 elseif suf == "T" then mul = 1e12 end
	minAutoPickupValue = num * mul
end

local activeConnections = {}
local activeCoroutines = {}
local activeTweenRunning = false
local activeTween = nil
local currentAnimTrack = nil
local toggleCooldown = false
local activeTargetEgg = nil

local statusIndicatorText = nil

local function updateStatusText(text, color)
	pcall(function()
		if statusIndicatorText then
			statusIndicatorText.Text = text
			if color then
				statusIndicatorText.TextColor3 = color
			end
		end
	end)
end

local function cancelActiveTween()
	activeTweenRunning = false
	activeTargetEgg = nil
	if currentAnimTrack and currentAnimTrack.IsPlaying then
		pcall(function() currentAnimTrack:Stop(0.05) end)
	end
	if activeTween then
		pcall(function() activeTween:Cancel() end)
		activeTween = nil
	end
end

local function interruptAndCancelAll()
	autoBreakExecutionToken = autoBreakExecutionToken + 1
	autoPickupExecutionToken = autoPickupExecutionToken + 1
	feedFriendExecutionToken = feedFriendExecutionToken + 1
	autoGemExecutionToken = autoGemExecutionToken + 1
	autoBreakTPToken = autoBreakTPToken + 1
	activeBreakThreadRunning = false
	activeAutoPickupLoopRunning = false
	activeFeedFriendLoopRunning = false
	activeAutoGemLoopRunning = false
	isExecutingTPZone = false
	cancelActiveTween()
	activeTargetEgg = nil
	isTaskRunning = false
	isPickingUp = false
	isCollectingGem = false
	isProcessingPickup = false
	isProcessingFeedFriend = false

	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoid then humanoid.PlatformStand = false end
			if rootPart then rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
		end
	end)
end

local function cleanupScript()
	isExecutingBaseSequenceActive = true
	interruptAndCancelAll()
	
	autoBreakZoneEnabled = false
	autoPickupEnabled = false
	feedFriendEnabled = false
	autoGemEnabled = false
	autoTpEnabled = false
	antiStuckEnabled = false
	antiRagdollEnabled = false
	espEnabled = false
	speedEnabled = false

	if auraConnection then
		auraConnection:Disconnect()
		auraConnection = nil
	end
	
	if antiRagdollConnection then
		antiRagdollConnection:Disconnect()
		antiRagdollConnection = nil
	end

	for _, co in ipairs(activeCoroutines) do
		if co and coroutine.status(co) == "suspended" then
			pcall(function() coroutine.close(co) end)
		end
	end
	table.clear(activeCoroutines)
	
	for _, conn in ipairs(activeConnections) do
		if conn and typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
	end
	table.clear(activeConnections)

	pcall(function()
		if CoreGui:FindFirstChild("BreakAndStealEggUI") then
			CoreGui.BreakAndStealEggUI:Destroy()
		end
	end)
end

getgenv().ActiveBreakScriptCleanup = cleanupScript

local function trackConnection(connection)
	if connection then table.insert(activeConnections, connection) end
	return connection
end

local function trackCoroutine(co)
	if co then table.insert(activeCoroutines, co) end
	return co
end

trackConnection(Players.LocalPlayer.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end))

local function getActivePromptAnchors()
	local anchors = {}
	pcall(function()
		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj.Name == "PromptAnchor" or obj.Name:match("^PromptAnchor") or obj.Name == "StealPrompt" then
				table.insert(anchors, obj)
			end
		end
	end)
	return anchors
end

local function getPromptForItem(item)
	if not item or not item.Parent then return nil end
	
	local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then return prompt end
	
	local mainPart = item:IsA("BasePart") and item or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)))
	if not mainPart then return nil end
	
	local bestPrompt = nil
	local shortestDist = 12 
	
	for _, anchor in ipairs(Workspace:GetChildren()) do
		if anchor.Name == "PromptAnchor" or anchor.Name:match("^PromptAnchor") or anchor.Name == "StealPrompt" then
			for _, desc in ipairs(anchor:GetDescendants()) do
				if desc:IsA("ProximityPrompt") then
					local promptPart = desc.Parent
					if promptPart and promptPart:IsA("BasePart") then
						local dist = (promptPart.Position - mainPart.Position).Magnitude
						if dist <= shortestDist then
							shortestDist = dist
							bestPrompt = desc
						end
					end
				end
			end
		end
	end
	
	return bestPrompt
end

local setupAutoPickupListenerFixed
local autoBreakZoneToggleButton
local autoPickupToggleButton
local feedToggleButton
local feedToggleStroke
local autoGemToggleButton
local antiRagdollToggleButton
local runAutoBreakLoop
local checkAndGrabAutoPickupRoutine
local runAutoPickupLoop
local runFeedFriendLoop
local runAutoGemLoop
local executeAutoPickupTPZone
local executeFeedFriendTPZone
local executeAutoBreakTPZone
local evaluateAndProcessItem
local executeBaseSequence
local speedToggleButton
local espToggleButton
local autoTpButton
local autoTpStroke
local auraToggleButton
local auraToggleStroke

local function setupAntiRagdoll()
	pcall(function()
		local ragdollModule = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("RagdollPhysics")
		if ragdollModule then
			local RagdollPhysics = require(ragdollModule)
			RagdollPhysics.SetCharacterVelocity = function(char, linear, angular)
				if char == LocalPlayer then return end
				return pcall(RagdollPhysics.SetCharacterVelocity, char, linear, angular)
			end
			RagdollPhysics.StartAntiTunnelGuard = function(char, ...)
				if char == LocalPlayer then return function() end end
			end
		end

		local catchFlingRemote = ReplicatedStorage:FindFirstChild("CatchFlingRemote")
		if catchFlingRemote and catchFlingRemote:IsA("RemoteEvent") then
			for _, connection in ipairs(getconnections(catchFlingRemote.OnClientEvent)) do
				connection:Disable()
			end
			catchFlingRemote.OnClientEvent:Connect(function(action, ...)
				if not antiRagdollEnabled then return end
				if action == "fling" then return end
			end)
		end
	end)

	if antiRagdollConnection then
		antiRagdollConnection:Disconnect()
		antiRagdollConnection = nil
	end

	antiRagdollConnection = RunService.Heartbeat:Connect(function()
		if not antiRagdollEnabled then return end
		local char = LocalPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
				hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
				
				local currentState = hum:GetState()
				if currentState == Enum.HumanoidStateType.Physics 
					or currentState == Enum.HumanoidStateType.Ragdoll 
					or hum.PlatformStand 
					or hum.Sit then
					
					hum.PlatformStand = false
					hum.Sit = false
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
					task.defer(function()
						hum:ChangeState(Enum.HumanoidStateType.Running)
					end)
				end
			end
			for _, obj in ipairs(char:GetDescendants()) do
				if obj:IsA("BallSocketConstraint") or obj:IsA("HingeConstraint") then
					obj:Destroy()
				end
			end
		end
	end)
	trackConnection(antiRagdollConnection)
end

local function applyPatches()
	pcall(function() 
		LocalPlayer:SetAttribute("FastSwingOwned", true) 
		LocalPlayer:SetAttribute("DoubleSwingOwned", true)
	end)
	local function removePromptDuration(prompt)
		if prompt:IsA("ProximityPrompt") then prompt.HoldDuration = 0 end
	end
	local function setupPromptAnchorListener(anchor)
		pcall(function()
			for _, desc in ipairs(anchor:GetDescendants()) do
				if desc:IsA("ProximityPrompt") then
					removePromptDuration(desc)
					if setupAutoPickupListenerFixed then setupAutoPickupListenerFixed(desc) end
				end
			end
			trackConnection(anchor.DescendantAdded:Connect(function(desc)
				if desc:IsA("ProximityPrompt") then
					removePromptDuration(desc)
					if setupAutoPickupListenerFixed then setupAutoPickupListenerFixed(desc) end
				end
			end))
		end)
	end
	for _, anchor in ipairs(getActivePromptAnchors()) do setupPromptAnchorListener(anchor) end
	trackConnection(Workspace.ChildAdded:Connect(function(child)
		if child.Name == "PromptAnchor" or child.Name:match("^PromptAnchor") or child.Name == "StealPrompt" then
			setupPromptAnchorListener(child)
		end
	end))
end

local function detectCurrentZoneIndex()
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return "1" end
	local rootPos = character.HumanoidRootPart.Position

	local buildFolder = Workspace:FindFirstChild("Build")
	if not buildFolder then return "1" end
	
	local zoneHitboxes = buildFolder:FindFirstChild("ZoneHitboxes")
	if zoneHitboxes then
		local hitboxes = zoneHitboxes:GetChildren()
		table.sort(hitboxes, function(a, b) 
			local numA = tonumber(a.Name) or 0
			local numB = tonumber(b.Name) or 0
			return numA < numB 
		end)
		
		for _, hitbox in ipairs(hitboxes) do
			if hitbox:IsA("BasePart") then
				local cf, size = hitbox.CFrame, hitbox.Size
				local localPos = cf:PointToObjectSpace(rootPos)
				
				if math.abs(localPos.X) <= (size.X / 2) and
				   math.abs(localPos.Y) <= (size.Y / 2) + 20 and
				   math.abs(localPos.Z) <= (size.Z / 2) then
					return hitbox.Name
				end
			end
		end
	end
	return "SaveZone"
end

local function getHitboxCFrame(hitboxObj)
	if not hitboxObj then return nil end
	local cf = nil
	if hitboxObj:IsA("BasePart") then cf = hitboxObj.CFrame
	elseif hitboxObj:IsA("Model") then
		local success, pivot = pcall(function() return hitboxObj:GetPivot() end)
		if success and pivot then cf = pivot
		elseif hitboxObj.PrimaryPart then cf = hitboxObj.PrimaryPart.CFrame end
	end
	
	if cf then
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local targetPos = cf.Position
			local flatPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
			return CFrame.new(flatPos, flatPos + cf.LookVector)
		end
	end
	return cf
end

local function findMyBase()
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, base in ipairs(plotsFolder:GetChildren()) do
		if base:GetAttribute("OwnerUserId") == LocalPlayer.UserId then return base end
	end
	return nil
end

local function findMySpawnPoint()
	local myBase = findMyBase()
	if not myBase then return nil end
	
	local function searchSpawn(folder)
		for _, obj in ipairs(folder:GetChildren()) do
			if obj.Name:lower():match("spawn") or obj.Name:lower():match("spawnpoint") then
				return obj
			elseif #obj:GetChildren() > 0 then
				local res = searchSpawn(obj)
				if res then return res end
			end
		end
		return nil
	end
	return searchSpawn(myBase)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BreakAndStealEggUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local floatButton = Instance.new("ImageButton")
floatButton.Name = "FloatButton"
floatButton.Size = UDim2.new(0, 42, 0, 42)
floatButton.AnchorPoint = Vector2.new(0.5, 0)
floatButton.Position = UDim2.new(0.5, -90, 0, -28)
floatButton.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
floatButton.BackgroundTransparency = 0.3
floatButton.BorderSizePixel = 0
floatButton.Image = "rbxassetid://6031094678"
floatButton.ImageColor3 = Color3.fromRGB(160, 170, 190)
floatButton.Active = true
floatButton.Draggable = true
floatButton.Parent = screenGui

local floatCorner = Instance.new("UICorner", floatButton)
floatCorner.CornerRadius = UDim.new(1, 0)
local floatStroke = Instance.new("UIStroke", floatButton)
floatStroke.Color = Color3.fromRGB(160, 170, 190)
floatStroke.Thickness = 1.8
floatStroke.Transparency = 0.25

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 375, 0, 375)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
mainFrame.BackgroundTransparency = 0.25
mainFrame.BorderSizePixel = 0
mainFrame.Visible = true
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 14)
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = Color3.fromRGB(160, 170, 190)
mainStroke.Thickness = 1.2
mainStroke.Transparency = 0.5

local mainGradient = Instance.new("UIGradient", mainFrame)
mainGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(60, 65, 75)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(35, 38, 45)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(20, 22, 26))
})
mainGradient.Rotation = 75

local headerBackground = Instance.new("Frame", mainFrame)
headerBackground.Size = UDim2.new(1, 0, 0, 28)
headerBackground.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
headerBackground.BackgroundTransparency = 0.35
headerBackground.BorderSizePixel = 0
local headerCorner = Instance.new("UICorner", headerBackground)
headerCorner.CornerRadius = UDim.new(0, 14)

local headerCover = Instance.new("Frame", headerBackground)
headerCover.Size = UDim2.new(1, 0, 0, 6)
headerCover.Position = UDim2.new(0, 0, 1, -6)
headerCover.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
headerCover.BackgroundTransparency = 0.35
headerCover.BorderSizePixel = 0

local titleLabel = Instance.new("TextLabel", headerBackground)
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "BREAK & STEAL EGG"
titleLabel.TextColor3 = Color3.fromRGB(210, 220, 235)
titleLabel.TextSize = 11
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = Instance.new("TextButton", headerBackground)
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 20, 0, 20)
closeButton.Position = UDim2.new(1, -24, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 75)
closeButton.BackgroundTransparency = 0.25
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 11
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 5)

closeButton.MouseButton1Click:Connect(function()
	cleanupScript()
end)

local hideButton = Instance.new("TextButton", headerBackground)
hideButton.Name = "HideButton"
hideButton.Size = UDim2.new(0, 20, 0, 20)
hideButton.Position = UDim2.new(1, -48, 0, 4)
hideButton.BackgroundColor3 = Color3.fromRGB(60, 68, 82)
hideButton.BackgroundTransparency = 0.25
hideButton.BorderSizePixel = 0
hideButton.Font = Enum.Font.GothamBold
hideButton.Text = "_"
hideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
hideButton.TextSize = 11
Instance.new("UICorner", hideButton).CornerRadius = UDim.new(0, 5)

hideButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

floatButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
end)

local selectedZoneHitboxObj = nil
local selectedBreakZoneFolder = nil
local detectionRange = 50
local rememberedObjectText = nil

local zoneNamesList = {
	"Forest", "Desert", "Snowy", "Candy", "Swamp", 
	"Ocean", "Volcano", "Blossom", "Galaxy", "PlanetX", "Haunted Graveyard", "Fairy Castle", "Fantasy Expansion"
}

local leftScrollingFrame = Instance.new("ScrollingFrame", mainFrame)
leftScrollingFrame.Name = "LeftScrollingFrame"
leftScrollingFrame.Size = UDim2.new(0, 192, 1, -34)
leftScrollingFrame.Position = UDim2.new(0, 6, 0, 32)
leftScrollingFrame.BackgroundTransparency = 1
leftScrollingFrame.BorderSizePixel = 0
leftScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
leftScrollingFrame.ScrollBarThickness = 2

local leftListLayout = Instance.new("UIListLayout", leftScrollingFrame)
leftListLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftListLayout.Padding = UDim.new(0, 5)

local tpRowFrame = Instance.new("Frame", leftScrollingFrame)
tpRowFrame.Name = "TpRowFrame"
tpRowFrame.Size = UDim2.new(1, 0, 0, 28)
tpRowFrame.BackgroundTransparency = 1
tpRowFrame.LayoutOrder = 1

local tpButton = Instance.new("TextButton", tpRowFrame)
tpButton.Name = "TPButton"
tpButton.Size = UDim2.new(0, 90, 0, 28)
tpButton.Position = UDim2.new(0, 0, 0, 0)
tpButton.BackgroundColor3 = Color3.fromRGB(50, 65, 90)
tpButton.BackgroundTransparency = 0.3
tpButton.BorderSizePixel = 0
tpButton.Font = Enum.Font.GothamBold
tpButton.Text = "TP"
tpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpButton.TextSize = 12
Instance.new("UICorner", tpButton).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", tpButton).Color = Color3.fromRGB(120, 140, 170)

autoTpButton = Instance.new("TextButton", tpRowFrame)
autoTpButton.Name = "AutoTPButton"
autoTpButton.Size = UDim2.new(0, 94, 0, 28)
autoTpButton.Position = UDim2.new(0, 94, 0, 0)
autoTpButton.BackgroundColor3 = autoTpEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
autoTpButton.BackgroundTransparency = 0.4
autoTpButton.BorderSizePixel = 0
autoTpButton.Font = Enum.Font.GothamBold
autoTpButton.Text = autoTpEnabled and "Auto: ON" or "Auto"
autoTpButton.TextColor3 = autoTpEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
autoTpButton.TextSize = 11
Instance.new("UICorner", autoTpButton).CornerRadius = UDim.new(0, 6)
autoTpStroke = Instance.new("UIStroke", autoTpButton)
autoTpStroke.Color = autoTpEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

local utilityRowFrame = Instance.new("Frame", leftScrollingFrame)
utilityRowFrame.Name = "UtilityRowFrame"
utilityRowFrame.Size = UDim2.new(1, 0, 0, 28)
utilityRowFrame.BackgroundTransparency = 1
utilityRowFrame.LayoutOrder = 2

local antiStuckToggleButton = Instance.new("TextButton", utilityRowFrame)
antiStuckToggleButton.Name = "AntiStuckToggleButton"
antiStuckToggleButton.Size = UDim2.new(0, 90, 0, 28)
antiStuckToggleButton.Position = UDim2.new(0, 0, 0, 0)
antiStuckToggleButton.BackgroundColor3 = antiStuckEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
antiStuckToggleButton.BackgroundTransparency = 0.4
antiStuckToggleButton.BorderSizePixel = 0
antiStuckToggleButton.Font = Enum.Font.GothamBold
antiStuckToggleButton.Text = antiStuckEnabled and "Anti T: ON" or "Anti T: OFF"
antiStuckToggleButton.TextColor3 = antiStuckEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
antiStuckToggleButton.TextSize = 10
Instance.new("UICorner", antiStuckToggleButton).CornerRadius = UDim.new(0, 6)
local antiStuckToggleStroke = Instance.new("UIStroke", antiStuckToggleButton)
antiStuckToggleStroke.Color = antiStuckEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

auraToggleButton = Instance.new("TextButton", utilityRowFrame)
auraToggleButton.Name = "AuraToggleButton"
auraToggleButton.Size = UDim2.new(0, 94, 0, 28)
auraToggleButton.Position = UDim2.new(0, 94, 0, 0)
auraToggleButton.BackgroundColor3 = auraEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
auraToggleButton.BackgroundTransparency = 0.4
auraToggleButton.BorderSizePixel = 0
auraToggleButton.Font = Enum.Font.GothamBold
auraToggleButton.Text = auraEnabled and "Aura: ON" or "Aura: OFF"
auraToggleButton.TextColor3 = auraEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
auraToggleButton.TextSize = 10
Instance.new("UICorner", auraToggleButton).CornerRadius = UDim.new(0, 6)
auraToggleStroke = Instance.new("UIStroke", auraToggleButton)
auraToggleStroke.Color = auraEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

auraToggleButton.MouseButton1Click:Connect(function()
	auraEnabled = not auraEnabled
	settingsData.AuraEnabled = auraEnabled
	saveSettings()
	
	applyAuraRemoval(auraEnabled)
	
	if auraEnabled then
		auraToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		auraToggleButton.Text = "Aura: ON"
		auraToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		auraToggleStroke.Color = Color3.fromRGB(80, 190, 120)
	else
		auraToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		auraToggleButton.Text = "Aura: OFF"
		auraToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		auraToggleStroke.Color = Color3.fromRGB(80, 90, 110)
	end
end)

applyAuraRemoval(auraEnabled)

local zoneRowFrame = Instance.new("Frame", leftScrollingFrame)
zoneRowFrame.Name = "ZoneRowFrame"
zoneRowFrame.Size = UDim2.new(1, 0, 0, 28)
zoneRowFrame.BackgroundTransparency = 1
zoneRowFrame.LayoutOrder = 3

local dropdownMainButton = Instance.new("TextButton", zoneRowFrame)
dropdownMainButton.Name = "DropdownMainButton"
dropdownMainButton.Size = UDim2.new(0, 158, 0, 28)
dropdownMainButton.Position = UDim2.new(0, 0, 0, 0)
dropdownMainButton.BackgroundColor3 = Color3.fromRGB(40, 45, 56)
dropdownMainButton.BackgroundTransparency = 0.35
dropdownMainButton.BorderSizePixel = 0
dropdownMainButton.Font = Enum.Font.GothamBold
dropdownMainButton.Text = "Zone ▾"
dropdownMainButton.TextColor3 = Color3.fromRGB(210, 220, 235)
dropdownMainButton.TextSize = 11
Instance.new("UICorner", dropdownMainButton).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", dropdownMainButton).Color = Color3.fromRGB(75, 85, 105)

local tpZoneButton = Instance.new("TextButton", zoneRowFrame)
tpZoneButton.Name = "TPZoneButton"
tpZoneButton.Size = UDim2.new(0, 26, 0, 28)
tpZoneButton.Position = UDim2.new(0, 162, 0, 0)
tpZoneButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
tpZoneButton.BackgroundTransparency = 0.25
tpZoneButton.BorderSizePixel = 0
tpZoneButton.Font = Enum.Font.GothamBold
tpZoneButton.Text = "TP"
tpZoneButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpZoneButton.TextSize = 11
Instance.new("UICorner", tpZoneButton).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", tpZoneButton).Color = Color3.fromRGB(80, 190, 120)

local dropdownListFrame = Instance.new("ScrollingFrame", leftScrollingFrame)
dropdownListFrame.Name = "DropdownListFrame"
dropdownListFrame.Size = UDim2.new(1, -6, 0, 100)
dropdownListFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
dropdownListFrame.BackgroundTransparency = 0.15
dropdownListFrame.BorderSizePixel = 0
dropdownListFrame.Visible = false
dropdownListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
dropdownListFrame.ScrollBarThickness = 3
dropdownListFrame.ZIndex = 25
dropdownListFrame.LayoutOrder = 4
Instance.new("UICorner", dropdownListFrame).CornerRadius = UDim.new(0, 6)
local dropListLayout = Instance.new("UIListLayout", dropdownListFrame)
dropListLayout.SortOrder = Enum.SortOrder.LayoutOrder
dropListLayout.Padding = UDim.new(0, 2)

local speedRowFrame = Instance.new("Frame", leftScrollingFrame)
speedRowFrame.Name = "SpeedRowFrame"
speedRowFrame.Size = UDim2.new(1, 0, 0, 28)
speedRowFrame.BackgroundTransparency = 1
speedRowFrame.LayoutOrder = 5

local speedBox = Instance.new("TextBox", speedRowFrame)
speedBox.Name = "SpeedBox"
speedBox.Size = UDim2.new(0, 104, 0, 28)
speedBox.Position = UDim2.new(0, 0, 0, 0)
speedBox.BackgroundColor3 = Color3.fromRGB(40, 45, 56)
speedBox.BackgroundTransparency = 0.35
speedBox.BorderSizePixel = 0
speedBox.Font = Enum.Font.GothamBold
speedBox.Text = tostring(customSpeed)
speedBox.PlaceholderText = "Speed..."
speedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
speedBox.TextSize = 12
speedBox.ClearTextOnFocus = false
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", speedBox).Color = Color3.fromRGB(75, 85, 105)

speedToggleButton = Instance.new("TextButton", speedRowFrame)
speedToggleButton.Name = "SpeedToggleButton"
speedToggleButton.Size = UDim2.new(0, 80, 0, 28)
speedToggleButton.Position = UDim2.new(0, 108, 0, 0)
speedToggleButton.BackgroundColor3 = speedEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
speedToggleButton.BackgroundTransparency = 0.4
speedToggleButton.BorderSizePixel = 0
speedToggleButton.Font = Enum.Font.GothamBold
speedToggleButton.Text = speedEnabled and "Spd: ON" or "Spd: OFF"
speedToggleButton.TextColor3 = speedEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
speedToggleButton.TextSize = 10
Instance.new("UICorner", speedToggleButton).CornerRadius = UDim.new(0, 6)
local speedToggleStroke = Instance.new("UIStroke", speedToggleButton)
speedToggleStroke.Color = speedEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

speedBox.FocusLost:Connect(function()
	local val = tonumber(speedBox.Text)
	if val then 
		customSpeed = val 
		settingsData.Speed = val
		saveSettings()
	else 
		speedBox.Text = tostring(customSpeed) 
	end
end)

speedToggleButton.MouseButton1Click:Connect(function()
	speedEnabled = not speedEnabled
	settingsData.SpeedEnabled = speedEnabled
	saveSettings()
	
	if speedEnabled then
		speedToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		speedToggleButton.Text = "Spd: ON"
		speedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		speedToggleStroke.Color = Color3.fromRGB(80, 190, 120)
	else
		speedToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		speedToggleButton.Text = "Spd: OFF"
		speedToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		speedToggleStroke.Color = Color3.fromRGB(80, 90, 110)
	end
end)

local espRowFrame = Instance.new("Frame", leftScrollingFrame)
espRowFrame.Name = "EspRowFrame"
espRowFrame.Size = UDim2.new(1, 0, 0, 28)
espRowFrame.BackgroundTransparency = 1
espRowFrame.LayoutOrder = 6

local espBox = Instance.new("TextBox", espRowFrame)
espBox.Name = "EspBox"
espBox.Size = UDim2.new(0, 104, 0, 28)
espBox.Position = UDim2.new(0, 0, 0, 0)
espBox.BackgroundColor3 = Color3.fromRGB(40, 45, 56)
espBox.BackgroundTransparency = 0.35
espBox.BorderSizePixel = 0
espBox.Font = Enum.Font.GothamBold
espBox.Text = settingsData.EspInputText or "2B"
espBox.PlaceholderText = "Min Cash/s..."
espBox.TextColor3 = Color3.fromRGB(255, 255, 255)
espBox.TextSize = 12
espBox.ClearTextOnFocus = false
Instance.new("UICorner", espBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", espBox).Color = Color3.fromRGB(75, 85, 105)

espToggleButton = Instance.new("TextButton", espRowFrame)
espToggleButton.Name = "EspToggleButton"
espToggleButton.Size = UDim2.new(0, 80, 0, 28)
espToggleButton.Position = UDim2.new(0, 108, 0, 0)
espToggleButton.BackgroundColor3 = espEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
espToggleButton.BackgroundTransparency = 0.4
espToggleButton.BorderSizePixel = 0
espToggleButton.Font = Enum.Font.GothamBold
espToggleButton.Text = espEnabled and "ESP: ON" or "ESP: OFF"
espToggleButton.TextColor3 = espEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
espToggleButton.TextSize = 10
Instance.new("UICorner", espToggleButton).CornerRadius = UDim.new(0, 6)
local espToggleStroke = Instance.new("UIStroke", espToggleButton)
espToggleStroke.Color = espEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

espBox.FocusLost:Connect(function()
	local textVal = espBox.Text
	minEspValue = parseValueToNumber(textVal)
	if minEspValue == 0 then 
		espBox.Text = "2B" 
		minEspValue = 2e9 
		textVal = "2B"
	end
	settingsData.MinEsp = minEspValue
	settingsData.EspInputText = textVal
	saveSettings()
end)

espToggleButton.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	settingsData.EspEnabled = espEnabled
	saveSettings()
	
	if espEnabled then
		espToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		espToggleButton.Text = "ESP: ON"
		espToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		espToggleStroke.Color = Color3.fromRGB(80, 190, 120)
	else
		espToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		espToggleButton.Text = "ESP: OFF"
		espToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		espToggleStroke.Color = Color3.fromRGB(80, 90, 110)
	end
end)

local breakZoneHeaderLabel = Instance.new("TextLabel", leftScrollingFrame)
breakZoneHeaderLabel.Name = "BreakZoneHeaderLabel"
breakZoneHeaderLabel.Size = UDim2.new(1, 0, 0, 16)
breakZoneHeaderLabel.BackgroundTransparency = 1
breakZoneHeaderLabel.Font = Enum.Font.GothamBold
breakZoneHeaderLabel.Text = "AUTO BREAK EGG"
breakZoneHeaderLabel.TextColor3 = Color3.fromRGB(180, 200, 225)
breakZoneHeaderLabel.TextSize = 11
breakZoneHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
breakZoneHeaderLabel.LayoutOrder = 7

local breakRowFrame = Instance.new("Frame", leftScrollingFrame)
breakRowFrame.Name = "BreakRowFrame"
breakRowFrame.Size = UDim2.new(1, 0, 0, 28)
breakRowFrame.BackgroundTransparency = 1
breakRowFrame.LayoutOrder = 8

local breakDropdownButton = Instance.new("TextButton", breakRowFrame)
breakDropdownButton.Name = "BreakDropdownButton"
breakDropdownButton.Size = UDim2.new(0, 94, 0, 28)
breakDropdownButton.Position = UDim2.new(0, 0, 0, 0)
breakDropdownButton.BackgroundColor3 = Color3.fromRGB(40, 45, 56)
breakDropdownButton.BackgroundTransparency = 0.35
breakDropdownButton.BorderSizePixel = 0
breakDropdownButton.Font = Enum.Font.GothamBold
breakDropdownButton.Text = "Zone ▾"
breakDropdownButton.TextColor3 = Color3.fromRGB(210, 220, 235)
breakDropdownButton.TextSize = 10
Instance.new("UICorner", breakDropdownButton).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", breakDropdownButton).Color = Color3.fromRGB(75, 85, 105)

local nearestEggToggleButton = Instance.new("TextButton", breakRowFrame)
nearestEggToggleButton.Name = "NearestEggToggleButton"
nearestEggToggleButton.Size = UDim2.new(0, 58, 0, 28)
nearestEggToggleButton.Position = UDim2.new(0, 98, 0, 0)
nearestEggToggleButton.BackgroundColor3 = nearestEggEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
nearestEggToggleButton.BackgroundTransparency = 0.4
nearestEggToggleButton.BorderSizePixel = 0
nearestEggToggleButton.Font = Enum.Font.GothamBold
nearestEggToggleButton.Text = nearestEggEnabled and "Mod: Near" or "Mod: Rand"
nearestEggToggleButton.TextColor3 = nearestEggEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
nearestEggToggleButton.TextSize = 9
Instance.new("UICorner", nearestEggToggleButton).CornerRadius = UDim.new(0, 6)
local nearestEggToggleStroke = Instance.new("UIStroke", nearestEggToggleButton)
nearestEggToggleStroke.Color = nearestEggEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

autoBreakZoneToggleButton = Instance.new("TextButton", breakRowFrame)
autoBreakZoneToggleButton.Name = "AutoBreakZoneToggleButton"
autoBreakZoneToggleButton.Size = UDim2.new(0, 28, 0, 28)
autoBreakZoneToggleButton.Position = UDim2.new(0, 160, 0, 0)
autoBreakZoneToggleButton.BackgroundColor3 = autoBreakZoneEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
autoBreakZoneToggleButton.BackgroundTransparency = 0.4
autoBreakZoneToggleButton.BorderSizePixel = 0
autoBreakZoneToggleButton.Font = Enum.Font.GothamBold
autoBreakZoneToggleButton.Text = autoBreakZoneEnabled and "ON" or "OFF"
autoBreakZoneToggleButton.TextColor3 = autoBreakZoneEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
autoBreakZoneToggleButton.TextSize = 9
Instance.new("UICorner", autoBreakZoneToggleButton).CornerRadius = UDim.new(0, 6)
local autoBreakZoneToggleStroke = Instance.new("UIStroke", autoBreakZoneToggleButton)
autoBreakZoneToggleStroke.Color = autoBreakZoneEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

nearestEggToggleButton.MouseButton1Click:Connect(function()
	nearestEggEnabled = not nearestEggEnabled
	settingsData.NearestEggEnabled = nearestEggEnabled
	saveSettings()

	if nearestEggEnabled then
		nearestEggToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		nearestEggToggleButton.Text = "Mod: Near"
		nearestEggToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		nearestEggToggleStroke.Color = Color3.fromRGB(80, 190, 120)
	else
		nearestEggToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		nearestEggToggleButton.Text = "Mod: Rand"
		nearestEggToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		nearestEggToggleStroke.Color = Color3.fromRGB(80, 90, 110)
	end
end)

local farmListFrame = Instance.new("ScrollingFrame", leftScrollingFrame)
farmListFrame.Name = "FarmListFrame"
farmListFrame.Size = UDim2.new(1, -6, 0, 90)
farmListFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
farmListFrame.BackgroundTransparency = 0.15
farmListFrame.BorderSizePixel = 0
farmListFrame.Visible = false
farmListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
farmListFrame.ScrollBarThickness = 3
farmListFrame.ZIndex = 25
farmListFrame.LayoutOrder = 9
Instance.new("UICorner", farmListFrame).CornerRadius = UDim.new(0, 6)
local farmListLayout = Instance.new("UIListLayout", farmListFrame)
farmListLayout.SortOrder = Enum.SortOrder.LayoutOrder
farmListLayout.Padding = UDim.new(0, 2)

-- ================= FEED FRIEND UI ROW (DI ATAS AUTO PICKUP) =================
local feedHeaderLabel = Instance.new("TextLabel", leftScrollingFrame)
feedHeaderLabel.Name = "FeedHeaderLabel"
feedHeaderLabel.Size = UDim2.new(1, 0, 0, 16)
feedHeaderLabel.BackgroundTransparency = 1
feedHeaderLabel.Font = Enum.Font.GothamBold
feedHeaderLabel.Text = "FEED FRIEND (ZONE 1)"
feedHeaderLabel.TextColor3 = Color3.fromRGB(255, 140, 210)
feedHeaderLabel.TextSize = 11
feedHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
feedHeaderLabel.LayoutOrder = 9.5

local feedRowFrame = Instance.new("Frame", leftScrollingFrame)
feedRowFrame.Name = "FeedRowFrame"
feedRowFrame.Size = UDim2.new(1, 0, 0, 28)
feedRowFrame.BackgroundTransparency = 1
feedRowFrame.LayoutOrder = 9.6

local feedLabel = Instance.new("TextLabel", feedRowFrame)
feedLabel.Name = "FeedLabel"
feedLabel.Size = UDim2.new(0, 94, 0, 28)
feedLabel.Position = UDim2.new(0, 0, 0, 0)
feedLabel.BackgroundTransparency = 1
feedLabel.Font = Enum.Font.GothamBold
feedLabel.Text = "Deliver Zone 1"
feedLabel.TextColor3 = Color3.fromRGB(220, 200, 235)
feedLabel.TextSize = 10
feedLabel.TextXAlignment = Enum.TextXAlignment.Left

feedToggleButton = Instance.new("TextButton", feedRowFrame)
feedToggleButton.Name = "FeedToggleButton"
feedToggleButton.Size = UDim2.new(0, 94, 0, 28)
feedToggleButton.Position = UDim2.new(0, 94, 0, 0)
feedToggleButton.BackgroundColor3 = feedFriendEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
feedToggleButton.BackgroundTransparency = 0.4
feedToggleButton.BorderSizePixel = 0
feedToggleButton.Font = Enum.Font.GothamBold
feedToggleButton.Text = feedFriendEnabled and "ON" or "OFF"
feedToggleButton.TextColor3 = feedFriendEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
feedToggleButton.TextSize = 11
Instance.new("UICorner", feedToggleButton).CornerRadius = UDim.new(0, 6)
feedToggleStroke = Instance.new("UIStroke", feedToggleButton)
feedToggleStroke.Color = feedFriendEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

-- ================= AUTO PICKUP UI ROW =================
local pickupHeaderLabel = Instance.new("TextLabel", leftScrollingFrame)
pickupHeaderLabel.Name = "PickupHeaderLabel"
pickupHeaderLabel.Size = UDim2.new(1, 0, 0, 16)
pickupHeaderLabel.BackgroundTransparency = 1
pickupHeaderLabel.Font = Enum.Font.GothamBold
pickupHeaderLabel.Text = "AUTO PICKUP"
pickupHeaderLabel.TextColor3 = Color3.fromRGB(210, 195, 150)
pickupHeaderLabel.TextSize = 11
pickupHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
pickupHeaderLabel.LayoutOrder = 10

local pickupRowFrame = Instance.new("Frame", leftScrollingFrame)
pickupRowFrame.Name = "PickupRowFrame"
pickupRowFrame.Size = UDim2.new(1, 0, 0, 28)
pickupRowFrame.BackgroundTransparency = 1
pickupRowFrame.LayoutOrder = 11

local autoPickupBox = Instance.new("TextBox", pickupRowFrame)
autoPickupBox.Name = "AutoPickupBox"
autoPickupBox.Size = UDim2.new(0, 60, 0, 28)
autoPickupBox.Position = UDim2.new(0, 0, 0, 0)
autoPickupBox.BackgroundColor3 = Color3.fromRGB(40, 45, 56)
autoPickupBox.BackgroundTransparency = 0.35
autoPickupBox.BorderSizePixel = 0
autoPickupBox.Font = Enum.Font.GothamBold
autoPickupBox.Text = tostring(settingsData.AutoPickupNum or 0)
autoPickupBox.PlaceholderText = "Val..."
autoPickupBox.TextColor3 = Color3.fromRGB(255, 255, 255)
autoPickupBox.TextSize = 11
autoPickupBox.ClearTextOnFocus = false
Instance.new("UICorner", autoPickupBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", autoPickupBox).Color = Color3.fromRGB(75, 85, 105)

local autoPickupSuffixBox = Instance.new("TextBox", pickupRowFrame)
autoPickupSuffixBox.Name = "AutoPickupSuffixBox"
autoPickupSuffixBox.Size = UDim2.new(0, 32, 0, 28)
autoPickupSuffixBox.Position = UDim2.new(0, 64, 0, 0)
autoPickupSuffixBox.BackgroundColor3 = Color3.fromRGB(40, 45, 56)
autoPickupSuffixBox.BackgroundTransparency = 0.35
autoPickupSuffixBox.BorderSizePixel = 0
autoPickupSuffixBox.Font = Enum.Font.GothamBold
autoPickupSuffixBox.Text = settingsData.AutoPickupSuf or "B"
autoPickupSuffixBox.PlaceholderText = "Suf..."
autoPickupSuffixBox.TextColor3 = Color3.fromRGB(230, 205, 130)
autoPickupSuffixBox.TextSize = 11
autoPickupSuffixBox.ClearTextOnFocus = false
Instance.new("UICorner", autoPickupSuffixBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", autoPickupSuffixBox).Color = Color3.fromRGB(75, 85, 105)

autoPickupToggleButton = Instance.new("TextButton", pickupRowFrame)
autoPickupToggleButton.Name = "AutoPickupToggleButton"
autoPickupToggleButton.Size = UDim2.new(0, 88, 0, 28)
autoPickupToggleButton.Position = UDim2.new(0, 100, 0, 0)
autoPickupToggleButton.BackgroundColor3 = autoPickupEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
autoPickupToggleButton.BackgroundTransparency = 0.4
autoPickupToggleButton.BorderSizePixel = 0
autoPickupToggleButton.Font = Enum.Font.GothamBold
autoPickupToggleButton.Text = autoPickupEnabled and "ON" or "OFF"
autoPickupToggleButton.TextColor3 = autoPickupEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
autoPickupToggleButton.TextSize = 11
Instance.new("UICorner", autoPickupToggleButton).CornerRadius = UDim.new(0, 6)
local autoPickupToggleStroke = Instance.new("UIStroke", autoPickupToggleButton)
autoPickupToggleStroke.Color = autoPickupEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

local function updateMinAutoPickupValue()
	local num = tonumber(autoPickupBox.Text) or 0
	local suf = (autoPickupSuffixBox.Text or "B"):upper()
	local mul = 1
	if suf == "K" then mul = 1e3 elseif suf == "M" then mul = 1e6 elseif suf == "B" then mul = 1e9 elseif suf == "T" then mul = 1e12 end
	
	minAutoPickupValue = num * mul
	settingsData.AutoPickupNum = num
	settingsData.AutoPickupSuf = suf
	settingsData.MinPickup = minAutoPickupValue
	saveSettings()

	autoPickupExecutionToken = autoPickupExecutionToken + 1
	feedFriendExecutionToken = feedFriendExecutionToken + 1
	isProcessingPickup = false
	isProcessingFeedFriend = false
	isPickingUp = false
	cancelActiveTween()
	
	if autoPickupEnabled then
		task.spawn(function()
			checkAndGrabAutoPickupRoutine()
		end)
	end
end

autoPickupBox.FocusLost:Connect(updateMinAutoPickupValue)
autoPickupSuffixBox.FocusLost:Connect(updateMinAutoPickupValue)
autoPickupBox:GetPropertyChangedSignal("Text"):Connect(updateMinAutoPickupValue)
autoPickupSuffixBox:GetPropertyChangedSignal("Text"):Connect(updateMinAutoPickupValue)

local filterRowFrame = Instance.new("Frame", leftScrollingFrame)
filterRowFrame.Name = "FilterRowFrame"
filterRowFrame.Size = UDim2.new(1, 0, 0, 28)
filterRowFrame.BackgroundTransparency = 1
filterRowFrame.LayoutOrder = 12

local rarityFilterBtn = Instance.new("TextButton", filterRowFrame)
rarityFilterBtn.Name = "RarityFilterBtn"
rarityFilterBtn.Size = UDim2.new(0, 90, 0, 28)
rarityFilterBtn.Position = UDim2.new(0, 0, 0, 0)
rarityFilterBtn.BackgroundColor3 = Color3.fromRGB(50, 58, 75)
rarityFilterBtn.BackgroundTransparency = 0.3
rarityFilterBtn.BorderSizePixel = 0
rarityFilterBtn.Font = Enum.Font.GothamBold
rarityFilterBtn.Text = "Rarity"
rarityFilterBtn.TextColor3 = Color3.fromRGB(210, 220, 235)
rarityFilterBtn.TextSize = 10
Instance.new("UICorner", rarityFilterBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", rarityFilterBtn).Color = Color3.fromRGB(90, 105, 130)

local variantFilterBtn = Instance.new("TextButton", filterRowFrame)
variantFilterBtn.Name = "VariantFilterBtn"
variantFilterBtn.Size = UDim2.new(0, 94, 0, 28)
variantFilterBtn.Position = UDim2.new(0, 94, 0, 0)
variantFilterBtn.BackgroundColor3 = Color3.fromRGB(50, 58, 75)
variantFilterBtn.BackgroundTransparency = 0.3
variantFilterBtn.BorderSizePixel = 0
variantFilterBtn.Font = Enum.Font.GothamBold
variantFilterBtn.Text = "Variant"
variantFilterBtn.TextColor3 = Color3.fromRGB(210, 220, 235)
variantFilterBtn.TextSize = 10
Instance.new("UICorner", variantFilterBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", variantFilterBtn).Color = Color3.fromRGB(90, 105, 130)

local gemHeaderLabel = Instance.new("TextLabel", leftScrollingFrame)
gemHeaderLabel.Name = "GemHeaderLabel"
gemHeaderLabel.Size = UDim2.new(1, 0, 0, 16)
gemHeaderLabel.BackgroundTransparency = 1
gemHeaderLabel.Font = Enum.Font.GothamBold
gemHeaderLabel.Text = "AUTO COLLECT GEM"
gemHeaderLabel.TextColor3 = Color3.fromRGB(130, 200, 255)
gemHeaderLabel.TextSize = 11
gemHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
gemHeaderLabel.LayoutOrder = 13

local gemRowFrame = Instance.new("Frame", leftScrollingFrame)
gemRowFrame.Name = "GemRowFrame"
gemRowFrame.Size = UDim2.new(1, 0, 0, 28)
gemRowFrame.BackgroundTransparency = 1
gemRowFrame.LayoutOrder = 14

local gemLabel = Instance.new("TextLabel", gemRowFrame)
gemLabel.Size = UDim2.new(0, 94, 0, 28)
gemLabel.Position = UDim2.new(0, 0, 0, 0)
gemLabel.BackgroundTransparency = 1
gemLabel.Font = Enum.Font.GothamBold
gemLabel.Text = "EggGemDrops"
gemLabel.TextColor3 = Color3.fromRGB(200, 215, 235)
gemLabel.TextSize = 10
gemLabel.TextXAlignment = Enum.TextXAlignment.Left

autoGemToggleButton = Instance.new("TextButton", gemRowFrame)
autoGemToggleButton.Name = "AutoGemToggleButton"
autoGemToggleButton.Size = UDim2.new(0, 94, 0, 28)
autoGemToggleButton.Position = UDim2.new(0, 94, 0, 0)
autoGemToggleButton.BackgroundColor3 = autoGemEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
autoGemToggleButton.BackgroundTransparency = 0.4
autoGemToggleButton.BorderSizePixel = 0
autoGemToggleButton.Font = Enum.Font.GothamBold
autoGemToggleButton.Text = autoGemEnabled and "ON" or "OFF"
autoGemToggleButton.TextColor3 = autoGemEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
autoGemToggleButton.TextSize = 11
Instance.new("UICorner", autoGemToggleButton).CornerRadius = UDim.new(0, 6)
local autoGemToggleStroke = Instance.new("UIStroke", autoGemToggleButton)
autoGemToggleStroke.Color = autoGemEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

local antiRagdollHeaderLabel = Instance.new("TextLabel", leftScrollingFrame)
antiRagdollHeaderLabel.Name = "AntiRagdollHeaderLabel"
antiRagdollHeaderLabel.Size = UDim2.new(1, 0, 0, 16)
antiRagdollHeaderLabel.BackgroundTransparency = 1
antiRagdollHeaderLabel.Font = Enum.Font.GothamBold
antiRagdollHeaderLabel.Text = "ANTI RAGDOLL"
antiRagdollHeaderLabel.TextColor3 = Color3.fromRGB(255, 130, 150)
antiRagdollHeaderLabel.TextSize = 11
antiRagdollHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
antiRagdollHeaderLabel.LayoutOrder = 15

local antiRagdollRowFrame = Instance.new("Frame", leftScrollingFrame)
antiRagdollRowFrame.Name = "AntiRagdollRowFrame"
antiRagdollRowFrame.Size = UDim2.new(1, 0, 0, 28)
antiRagdollRowFrame.BackgroundTransparency = 1
antiRagdollRowFrame.LayoutOrder = 16

local antiRagdollLabel = Instance.new("TextLabel", antiRagdollRowFrame)
antiRagdollLabel.Size = UDim2.new(0, 94, 0, 28)
antiRagdollLabel.Position = UDim2.new(0, 0, 0, 0)
antiRagdollLabel.BackgroundTransparency = 1
antiRagdollLabel.Font = Enum.Font.GothamBold
antiRagdollLabel.Text = "Proteksi"
antiRagdollLabel.TextColor3 = Color3.fromRGB(200, 215, 235)
antiRagdollLabel.TextSize = 10
antiRagdollLabel.TextXAlignment = Enum.TextXAlignment.Left

antiRagdollToggleButton = Instance.new("TextButton", antiRagdollRowFrame)
antiRagdollToggleButton.Name = "AntiRagdollToggleButton"
antiRagdollToggleButton.Size = UDim2.new(0, 94, 0, 28)
antiRagdollToggleButton.Position = UDim2.new(0, 94, 0, 0)
antiRagdollToggleButton.BackgroundColor3 = antiRagdollEnabled and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
antiRagdollToggleButton.BackgroundTransparency = 0.4
antiRagdollToggleButton.BorderSizePixel = 0
antiRagdollToggleButton.Font = Enum.Font.GothamBold
antiRagdollToggleButton.Text = antiRagdollEnabled and "ON" or "OFF"
antiRagdollToggleButton.TextColor3 = antiRagdollEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
antiRagdollToggleButton.TextSize = 11
Instance.new("UICorner", antiRagdollToggleButton).CornerRadius = UDim.new(0, 6)
local antiRagdollToggleStroke = Instance.new("UIStroke", antiRagdollToggleButton)
antiRagdollToggleStroke.Color = antiRagdollEnabled and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110)

-- ================= STYLISH POPUPS SETUP =================
local rarityPopup = Instance.new("Frame", mainFrame)
rarityPopup.Name = "RarityPopup"
rarityPopup.Size = UDim2.new(0, 170, 0, 235)
rarityPopup.Position = UDim2.new(0, 6, 0, 125)
rarityPopup.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
rarityPopup.BackgroundTransparency = 0.1
rarityPopup.BorderSizePixel = 0
rarityPopup.Visible = false
rarityPopup.ZIndex = 30
Instance.new("UICorner", rarityPopup).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", rarityPopup).Color = Color3.fromRGB(90, 120, 170)

local rPopupTitle = Instance.new("TextLabel", rarityPopup)
rPopupTitle.Size = UDim2.new(1, -28, 0, 24)
rPopupTitle.Position = UDim2.new(0, 8, 0, 6)
rPopupTitle.BackgroundTransparency = 1
rPopupTitle.Font = Enum.Font.GothamBold
rPopupTitle.Text = "Rarity Checkbox"
rPopupTitle.TextColor3 = Color3.fromRGB(130, 190, 255)
rPopupTitle.TextSize = 11
rPopupTitle.TextXAlignment = Enum.TextXAlignment.Left
rPopupTitle.ZIndex = 31

local rPopupClose = Instance.new("TextButton", rarityPopup)
rPopupClose.Size = UDim2.new(0, 18, 0, 18)
rPopupClose.Position = UDim2.new(1, -22, 0, 7)
rPopupClose.BackgroundColor3 = Color3.fromRGB(210, 60, 75)
rPopupClose.BackgroundTransparency = 0.2
rPopupClose.BorderSizePixel = 0
rPopupClose.Font = Enum.Font.GothamBold
rPopupClose.Text = "X"
rPopupClose.TextColor3 = Color3.fromRGB(255, 255, 255)
rPopupClose.TextSize = 9
rPopupClose.ZIndex = 31
Instance.new("UICorner", rPopupClose).CornerRadius = UDim.new(0, 4)

local rListContainer = Instance.new("ScrollingFrame", rarityPopup)
rListContainer.Size = UDim2.new(1, -10, 1, -36)
rListContainer.Position = UDim2.new(0, 5, 0, 32)
rListContainer.BackgroundTransparency = 1
rListContainer.BorderSizePixel = 0
rListContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
rListContainer.ScrollBarThickness = 2
rListContainer.ZIndex = 31
local rListLay = Instance.new("UIListLayout", rListContainer)
rListLay.SortOrder = Enum.SortOrder.LayoutOrder
rListLay.Padding = UDim.new(0, 3)

local variantPopup = Instance.new("Frame", mainFrame)
variantPopup.Name = "VariantPopup"
variantPopup.Size = UDim2.new(0, 170, 0, 285)
variantPopup.Position = UDim2.new(0, 6, 0, 105)
variantPopup.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
variantPopup.BackgroundTransparency = 0.1
variantPopup.BorderSizePixel = 0
variantPopup.Visible = false
variantPopup.ZIndex = 30
Instance.new("UICorner", variantPopup).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", variantPopup).Color = Color3.fromRGB(210, 185, 100)

local vPopupTitle = Instance.new("TextLabel", variantPopup)
vPopupTitle.Size = UDim2.new(1, -28, 0, 24)
vPopupTitle.Position = UDim2.new(0, 8, 0, 6)
vPopupTitle.BackgroundTransparency = 1
vPopupTitle.Font = Enum.Font.GothamBold
vPopupTitle.Text = "Variant & Rarity"
vPopupTitle.TextColor3 = Color3.fromRGB(240, 210, 120)
vPopupTitle.TextSize = 11
vPopupTitle.TextXAlignment = Enum.TextXAlignment.Left
vPopupTitle.ZIndex = 31

local vPopupClose = Instance.new("TextButton", variantPopup)
vPopupClose.Size = UDim2.new(0, 18, 0, 18)
vPopupClose.Position = UDim2.new(1, -22, 0, 7)
vPopupClose.BackgroundColor3 = Color3.fromRGB(210, 60, 75)
vPopupClose.BackgroundTransparency = 0.2
vPopupClose.BorderSizePixel = 0
vPopupClose.Font = Enum.Font.GothamBold
vPopupClose.Text = "X"
vPopupClose.TextColor3 = Color3.fromRGB(255, 255, 255)
vPopupClose.TextSize = 9
vPopupClose.ZIndex = 31
Instance.new("UICorner", vPopupClose).CornerRadius = UDim.new(0, 4)

local vListContainer = Instance.new("ScrollingFrame", variantPopup)
vListContainer.Size = UDim2.new(1, -10, 1, -36)
vListContainer.Position = UDim2.new(0, 5, 0, 32)
vListContainer.BackgroundTransparency = 1
vListContainer.BorderSizePixel = 0
vListContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
vListContainer.ScrollBarThickness = 2
vListContainer.ZIndex = 31
local vListLay = Instance.new("UIListLayout", vListContainer)
vListLay.SortOrder = Enum.SortOrder.LayoutOrder
vListLay.Padding = UDim.new(0, 3)

local function populateRarityPopup()
	for _, child in ipairs(rListContainer:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	for _, rName in ipairs(rarityList) do
		local row = Instance.new("Frame", rListContainer)
		row.Size = UDim2.new(1, -2, 0, 28)
		row.BackgroundColor3 = Color3.fromRGB(42, 48, 62)
		row.BackgroundTransparency = 0.4
		row.BorderSizePixel = 0
		row.ZIndex = 32
		
		local corner = Instance.new("UICorner", row)
		corner.CornerRadius = UDim.new(0, 6)
		
		local stroke = Instance.new("UIStroke", row)
		stroke.Color = Color3.fromRGB(70, 85, 115)
		stroke.Transparency = 0.6
		
		local label = Instance.new("TextLabel", row)
		label.Size = UDim2.new(0.7, 0, 1, 0)
		label.Position = UDim2.new(0, 8, 0, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = rName
		label.TextColor3 = Color3.fromRGB(225, 235, 245)
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 33
		
		local chkBox = Instance.new("TextButton", row)
		chkBox.Size = UDim2.new(0, 20, 0, 20)
		chkBox.Position = UDim2.new(1, -24, 0.5, -10)
		chkBox.BackgroundColor3 = rarityForcePickup[rName] and Color3.fromRGB(46, 160, 95) or Color3.fromRGB(35, 40, 52)
		chkBox.BorderSizePixel = 0
		chkBox.Font = Enum.Font.GothamBold
		chkBox.Text = rarityForcePickup[rName] and "✓" or ""
		chkBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		chkBox.TextSize = 11
		chkBox.ZIndex = 33
		
		Instance.new("UICorner", chkBox).CornerRadius = UDim.new(0, 5)
		local chkStroke = Instance.new("UIStroke", chkBox)
		chkStroke.Color = rarityForcePickup[rName] and Color3.fromRGB(70, 210, 130) or Color3.fromRGB(80, 95, 120)
		
		chkBox.MouseButton1Click:Connect(function()
			rarityForcePickup[rName] = not rarityForcePickup[rName]
			settingsData.RarityForcePickup = rarityForcePickup
			saveSettings()
			
			chkBox.BackgroundColor3 = rarityForcePickup[rName] and Color3.fromRGB(46, 160, 95) or Color3.fromRGB(35, 40, 52)
			chkBox.Text = rarityForcePickup[rName] and "✓" or ""
			chkStroke.Color = rarityForcePickup[rName] and Color3.fromRGB(70, 210, 130) or Color3.fromRGB(80, 95, 120)
			
			autoPickupExecutionToken = autoPickupExecutionToken + 1
			feedFriendExecutionToken = feedFriendExecutionToken + 1
			isProcessingPickup = false
			isProcessingFeedFriend = false
			isPickingUp = false
			cancelActiveTween()
			
			if autoPickupEnabled then
				task.spawn(function()
					checkAndGrabAutoPickupRoutine()
				end)
			end
		end)
	end
	rListContainer.CanvasSize = UDim2.new(0, 0, 0, rListLay.AbsoluteContentSize.Y + 6)
end

local function populateVariantPopup()
	for _, child in ipairs(vListContainer:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
	
	local secHeader1 = Instance.new("TextLabel", vListContainer)
	secHeader1.Size = UDim2.new(1, -2, 0, 18)
	secHeader1.BackgroundTransparency = 1
	secHeader1.Font = Enum.Font.GothamBold
	secHeader1.Text = "⚡ VARIANT / MUTATION"
	secHeader1.TextColor3 = Color3.fromRGB(240, 205, 110)
	secHeader1.TextSize = 10
	secHeader1.TextXAlignment = Enum.TextXAlignment.Left
	secHeader1.ZIndex = 32

	local variantTypes = {"Gold", "Diamond", "Lightning", "Frozen", "Angelic"}
	for _, vType in ipairs(variantTypes) do
		local row = Instance.new("Frame", vListContainer)
		row.Size = UDim2.new(1, -2, 0, 26)
		row.BackgroundColor3 = Color3.fromRGB(42, 48, 62)
		row.BackgroundTransparency = 0.4
		row.BorderSizePixel = 0
		row.ZIndex = 32
		
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", row)
		stroke.Color = Color3.fromRGB(90, 85, 60)
		stroke.Transparency = 0.6
		
		local label = Instance.new("TextLabel", row)
		label.Size = UDim2.new(0.7, 0, 1, 0)
		label.Position = UDim2.new(0, 8, 0, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = vType
		label.TextColor3 = Color3.fromRGB(225, 235, 245)
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 33
		
		local chkBox = Instance.new("TextButton", row)
		chkBox.Size = UDim2.new(0, 20, 0, 20)
		chkBox.Position = UDim2.new(1, -24, 0.5, -10)
		chkBox.BackgroundColor3 = variantCheckboxes[vType] and Color3.fromRGB(46, 160, 95) or Color3.fromRGB(35, 40, 52)
		chkBox.BorderSizePixel = 0
		chkBox.Font = Enum.Font.GothamBold
		chkBox.Text = variantCheckboxes[vType] and "✓" or ""
		chkBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		chkBox.TextSize = 11
		chkBox.ZIndex = 33
		
		Instance.new("UICorner", chkBox).CornerRadius = UDim.new(0, 5)
		local chkStroke = Instance.new("UIStroke", chkBox)
		chkStroke.Color = variantCheckboxes[vType] and Color3.fromRGB(70, 210, 130) or Color3.fromRGB(80, 95, 120)
		
		chkBox.MouseButton1Click:Connect(function()
			variantCheckboxes[vType] = not variantCheckboxes[vType]
			settingsData.VariantCheckboxes = variantCheckboxes
			saveSettings()
			
			chkBox.BackgroundColor3 = variantCheckboxes[vType] and Color3.fromRGB(46, 160, 95) or Color3.fromRGB(35, 40, 52)
			chkBox.Text = variantCheckboxes[vType] and "✓" or ""
			chkStroke.Color = variantCheckboxes[vType] and Color3.fromRGB(70, 210, 130) or Color3.fromRGB(80, 95, 120)
			
			autoPickupExecutionToken = autoPickupExecutionToken + 1
			feedFriendExecutionToken = feedFriendExecutionToken + 1
			isProcessingPickup = false
			isProcessingFeedFriend = false
			isPickingUp = false
			cancelActiveTween()
			
			if autoPickupEnabled then
				task.spawn(function()
					checkAndGrabAutoPickupRoutine()
				end)
			end
		end)
	end

	local secHeader2 = Instance.new("TextLabel", vListContainer)
	secHeader2.Size = UDim2.new(1, -2, 0, 22)
	secHeader2.BackgroundTransparency = 1
	secHeader2.Font = Enum.Font.GothamBold
	secHeader2.Text = "💎 RARITY KHUSUS VARIANT"
	secHeader2.TextColor3 = Color3.fromRGB(240, 205, 110)
	secHeader2.TextSize = 10
	secHeader2.TextXAlignment = Enum.TextXAlignment.Left
	secHeader2.ZIndex = 32

	for _, rName in ipairs(rarityList) do
		local row = Instance.new("Frame", vListContainer)
		row.Size = UDim2.new(1, -2, 0, 26)
		row.BackgroundColor3 = Color3.fromRGB(42, 48, 62)
		row.BackgroundTransparency = 0.4
		row.BorderSizePixel = 0
		row.ZIndex = 32
		
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", row)
		stroke.Color = Color3.fromRGB(90, 85, 60)
		stroke.Transparency = 0.6
		
		local label = Instance.new("TextLabel", row)
		label.Size = UDim2.new(0.7, 0, 1, 0)
		label.Position = UDim2.new(0, 8, 0, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = rName
		label.TextColor3 = Color3.fromRGB(225, 235, 245)
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 33
		
		local chkBox = Instance.new("TextButton", row)
		chkBox.Size = UDim2.new(0, 20, 0, 20)
		chkBox.Position = UDim2.new(1, -24, 0.5, -10)
		chkBox.BackgroundColor3 = variantRarityCheckboxes[rName] and Color3.fromRGB(46, 160, 95) or Color3.fromRGB(35, 40, 52)
		chkBox.BorderSizePixel = 0
		chkBox.Font = Enum.Font.GothamBold
		chkBox.Text = variantRarityCheckboxes[rName] and "✓" or ""
		chkBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		chkBox.TextSize = 11
		chkBox.ZIndex = 33
		
		Instance.new("UICorner", chkBox).CornerRadius = UDim.new(0, 5)
		local chkStroke = Instance.new("UIStroke", chkBox)
		chkStroke.Color = variantRarityCheckboxes[rName] and Color3.fromRGB(70, 210, 130) or Color3.fromRGB(80, 95, 120)
		
		chkBox.MouseButton1Click:Connect(function()
			variantRarityCheckboxes[rName] = not variantRarityCheckboxes[rName]
			settingsData.VariantRarityCheckboxes = variantRarityCheckboxes
			saveSettings()
			
			chkBox.BackgroundColor3 = variantRarityCheckboxes[rName] and Color3.fromRGB(46, 160, 95) or Color3.fromRGB(35, 40, 52)
			chkBox.Text = variantRarityCheckboxes[rName] and "✓" or ""
			chkStroke.Color = variantRarityCheckboxes[rName] and Color3.fromRGB(70, 210, 130) or Color3.fromRGB(80, 95, 120)
			
			autoPickupExecutionToken = autoPickupExecutionToken + 1
			feedFriendExecutionToken = feedFriendExecutionToken + 1
			isProcessingPickup = false
			isProcessingFeedFriend = false
			isPickingUp = false
			cancelActiveTween()
			
			if autoPickupEnabled then
				task.spawn(function()
					checkAndGrabAutoPickupRoutine()
				end)
			end
		end)
	end
	
	vListContainer.CanvasSize = UDim2.new(0, 0, 0, vListLay.AbsoluteContentSize.Y + 8)
end

rarityFilterBtn.MouseButton1Click:Connect(function()
	populateRarityPopup()
	rarityPopup.Visible = not rarityPopup.Visible
	variantPopup.Visible = false
end)

variantFilterBtn.MouseButton1Click:Connect(function()
	populateVariantPopup()
	variantPopup.Visible = not variantPopup.Visible
	rarityPopup.Visible = false
end)

rPopupClose.MouseButton1Click:Connect(function()
	rarityPopup.Visible = false
end)

vPopupClose.MouseButton1Click:Connect(function()
	variantPopup.Visible = false
end)

leftListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	leftScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, leftListLayout.AbsoluteContentSize.Y + 10)
end)

local function populateZoneDropdown()
	for _, child in ipairs(dropdownListFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	local buildFolder = Workspace:FindFirstChild("Build")
	if not buildFolder then return end
	local zoneHitboxes = buildFolder:FindFirstChild("ZoneHitboxes")
	if not zoneHitboxes then return end

	for i, displayName in ipairs(zoneNamesList) do
		local hitboxObj = zoneHitboxes:FindFirstChild(tostring(i))
		if hitboxObj then
			local zoneItemButton = Instance.new("TextButton", dropdownListFrame)
			zoneItemButton.Size = UDim2.new(1, -4, 0, 24)
			zoneItemButton.BackgroundColor3 = Color3.fromRGB(40, 46, 58)
			zoneItemButton.BackgroundTransparency = 0.3
			zoneItemButton.BorderSizePixel = 0
			zoneItemButton.Font = Enum.Font.GothamMedium
			zoneItemButton.Text = "  " .. displayName
			zoneItemButton.TextColor3 = Color3.fromRGB(210, 220, 235)
			zoneItemButton.TextSize = 11
			zoneItemButton.TextXAlignment = Enum.TextXAlignment.Left
			zoneItemButton.ZIndex = 26
			Instance.new("UICorner", zoneItemButton).CornerRadius = UDim.new(0, 5)

			zoneItemButton.MouseButton1Click:Connect(function()
				dropdownMainButton.Text = displayName .. " ▾"
				dropdownListFrame.Visible = false
				selectedZoneHitboxObj = hitboxObj
			end)
		end
	end
	dropdownListFrame.CanvasSize = UDim2.new(0, 0, 0, dropListLayout.AbsoluteContentSize.Y + 4)
end

populateZoneDropdown()
dropdownMainButton.MouseButton1Click:Connect(function()
	populateZoneDropdown()
	dropdownListFrame.Visible = not dropdownListFrame.Visible
	farmListFrame.Visible = false
end)

local function populateBreakZoneDropdown()
	for _, child in ipairs(farmListFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	local buildFolder = Workspace:FindFirstChild("Build")
	if not buildFolder then return end
	local zoneBuilds = buildFolder:FindFirstChild("ZoneBuilds")
	if not zoneBuilds then return end

	for i, displayName in ipairs(zoneNamesList) do
		local zoneFolderNameClean = "Zone" .. tostring(i)
		local zoneFolderObj = zoneBuilds:FindFirstChild(zoneFolderNameClean)
		if zoneFolderObj then
			local itemBtn = Instance.new("TextButton", farmListFrame)
			itemBtn.Size = UDim2.new(1, -4, 0, 24)
			itemBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 58)
			itemBtn.BackgroundTransparency = 0.3
			itemBtn.BorderSizePixel = 0
			itemBtn.Font = Enum.Font.GothamMedium
			itemBtn.Text = "  " .. displayName
			itemBtn.TextColor3 = Color3.fromRGB(210, 220, 235)
			itemBtn.TextSize = 11
			itemBtn.TextXAlignment = Enum.TextXAlignment.Left
			itemBtn.ZIndex = 26
			Instance.new("UICorner", itemBtn).CornerRadius = UDim.new(0, 5)

			itemBtn.MouseButton1Click:Connect(function()
				breakDropdownButton.Text = displayName .. " ▾"
				farmListFrame.Visible = false
				selectedBreakZoneFolder = zoneFolderObj
				activeTargetEgg = nil
				
				settingsData.SelectedBreakZoneName = zoneFolderNameClean
				saveSettings()

				if autoBreakZoneEnabled then
					cancelActiveTween()
					interruptAndCancelAll()
					
					autoBreakZoneEnabled = false
					settingsData.AutoBreakEnabled = false
					saveSettings()
					
					task.wait(0.1)
					
					autoBreakZoneEnabled = true
					settingsData.AutoBreakEnabled = true
					saveSettings()
					
					runAutoBreakLoop()
				end
			end)
		end
	end
	farmListFrame.CanvasSize = UDim2.new(0, 0, 0, farmListLayout.AbsoluteContentSize.Y + 4)
end

populateBreakZoneDropdown()

pcall(function()
	if settingsData.SelectedBreakZoneName and settingsData.SelectedBreakZoneName ~= "" then
		local buildFolder = Workspace:FindFirstChild("Build")
		if buildFolder then
			local zoneBuilds = buildFolder:FindFirstChild("ZoneBuilds")
			if zoneBuilds then
				local targetFolder = zoneBuilds:FindFirstChild(settingsData.SelectedBreakZoneName)
				if targetFolder then
					selectedBreakZoneFolder = targetFolder
					for i, displayName in ipairs(zoneNamesList) do
						if "Zone" .. tostring(i) == settingsData.SelectedBreakZoneName then
							breakDropdownButton.Text = displayName .. " ▾"
							break
						end
					end
				end
			end
		end
	end
end)

breakDropdownButton.MouseButton1Click:Connect(function()
	populateBreakZoneDropdown()
	farmListFrame.Visible = not farmListFrame.Visible
	dropdownListFrame.Visible = false
end)

local function isWithinRange3D(pos1, pos2, maxHorizontalDist, maxVerticalDist)
	local horizontalPos1 = Vector3.new(pos1.X, 0, pos1.Z)
	local horizontalPos2 = Vector3.new(pos2.X, 0, pos2.Z)
	local horizontalDist = (horizontalPos1 - horizontalPos2).Magnitude
	local verticalDist = math.abs(pos1.Y - pos2.Y)
	return horizontalDist <= maxHorizontalDist and verticalDist <= maxVerticalDist
end

local function isInsideZone1(itemPart)
	local buildFolder = Workspace:FindFirstChild("Build")
	if not buildFolder then return false end
	local zoneHitboxes = buildFolder:FindFirstChild("ZoneHitboxes")
	if not zoneHitboxes then return false end
	
	local zone1Hitbox = zoneHitboxes:FindFirstChild("1")
	if not zone1Hitbox or not zone1Hitbox:IsA("BasePart") then return false end

	local cf, size = zone1Hitbox.CFrame, zone1Hitbox.Size
	local localPos = cf:PointToObjectSpace(itemPart.Position)

	if math.abs(localPos.X) <= (size.X / 2) and
	   math.abs(localPos.Y) <= (size.Y / 2) + 15 and
	   math.abs(localPos.Z) <= (size.Z / 2) then
		return true
	end
	return false
end

local function firePrompt(prompt)
	if prompt then
		pcall(function()
			prompt.HoldDuration = 0
			if fireproximityprompt then
				fireproximityprompt(prompt)
			else
				prompt:InputHoldBegin()
				prompt:InputHoldEnd()
			end
		end)
	end
end

local function safeTriggerPromptAndWait(prompt, targetItem, timeoutLimit)
	local successfullyTriggered = false
	timeoutLimit = timeoutLimit or 0.6 
	
	if not prompt or not prompt.Parent then return false end

	local triggerConn
	triggerConn = prompt.Triggered:Connect(function(playerWhoTriggered)
		if playerWhoTriggered == LocalPlayer then
			successfullyTriggered = true
		end
	end)

	firePrompt(prompt)

	local waitStart = tick()
	while not successfullyTriggered and (targetItem and targetItem.Parent) and (tick() - waitStart < timeoutLimit) do
		task.wait(0.01)
	end

	if triggerConn then
		triggerConn:Disconnect()
	end

	return successfullyTriggered or (targetItem and not targetItem.Parent)
end

local function flatTweenTo(targetCFrame, targetLookAtPos)
	cancelActiveTween()

	local character = LocalPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then return end

	activeTweenRunning = true
	local startPos = rootPart.Position
	local targetPos = targetCFrame.Position
	local groundTargetPos = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
	local totalDistance = (groundTargetPos - startPos).Magnitude

	if totalDistance < 0.1 then
		if targetLookAtPos then
			local lookPos = Vector3.new(targetLookAtPos.X, groundTargetPos.Y, targetLookAtPos.Z)
			rootPart.CFrame = CFrame.new(groundTargetPos, lookPos)
		else
			rootPart.CFrame = targetCFrame
		end
		activeTweenRunning = false
		return
	end

	local traveledDistance = 0
	local speedVal = customSpeed or 190
	local connection

	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 1)
		if animator then
			if not currentAnimTrack or not currentAnimTrack.IsPlaying then
				local animateScript = character:FindFirstChild("Animate")
				local runAnimId = "rbxassetid://913376220"
				
				if animateScript then
					local runObj = animateScript:FindFirstChild("run") or animateScript:FindFirstChild("Walk")
					if runObj then
						local anim = runObj:FindFirstChildOfClass("Animation")
						if anim and anim.AnimationId ~= "" then
							runAnimId = anim.AnimationId
						end
					end
				end

				local anim = Instance.new("Animation")
				anim.AnimationId = runAnimId
				currentAnimTrack = animator:LoadAnimation(anim)
			end

			if currentAnimTrack and not currentAnimTrack.IsPlaying then
				currentAnimTrack:Play(0.1)
				currentAnimTrack:AdjustSpeed(speedVal / 16)
			end
		end
	end)

	connection = RunService.Heartbeat:Connect(function(dt)
		if not activeTweenRunning or isPickingUp or isCollectingGem or (not autoBreakZoneEnabled and not autoPickupEnabled and not feedFriendEnabled and not autoGemEnabled) or not character or not rootPart.Parent then
			if connection then connection:Disconnect() end
			cancelActiveTween()
			return
		end
		
		traveledDistance = traveledDistance + (speedVal * dt)
		local currentCenter = targetLookAtPos or (groundTargetPos + targetCFrame.LookVector)

		if traveledDistance >= totalDistance then
			local finalLook = Vector3.new(currentCenter.X, groundTargetPos.Y, currentCenter.Z)
			rootPart.CFrame = CFrame.new(groundTargetPos, finalLook)
			activeTweenRunning = false
			if connection then connection:Disconnect() end
		else
			local alpha = traveledDistance / totalDistance
			local lerpPos = startPos:Lerp(groundTargetPos, alpha)
			local dynamicLook = Vector3.new(currentCenter.X, lerpPos.Y, currentCenter.Z)
			rootPart.CFrame = CFrame.new(lerpPos, dynamicLook)
		end
	end)

	while activeTweenRunning and (autoBreakZoneEnabled or autoPickupEnabled or feedFriendEnabled or autoGemEnabled) and not isPickingUp and not isCollectingGem and rootPart and rootPart.Parent do
		RunService.Heartbeat:Wait()
	end
	
	if connection then connection:Disconnect() end
	
	if currentAnimTrack and currentAnimTrack.IsPlaying then
		pcall(function() currentAnimTrack:Stop(0.1) end)
	end
	
	if rootPart then
		pcall(function() 
			local finalCenter = targetLookAtPos or (groundTargetPos + targetCFrame.LookVector)
			rootPart.CFrame = CFrame.new(groundTargetPos, Vector3.new(finalCenter.X, groundTargetPos.Y, finalCenter.Z))
		end)
	end
	activeTweenRunning = false
end

local function verifyAndEquipPickaxe()
	pcall(function()
		LocalPlayer:SetAttribute("FastSwingOwned", true)
		LocalPlayer:SetAttribute("DoubleSwingOwned", true)

		local character = LocalPlayer.Character
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		if not humanoid then return end

		local equippedTool = character:FindFirstChildOfClass("Tool")
		local isHoldingPickaxe = equippedTool and (equippedTool.Name:lower():match("pickaxe") or equippedTool.Name:lower():match("pick"))

		if not isHoldingPickaxe then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") then child.Parent = backpack end
			end
			task.wait(0.01)
			
			if backpack then
				for _, tool in ipairs(backpack:GetChildren()) do
					if tool:IsA("Tool") and (tool.Name:lower():match("pickaxe") or tool.Name:lower():match("pick")) then
						humanoid:EquipTool(tool)
						task.wait(0.02)
						break
					end
				end
			end
		end

		pcall(function()
			local autoSwingBtn = LocalPlayer.PlayerGui:FindFirstChild("MainGUI") 
				and LocalPlayer.PlayerGui.MainGUI:FindFirstChild("AutoSwing")
            
			if autoSwingBtn and autoSwingBtn:IsA("GuiButton") then
				local colorAlpha = autoSwingBtn:FindFirstChild("AutoSwingColorAlpha")
				local isOn = false
				if colorAlpha and colorAlpha:IsA("NumberValue") then
					if colorAlpha.Value >= 0.5 then
						isOn = true
					end
				end
                
				if not isOn then
					for _, connection in ipairs(getconnections(autoSwingBtn.Activated)) do
						connection:Fire()
					end
				end
			end
		end)
	end)
end

local function triggerTreadmillBypass()
	pcall(function()
		local myBase = findMyBase()
		if not myBase then return end
		local targetTreadmill = nil
		local function searchFolder(folder)
			for _, obj in ipairs(folder:GetChildren()) do
				if obj.Name:lower():match("treadmill$") then return obj
				elseif #obj:GetChildren() > 0 then
					local res = searchFolder(obj)
					if res then return res end
				end
			end
			return nil
		end
		targetTreadmill = searchFolder(myBase)
		if targetTreadmill then
			local targetPart = targetTreadmill:IsA("BasePart") and targetTreadmill or (targetTreadmill:IsA("Model") and (targetTreadmill.PrimaryPart or targetTreadmill:FindFirstChildWhichIsA("BasePart", true)))
			if targetPart then
				local treadmillCFrame = targetPart.CFrame
				pcall(function()
					local event = ReplicatedStorage:FindFirstChild("TreadmillSessionRemote")
					if event then firesignal(event.OnClientEvent, 1, treadmillCFrame) end
				end)
				task.wait(0.5)
				pcall(function()
					local Event = ReplicatedStorage:FindFirstChild("TreadmillSessionRemote")
					if Event then firesignal(Event.OnClientEvent, nil) end
				end)
				task.wait(0.3)
				pcall(function()
					local event = ReplicatedStorage:FindFirstChild("TreadmillSessionRemote")
					if event then event:FireServer() end
				end)
				task.wait(0.2)
			end
		end
	end)
end

executeBaseSequence = function()
	if isExecutingBaseSequenceActive then return end
	isExecutingBaseSequenceActive = true

	autoBreakExecutionToken = autoBreakExecutionToken + 1
	autoPickupExecutionToken = autoPickupExecutionToken + 1
	feedFriendExecutionToken = feedFriendExecutionToken + 1
	autoGemExecutionToken = autoGemExecutionToken + 1
	autoBreakTPToken = autoBreakTPToken + 1

	autoBreakZoneEnabled = false
	autoPickupEnabled = false
	feedFriendEnabled = false
	autoGemEnabled = false
	speedEnabled = false

	isTaskRunning = true
	isPickingUp = true
	isCollectingGem = true
	isProcessingPickup = true
	isProcessingFeedFriend = true

	activeBreakThreadRunning = false
	activeAutoPickupLoopRunning = false
	activeFeedFriendLoopRunning = false
	activeAutoGemLoopRunning = false
	isExecutingTPZone = false

	interruptAndCancelAll()
	cancelActiveTween()
	activeTargetEgg = nil
	rememberedObjectText = nil

	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoid then humanoid.PlatformStand = false end
			if rootPart then rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
		end
	end)

	updateStatusText("Status: Base Sequence...", Color3.fromRGB(255, 180, 50))
	task.wait(0.2)

	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		isExecutingBaseSequenceActive = false
		isTaskRunning = false
		isPickingUp = false
		isCollectingGem = false
		isProcessingPickup = false
		isProcessingFeedFriend = false
		return
	end

	local rootPart = character.HumanoidRootPart
	local myBase = findMyBase()
	if not myBase then
		isExecutingBaseSequenceActive = false
		isTaskRunning = false
		isPickingUp = false
		isCollectingGem = false
		isProcessingPickup = false
		isProcessingFeedFriend = false
		return
	end

	triggerTreadmillBypass()
	task.wait(0.5)

	pcall(function()
		local Event = ReplicatedStorage:FindFirstChild("PetsInventoryRemote")
		if Event and Event:IsA("RemoteEvent") then
			Event:FireServer("EquipBest", nil)
		end
	end)
	task.wait(0.2)

	local spawnPart = nil
	pcall(function()
		local spawnPoint = findMySpawnPoint()
		if spawnPoint then
			spawnPart = spawnPoint:IsA("BasePart") and spawnPoint or (spawnPoint:IsA("Model") and (spawnPoint.PrimaryPart or spawnPoint:FindFirstChildWhichIsA("BasePart", true)))
		elseif myBase then
			spawnPart = myBase:IsA("BasePart") and spawnPart or (myBase:IsA("Model") and (myBase.PrimaryPart or myBase:FindFirstChildWhichIsA("BasePart", true)))
		end
	end)

	if spawnPart and rootPart then
		local targetSpawnCFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
		
		rootPart.CFrame = targetSpawnCFrame
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		
		local startTime = tick()
		local timeoutDuration = 5.0
		
		while (tick() - startTime) < timeoutDuration do
			if not character or not rootPart.Parent then break end
			
			local distance = (rootPart.Position - targetSpawnCFrame.Position).Magnitude
			if distance <= 3 then
				break
			end
			
			task.wait(0.1)
		end
	end
	
	task.wait(0.5)

	local wasAutoBreakActive = settingsData.AutoBreakEnabled
	local wasAutoPickupActive = settingsData.AutoPickupEnabled
	local wasFeedFriendActive = settingsData.FeedFriendEnabled
	local wasAutoGemActive = settingsData.AutoGemEnabled
	local wasAutoTpActive = autoTpEnabled
	local wasSpeedActive = settingsData.SpeedEnabled
	local wasEspActive = settingsData.EspEnabled

	speedEnabled = wasSpeedActive
	autoTpEnabled = wasAutoTpActive
	espEnabled = wasEspActive
	settingsData.SpeedEnabled = wasSpeedActive
	settingsData.EspEnabled = wasEspActive
	settingsData.AutoTpEnabled = wasAutoTpActive
	saveSettings()

	if speedToggleButton then
		speedToggleButton.BackgroundColor3 = wasSpeedActive and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
		speedToggleButton.Text = wasSpeedActive and "Spd: ON" or "Spd: OFF"
		speedToggleButton.TextColor3 = wasSpeedActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
		local stroke = speedToggleButton:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = wasSpeedActive and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110) end
	end

	if espToggleButton then
		espToggleButton.BackgroundColor3 = wasEspActive and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
		espToggleButton.Text = wasEspActive and "ESP: ON" or "ESP: OFF"
		espToggleButton.TextColor3 = wasEspActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
		local stroke = espToggleButton:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = wasEspActive and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110) end
	end

	if autoTpButton then
		autoTpButton.BackgroundColor3 = wasAutoTpActive and Color3.fromRGB(50, 130, 85) or Color3.fromRGB(45, 50, 62)
		autoTpButton.Text = wasAutoTpActive and "Auto: ON" or "Auto"
		autoTpButton.TextColor3 = wasAutoTpActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 180, 200)
		if autoTpStroke then autoTpStroke.Color = wasAutoTpActive and Color3.fromRGB(80, 190, 120) or Color3.fromRGB(80, 90, 110) end
	end

	isTaskRunning = false
	isPickingUp = false
	isCollectingGem = false
	isProcessingPickup = false
	isProcessingFeedFriend = false

	task.wait(1.0)

	if wasAutoBreakActive then
		autoBreakZoneEnabled = true
		settingsData.AutoBreakEnabled = true
		if autoBreakZoneToggleButton then
			autoBreakZoneToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
			autoBreakZoneToggleButton.Text = "ON"
			autoBreakZoneToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			local stroke = autoBreakZoneToggleButton:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(80, 190, 120) end
		end
		task.spawn(function()
			runAutoBreakLoop()
		end)
	end

	if wasAutoPickupActive then
		autoPickupEnabled = true
		settingsData.AutoPickupEnabled = true
		if autoPickupToggleButton then
			autoPickupToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
			autoPickupToggleButton.Text = "ON"
			autoPickupToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			local stroke = autoPickupToggleButton:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(80, 190, 120) end
		end
		task.spawn(function()
			runAutoPickupLoop()
		end)
	end

	if wasFeedFriendActive then
		feedFriendEnabled = true
		settingsData.FeedFriendEnabled = true
		if feedToggleButton then
			feedToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
			feedToggleButton.Text = "ON"
			feedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			if feedToggleStroke then feedToggleStroke.Color = Color3.fromRGB(80, 190, 120) end
		end
		task.spawn(function()
			runFeedFriendLoop()
		end)
	end

	if wasAutoGemActive then
		autoGemEnabled = true
		settingsData.AutoGemEnabled = true
		if autoGemToggleButton then
			autoGemToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
			autoGemToggleButton.Text = "ON"
			autoGemToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			local stroke = autoGemToggleButton:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(80, 190, 120) end
		end
		task.spawn(function()
			runAutoGemLoop()
		end)
	end

	isExecutingBaseSequenceActive = false
	updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
end

tpButton.MouseButton1Click:Connect(function()
	task.spawn(function()
		executeBaseSequence()
	end)
end)

local function triggerAntiTreadmill()
	if not antiStuckEnabled then return end
	activeTargetEgg = nil
	isTaskRunning = true
	
	pcall(function()
		pcall(function()
			local event = ReplicatedStorage:FindFirstChild("TreadmillSessionRemote")
			if event then event:FireServer() end
		end)
		task.wait(0.2)
	end)
	
	isTaskRunning = false
end

trackConnection(ReplicatedStorage:WaitForChild("SpeedGainRemote", 10).OnClientEvent:Connect(function(...)
	if not antiStuckEnabled then return end
	hasReceivedSpeedSignal = true
	triggerAntiTreadmill()
end))

antiStuckToggleButton.MouseButton1Click:Connect(function()
	antiStuckEnabled = not antiStuckEnabled
	settingsData.AntiStuckEnabled = antiStuckEnabled
	saveSettings()
	
	if antiStuckEnabled then
		antiStuckToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		antiStuckToggleButton.Text = "Anti T: ON"
		antiStuckToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		antiStuckToggleStroke.Color = Color3.fromRGB(80, 190, 120)
		
		if hasReceivedSpeedSignal and not isTaskRunning then
			triggerAntiTreadmill()
		end
	else
		antiStuckToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		antiStuckToggleButton.Text = "Anti T: OFF"
		antiStuckToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		antiStuckToggleStroke.Color = Color3.fromRGB(80, 90, 110)
		hasReceivedSpeedSignal = false
	end
end)

-- ================= EKSKLUSIF TOMBOL TOGGLE (MUTUAL EXCLUSION) =================
local function exclusiveToggle(mode)
	if mode == "Feed" then
		if feedFriendEnabled then
			if autoPickupEnabled then
				autoPickupEnabled = false
				settingsData.AutoPickupEnabled = false
				autoPickupToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
				autoPickupToggleButton.Text = "OFF"
				autoPickupToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
				autoPickupToggleButton:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(80, 90, 110)
			end
			if autoTpEnabled then
				autoTpEnabled = false
				settingsData.AutoTpEnabled = false
				autoTpButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
				autoTpButton.Text = "Auto"
				autoTpButton.TextColor3 = Color3.fromRGB(170, 180, 200)
				autoTpStroke.Color = Color3.fromRGB(80, 90, 110)
			end
		end
	elseif mode == "Pickup" then
		if autoPickupEnabled then
			if feedFriendEnabled then
				feedFriendEnabled = false
				settingsData.FeedFriendEnabled = false
				feedToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
				feedToggleButton.Text = "OFF"
				feedToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
				feedToggleStroke.Color = Color3.fromRGB(80, 90, 110)
			end
			if autoTpEnabled then
				autoTpEnabled = false
				settingsData.AutoTpEnabled = false
				autoTpButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
				autoTpButton.Text = "Auto"
				autoTpButton.TextColor3 = Color3.fromRGB(170, 180, 200)
				autoTpStroke.Color = Color3.fromRGB(80, 90, 110)
			end
		end
	elseif mode == "AutoTP" then
		if autoTpEnabled then
			if feedFriendEnabled then
				feedFriendEnabled = false
				settingsData.FeedFriendEnabled = false
				feedToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
				feedToggleButton.Text = "OFF"
				feedToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
				feedToggleStroke.Color = Color3.fromRGB(80, 90, 110)
			end
			if autoPickupEnabled then
				autoPickupEnabled = false
				settingsData.AutoPickupEnabled = false
				autoPickupToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
				autoPickupToggleButton.Text = "OFF"
				autoPickupToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
				autoPickupToggleButton:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(80, 90, 110)
			end
		end
	end
	saveSettings()
end

executeAutoPickupTPZone = function(targetItem, currentToken)
	if autoPickupExecutionToken ~= currentToken or isExecutingBaseSequenceActive then return false end

	cancelActiveTween()
	isPickingUp = true
	isTaskRunning = false
	isProcessingPickup = true

	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then 
		isPickingUp = false
		isProcessingPickup = false
		return false 
	end

	local rootPart = character.HumanoidRootPart
	local part = targetItem:IsA("BasePart") and targetItem or (targetItem:IsA("Model") and (targetItem.PrimaryPart or targetItem:FindFirstChildWhichIsA("BasePart", true)))
	if not part then
		isPickingUp = false
		isProcessingPickup = false
		return false
	end

	local targetCFrame = part.CFrame + Vector3.new(0, 3, 0)

	triggerTreadmillBypass()
	task.wait(0.2)

	rootPart.CFrame = targetCFrame
	task.wait(0.3)

	local prompt = getPromptForItem(targetItem)
	if prompt then
		safeTriggerPromptAndWait(prompt, targetItem, 0.6)
		task.wait(0.3)
	end

	rootPart.CFrame = CFrame.new(-95, 3, -55)
	task.wait(0.8)

	pcall(function()
		local dropEvent = ReplicatedStorage:FindFirstChild("DropCarriedRemote")
		if dropEvent and dropEvent:IsA("RemoteEvent") then
			dropEvent:FireServer()
		end
	end)

	task.wait(0.2)

	isPickingUp = false
	isProcessingPickup = false
	activeTargetEgg = nil

	task.spawn(function()
		task.wait(0.1)
		checkAndGrabAutoPickupRoutine()
	end)
	
	return true
end

-- ================= EKSEKUSI FEED FRIEND KE ZONE 1 (TITIK ACAK) =================
executeFeedFriendTPZone = function(targetItem, currentToken)
	if feedFriendExecutionToken ~= currentToken or isExecutingBaseSequenceActive then return false end

	cancelActiveTween()
	isPickingUp = true
	isTaskRunning = false
	isProcessingFeedFriend = true

	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then 
		isPickingUp = false
		isProcessingFeedFriend = false
		return false 
	end

	local rootPart = character.HumanoidRootPart
	local part = targetItem:IsA("BasePart") and targetItem or (targetItem:IsA("Model") and (targetItem.PrimaryPart or targetItem:FindFirstChildWhichIsA("BasePart", true)))
	if not part then
		isPickingUp = false
		isProcessingFeedFriend = false
		return false
	end

	local targetCFrame = part.CFrame + Vector3.new(0, 3, 0)

	triggerTreadmillBypass()
	task.wait(0.2)

	rootPart.CFrame = targetCFrame
	task.wait(0.3)

	local prompt = getPromptForItem(targetItem)
	if prompt then
		safeTriggerPromptAndWait(prompt, targetItem, 0.6)
		task.wait(0.3)
	end

	-- Ambil Hitbox Zone 1 untuk titik acak drop
	local buildFolder = Workspace:FindFirstChild("Build")
	local zoneHitboxes = buildFolder and buildFolder:FindFirstChild("ZoneHitboxes")
	local zone1Hitbox = zoneHitboxes and zoneHitboxes:FindFirstChild("1")

	local dropCFrame = CFrame.new(0, 3, 0)
	if zone1Hitbox and zone1Hitbox:IsA("BasePart") then
		local cf, size = zone1Hitbox.CFrame, zone1Hitbox.Size
		local randomX = math.random(-size.X / 2 + 5, size.X / 2 - 5)
		local randomZ = math.random(-size.Z / 2 + 5, size.Z / 2 - 5)
		dropCFrame = cf * CFrame.new(randomX, 5, randomZ)
	end

	rootPart.CFrame = dropCFrame
	task.wait(0.5)

	pcall(function()
		local dropEvent = ReplicatedStorage:FindFirstChild("DropCarriedRemote")
		if dropEvent and dropEvent:IsA("RemoteEvent") then
			dropEvent:FireServer()
		end
	end)

	task.wait(0.3)

	isPickingUp = false
	isProcessingFeedFriend = false
	activeTargetEgg = nil

	return true
end

evaluateAndProcessItem = function(item, currentToken)
	if isExecutingBaseSequenceActive then return false end
	if not autoPickupEnabled or not settingsData.AutoPickupEnabled then 
		isProcessingPickup = false
		return false 
	end
	if not item or not item.Parent then 
		isProcessingPickup = false
		return false 
	end
	if autoPickupExecutionToken ~= currentToken then 
		isProcessingPickup = false
		return false 
	end

	local cashVal = 0
	local itemRarity = ""
	local itemVariant = ""
	local itemMutation = ""
	
	local overhead = item:FindFirstChild("AnimalOverhead", true) or item
	
	local cashFolder = overhead:FindFirstChild("CashPerSecond")
	if cashFolder then
		local found = false
		for _, lbl in ipairs(cashFolder:GetDescendants()) do
			if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
				cashVal = parseValueToNumber(lbl.Text)
				found = true
				break
			end
		end
		if not found then
			for _, valObj in ipairs(cashFolder:GetDescendants()) do
				if (valObj:IsA("NumberValue") or valObj:IsA("IntValue")) then
					cashVal = valObj.Value
					break
				end
			end
		end
	end
	if cashVal == 0 then
		local directVal = item:GetAttribute("CashPerSecond") or item:GetAttribute("Cash") or overhead:GetAttribute("CashPerSecond")
		if directVal then
			cashVal = tonumber(directVal) or parseValueToNumber(tostring(directVal))
		end
	end
	
	local rarityAttr = item:GetAttribute("Rarity") or overhead:GetAttribute("Rarity")
	if not rarityAttr then
		local rFolder = overhead:FindFirstChild("Rarity")
		if rFolder then
			for _, lbl in ipairs(rFolder:GetDescendants()) do
				if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
					rarityAttr = lbl.Text
					break
				end
			end
		end
	end
	if type(rarityAttr) == "string" then itemRarity = rarityAttr end

	local varAttr = item:GetAttribute("Variant") or overhead:GetAttribute("Variant")
	if type(varAttr) == "string" then itemVariant = varAttr end

	local mutAttr = item:GetAttribute("Mutation") or overhead:GetAttribute("Mutation")
	if type(mutAttr) == "string" then itemMutation = mutAttr end

	local shouldTake = false

	if minAutoPickupValue > 0 and cashVal >= minAutoPickupValue then shouldTake = true end
	if not shouldTake and itemRarity ~= "" and rarityForcePickup[itemRarity] == true then shouldTake = true end

	if not shouldTake then
		local activeVariantTypes = {"Gold", "Diamond", "Lightning", "Frozen", "Angelic"}
		local hasAnyVariantTypeChecked = false
		local matchesVariantType = false
		
		for _, vType in ipairs(activeVariantTypes) do
			if variantCheckboxes[vType] then
				hasAnyVariantTypeChecked = true
				if (type(itemVariant) == "string" and itemVariant:lower():match(vType:lower())) or
				   (type(itemMutation) == "string" and itemMutation:lower():match(vType:lower())) or
				   item.Name:lower():match(vType:lower()) then
					matchesVariantType = true
					break
				end
			end
		end

		if hasAnyVariantTypeChecked and matchesVariantType then
			local hasAnyVariantRarityChecked = false
			local matchesVariantRarity = false
			for _, rName in ipairs(rarityList) do
				if variantRarityCheckboxes[rName] then
					hasAnyVariantRarityChecked = true
					if itemRarity == rName then matchesVariantRarity = true break end
				end
			end
			if hasAnyVariantRarityChecked then
				if matchesVariantRarity then shouldTake = true end
			else
				shouldTake = true
			end
		end
	end

	if not shouldTake or autoPickupExecutionToken ~= currentToken or isExecutingBaseSequenceActive then
		isProcessingPickup = false
		return false
	end

	updateStatusText("Status: Picking Up...", Color3.fromRGB(80, 220, 150))
	cancelActiveTween()
	isTaskRunning = false
	isPickingUp = true

	task.wait(0.01)

	local part = item:IsA("BasePart") and item or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)))
	if part and item.Parent and autoPickupEnabled and settingsData.AutoPickupEnabled and (autoPickupExecutionToken == currentToken) and not isExecutingBaseSequenceActive then
		local character = LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if rootPart then
			local distanceToTarget = (rootPart.Position - part.Position).Magnitude
			if distanceToTarget > 1000 then
				return executeAutoPickupTPZone(item, currentToken)
			end
		end

		activeTweenRunning = true
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		
		if rootPart and humanoid and autoPickupEnabled and settingsData.AutoPickupEnabled and (autoPickupExecutionToken == currentToken) and not isExecutingBaseSequenceActive then
			local startPos = rootPart.Position
			local targetPos = part.Position
			local groundTargetPos = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
			local lookTargetPos = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
			local totalDistance = (groundTargetPos - startPos).Magnitude

			if totalDistance > 0.1 then
				local traveledDistance = 0
				local speedVal = customSpeed or 190

				pcall(function()
					local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 1)
					if animator then
						if not currentAnimTrack or not currentAnimTrack.IsPlaying then
							local animateScript = character:FindFirstChild("Animate")
							local runAnimId = "rbxassetid://913376220"
							if animateScript then
								local runObj = animateScript:FindFirstChild("run") or animateScript:FindFirstChild("Walk")
								if runObj then
									local anim = runObj:FindFirstChildOfClass("Animation")
									if anim and anim.AnimationId ~= "" then runAnimId = anim.AnimationId end
								end
							end
							local anim = Instance.new("Animation")
							anim.AnimationId = runAnimId
							currentAnimTrack = animator:LoadAnimation(anim)
						end
						if currentAnimTrack and not currentAnimTrack.IsPlaying then
							currentAnimTrack:Play(0.1)
							currentAnimTrack:AdjustSpeed(speedVal / 16)
						end
					end
				end)

				local connection
				connection = RunService.Heartbeat:Connect(function(dt)
					if not activeTweenRunning or not item.Parent or not part.Parent or not autoPickupEnabled or not settingsData.AutoPickupEnabled or (autoPickupExecutionToken ~= currentToken) or isExecutingBaseSequenceActive then
						if connection then connection:Disconnect() end
						cancelActiveTween()
						return
					end
					traveledDistance = traveledDistance + (speedVal * dt)
					if traveledDistance >= totalDistance then
						rootPart.CFrame = CFrame.new(groundTargetPos, lookTargetPos + Vector3.new(0, 0, -1))
						activeTweenRunning = false
						if connection then connection:Disconnect() end
					else
						local alpha = traveledDistance / totalDistance
						rootPart.CFrame = CFrame.new(startPos:Lerp(groundTargetPos, alpha), lookTargetPos + Vector3.new(0, 0, -1))
					end
				end)

				while activeTweenRunning and item.Parent and autoPickupEnabled and settingsData.AutoPickupEnabled and (autoPickupExecutionToken == currentToken) and not isExecutingBaseSequenceActive do
					RunService.Heartbeat:Wait()
				end
				if connection then connection:Disconnect() end
			end
		end

		if currentAnimTrack and currentAnimTrack.IsPlaying then
			pcall(function() currentAnimTrack:Stop(0.1) end)
		end

		if not item.Parent or not part.Parent or not autoPickupEnabled or not settingsData.AutoPickupEnabled or (autoPickupExecutionToken ~= currentToken) and not isExecutingBaseSequenceActive then 
			isPickingUp = false
			isTaskRunning = false
			isProcessingPickup = false
			return false
		end
		
		task.wait(0.01)
		
		local prompt = getPromptForItem(item)
		if prompt and autoPickupEnabled and settingsData.AutoPickupEnabled and item.Parent and (autoPickupExecutionToken == currentToken) and not isExecutingBaseSequenceActive then 
			local isSuccess = safeTriggerPromptAndWait(prompt, item, 0.6)
			
			if isSuccess and autoPickupEnabled and settingsData.AutoPickupEnabled and (autoPickupExecutionToken == currentToken) and not isExecutingBaseSequenceActive then
				task.wait(0.05) 
				
				isPickingUp = false
				isProcessingPickup = false
				executeBaseSequence() 
				return true
			end
		end
	end
	
	isProcessingPickup = false
	isPickingUp = false
	return false
end

checkAndGrabAutoPickupRoutine = function()
	if isExecutingBaseSequenceActive then return false end
	if not autoPickupEnabled or not settingsData.AutoPickupEnabled then return false end
	if isProcessingPickup or isTaskRunning or isPickingUp or isCollectingGem then return false end
	
	isProcessingPickup = true

	local currentToken = autoPickupExecutionToken

	cancelActiveTween()
	isPickingUp = false

	local animalPickups = Workspace:FindFirstChild("AnimalPickups")
	if not animalPickups then 
		isProcessingPickup = false
		return false 
	end

	local validItems = {}
	for _, item in ipairs(animalPickups:GetChildren()) do
		if isExecutingBaseSequenceActive or not autoPickupEnabled or not settingsData.AutoPickupEnabled or (autoPickupExecutionToken ~= currentToken) then 
			isProcessingPickup = false
			return false 
		end
		local cashVal = 0
		local itemRarity = ""
		local itemVariant = ""
		local itemMutation = ""
		
		local overhead = item:FindFirstChild("AnimalOverhead", true) or item
		local cashFolder = overhead:FindFirstChild("CashPerSecond")
		if cashFolder then
			local found = false
			for _, lbl in ipairs(cashFolder:GetDescendants()) do
				if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
					cashVal = parseValueToNumber(lbl.Text)
					found = true
					break
				end
			end
			if not found then
				for _, valObj in ipairs(cashFolder:GetDescendants()) do
					if (valObj:IsA("NumberValue") or valObj:IsA("IntValue")) then
						cashVal = valObj.Value
						break
					end
				end
			end
		end
		if cashVal == 0 then
			local directVal = item:GetAttribute("CashPerSecond") or item:GetAttribute("Cash") or overhead:GetAttribute("CashPerSecond")
			if directVal then
				cashVal = tonumber(directVal) or parseValueToNumber(tostring(directVal))
			end
		end
		
		local rarityAttr = item:GetAttribute("Rarity") or overhead:GetAttribute("Rarity")
		if not rarityAttr then
			local rFolder = overhead:FindFirstChild("Rarity")
			if rFolder then
				for _, lbl in ipairs(rFolder:GetDescendants()) do
					if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
						rarityAttr = lbl.Text
						break
					end
				end
			end
		end
		if type(rarityAttr) == "string" then itemRarity = rarityAttr end

		local varAttr = item:GetAttribute("Variant") or overhead:GetAttribute("Variant")
		if type(varAttr) == "string" then itemVariant = varAttr end

		local mutAttr = item:GetAttribute("Mutation") or overhead:GetAttribute("Mutation")
		if type(mutAttr) == "string" then itemMutation = mutAttr end

		local shouldTake = false
		if minAutoPickupValue > 0 and cashVal >= minAutoPickupValue then shouldTake = true end
		if not shouldTake and itemRarity ~= "" and rarityForcePickup[itemRarity] == true then shouldTake = true end
		if not shouldTake then
			local activeVariantTypes = {"Gold", "Diamond", "Lightning", "Frozen", "Angelic"}
			local hasAnyVariantTypeChecked = false
			local matchesVariantType = false
			
			for _, vType in ipairs(activeVariantTypes) do
				if variantCheckboxes[vType] then
					hasAnyVariantTypeChecked = true
					if (type(itemVariant) == "string" and itemVariant:lower():match(vType:lower())) or
					   (type(itemMutation) == "string" and itemMutation:lower():match(vType:lower())) or
					   item.Name:lower():match(vType:lower()) then
						matchesVariantType = true
						break
					end
				end
			end

			if hasAnyVariantTypeChecked and matchesVariantType then
				local hasAnyVariantRarityChecked = false
				local matchesVariantRarity = false
				for _, rName in ipairs(rarityList) do
					if variantRarityCheckboxes[rName] then
						hasAnyVariantRarityChecked = true
						if itemRarity == rName then matchesVariantRarity = true break end
					end
				end
				if hasAnyVariantRarityChecked then
					if matchesVariantRarity then shouldTake = true end
				else
					shouldTake = true
				end
			end
		end

		if shouldTake then
			table.insert(validItems, { item = item, value = cashVal })
		end
	end

	table.sort(validItems, function(a, b) return a.value > b.value end)
	
	if #validItems > 0 and (autoPickupExecutionToken == currentToken) and not isExecutingBaseSequenceActive then
		local targetEntry = validItems[1]
		if targetEntry and targetEntry.item and targetEntry.item.Parent then
			return evaluateAndProcessItem(targetEntry.item, currentToken)
		end
	end
	
	isProcessingPickup = false
	return false
end

local function hasCloseGems()
	if not autoGemEnabled or not settingsData.AutoGemEnabled then return false end
	local gemDropsFolder = Workspace:FindFirstChild("EggGemDrops")
	if not gemDropsFolder then return false end

	local character = LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	for _, gem in ipairs(gemDropsFolder:GetChildren()) do
		local part = gem:IsA("BasePart") and gem or (gem:IsA("Model") and (gem.PrimaryPart or gem:FindFirstChildWhichIsA("BasePart", true)))
		if part then
			local dist = (rootPart.Position - part.Position).Magnitude
			if dist <= 850 then
				return true
			end
		end
	end
	return false
end

runAutoGemLoop = function()
	if activeAutoGemLoopRunning then return end
	autoGemExecutionToken = autoGemExecutionToken + 1
	local currentGemToken = autoGemExecutionToken
	activeAutoGemLoopRunning = true

	local gemThread = task.spawn(function()
		task.wait(1.0)

		while screenGui.Parent and (autoGemEnabled or settingsData.AutoGemEnabled) and (autoGemExecutionToken == currentGemToken) do
			if isExecutingBaseSequenceActive or (not autoGemEnabled and not settingsData.AutoGemEnabled) then
				task.wait(0.2)
				continue
			end

			local gemDropsFolder = Workspace:FindFirstChild("EggGemDrops")
			if gemDropsFolder then
				local gemsList = gemDropsFolder:GetChildren()
				if #gemsList > 0 then
					local character = LocalPlayer.Character
					local rootPart = character and character:FindFirstChild("HumanoidRootPart")
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					
					if rootPart and humanoid and humanoid.Health > 0 then
						local nearestGem = nil
						local shortestDist = 850

						for _, gem in ipairs(gemsList) do
							if autoGemExecutionToken ~= currentGemToken or isExecutingBaseSequenceActive or not autoGemEnabled then break end
							local part = gem:IsA("BasePart") and gem or (gem:IsA("Model") and (gem.PrimaryPart or gem:FindFirstChildWhichIsA("BasePart", true)))
							if part then
								local dist = (rootPart.Position - part.Position).Magnitude
								if dist <= 850 and dist < shortestDist then
									shortestDist = dist
									nearestGem = gem
								end
							end
						end

						if nearestGem and nearestGem.Parent then
							local gemPart = nearestGem:IsA("BasePart") and nearestGem or (nearestGem:IsA("Model") and (nearestGem.PrimaryPart or nearestGem:FindFirstChildWhichIsA("BasePart", true)))
							if gemPart then
								isCollectingGem = true
								updateStatusText("Status: Mengambil Gem...", Color3.fromRGB(130, 200, 255))

								cancelActiveTween()

								activeTweenRunning = true
								local startPos = rootPart.Position
								local targetPos = gemPart.Position
								local groundTargetPos = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
								local lookTargetPos = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
								local totalDistance = (groundTargetPos - startPos).Magnitude

								if totalDistance <= 850 and totalDistance > 0.1 then
									local traveledDistance = 0
									local speedVal = math.max(customSpeed or 190, 100)
									local connection
									local tweenTimeout = tick()

									pcall(function()
										local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 1)
										if animator then
											if not currentAnimTrack or not currentAnimTrack.IsPlaying then
												local animateScript = character:FindFirstChild("Animate")
												local runAnimId = "rbxassetid://913376220"
												if animateScript then
													local runObj = animateScript:FindFirstChild("run") or animateScript:FindFirstChild("Walk")
													if runObj then
														local anim = runObj:FindFirstChildOfClass("Animation")
														if anim and anim.AnimationId ~= "" then runAnimId = anim.AnimationId end
													end
												end
												local anim = Instance.new("Animation")
												anim.AnimationId = runAnimId
												currentAnimTrack = animator:LoadAnimation(anim)
											end
											if currentAnimTrack and not currentAnimTrack.IsPlaying then
												currentAnimTrack:Play(0.1)
												currentAnimTrack:AdjustSpeed(speedVal / 16)
											end
										end
									end)

									connection = RunService.Heartbeat:Connect(function(dt)
										if not activeTweenRunning or not nearestGem.Parent or not autoGemEnabled or (autoGemExecutionToken ~= currentGemToken) or isExecutingBaseSequenceActive then
											if connection then connection:Disconnect() end
											cancelActiveTween()
											return
										end
										
										if tick() - tweenTimeout > 3.0 then
											activeTweenRunning = false
											if connection then connection:Disconnect() end
											return
										end
										
										if gemPart and gemPart.Parent then
											targetPos = gemPart.Position
											groundTargetPos = Vector3.new(targetPos.X, rootPart.Position.Y, targetPos.Z)
											lookTargetPos = Vector3.new(targetPos.X, rootPart.Position.Y, targetPos.Z)
											totalDistance = (groundTargetPos - rootPart.Position).Magnitude
										end

										traveledDistance = traveledDistance + (speedVal * dt)
										if traveledDistance >= totalDistance or (rootPart.Position - groundTargetPos).Magnitude < 2.5 then
											rootPart.CFrame = CFrame.new(groundTargetPos, lookTargetPos + Vector3.new(0, 0, -1))
											activeTweenRunning = false
											if connection then connection:Disconnect() end
										else
											local alpha = math.clamp(traveledDistance / math.max(totalDistance, 1), 0, 1)
											rootPart.CFrame = CFrame.new(rootPart.Position:Lerp(groundTargetPos, alpha), lookTargetPos + Vector3.new(0, 0, -1))
										end
									end)

									while activeTweenRunning and nearestGem.Parent and autoGemEnabled and (autoGemExecutionToken == currentGemToken) and not isExecutingBaseSequenceActive do
										RunService.Heartbeat:Wait()
									end

									if connection then connection:Disconnect() end
								end

								if currentAnimTrack and currentAnimTrack.IsPlaying then
									pcall(function() currentAnimTrack:Stop(0.05) end)
								end

								isCollectingGem = false
								updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
							end
						end
					end
				end
			end

			task.wait(0.03)
		end
		activeAutoGemLoopRunning = false
	end)
	trackCoroutine(gemThread)
end

local function hasValidAnimalPickups()
	local animalPickups = Workspace:FindFirstChild("AnimalPickups")
	if not animalPickups then return false end

	for _, item in ipairs(animalPickups:GetChildren()) do
		local part = item:IsA("BasePart") and item or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)))
		
		-- Jika mode Feed Friend aktif, abaikan animal yang sudah di dalam Zone 1
		if feedFriendEnabled and part and isInsideZone1(part) then
			continue
		end

		local cashVal = 0
		local itemRarity = ""
		local itemVariant = ""
		local itemMutation = ""
		
		local overhead = item:FindFirstChild("AnimalOverhead", true) or item
		local cashFolder = overhead:FindFirstChild("CashPerSecond")
		if cashFolder then
			local found = false
			for _, lbl in ipairs(cashFolder:GetDescendants()) do
				if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
					cashVal = parseValueToNumber(lbl.Text)
					found = true
					break
				end
			end
			if not found then
				for _, valObj in ipairs(cashFolder:GetDescendants()) do
					if (valObj:IsA("NumberValue") or valObj:IsA("IntValue")) then
						cashVal = valObj.Value
						break
					end
				end
			end
		end
		if cashVal == 0 then
			local directVal = item:GetAttribute("CashPerSecond") or item:GetAttribute("Cash") or overhead:GetAttribute("CashPerSecond")
			if directVal then
				cashVal = tonumber(directVal) or parseValueToNumber(tostring(directVal))
			end
		end
		
		local rarityAttr = item:GetAttribute("Rarity") or overhead:GetAttribute("Rarity")
		if not rarityAttr then
			local rFolder = overhead:FindFirstChild("Rarity")
			if rFolder then
				for _, lbl in ipairs(rFolder:GetDescendants()) do
					if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
						rarityAttr = lbl.Text
						break
					end
				end
			end
		end
		if type(rarityAttr) == "string" then itemRarity = rarityAttr end

		local varAttr = item:GetAttribute("Variant") or overhead:GetAttribute("Variant")
		if type(varAttr) == "string" then itemVariant = varAttr end

		local mutAttr = item:GetAttribute("Mutation") or overhead:GetAttribute("Mutation")
		if type(mutAttr) == "string" then itemMutation = mutAttr end

		local shouldTake = false
		if minAutoPickupValue > 0 and cashVal >= minAutoPickupValue then shouldTake = true end
		if not shouldTake and itemRarity ~= "" and rarityForcePickup[itemRarity] == true then shouldTake = true end
		if not shouldTake then
			local activeVariantTypes = {"Gold", "Diamond", "Lightning", "Frozen", "Angelic"}
			local hasAnyVariantTypeChecked = false
			local matchesVariantType = false
			
			for _, vType in ipairs(activeVariantTypes) do
				if variantCheckboxes[vType] then
					hasAnyVariantTypeChecked = true
					if (type(itemVariant) == "string" and itemVariant:lower():match(vType:lower())) or
					   (type(itemMutation) == "string" and itemMutation:lower():match(vType:lower())) or
					   item.Name:lower():match(vType:lower()) then
						matchesVariantType = true
						break
					end
				end
			end

			if hasAnyVariantTypeChecked and matchesVariantType then
				local hasAnyVariantRarityChecked = false
				local matchesVariantRarity = false
				for _, rName in ipairs(rarityList) do
					if variantRarityCheckboxes[rName] then
						hasAnyVariantRarityChecked = true
						if itemRarity == rName then matchesVariantRarity = true break end
					end
				end
				if hasAnyVariantRarityChecked then
					if matchesVariantRarity then shouldTake = true end
				else
					shouldTake = true
				end
			end
		end

		if shouldTake then
			return true
		end
	end
	return false
end

runAutoPickupLoop = function()
	if activeAutoPickupLoopRunning then return end
	autoPickupExecutionToken = autoPickupExecutionToken + 1
	local currentPickupToken = autoPickupExecutionToken
	activeAutoPickupLoopRunning = true

	local pickupThread = task.spawn(function()
		while screenGui.Parent and (autoPickupEnabled or settingsData.AutoPickupEnabled) and (autoPickupExecutionToken == currentPickupToken) do
			if isExecutingBaseSequenceActive or (not autoPickupEnabled and not settingsData.AutoPickupEnabled) then
				task.wait(0.2)
				continue
			end

			if not isProcessingPickup and not isTaskRunning and not isPickingUp and not activeTweenRunning and not isExecutingBaseSequenceActive then
				checkAndGrabAutoPickupRoutine()
			end

			task.wait(0.2)
		end
		activeAutoPickupLoopRunning = false
	end)
	trackCoroutine(pickupThread)
end

-- ================= LOOP UTAMA FEED FRIEND =================
runFeedFriendLoop = function()
	if activeFeedFriendLoopRunning then return end
	feedFriendExecutionToken = feedFriendExecutionToken + 1
	local currentFeedToken = feedFriendExecutionToken
	activeFeedFriendLoopRunning = true

	local feedThread = task.spawn(function()
		while screenGui.Parent and (feedFriendEnabled or settingsData.FeedFriendEnabled) and (feedFriendExecutionToken == currentFeedToken) do
			if isExecutingBaseSequenceActive or (not feedFriendEnabled and not settingsData.FeedFriendEnabled) then
				task.wait(0.2)
				continue
			end

			if not isProcessingFeedFriend and not isTaskRunning and not isPickingUp and not activeTweenRunning and not isExecutingBaseSequenceActive then
				isProcessingFeedFriend = true
				
				local animalPickups = Workspace:FindFirstChild("AnimalPickups")
				if animalPickups then
					local validItems = {}
					
					for _, item in ipairs(animalPickups:GetChildren()) do
						local part = item:IsA("BasePart") and item or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)))
						
						-- Syarat 3: Abaikan animal yang sudah berada di dalam area Hitbox Zone 1
						if part and not isInsideZone1(part) then
							local cashVal = 0
							local itemRarity = ""
							local itemVariant = ""
							local itemMutation = ""
							
							local overhead = item:FindFirstChild("AnimalOverhead", true) or item
							local cashFolder = overhead:FindFirstChild("CashPerSecond")
							if cashFolder then
								for _, lbl in ipairs(cashFolder:GetDescendants()) do
									if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
										cashVal = parseValueToNumber(lbl.Text)
										break
									end
								end
							end
							if cashVal == 0 then
								local directVal = item:GetAttribute("CashPerSecond") or item:GetAttribute("Cash") or overhead:GetAttribute("CashPerSecond")
								if directVal then
									cashVal = tonumber(directVal) or parseValueToNumber(tostring(directVal))
								end
							end
							
							local rarityAttr = item:GetAttribute("Rarity") or overhead:GetAttribute("Rarity")
							if type(rarityAttr) == "string" then itemRarity = rarityAttr end

							local varAttr = item:GetAttribute("Variant") or overhead:GetAttribute("Variant")
							if type(varAttr) == "string" then itemVariant = varAttr end

							local mutAttr = item:GetAttribute("Mutation") or overhead:GetAttribute("Mutation")
							if type(mutAttr) == "string" then itemMutation = mutAttr end

							local shouldTake = false
							if minAutoPickupValue > 0 and cashVal >= minAutoPickupValue then shouldTake = true end
							if not shouldTake and itemRarity ~= "" and rarityForcePickup[itemRarity] == true then shouldTake = true end
							if not shouldTake then
								local activeVariantTypes = {"Gold", "Diamond", "Lightning", "Frozen", "Angelic"}
								for _, vType in ipairs(activeVariantTypes) do
									if variantCheckboxes[vType] then
										if (type(itemVariant) == "string" and itemVariant:lower():match(vType:lower())) or
										   (type(itemMutation) == "string" and itemMutation:lower():match(vType:lower())) or
										   item.Name:lower():match(vType:lower()) then
											shouldTake = true
											break
										end
									end
								end
							end

							if shouldTake then
								table.insert(validItems, { item = item, value = cashVal })
							end
						end
					end

					table.sort(validItems, function(a, b) return a.value > b.value end)

					if #validItems > 0 and (feedFriendExecutionToken == currentFeedToken) and not isExecutingBaseSequenceActive then
						local targetEntry = validItems[1]
						if targetEntry and targetEntry.item and targetEntry.item.Parent then
							updateStatusText("Status: Feeding Friend (Zone 1)...", Color3.fromRGB(255, 140, 210))
							executeFeedFriendTPZone(targetEntry.item, currentFeedToken)
						end
					end
				end
				
				isProcessingFeedFriend = false
			end

			task.wait(0.3)
		end
		activeFeedFriendLoopRunning = false
	end)
	trackCoroutine(feedThread)
end

executeAutoBreakTPZone = function()
	if isExecutingBaseSequenceActive or isTaskRunning or isPickingUp or isCollectingGem or isProcessingPickup or isProcessingFeedFriend or isExecutingTPZone then
		return false
	end

	autoBreakTPToken = autoBreakTPToken + 1
	local currentTPToken = autoBreakTPToken
	isExecutingTPZone = true

	cancelActiveTween()

	local success, result = pcall(function()
		local character = LocalPlayer.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") or isExecutingBaseSequenceActive then 
			isExecutingTPZone = false
			return false 
		end
		
		local rootPart = character.HumanoidRootPart
		local currentY = rootPart.Position.Y

		local buildFolder = Workspace:FindFirstChild("Build")
		if not buildFolder then 
			isExecutingTPZone = false
			return false 
		end

		local targetZoneFolder = selectedBreakZoneFolder
		local zoneNumStr = "1"
		
		if targetZoneFolder and targetZoneFolder.Parent then
			local zoneNameFull = targetZoneFolder.Name
			zoneNumStr = zoneNameFull:match("Zone(%d+)") or "1"
		else
			local currentZoneIdx = detectCurrentZoneIndex()
			if currentZoneIdx ~= "SaveZone" then
				zoneNumStr = currentZoneIdx
			end
			targetZoneFolder = buildFolder:FindFirstChild("ZoneBuilds") and buildFolder.ZoneBuilds:FindFirstChild("Zone" .. zoneNumStr)
		end

		local targetHitboxObj = buildFolder:FindFirstChild("ZoneHitboxes") and buildFolder.ZoneHitboxes:FindFirstChild(zoneNumStr)
		if not targetHitboxObj then
			targetHitboxObj = buildFolder.ZoneHitboxes and buildFolder.ZoneHitboxes:FindFirstChild("1")
		end

		if not targetHitboxObj then 
			isExecutingTPZone = false
			return false 
		end

		local targetCFrame = getHitboxCFrame(targetHitboxObj)
		if not targetCFrame then 
			isExecutingTPZone = false
			return false 
		end

		local targetPos = targetCFrame.Position
		local adjustedTargetCFrame = CFrame.new(Vector3.new(targetPos.X, currentY, targetPos.Z), targetPos + targetCFrame.LookVector)

		updateStatusText("Status: TP to Break Zone...", Color3.fromRGB(255, 150, 100))

		local prevAutoBreakState = autoBreakZoneEnabled
		autoBreakZoneEnabled = false

		triggerTreadmillBypass()
		task.wait(0.2)

		if (autoBreakTPToken ~= currentTPToken) or isExecutingBaseSequenceActive then
			isExecutingTPZone = false
			autoBreakZoneEnabled = prevAutoBreakState
			return false
		end

		task.wait(0.2)
		rootPart.CFrame = adjustedTargetCFrame
		task.wait(0.4)

		verifyAndEquipPickaxe()
		task.wait(0.5)

		lastGlobalTPTime = tick()
		autoBreakZoneEnabled = prevAutoBreakState
		isExecutingTPZone = false
		updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
		return true
	end)

	isExecutingTPZone = false
	updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
	return success and result == true
end

runAutoBreakLoop = function()
	if activeBreakThreadRunning then return end
	
	autoBreakExecutionToken = autoBreakExecutionToken + 1
	local currentExecutionToken = autoBreakExecutionToken
	activeBreakThreadRunning = true

	local breakThread = task.spawn(function()
		math.randomseed(tick())

		while screenGui.Parent and (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) and (autoBreakExecutionToken == currentExecutionToken) do
			if isExecutingBaseSequenceActive or (not autoBreakZoneEnabled and not settingsData.AutoBreakEnabled) then
				task.wait(0.2)
				continue
			end

			if hasCloseGems() and (autoGemEnabled or settingsData.AutoGemEnabled) then
				updateStatusText("Status: Menunggu Gem Diambil...", Color3.fromRGB(130, 200, 255))
				activeTargetEgg = nil
				cancelActiveTween()
				task.wait(0.1)
				continue
			end

			if isTaskRunning or isPickingUp or isCollectingGem or isProcessingPickup or isProcessingFeedFriend or isExecutingBaseSequenceActive then
				task.wait(0.05)
				continue
			end

			if autoPickupEnabled and settingsData.AutoPickupEnabled then
				if hasValidAnimalPickups() then
					updateStatusText("Status: Switching to Pickup...", Color3.fromRGB(230, 200, 100))
					checkAndGrabAutoPickupRoutine()
					task.wait(0.05)
					continue
				end
			end

			if feedFriendEnabled and settingsData.FeedFriendEnabled then
				if hasValidAnimalPickups() then
					updateStatusText("Status: Switching to Feed...", Color3.fromRGB(255, 140, 210))
					-- Loop Feed Friend akan berjalan sendiri via thread terpisah atau bisa disisipkan
					task.wait(0.05)
					continue
				end
			end

			local currentZoneIdx = detectCurrentZoneIndex()
			local buildFolder = Workspace:FindFirstChild("Build")
			local targetFolder = selectedBreakZoneFolder

			if (not targetFolder or not targetFolder.Parent) and buildFolder and buildFolder:FindFirstChild("ZoneBuilds") then
				if currentZoneIdx ~= "SaveZone" then
					targetFolder = buildFolder.ZoneBuilds:FindFirstChild("Zone" .. tostring(currentZoneIdx))
				end
			end

			if targetFolder and targetFolder.Parent and (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) and not isExecutingBaseSequenceActive then
				local eggsFolder = targetFolder:FindFirstChild("Eggs")
				
				if not eggsFolder or #eggsFolder:GetChildren() == 0 then
					updateStatusText("Status: Egg Kosong, TP Next Zone...", Color3.fromRGB(255, 150, 100))
					autoBreakZoneEnabled = false
					cancelActiveTween()
					
					executeAutoBreakTPZone()
					
					if settingsData.AutoBreakEnabled then
						autoBreakZoneEnabled = true
					end
					
					task.wait(1.0)
					continue
				end

				if eggsFolder then
					local chosenEgg = nil
					local eggsList = eggsFolder:GetChildren()
					local character = LocalPlayer.Character
					local rootPart = character and character:FindFirstChild("HumanoidRootPart")

					if rootPart and #eggsList > 0 and (tick() - lastGlobalTPTime > 5) then
						local eggPartCheck = eggsList[1] and (eggsList[1]:IsA("BasePart") and eggsList[1] or eggsList[1]:FindFirstChildWhichIsA("BasePart", true))
						if eggPartCheck then
							local distanceToEgg = (rootPart.Position - eggPartCheck.Position).Magnitude
							if distanceToEgg > 1000 and (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) and not isExecutingTPZone and not isTaskRunning and not isExecutingBaseSequenceActive then
								autoBreakZoneEnabled = false
								cancelActiveTween()
								
								executeAutoBreakTPZone()
								
								if settingsData.AutoBreakEnabled then
									autoBreakZoneEnabled = true
								end
								
								task.wait(0.5)
								continue
							end
						end
					end

					if nearestEggEnabled and rootPart then
						local shortestDist = math.huge
						for _, eggModel in ipairs(eggsList) do
							if isExecutingBaseSequenceActive or not (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) or (autoBreakExecutionToken ~= currentExecutionToken) or isTaskRunning then break end
							if eggModel and eggModel.Parent then
								local eggChildObj = eggModel:FindFirstChild("Egg")
								local healthVal = nil
								if eggChildObj then
									healthVal = eggChildObj:GetAttribute("Health") or eggChildObj:GetAttribute("HP")
								end
								healthVal = healthVal or eggModel:GetAttribute("Health") or eggModel:GetAttribute("HP")
								
								if healthVal and tonumber(healthVal) > 0 then
									local eggPartCheck = eggModel:IsA("BasePart") and eggModel or (eggModel:IsA("Model") and (eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart", true)))
									if eggPartCheck then
										local dist = (rootPart.Position - eggPartCheck.Position).Magnitude
										if dist < shortestDist then
											shortestDist = dist
											chosenEgg = eggModel
										end
									end
								end
							end
						end
					else
						for _, eggModel in ipairs(eggsList) do
							if isExecutingBaseSequenceActive or not (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) or (autoBreakExecutionToken ~= currentExecutionToken) or isTaskRunning then break end
							if eggModel and eggModel.Parent then
								local eggChildObj = eggModel:FindFirstChild("Egg")
								local healthVal = nil
								if eggChildObj then
									healthVal = eggChildObj:GetAttribute("Health") or eggChildObj:GetAttribute("HP")
								end
								healthVal = healthVal or eggModel:GetAttribute("Health") or eggModel:GetAttribute("HP")
								
								if healthVal and tonumber(healthVal) > 0 then
									chosenEgg = eggModel
									break
								end
							end
						end

						if not chosenEgg then
							for _, eggModel in ipairs(eggsList) do
								if isExecutingBaseSequenceActive or not (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) or (autoBreakExecutionToken ~= currentExecutionToken) or isTaskRunning then break end
								if eggModel and eggModel.Parent then
									local eggChildObj = eggModel:FindFirstChild("Egg")
									local healthVal = nil
									if eggChildObj then
										healthVal = eggChildObj:GetAttribute("Health") or eggChildObj:GetAttribute("HP")
									end
									healthVal = healthVal or chosenEgg:GetAttribute("Health") or chosenEgg:GetAttribute("HP")
									
									if not healthVal or tonumber(healthVal) > 0 then
										chosenEgg = eggModel
										break
									end
								end
							end
						end
					end

					if isExecutingBaseSequenceActive or not chosenEgg or not (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) or (autoBreakExecutionToken ~= currentExecutionToken) or isTaskRunning then
						activeTargetEgg = nil
						task.wait(0.01)
						continue
					end

					activeTargetEgg = chosenEgg
					cancelActiveTween()

					local eggPart = chosenEgg:IsA("BasePart") and chosenEgg or (chosenEgg:IsA("Model") and (chosenEgg.PrimaryPart or chosenEgg:FindFirstChildWhichIsA("BasePart", true)))

					if eggPart and (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) and (autoBreakExecutionToken == currentExecutionToken) and not isTaskRunning and not isExecutingBaseSequenceActive then
						if isExecutingBaseSequenceActive or not (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) or isTaskRunning then break end

						updateStatusText("Status: Breaking Egg...", Color3.fromRGB(100, 220, 255))
						
						local eggCenterPos = eggPart.Position
						local targetCFrame = eggPart.CFrame

						pcall(function()
							local char = LocalPlayer.Character
							local root = char and char:FindFirstChild("HumanoidRootPart")
							if root and eggPart then
								local currentOffset = root.Position - eggCenterPos
								local currentAngle = math.atan2(currentOffset.Z, currentOffset.X)
								local eggSize = eggPart.Size or Vector3.new(4, 4, 4)
								local radius = math.max(eggSize.X, eggSize.Z) * 0.5 + 2.5
								
								local orbitalPosX = eggCenterPos.X + math.cos(currentAngle) * radius
								local orbitalPosZ = eggCenterPos.Z + math.sin(currentAngle) * radius
								
								local adjustedPos = Vector3.new(orbitalPosX, eggCenterPos.Y, orbitalPosZ)
								targetCFrame = CFrame.new(adjustedPos, eggCenterPos)
							end
						end)

						flatTweenTo(targetCFrame, eggCenterPos)
						verifyAndEquipPickaxe()

						local attackStartTime = tick()
						
						while not isExecutingBaseSequenceActive and (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) and (autoBreakExecutionToken == currentExecutionToken) and not isTaskRunning and not isPickingUp and not isCollectingGem and not isProcessingPickup and not isProcessingFeedFriend do
							if isExecutingBaseSequenceActive or not (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) or isTaskRunning then break end
							
							if hasCloseGems() then break end

							if (autoPickupEnabled and settingsData.AutoPickupEnabled) or (feedFriendEnabled and settingsData.FeedFriendEnabled) then
								if hasValidAnimalPickups() then
									break
								end
							end

							if tick() - attackStartTime > 12 then break end

							local eggChildObj = chosenEgg:FindFirstChild("Egg")
							local healthVal = nil
							if eggChildObj then
								healthVal = eggChildObj:GetAttribute("Health") or eggChildObj:GetAttribute("HP")
							end
							healthVal = healthVal or chosenEgg:GetAttribute("Health") or chosenEgg:GetAttribute("HP")
							
							if healthVal and tonumber(healthVal) <= 0 then
								break
							end

							local char = LocalPlayer.Character
							local root = char and char:FindFirstChild("HumanoidRootPart")

							if root and eggPart and eggPart.Parent and not isTaskRunning and not isExecutingBaseSequenceActive then
								pcall(function()
									local currentPos = root.Position
									local lookAtCenter = Vector3.new(eggCenterPos.X, currentPos.Y, eggCenterPos.Z)
									local currentLook = root.CFrame.LookVector
									local targetLook = (lookAtCenter - currentPos)
									
									if targetLook.Magnitude > 0 then
										targetLook = targetLook.Unit
										if currentLook:Dot(targetLook) < 0.90 then
											root.CFrame = CFrame.new(currentPos, lookAtCenter)
										end
									end
								end)

								if not isWithinRange3D(root.Position, eggCenterPos, 12, 12) then
									if not isPickingUp and not isCollectingGem and not isProcessingPickup and not isProcessingFeedFriend then
										cancelActiveTween()
										task.wait(0.01)
										flatTweenTo(targetCFrame, eggCenterPos)
										verifyAndEquipPickaxe()
									end
								end
							end

							verifyAndEquipPickaxe()
							task.wait(0.01)
						end
						
						activeTargetEgg = nil
						cancelActiveTween()
						task.wait(0.01)
					end
				else
					activeTargetEgg = nil
					task.wait(0.02)
				end
			else
				activeTargetEgg = nil
				task.wait(0.02)
			end
			task.wait(0.002)
		end
		activeTargetEgg = nil
		activeBreakThreadRunning = false
		updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
	end)
	trackCoroutine(breakThread)
end

autoPickupToggleButton.MouseButton1Click:Connect(function()
	if toggleCooldown then return end
	toggleCooldown = true

	autoPickupEnabled = not autoPickupEnabled
	settingsData.AutoPickupEnabled = autoPickupEnabled
	
	if autoPickupEnabled then
		exclusiveToggle("Pickup")
	end
	saveSettings()

	isPickingUp = false
	isTaskRunning = false
	isProcessingPickup = false

	if autoPickupEnabled then
		autoPickupToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		autoPickupToggleButton.Text = "ON"
		autoPickupToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		local autoPickupToggleStroke = autoPickupToggleButton:FindFirstChildOfClass("UIStroke")
		if autoPickupToggleStroke then autoPickupToggleStroke.Color = Color3.fromRGB(80, 190, 120) end
		
		runAutoPickupLoop()
	else
		autoPickupToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		autoPickupToggleButton.Text = "OFF"
		autoPickupToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		local autoPickupToggleStroke = autoPickupToggleButton:FindFirstChildOfClass("UIStroke")
		if autoPickupToggleStroke then autoPickupToggleStroke.Color = Color3.fromRGB(80, 90, 110) end
		
		activeAutoPickupLoopRunning = false
		cancelActiveTween()
	end
	
	task.wait(0.02)
	toggleCooldown = false
end)

feedToggleButton.MouseButton1Click:Connect(function()
	if toggleCooldown then return end
	toggleCooldown = true

	feedFriendEnabled = not feedFriendEnabled
	settingsData.FeedFriendEnabled = feedFriendEnabled
	
	if feedFriendEnabled then
		exclusiveToggle("Feed")
	end
	saveSettings()

	isPickingUp = false
	isTaskRunning = false
	isProcessingFeedFriend = false

	if feedFriendEnabled then
		feedToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		feedToggleButton.Text = "ON"
		feedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		if feedToggleStroke then feedToggleStroke.Color = Color3.fromRGB(80, 190, 120) end
		
		runFeedFriendLoop()
	else
		feedToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		feedToggleButton.Text = "OFF"
		feedToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		if feedToggleStroke then feedToggleStroke.Color = Color3.fromRGB(80, 90, 110) end
		
		activeFeedFriendLoopRunning = false
		cancelActiveTween()
	end
	
	task.wait(0.02)
	toggleCooldown = false
end)

autoGemToggleButton.MouseButton1Click:Connect(function()
	if toggleCooldown then return end
	toggleCooldown = true

	autoGemEnabled = not autoGemEnabled
	settingsData.AutoGemEnabled = autoGemEnabled
	saveSettings()

	isCollectingGem = false

	if autoGemEnabled then
		autoGemToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		autoGemToggleButton.Text = "ON"
		autoGemToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		if autoGemToggleStroke then autoGemToggleStroke.Color = Color3.fromRGB(80, 190, 120) end
		
		runAutoGemLoop()
	else
		autoGemToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		autoGemToggleButton.Text = "OFF"
		autoGemToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		if autoGemToggleStroke then autoGemToggleStroke.Color = Color3.fromRGB(80, 90, 110) end
		
		activeAutoGemLoopRunning = false
		cancelActiveTween()
	end
	
	task.wait(0.02)
	toggleCooldown = false
end)

antiRagdollToggleButton.MouseButton1Click:Connect(function()
	if toggleCooldown then return end
	toggleCooldown = true

	antiRagdollEnabled = not antiRagdollEnabled
	settingsData.AntiRagdollEnabled = antiRagdollEnabled
	saveSettings()

	if antiRagdollEnabled then
		antiRagdollToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		antiRagdollToggleButton.Text = "ON"
		antiRagdollToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		if antiRagdollToggleStroke then antiRagdollToggleStroke.Color = Color3.fromRGB(80, 190, 120) end
		setupAntiRagdoll()
	else
		antiRagdollToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		antiRagdollToggleButton.Text = "OFF"
		antiRagdollToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		if antiRagdollToggleStroke then antiRagdollToggleStroke.Color = Color3.fromRGB(80, 90, 110) end
		
		if antiRagdollConnection then
			antiRagdollConnection:Disconnect()
			antiRagdollConnection = nil
		end
	end
	
	task.wait(0.02)
	toggleCooldown = false
end)

if antiRagdollEnabled then
	setupAntiRagdoll()
end

autoBreakZoneToggleButton.MouseButton1Click:Connect(function()
	if toggleCooldown then return end
	toggleCooldown = true

	autoBreakZoneEnabled = not autoBreakZoneEnabled
	settingsData.AutoBreakEnabled = autoBreakZoneEnabled
	saveSettings()

	local wasGemActive = autoGemEnabled

	autoBreakExecutionToken = autoBreakExecutionToken + 1
	autoBreakTPToken = autoBreakTPToken + 1
	activeBreakThreadRunning = false
	isExecutingTPZone = false
	isProcessingPickup = false
	isProcessingFeedFriend = false

	if autoBreakZoneEnabled then
		autoBreakZoneToggleButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		autoBreakZoneToggleButton.Text = "ON"
		autoBreakZoneToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		local autoBreakZoneToggleStroke = autoBreakZoneToggleButton:FindFirstChildOfClass("UIStroke")
		if autoBreakZoneToggleStroke then autoBreakZoneToggleStroke.Color = Color3.fromRGB(80, 190, 120) end

		task.spawn(function()
			runAutoBreakLoop()
		end)

		if wasGemActive and not activeAutoGemLoopRunning then
			autoGemEnabled = true
			task.spawn(function()
				runAutoGemLoop()
			end)
		end
	else
		autoBreakZoneToggleButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		autoBreakZoneToggleButton.Text = "OFF"
		autoBreakZoneToggleButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		local autoBreakZoneToggleStroke = autoBreakZoneToggleButton:FindFirstChildOfClass("UIStroke")
		if autoBreakZoneToggleStroke then autoBreakZoneToggleStroke.Color = Color3.fromRGB(80, 90, 110) end
		updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
	end
	
	task.wait(0.02)
	toggleCooldown = false
end)

task.spawn(function()
	task.wait(2.5)

	if autoBreakZoneEnabled then
		task.spawn(runAutoBreakLoop)
	end

	if autoPickupEnabled then
		task.spawn(runAutoPickupLoop)
	end

	if feedFriendEnabled then
		task.spawn(runFeedFriendLoop)
	end

	if autoGemEnabled then
		task.spawn(runAutoGemLoop)
	end
end)

trackCoroutine(task.spawn(function()
	local lastPos = Vector3.new(0, 0, 0)
	local stuckTimer = 0
	
	while screenGui.Parent do
		task.wait(1.0)
		
		pcall(function()
			local character = LocalPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			
			if not rootPart or not humanoid or humanoid.Health <= 0 then
				stuckTimer = 0
				return
			end
			
			local isBreaking = activeTargetEgg ~= nil or (statusIndicatorText and statusIndicatorText.Text:lower():match("breaking"))
			local isIdle = statusIndicatorText and statusIndicatorText.Text:lower():match("idle")
			local isBusy = isTaskRunning or isPickingUp or isCollectingGem or isProcessingPickup or isProcessingFeedFriend or isExecutingBaseSequenceActive or isExecutingTPZone
			
			if isBreaking or isIdle or isBusy then
				stuckTimer = 0
				lastPos = rootPart.Position
				return
			end
			
			local currentPos = rootPart.Position
			local distanceMoved = (currentPos - lastPos).Magnitude
			
			if distanceMoved < 2.0 then
				stuckTimer = stuckTimer + 1
				if stuckTimer >= 10 then
					updateStatusText("Status: Stuck Detected! Using Treadmill...", Color3.fromRGB(255, 80, 80))
					stuckTimer = 0
					
					triggerTreadmillBypass()
					task.wait(1.0)
				end
			else
				stuckTimer = 0
				lastPos = currentPos
			end
		end)
	end
end))

trackCoroutine(task.spawn(function()
	local idleCounter = 0
	while screenGui.Parent do
		task.wait(1.0)
		
		local isCurrentlyIdle = false
		pcall(function()
			if statusIndicatorText and statusIndicatorText.Text:lower():match("idle") then
				if not isTaskRunning and not isPickingUp and not isCollectingGem and not isProcessingPickup and not isProcessingFeedFriend and not activeTweenRunning and not isExecutingBaseSequenceActive then
					isCurrentlyIdle = true
				end
			end
		end)

		if isCurrentlyIdle then
			idleCounter = idleCounter + 1
			if idleCounter >= 3 then
				local shouldResumeBreak = (autoBreakZoneEnabled or settingsData.AutoBreakEnabled) and not activeBreakThreadRunning
				local shouldResumePickup = (autoPickupEnabled or settingsData.AutoPickupEnabled) and not activeAutoPickupLoopRunning
				local shouldResumeFeed = (feedFriendEnabled or settingsData.FeedFriendEnabled) and not activeFeedFriendLoopRunning
				local shouldResumeGem = (autoGemEnabled or settingsData.AutoGemEnabled) and not activeAutoGemLoopRunning

				if (shouldResumeBreak or shouldResumePickup or shouldResumeFeed or shouldResumeGem) and not isExecutingBaseSequenceActive then
					updateStatusText("Status: Resuming Loops...", Color3.fromRGB(255, 200, 100))
					
					isTaskRunning = false
					isPickingUp = false
					isCollectingGem = false
					isProcessingPickup = false
					isProcessingFeedFriend = false

					if shouldResumeBreak then
						autoBreakZoneEnabled = true
						settingsData.AutoBreakEnabled = true
						task.spawn(function()
							runAutoBreakLoop()
						end)
					end

					if shouldResumePickup then
						autoPickupEnabled = true
						settingsData.AutoPickupEnabled = true
						task.spawn(function()
							runAutoPickupLoop()
						end)
					end

					if shouldResumeFeed then
						feedFriendEnabled = true
						settingsData.FeedFriendEnabled = true
						task.spawn(function()
							runFeedFriendLoop()
						end)
					end

					if shouldResumeGem then
						autoGemEnabled = true
						settingsData.AutoGemEnabled = true
						task.spawn(function()
							runAutoGemLoop()
						end)
					end
					
					task.wait(0.3)
					updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
				end
				idleCounter = 0
			end
		else
			idleCounter = 0
		end
	end
end))

tpZoneButton.MouseButton1Click:Connect(function()
	if isTaskRunning or isExecutingBaseSequenceActive then return end
	isTaskRunning = true

	task.spawn(function()
		updateStatusText("Status: TP to Selected Zone...", Color3.fromRGB(255, 150, 100))
		
		local character = LocalPlayer.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then 
			isTaskRunning = false
			updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
			return 
		end
		
		local rootPart = character.HumanoidRootPart
		local currentY = rootPart.Position.Y

		triggerTreadmillBypass()
		task.wait(0.2)

		local targetHitboxObj = selectedZoneHitboxObj
		local buildFolder = Workspace:FindFirstChild("Build")
		if not targetHitboxObj and buildFolder and buildFolder:FindFirstChild("ZoneHitboxes") then
			targetHitboxObj = buildFolder.ZoneHitboxes:FindFirstChild("1")
		end

		if not targetHitboxObj then
			isTaskRunning = false
			updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
			return
		end

		local targetCFrame = getHitboxCFrame(targetHitboxObj)
		if not targetCFrame then
			isTaskRunning = false
			updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
			return
		end

		local targetPos = targetCFrame.Position
		local adjustedTargetCFrame = CFrame.new(Vector3.new(targetPos.X, currentY, targetPos.Z), targetPos + targetCFrame.LookVector)

		rootPart.CFrame = adjustedTargetCFrame
		task.wait(0.3)

		isTaskRunning = false
		updateStatusText("Status: Idle", Color3.fromRGB(100, 220, 255))
	end)
end)

local statusIndicatorFrame = Instance.new("Frame", mainFrame)
statusIndicatorFrame.Name = "StatusIndicatorFrame"
statusIndicatorFrame.Size = UDim2.new(0, 160, 0, 22)
statusIndicatorFrame.Position = UDim2.new(0, 204, 0, 32)
statusIndicatorFrame.BackgroundColor3 = Color3.fromRGB(40, 46, 58)
statusIndicatorFrame.BackgroundTransparency = 0.3
statusIndicatorFrame.BorderSizePixel = 0
Instance.new("UICorner", statusIndicatorFrame).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", statusIndicatorFrame).Color = Color3.fromRGB(80, 100, 130)

statusIndicatorText = Instance.new("TextLabel", statusIndicatorFrame)
statusIndicatorText.Name = "StatusIndicatorText"
statusIndicatorText.Size = UDim2.new(1, -8, 1, 0)
statusIndicatorText.Position = UDim2.new(0, 4, 0, 0)
statusIndicatorText.BackgroundTransparency = 1
statusIndicatorText.Font = Enum.Font.GothamBold
statusIndicatorText.Text = "Status: Idle"
statusIndicatorText.TextColor3 = Color3.fromRGB(100, 220, 255)
statusIndicatorText.TextSize = 10
statusIndicatorText.TextXAlignment = Enum.TextXAlignment.Left

local listHeader = Instance.new("TextLabel", mainFrame)
listHeader.Name = "ListHeader"
listHeader.Size = UDim2.new(0, 160, 0, 16)
listHeader.Position = UDim2.new(0, 204, 0, 58)
listHeader.BackgroundTransparency = 1
listHeader.Font = Enum.Font.GothamBold
listHeader.Text = "Animal Pickups (Cash/s):"
listHeader.TextColor3 = Color3.fromRGB(180, 205, 235)
listHeader.TextSize = 11
listHeader.TextXAlignment = Enum.TextXAlignment.Left

local scrollingFrame = Instance.new("ScrollingFrame", mainFrame)
scrollingFrame.Name = "AnimalScrollingFrame"
scrollingFrame.Size = UDim2.new(0, 160, 0, 284)
scrollingFrame.Position = UDim2.new(0, 204, 0, 76)
scrollingFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
scrollingFrame.BackgroundTransparency = 0.5
scrollingFrame.BorderSizePixel = 0
scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollingFrame.ScrollBarThickness = 3
Instance.new("UICorner", scrollingFrame).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", scrollingFrame).Color = Color3.fromRGB(75, 85, 105)

local uiListLayout = Instance.new("UIListLayout", scrollingFrame)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 3)

local resizeButton = Instance.new("TextButton", mainFrame)
resizeButton.Name = "ResizeButton"
resizeButton.Size = UDim2.new(0, 14, 0, 14)
resizeButton.Position = UDim2.new(1, -14, 1, -14)
resizeButton.BackgroundTransparency = 1
resizeButton.Font = Enum.Font.GothamBold
resizeButton.Text = "◢"
resizeButton.TextColor3 = Color3.fromRGB(150, 165, 190)
resizeButton.TextSize = 11

local resizing = false
local dragStartSize, dragStartPos

resizeButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		dragStartSize = mainFrame.AbsoluteSize
		dragStartPos = input.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartPos
		local newWidth = math.clamp(dragStartSize.X + delta.X, 375, 620)
		local newHeight = math.clamp(dragStartSize.Y + delta.Y, 350, 540)
		
		mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
		local innerRightWidth = newWidth - 214
		scrollingFrame.Size = UDim2.new(0, innerRightWidth, 0, newHeight - 88)
		listHeader.Size = UDim2.new(0, innerRightWidth, 0, 16)
		statusIndicatorFrame.Size = UDim2.new(0, innerRightWidth, 0, 22)
		leftScrollingFrame.Size = UDim2.new(0, 192, 1, -34)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = false
	end
end)

local function updateAnimalList()
	pcall(function()
		for _, child in ipairs(scrollingFrame:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
		end

		local animalPickups = Workspace:FindFirstChild("AnimalPickups")
		if not animalPickups then 
			local lbl = Instance.new("TextLabel", scrollingFrame)
			lbl.Size = UDim2.new(1, 0, 0, 22)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.Gotham
			lbl.Text = "  Menunggu AnimalPickups..."
			lbl.TextColor3 = Color3.fromRGB(230, 180, 100)
			lbl.TextSize = 11
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			return 
		end

		local animalData = {}
		for _, item in ipairs(animalPickups:GetChildren()) do
			local cashText = ""
			local overhead = item:FindFirstChild("AnimalOverhead", true) or item
			local cashFolder = overhead:FindFirstChild("CashPerSecond")
			if cashFolder then
				for _, lbl in ipairs(cashFolder:GetDescendants()) do
					if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
						cashText = lbl.Text
						break
					end
				end
			end
			if cashText ~= "" then
				if not cashText:lower():match("/s") and not cashText:lower():match("second") then
					cashText = cashText .. "/s"
				end
				table.insert(animalData, { name = item.Name, cashText = cashText, numericVal = parseValueToNumber(cashText) })
			end
		end

		table.sort(animalData, function(a, b) return a.numericVal > b.numericVal end)

		if #animalData == 0 then
			local lbl = Instance.new("TextLabel", scrollingFrame)
			lbl.Size = UDim2.new(1, 0, 0, 22)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.Gotham
			lbl.Text = "  Belum ada item terbaca."
			lbl.TextColor3 = Color3.fromRGB(160, 175, 200)
			lbl.TextSize = 11
			lbl.TextXAlignment = Enum.TextXAlignment.Left
		else
			for _, data in ipairs(animalData) do
				local rowFrame = Instance.new("Frame", scrollingFrame)
				rowFrame.Size = UDim2.new(1, -6, 0, 22)
				rowFrame.BackgroundColor3 = Color3.fromRGB(45, 52, 65)
				rowFrame.BackgroundTransparency = 0.4
				rowFrame.BorderSizePixel = 0
				Instance.new("UICorner", rowFrame).CornerRadius = UDim.new(0, 5)

				local nameLabel = Instance.new("TextLabel", rowFrame)
				nameLabel.Size = UDim2.new(0.58, 0, 1, 0)
				nameLabel.Position = UDim2.new(0, 6, 0, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.Text = data.name
				nameLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
				nameLabel.TextSize = 11
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left

				local cashLabel = Instance.new("TextLabel", rowFrame)
				cashLabel.Size = UDim2.new(0.42, -8, 1, 0)
				cashLabel.Position = UDim2.new(0.58, 0, 0, 0)
				cashLabel.BackgroundTransparency = 1
				cashLabel.Font = Enum.Font.GothamBold
				cashLabel.Text = data.cashText
				cashLabel.TextColor3 = Color3.fromRGB(80, 220, 150)
				cashLabel.TextSize = 11
				cashLabel.TextXAlignment = Enum.TextXAlignment.Right
			end
		end
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 6)
	end)
end

local animalPickupsFolder = Workspace:FindFirstChild("AnimalPickups")
if animalPickupsFolder then
	trackConnection(animalPickupsFolder.ChildAdded:Connect(updateAnimalList))
	trackConnection(animalPickupsFolder.ChildRemoved:Connect(updateAnimalList))
	updateAnimalList()
end

trackCoroutine(task.spawn(function()
	while screenGui.Parent do
		task.wait(1.0)
		if mainFrame.Visible then updateAnimalList() end
	end
end))

autoTpButton.MouseButton1Click:Connect(function()
	autoTpEnabled = not autoTpEnabled
	settingsData.AutoTpEnabled = autoTpEnabled
	
	if autoTpEnabled then
		exclusiveToggle("AutoTP")
	end
	saveSettings()

	if autoTpEnabled then
		autoTpButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
		autoTpButton.Text = "Auto: ON"
		autoTpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		autoTpStroke.Color = Color3.fromRGB(80, 190, 120)
	else
		autoTpButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		autoTpButton.Text = "Auto"
		autoTpButton.TextColor3 = Color3.fromRGB(170, 180, 200)
		autoTpStroke.Color = Color3.fromRGB(80, 90, 110)
		rememberedObjectText = nil
		activeTargetEgg = nil
		isTaskRunning = false
	end
end)

if autoTpEnabled then
	autoTpButton.BackgroundColor3 = Color3.fromRGB(50, 130, 85)
	autoTpButton.Text = "Auto: ON"
	autoTpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoTpStroke.Color = Color3.fromRGB(80, 190, 120)
end

setupAutoPickupListenerFixed = function(prompt)
	if prompt:IsA("ProximityPrompt") then
		trackConnection(prompt.Triggered:Connect(function(playerWhoTriggered)
			if playerWhoTriggered == LocalPlayer and autoTpEnabled then
				if isTaskRunning or isExecutingBaseSequenceActive then return end
				if prompt.ObjectText and prompt.ObjectText ~= "" then rememberedObjectText = prompt.ObjectText end
				local waitStartTime = tick()
				while prompt and prompt.Parent and tick() - waitStartTime < 5 do task.wait(0.05) end
				task.wait(0.1)
				
				executeBaseSequence()
				rememberedObjectText = nil
				activeTargetEgg = nil
			end
		end))
	end
end

applyPatches()

trackCoroutine(task.spawn(function()
	while screenGui.Parent do
		task.wait(0.1)
		pcall(function()
			if autoTpEnabled and rememberedObjectText and not isTaskRunning and not isExecutingBaseSequenceActive then
				local char = LocalPlayer.Character
				local rootPart = char and char:FindFirstChild("HumanoidRootPart")
				if not rootPart then return end
				local rootPos = rootPart.Position
				for _, anchor in ipairs(getActivePromptAnchors()) do
					for _, desc in ipairs(anchor:GetDescendants()) do
						if desc:IsA("ProximityPrompt") and desc.ObjectText == rememberedObjectText then
							desc.MaxActivationDistance = detectionRange
							local parent = desc.Parent
							local part = parent and (parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart", true))
							if part and isWithinRange3D(rootPos, part.Position, detectionRange, 15) then
								firePrompt(desc)
							end
						end
					end
				end
			end
		end)
	end
end))

-- ================= ESP RENDER LOOP =================
trackCoroutine(task.spawn(function()
	while screenGui.Parent do
		task.wait(0.2)
		pcall(function()
			local targetItems = {}
			
			local animalPickups = Workspace:FindFirstChild("AnimalPickups")
			if animalPickups then
				for _, item in ipairs(animalPickups:GetChildren()) do
					table.insert(targetItems, { item = item, isCarried = false })
				end
			end
			
			local carriedAnimals = Workspace:FindFirstChild("CarriedAnimals")
			if carriedAnimals then
				for _, item in ipairs(carriedAnimals:GetChildren()) do
					table.insert(targetItems, { item = item, isCarried = true })
				end
			end
			
			for _, entry in ipairs(targetItems) do
				local item = entry.item
				local isCarried = entry.isCarried
				
				local animalNameAttr = item:GetAttribute("AnimalName") or item:GetAttribute("animalname")
				local displayName = (type(animalNameAttr) == "string" and animalNameAttr ~= "") and animalNameAttr or item.Name
				
				local cashVal = 0
				local cashTextValue = ""
				local timerTextStr = ""
				local rarityTextStr = ""
				
				local overhead = item:FindFirstChild("AnimalOverhead", true) or item:FindFirstChild("Overhead") or item
				
				local cashFolder = overhead:FindFirstChild("CashPerSecond") or overhead:FindFirstChild("Cash")
				if cashFolder then
					for _, lbl in ipairs(cashFolder:GetDescendants()) do
						if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
							cashTextValue = lbl.Text
							cashVal = parseValueToNumber(lbl.Text)
							break
						end
					end
				end
				
				if cashVal == 0 then
					local directCash = item:GetAttribute("CashPerSecond") or item:GetAttribute("Cash") or overhead:GetAttribute("CashPerSecond")
					if directCash then
						cashVal = tonumber(directCash) or parseValueToNumber(tostring(directCash))
						cashTextValue = tostring(directCash)
					end
				end
				
				local rarityFolder = overhead:FindFirstChild("Rarity")
				if rarityFolder then
					for _, lbl in ipairs(rarityFolder:GetDescendants()) do
						if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
							rarityTextStr = lbl.Text
							break
						end
					end
				end
				if rarityTextStr == "" then
					rarityTextStr = tostring(item:GetAttribute("Rarity") or item:GetAttribute("rarity") or "")
				end
				
				local timerFolder = overhead:FindFirstChild("SelfDestructTimer") or overhead:FindFirstChild("Timer")
				if timerFolder then
					for _, lbl in ipairs(timerFolder:GetDescendants()) do
						if lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "" then
							timerTextStr = lbl.Text
							break
						end
					end
				end

				local mainPart = nil
				if item:IsA("BasePart") then
					mainPart = item
				elseif item:IsA("Model") then
					mainPart = item.PrimaryPart 
						or item:FindFirstChild("HumanoidRootPart")
						or item:FindFirstChild("Torso")
						or item:FindFirstChild("Head")
						or item:FindFirstChildWhichIsA("BasePart", true)
				end
				
				if mainPart then
					local billboard = mainPart:FindFirstChild("CustomESPBillboard")
					local highlight = item:FindFirstChild("CustomESPHighlight")
					
					if espEnabled and (cashVal >= minEspValue or isCarried) then
						if not highlight and item:IsA("Model") then
							highlight = Instance.new("Highlight", item)
							highlight.Name = "CustomESPHighlight"
							highlight.Adornee = item
							highlight.FillTransparency = 1
							highlight.OutlineColor = isCarried and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
							highlight.OutlineTransparency = 0
						end
						
						if not billboard then
							billboard = Instance.new("BillboardGui", mainPart)
							billboard.Name = "CustomESPBillboard"
							billboard.Size = UDim2.new(0, 200, 0, 45)
							billboard.StudsOffset = Vector3.new(0, 3.5, 0)
							billboard.AlwaysOnTop = true
							billboard.MaxDistance = math.huge
							billboard.Adornee = mainPart

							local bgFrame = Instance.new("Frame", billboard)
							bgFrame.Name = "BGFrame"
							bgFrame.Size = UDim2.new(0, 0, 0, 0)
							bgFrame.AutomaticSize = Enum.AutomaticSize.XY
							bgFrame.AnchorPoint = Vector2.new(0.5, 0.5)
							bgFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
							bgFrame.BackgroundColor3 = isCarried and Color3.fromRGB(220, 50, 50) or Color3.fromRGB(255, 255, 255)
							bgFrame.BackgroundTransparency = 0.25
							bgFrame.BorderSizePixel = 0
							
							local corner = Instance.new("UICorner", bgFrame)
							corner.CornerRadius = UDim.new(0, 5)

							local bgStroke = Instance.new("UIStroke", bgFrame)
							bgStroke.Name = "BGStroke"
							bgStroke.Color = Color3.fromRGB(0, 0, 0)
							bgStroke.Thickness = 1.5
							bgStroke.Transparency = 0

							local padding = Instance.new("UIPadding", bgFrame)
							padding.PaddingTop = UDim.new(0, 3)
							padding.PaddingBottom = UDim.new(0, 3)
							padding.PaddingLeft = UDim.new(0, 6)
							padding.PaddingRight = UDim.new(0, 6)

							local listLayout = Instance.new("UIListLayout", bgFrame)
							listLayout.SortOrder = Enum.SortOrder.LayoutOrder
							listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
							listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
							listLayout.Padding = UDim.new(0, -1)

							local topRowLayout = Instance.new("Frame", bgFrame)
							topRowLayout.Name = "TopRowLayout"
							topRowLayout.Size = UDim2.new(0, 0, 0, 11)
							topRowLayout.AutomaticSize = Enum.AutomaticSize.XY
							topRowLayout.BackgroundTransparency = 1
							
							local topList = Instance.new("UIListLayout", topRowLayout)
							topList.FillDirection = Enum.FillDirection.Horizontal
							topList.SortOrder = Enum.SortOrder.LayoutOrder
							topList.Padding = UDim.new(0, 2)

							local function createSubText(name, size, color)
								local lbl = Instance.new("TextLabel", topRowLayout)
								lbl.Name = name
								lbl.Size = UDim2.new(0, 0, 0, size + 2)
								lbl.AutomaticSize = Enum.AutomaticSize.X
								lbl.BackgroundTransparency = 1
								lbl.Font = Enum.Font.GothamBold
								lbl.TextSize = size
								lbl.TextColor3 = color
								lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
								lbl.TextStrokeTransparency = 0
								return lbl
							end

							createSubText("TimerText", 9, Color3.fromRGB(255, 90, 90))
							createSubText("Sep1Text", 9, Color3.fromRGB(200, 200, 200))
							createSubText("RarityText", 9, Color3.fromRGB(255, 220, 100))
							createSubText("Sep2Text", 9, Color3.fromRGB(200, 200, 200))
							createSubText("CashText", 9, Color3.fromRGB(50, 205, 50))

							local nLbl = Instance.new("TextLabel", bgFrame)
							nLbl.Name = "NameText"
							nLbl.Size = UDim2.new(0, 0, 0, 12)
							nLbl.AutomaticSize = Enum.AutomaticSize.X
							nLbl.BackgroundTransparency = 1
							nLbl.Font = Enum.Font.GothamBold
							nLbl.TextSize = 10
							nLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
							nLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
							nLbl.TextStrokeTransparency = 0
						else
							local bgFrame = billboard:FindFirstChild("BGFrame")
							if bgFrame then
								bgFrame.BackgroundColor3 = isCarried and Color3.fromRGB(220, 50, 50) or Color3.fromRGB(255, 255, 255)
							end
						end

						local tTest = billboard:FindFirstChild("TimerText", true)
						local s1Text = billboard:FindFirstChild("Sep1Text", true)
						local rText = billboard:FindFirstChild("RarityText", true)
						local s2Text = billboard:FindFirstChild("Sep2Text", true)
						local cText = billboard:FindFirstChild("CashText", true)
						local nText = billboard:FindFirstChild("NameText", true)
						
						if tTest then tTest.Text = timerTextStr ~= "" and timerTextStr or "" end
						if s1Text then s1Text.Text = timerTextStr ~= "" and rarityTextStr ~= "" and " | " or "" end
						if rText then rText.Text = rarityTextStr ~= "" and rarityTextStr or "" end
						if s2Text then s2Text.Text = rarityTextStr ~= "" and " | " or "" end
						if cText then cText.Text = cashTextValue ~= "" and cashTextValue or (tostring(cashVal) .. "/s") end
						if nText then nText.Text = displayName end
					else
						if billboard then billboard:Destroy() end
						if highlight then highlight:Destroy() end
					end
				end
			end
		end)
	end
end))

trackConnection(RunService.RenderStepped:Connect(function()
	if not speedEnabled or activeTweenRunning or isExecutingBaseSequenceActive then return end
	local char = LocalPlayer.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if humanoid and rootPart and humanoid.Health > 0 then
		local moveDir = humanoid.MoveDirection
		if moveDir.Magnitude > 0 then
			local currentVel = rootPart.AssemblyLinearVelocity
			local targetVel = moveDir * customSpeed
			rootPart.AssemblyLinearVelocity = Vector3.new(targetVel.X, currentVel.Y, targetVel.Z)
		end
	end
end))
