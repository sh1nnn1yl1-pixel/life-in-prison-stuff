-- Single-script optimized for Roblox Executors (Absolute Screen-Edge Fix)
local CoreGui = game:GetService("CoreGui")

-- 1. Anti-Stacking Cleanup
local existingGui = CoreGui:FindFirstChild("ExecutorScreenDecalGui")
if existingGui then
    existingGui:Destroy()
end

-- 2. Create the protected container inside CoreGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExecutorScreenDecalGui"
screenGui.ResetOnSpawn = false

-- ABSOLUTE EDGE FIX: This forces the UI to ignore Roblox's top-bar restriction boundaries
screenGui.IgnoreGuiInset = true
screenGui.Parent = CoreGui

-- Generic configuration function to avoid repeating code
local function configureFlagBar(name, anchorPoint, position)
    local imageLabel = Instance.new("ImageLabel")
    imageLabel.Name = name
    imageLabel.Image = "rbxassetid://964998527"
    
    -- Setup sizing and positions based on parameters
    imageLabel.AnchorPoint = anchorPoint
    imageLabel.Position = position
    imageLabel.Size = UDim2.new(1, 0, 0, 55) -- 55 pixels tall
    
    -- Formatting, tiling, and 80% transparency
    imageLabel.BackgroundTransparency = 1
    imageLabel.ScaleType = Enum.ScaleType.Tile
    imageLabel.TileSize = UDim2.new(0, 80, 0, 55)
    imageLabel.ImageTransparency = 0.8
    
    imageLabel.Parent = screenGui
end

-- 3. Create the Bottom Bar (Anchored at bottom-left, positioned at bottom-left)
configureFlagBar(
    "BottomDecal", 
    Vector2.new(0, 1), 
    UDim2.new(0, 0, 1, 0)
)

-- 4. Create the Top Bar (Anchored at top-left, positioned at top-left)
configureFlagBar(
    "TopDecal", 
    Vector2.new(0, 0), 
    UDim2.new(0, 0, 0, 0)
)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- SELF-CLEANING MECHANISM:
local oldGui = playerGui:FindFirstChild("MinecraftGuideGui")
if oldGui then oldGui:Destroy() end

-- Create the Main GUI Container
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MinecraftGuideGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true 
screenGui.Parent = playerGui

-- =========================================================================
-- THE CENTER STAR CROSSHAIR & FOV CIRCLE
-- =========================================================================
local imageLabel = Instance.new("ImageLabel")
imageLabel.Name = "CenterImage"
imageLabel.Parent = screenGui
imageLabel.Image = "rbxassetid://87315646023960"
imageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
imageLabel.Position = UDim2.new(0.5, 0, 0.5, 0) 
imageLabel.Size = UDim2.new(0, 50, 0, 55)
imageLabel.BackgroundTransparency = 1
imageLabel.Active = false
imageLabel.Selectable = false

-- White Aimbot FOV Circle UI Element
local fovCircleUI = Instance.new("Frame")
fovCircleUI.Name = "LarpFovCircle"
fovCircleUI.Parent = screenGui
fovCircleUI.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircleUI.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircleUI.Size = UDim2.new(0, 250, 0, 250) 
fovCircleUI.BackgroundTransparency = 1
fovCircleUI.Visible = false

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0.5, 0) 
uiCorner.Parent = fovCircleUI

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 255, 255) 
uiStroke.Thickness = 1
uiStroke.Parent = fovCircleUI

-- =========================================================================
-- THE TOP-RIGHT MENU BUTTONS
-- =========================================================================
local container = Instance.new("Frame")
container.Name = "ButtonContainer"
container.Size = UDim2.new(0, 100, 0, 180) 
container.AnchorPoint = Vector2.new(1, 0)
container.Position = UDim2.new(1, -10, 0, 5) 
container.BackgroundTransparency = 1
container.Parent = screenGui

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Parent = container
uiListLayout.Padding = UDim.new(0, 4)
uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

local buttonNames = {"Larp fly [Q]", "Larp [H]", "Larp Tree [B/Z]", "Team check [K]", "Wallcheck [J]", "Fps boost [P]"}
local menuButtons = {}

for index, name in ipairs(buttonNames) do
	local button = Instance.new("TextButton")
	button.Name = "GuideBtn_" .. index
	button.Size = UDim2.new(0, 85, 0, 22)             
	button.BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 1
	button.BorderColor3 = Color3.fromRGB(0, 0, 0)
	button.Text = name
	button.Font = Enum.Font.Arcade
	button.TextSize = 11
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.4
	button.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	button.Parent = container
	menuButtons[index] = button
end
-- =========================================================================
-- SYSTEM UTILITIES & GLOBAL CHEAT STATES
-- =========================================================================
local flying = false
local flySpeed = 85
local camera = workspace.CurrentCamera
local flyStabilizer = nil

local larpEspActive = false
local activeHighlights = {}
local activeTracers = {}

local larpTreeActive = false
local lockingOn = false
local currentLockedTarget = nil 
local maxFovRadius = 125

local teamCheckActive = false
local wallCheckActive = false
local fpsBoostActive = false

local animationBackup = Instance.new("Folder")
local originalMaterials = {}
local originalColors = {}

local function getRandomPastelColor()
	return Color3.fromHSV(math.random(), 0.4, 0.95)
end

local function getTorso(character)
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function isVisibleBehindWalls(targetPart)
	if not wallCheckActive then return true end
	local character = localPlayer.Character
	if not character then return false end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character, targetPart.Parent}
	raycastParams.IgnoreWater = true

	local origin = camera.CFrame.Position
	local direction = targetPart.Position - origin
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)

	return raycastResult == nil
end
-- =========================================================================
-- ENGINE MODULE TOGGLES (Fixed Table Indexing Keys)
-- =========================================================================
local function toggleFly()
	local character = localPlayer.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	flying = not flying
	if flying then
		humanoid.PlatformStand = true
		menuButtons[1].BackgroundColor3 = Color3.fromRGB(100, 30, 150) 
		flyStabilizer = Instance.new("BodyVelocity")
		flyStabilizer.Name = "LarpFlyStabilizer"
		flyStabilizer.Velocity = Vector3.new(0, 0, 0)
		flyStabilizer.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		flyStabilizer.Parent = rootPart
	else
		humanoid.PlatformStand = false
		menuButtons[1].BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
		if flyStabilizer then flyStabilizer:Destroy() flyStabilizer = nil end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
end

local function applyHighlight(player)
	if player == localPlayer then return end
	local function onCharacterAdded(character)
		if not larpEspActive then return end
		if activeHighlights[player] then activeHighlights[player]:Destroy() end
		if activeTracers[player] then activeTracers[player]:Destroy() end
		
		local assignedColor = getRandomPastelColor()
		local highlight = Instance.new("Highlight")
		highlight.Name = "LarpEspBox"
		highlight.FillColor = assignedColor
		highlight.FillTransparency = 0.65               
		highlight.OutlineColor = assignedColor    
		highlight.OutlineTransparency = 0.1
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop 
		highlight.Adornee = character
		highlight.Parent = screenGui
		activeHighlights[player] = highlight

		local tracerPart = Instance.new("Part")
		tracerPart.Name = "LarpTracerPart"
		tracerPart.Transparency = 1
		tracerPart.Anchored = true
		tracerPart.CanCollide = false
		tracerPart.Parent = workspace

		local attachment = Instance.new("Attachment")
		attachment.Parent = tracerPart
		
		local beam = Instance.new("Beam")
		beam.Name = "LarpTracerBeam"
		beam.Texture = "" 
		beam.Color = ColorSequence.new(assignedColor)
		beam.Width0 = 0.01 
		beam.Width1 = 0.01 
		beam.FaceCamera = true
		beam.Attachment1 = attachment
		beam.Enabled = false
		beam.Parent = tracerPart
		activeTracers[player] = tracerPart
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then onCharacterAdded(player.Character) end
end

local function removeHighlight(player)
	if activeHighlights[player] then activeHighlights[player]:Destroy() activeHighlights[player] = nil end
	if activeTracers[player] then activeTracers[player]:Destroy() activeTracers[player] = nil end
end

local function toggleLarpEsp()
	larpEspActive = not larpEspActive
	if larpEspActive then
		menuButtons[2].BackgroundColor3 = Color3.fromRGB(100, 30, 150) 
		for _, player in ipairs(Players:GetPlayers()) do applyHighlight(player) end
	else
		menuButtons[2].BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
		for player, _ in pairs(activeHighlights) do removeHighlight(player) end
	end
end

local function toggleLarpTree()
	larpTreeActive = not larpTreeActive
	if larpTreeActive then
		menuButtons[3].BackgroundColor3 = Color3.fromRGB(100, 30, 150) 
		fovCircleUI.Visible = true
	else
		menuButtons[3].BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
		fovCircleUI.Visible = false
		lockingOn = false
		currentLockedTarget = nil
	end
end

local function toggleTeamCheck()
	teamCheckActive = not teamCheckActive
	menuButtons[4].BackgroundColor3 = teamCheckActive and Color3.fromRGB(100, 30, 150) or Color3.fromRGB(15, 15, 15)
	if currentLockedTarget and teamCheckActive and currentLockedTarget.Team == localPlayer.Team then
		currentLockedTarget = nil
	end
end

local function toggleWallCheck()
	wallCheckActive = not wallCheckActive
	menuButtons[5].BackgroundColor3 = wallCheckActive and Color3.fromRGB(100, 30, 150) or Color3.fromRGB(15, 15, 15)
end

local function applyFpsBoostMechanics(character)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if humanoid then
		for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do track:Stop() end
		local animScript = character:FindFirstChild("Animate")
		if animScript then
			animationBackup.Parent = animScript.Parent
			animScript.Parent = nil
		end
	end

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			originalMaterials[desc] = desc.Material
			originalColors[desc] = desc.Color
			desc.Material = Enum.Material.SmoothPlastic
			desc.Color = Color3.fromRGB(255, 255, 255)
		elseif desc:IsA("Decal") or desc:IsA("Texture") or desc:IsA("Clothing") or desc:IsA("ShirtGraphic") or desc:IsA("Accessory") then
			originalMaterials[desc] = desc.Parent
			desc.Parent = nil
		end
	end
end

local function toggleFpsBoost()
	local character = localPlayer.Character
	fpsBoostActive = not fpsBoostActive
	menuButtons[6].BackgroundColor3 = fpsBoostActive and Color3.fromRGB(100, 30, 150) or Color3.fromRGB(15, 15, 15)

	if fpsBoostActive then
		if character then applyFpsBoostMechanics(character) end
	else
		if animationBackup.Parent then
			animationBackup.Parent.Parent = character
			animationBackup.Parent = nil
		end
		for desc, mat in pairs(originalMaterials) do
			if desc:IsA("BasePart") and desc.Parent then
				desc.Material = mat
				desc.Color = originalColors[desc]
			elseif typeof(mat) == "Instance" then
				desc.Parent = mat
			end
		end
		table.clear(originalMaterials)
		table.clear(originalColors)
	end
end

localPlayer.CharacterAdded:Connect(function(newCharacter)
	if fpsBoostActive then
		task.wait(0.1) 
		applyFpsBoostMechanics(newCharacter)
	end
end)

local function getClosestTargetToCrosshair()
	local closestPlayer = nil
	local shortestDistance = maxFovRadius 
	local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			if teamCheckActive and player.Team == localPlayer.Team then continue end
			local head = player.Character:FindFirstChild("Head")
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			
			if head and humanoid and humanoid.Health > 0 and isVisibleBehindWalls(head) then
				local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
				if onScreen then
					local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
					local distanceToCenter = (screenPos2D - screenCenter).Magnitude
					if distanceToCenter < shortestDistance then
						shortestDistance = distanceToCenter
						closestPlayer = player
					end
				end
			end
		end
	end
	return closestPlayer
end

local function isTargetValid(player)
	if not player or not player.Character or player == localPlayer then return false end
	if teamCheckActive and player.Team == localPlayer.Team then return false end
	local head = player.Character:FindFirstChild("Head")
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	return head and humanoid and humanoid.Health > 0 and isVisibleBehindWalls(head)
end
-- =========================================================================
-- SYSTEM RUNTIME LOOPS
-- =========================================================================
RunService.RenderStepped:Connect(function(deltaTime)
	local character = localPlayer.Character
	if character and flying then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
			end
			local directionVector = Vector3.new(0, 0, 0)
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then directionVector = directionVector + camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then directionVector = directionVector - camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then directionVector = directionVector + camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then directionVector = directionVector - camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then directionVector = directionVector + Vector3.new(0, 1, 0) end

			if directionVector.Magnitude > 0 then
				rootPart.CFrame = CFrame.new(rootPart.Position + (directionVector.Unit * (flySpeed * deltaTime))) * camera.CFrame.Rotation
			else
				rootPart.CFrame = CFrame.new(rootPart.Position) * camera.CFrame.Rotation
			end
		end
	end

	if larpTreeActive and lockingOn then
		if not currentLockedTarget or not isTargetValid(currentLockedTarget) then
			currentLockedTarget = getClosestTargetToCrosshair()
		end
		if currentLockedTarget then
			local targetHead = currentLockedTarget.Character.Head
			camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetHead.Position)
		end
	else
		currentLockedTarget = nil
	end

	if larpEspActive and character then
		local myTorso = getTorso(character)
		for player, tracerPart in pairs(activeTracers) do
			if teamCheckActive and player.Team == localPlayer.Team then
				tracerPart.LarpTracerBeam.Enabled = false
				if activeHighlights[player] then activeHighlights[player].Enabled = false end
				continue
			end
			local targetChar = player.Character
			local targetTorso = targetChar and getTorso(targetChar)
			local beam = tracerPart:FindFirstChild("LarpTracerBeam")
			local attachment = tracerPart:FindFirstChild("Attachment")
			local highlight = activeHighlights[player]
			
			if myTorso and targetTorso and beam and attachment then
				local cameraLook = camera.CFrame.LookVector
				local toTarget = (targetTorso.Position - camera.CFrame.Position).Unit
				local isBehind = cameraLook:Dot(toTarget) <= 0

				if isBehind then
					beam.Enabled = false
					if highlight then highlight.Enabled = false end
				else
					attachment.WorldPosition = targetTorso.Position
					beam.Attachment0 = myTorso:FindFirstChildOfClass("Attachment") or myTorso:WaitForChild("RootAttachment", 1)
					beam.Enabled = true
					if highlight then highlight.Enabled = true end
				end
			else
				if beam then beam.Enabled = false end
				if highlight then highlight.Enabled = false end
			end
		end
	end
end)

Players.PlayerAdded:Connect(applyHighlight)
Players.PlayerRemoving:Connect(removeHighlight)

-- =========================================================================
-- ACTIVATION LISTENERS WITH EXPLICIT ACCURATE ARRAY KEY INDEXES
-- =========================================================================
menuButtons[1].MouseButton1Click:Connect(toggleFly)
menuButtons[2].MouseButton1Click:Connect(toggleLarpEsp)
menuButtons[3].MouseButton1Click:Connect(toggleLarpTree)
menuButtons[4].MouseButton1Click:Connect(toggleTeamCheck)
menuButtons[5].MouseButton1Click:Connect(toggleWallCheck)
menuButtons[6].MouseButton1Click:Connect(toggleFpsBoost)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		toggleFly()
	elseif input.KeyCode == Enum.KeyCode.H then
		toggleLarpEsp()
	elseif input.KeyCode == Enum.KeyCode.B then
		toggleLarpTree()
	elseif input.KeyCode == Enum.KeyCode.K then
		toggleTeamCheck()
	elseif input.KeyCode == Enum.KeyCode.J then
		toggleWallCheck()
	elseif input.KeyCode == Enum.KeyCode.P then
		toggleFpsBoost()
	elseif input.KeyCode == Enum.KeyCode.Z then
		lockingOn = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Z then
		lockingOn = false
	end
end)

-- Single-script optimized for Roblox Executors (Field of View Modifier)
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")

-- Define the target FOV
local TARGET_FOV = 120

-- 1. Disconnect any older loops if the script is re-executed
if _G.FOVLoopConnection then
    _G.FOVLoopConnection:Disconnect()
    _G.FOVLoopConnection = nil
end

-- 2. Apply instantly
camera.FieldOfView = TARGET_FOV

-- 3. Force-lock the FOV on every frame to prevent game-script overwrites
_G.FOVLoopConnection = RunService.RenderStepped:Connect(function()
    if camera then
        camera.FieldOfView = TARGET_FOV
    else
        -- Re-assign camera if the player resets or game changes it
        camera = Workspace.CurrentCamera
    end
end)

-----------------------------------------------------------------------------
-----------------------JEWISH GUN TEXTURE------------------------------------
-----------------------------------------------------------------------------

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- The asset ID provided by the user converted to Roblox format
local CUSTOM_TEXTURE_ID = "rbxassetid://964998527"

-- Applied to every visual element found inside a tool
local function applyCustomTexture(tool)
	if not tool:IsA("Tool") then return end
	
	for _, child in ipairs(tool:GetDescendants()) do
		
		-- 1. If it is a modern MeshPart, remove its custom mesh visual styling and force your texture
		if child:IsA("MeshPart") then
			child.TextureID = CUSTOM_TEXTURE_ID
			child.Color = Color3.fromRGB(255, 255, 255) -- Keeps texture colors true
			child.Material = Enum.Material.SmoothPlastic
			
		-- 2. If it is an old-school SpecialMesh, apply the texture ID directly to it
		elseif child:IsA("SpecialMesh") then
			child.TextureId = CUSTOM_TEXTURE_ID
			
		-- 3. Replace any pre-existing individual Decals/Textures with your custom one
		elseif child:IsA("Decal") or child:IsA("Texture") then
			child.Texture = CUSTOM_TEXTURE_ID
			
		-- 4. If it is a basic structural geometric block without a pre-built texture space
		elseif child:IsA("BasePart") then
			child.Color = Color3.fromRGB(255, 255, 255)
			child.Material = Enum.Material.SmoothPlastic
			
			-- Wrap the texture completely around flat surfaces so it shows up perfectly
			-- checks if textures are already placed on the faces to avoid duplicates
			local faces = {Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back}
			for _, face in ipairs(faces) do
				local textureName = "CustomWrap_" .. face.Name
				if not child:FindFirstChild(textureName) then
					local tex = Instance.new("Texture")
					tex.Name = textureName
					tex.Texture = CUSTOM_TEXTURE_ID
					tex.Face = face
					tex.StudsPerTileU = 2 -- Adjust these values if you want the image to stretch or tile differently
					tex.StudsPerTileV = 2
					tex.Parent = child
				end
			end
		end
	end
end

-- Monitor inventory (Backpack) changes
local function setupInventoryMonitor(backpack)
	if not backpack then return end
	
	-- Scan tools currently resting in the inventory
	for _, item in ipairs(backpack:GetChildren()) do
		applyCustomTexture(item)
	end
	
	-- Catch new tools added to inventory mid-game
	backpack.ChildAdded:Connect(function(child)
		task.wait(0.1) -- Small delay to ensure all parts inside the tool have loaded properly
		applyCustomTexture(child)
	end)
end

-- Monitor equipped items (Tools currently being held by character)
local function setupCharacterMonitor(character)
	for _, item in ipairs(character:GetChildren()) do
		applyCustomTexture(item)
	end
	
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			applyCustomTexture(child)
		end
	end)
end

-- Initialize listeners for the Local Player
task.spawn(function()
	local backpack = LocalPlayer:WaitForChild("Backpack", 10)
	setupInventoryMonitor(backpack)
end)

if LocalPlayer.Character then
	setupCharacterMonitor(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
	setupCharacterMonitor(newCharacter)
	local backpack = LocalPlayer:WaitForChild("Backpack", 10)
	setupInventoryMonitor(backpack)
end)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Miku Asset Constants (Scaled to 0.15)
local MIKU_MESH = "rbxassetid://7749007933"
local MIKU_TEXTURE = "rbxassetid://7749008046"
local TARGET_SCALE = Vector3.new(0.15, 0.15, 0.15)

local function morphToolVisuals(item)
	if not item:IsA("Tool") then return end

	-- Find the real handle that the server requires
	local realHandle = item:WaitForChild("Handle", 5)
	if not realHandle or not realHandle:IsA("BasePart") then return end
	
	-- Skip if we already hid it and added Miku
	if realHandle:FindFirstChild("MikuAttached") then return end

	-- 1. Make the real server handle completely invisible
	realHandle.Transparency = 1
	
	-- Hide any existing meshes or textures inside the real handle
	for _, child in ipairs(realHandle:GetChildren()) do
		if child:IsA("DataModelMesh") or child:IsA("Texture") then
			if child:IsA("SpecialMesh") then
				child.Scale = Vector3.new(0, 0, 0) -- Shrink old mesh out of sight
			end
		end
	end

	-- 2. Create a fake cosmetic part that ONLY your client sees
	local fakeVisual = Instance.new("Part")
	fakeVisual.Name = "MikuVisualPart"
	fakeVisual.Size = Vector3.new(0.15, 0.15, 0.15) -- Matches part size to mesh scale
	fakeVisual.Transparency = 0
	fakeVisual.CanCollide = false
	fakeVisual.Massless = true
	
	-- Put the Miku mesh inside the fake part
	local specialMesh = Instance.new("SpecialMesh")
	specialMesh.MeshType = Enum.MeshType.FileMesh
	specialMesh.MeshId = MIKU_MESH
	specialMesh.TextureId = MIKU_TEXTURE
	specialMesh.Scale = TARGET_SCALE
	specialMesh.Parent = fakeVisual

	-- 3. Weld the fake Miku part directly onto the invisible real handle
	local weld = Instance.new("Weld")
	weld.Part0 = realHandle
	weld.Part1 = fakeVisual
	weld.C0 = CFrame.new(0, 0, 0) 
	weld.Parent = fakeVisual

	-- Place the fake part inside the tool
	fakeVisual.Parent = item

	-- Tag the real handle so the script doesn't loop infinitely
	local tag = Instance.new("BoolValue")
	tag.Name = "MikuAttached"
	tag.Parent = realHandle
end

local function processTool(item)
	if not item:IsA("Tool") then return end
	task.spawn(function()
		morphToolVisuals(item)
	end)
end

-- Track Inventory (Backpack)
local backpack = localPlayer:WaitForChild("Backpack")
for _, item in ipairs(backpack:GetChildren()) do
	processTool(item)
end
backpack.ChildAdded:Connect(processTool)

-- Track Equipped (Character)
local function trackCharacter(character)
	for _, item in ipairs(character:GetChildren()) do
		processTool(item)
	end
	character.ChildAdded:Connect(processTool)
end

if localPlayer.Character then
	trackCharacter(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(trackCharacter)
