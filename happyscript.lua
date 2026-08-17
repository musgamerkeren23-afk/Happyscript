--[[
    HAPPY BEST SCRIPT FE
    Brand: H4ll0 W0rld
    Type: Universal LocalScript (FE / broadcast-style horror effect)
    Jalanin di executor apapun, di map/game manapun.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== CONFIG ====================
local CONFIG = {
    FogColor = Color3.fromRGB(5, 5, 8),
    FogEndDefault = 500,
    FogEndScary = 40,
    ExploreTimeMin = 6,
    ExploreTimeMax = 14,
    StillTimeToTrigger = 1.5,      -- berapa lama diem sebelum monster muncul
    MonsterSpawnDistance = 60,     -- jarak spawn di depan pandangan player
    MonsterHeight = 20,
    MonsterWalkSpeed = 6,          -- speed pas belum ketauan (creep mode)
    MonsterChaseSpeed = 34,        -- speed pas ngejar (lebih cepat dari player)
    PlayerCatchDistance = 5,
    ChaseCheckInterval = 0.1,
}

-- ==================== UTIL ====================
local function getCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    return char, hrp, hum
end

local function systemMessage(text)
    local ok = pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = text,
            Color = Color3.fromRGB(200, 30, 30),
            Font = Enum.Font.SourceSansBold,
            FontSize = Enum.FontSize.Size24,
        })
    end)
    if not ok then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "???",
                Text = text,
                Duration = 5,
            })
        end)
    end
end

local function tweenFog(endDist, time)
    local goal = { FogEnd = endDist }
    local tween = TweenService:Create(Lighting, TweenInfo.new(time, Enum.EasingStyle.Sine), goal)
    tween:Play()
    return tween
end

-- ==================== ATMOSPHERE SETUP ====================
local function setupAtmosphere()
    Lighting.FogColor = CONFIG.FogColor
    Lighting.FogStart = 0
    tweenFog(CONFIG.FogEndScary, 4)

    -- sedikit gelapin ambient biar makin creepy
    pcall(function()
        Lighting.Brightness = math.min(Lighting.Brightness, 0.5)
        Lighting.ClockTime = 0 -- tengah malam
        Lighting.Ambient = Color3.fromRGB(10, 10, 15)
        Lighting.OutdoorAmbient = Color3.fromRGB(10, 10, 15)
    end)

    systemMessage("Unknown entity has joined")
end

-- ==================== MONSTER BUILDER ====================
local function buildMonster()
    local model = Instance.new("Model")
    model.Name = "???"

    local torso = Instance.new("Part")
    torso.Name = "HumanoidRootPart"
    torso.Size = Vector3.new(4, CONFIG.MonsterHeight, 3)
    torso.Anchored = false
    torso.CanCollide = false
    torso.Material = Enum.Material.Neon
    torso.Color = Color3.fromRGB(0, 0, 0)
    torso.Transparency = 0.05
    torso.Parent = model

    -- sedikit "tekstur" gelap biar gak keliatan neon glowing biasa
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Head
    mesh.Scale = Vector3.new(3.6, 5.5, 2.6)
    mesh.Parent = torso

    -- mata merah nyala
    local function makeEye(offsetX)
        local eye = Instance.new("Part")
        eye.Name = "Eye"
        eye.Shape = Enum.PartType.Ball
        eye.Size = Vector3.new(0.6, 0.6, 0.6)
        eye.Material = Enum.Material.Neon
        eye.Color = Color3.fromRGB(255, 0, 0)
        eye.CanCollide = false
        eye.Anchored = false
        eye.Parent = model

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 0, 0)
        light.Range = 12
        light.Brightness = 3
        light.Parent = eye

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = torso
        weld.Part1 = eye
        weld.Parent = eye

        eye.CFrame = torso.CFrame * CFrame.new(offsetX, CONFIG.MonsterHeight * 0.32, -1.3)
        return eye
    end
    makeEye(-0.6)
    makeEye(0.6)

    local hum = Instance.new("Humanoid")
    hum.WalkSpeed = CONFIG.MonsterWalkSpeed
    hum.MaxHealth = math.huge
    hum.Health = math.huge
    hum.Parent = model

    model.PrimaryPart = torso
    model.Parent = workspace

    return model, torso, hum
end

-- ==================== STATE ====================
local monster, monsterRoot, monsterHum = nil, nil, nil
local monsterActive = false
local chaseTriggered = false
local monsterConn = nil

local function despawnMonster()
    monsterActive = false
    chaseTriggered = false
    if monsterConn then
        monsterConn:Disconnect()
        monsterConn = nil
    end
    if monster then
        monster:Destroy()
        monster = nil
    end
end

-- Kick sequence pas ketangkep
local function catchPlayer()
    local char, hrp = getCharacter()

    local gui = Instance.new("ScreenGui")
    gui.Name = "FE_CaughtGui"
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = gui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.2, 0)
    label.Position = UDim2.new(0, 0, 0.4, 0)
    label.BackgroundTransparency = 1
    label.Text = "IT GOT YOU"
    label.TextColor3 = Color3.fromRGB(180, 0, 0)
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.TextTransparency = 1
    label.Parent = frame

    TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()

    despawnMonster()

    task.wait(1.6)
    pcall(function()
        LocalPlayer:Kick("You were caught. || H4ll0 W0rld")
    end)
end

-- ==================== TRIGGER / CHASE LOGIC ====================
local function startChaseLoop(char, hrp, hum)
    monsterConn = RunService.Heartbeat:Connect(function(dt)
        if not monsterActive or not monster or not monsterRoot or not monsterRoot.Parent then
            return
        end
        if not hrp or not hrp.Parent then
            return
        end

        local dist = (monsterRoot.Position - hrp.Position).Magnitude

        -- lihat arah kamera player buat nentuin "lagi ngeliat monster apa nggak"
        local toMonster = (monsterRoot.Position - Camera.CFrame.Position).Unit
        local lookDot = Camera.CFrame.LookVector:Dot(toMonster)
        local isLookingAtMonster = lookDot > 0.55 and dist < 90

        if isLookingAtMonster and not chaseTriggered then
            chaseTriggered = true
            monsterHum.WalkSpeed = CONFIG.MonsterChaseSpeed
            systemMessage("It sees you.")
        end

        if chaseTriggered then
            monster:PivotTo(CFrame.lookAt(monsterRoot.Position, hrp.Position) + Vector3.new(0, 0, 0))
            monsterHum:MoveTo(hrp.Position)
        else
            -- creep mode: monster diem / gerak pelan ke arah player
            monsterHum:MoveTo(hrp.Position)
        end

        if dist <= CONFIG.PlayerCatchDistance then
            monsterActive = false
            task.spawn(catchPlayer)
        end
    end)
end

local function spawnMonsterInFront(char, hrp)
    local lookDir = Camera.CFrame.LookVector
    local spawnPos = hrp.Position + (lookDir * CONFIG.MonsterSpawnDistance) + Vector3.new(0, CONFIG.MonsterHeight / 2, 0)

    -- raycast biar nempel ground kalau ada
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { char }
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(spawnPos, Vector3.new(0, -300, 0), rayParams)
    if result then
        spawnPos = result.Position + Vector3.new(0, CONFIG.MonsterHeight / 2, 0)
    end

    local m, root, hum = buildMonster()
    m:PivotTo(CFrame.lookAt(spawnPos, hrp.Position))

    monster, monsterRoot, monsterHum = m, root, hum
    monsterActive = true
    chaseTriggered = false

    startChaseLoop(char, hrp, hum)
end

-- ==================== MAIN LOOP: nunggu player diem & liat kosong ====================
local function watchForStillness(char, hrp, hum)
    local stillTimer = 0
    local lastPos = hrp.Position

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not hrp or not hrp.Parent then
            if conn then conn:Disconnect() end
            return
        end
        if monsterActive then
            return -- udah ada monster aktif, gak usah spawn lagi
        end

        local moved = (hrp.Position - lastPos).Magnitude
        lastPos = hrp.Position

        if moved < 0.05 then
            stillTimer += dt
        else
            stillTimer = 0
        end

        if stillTimer >= CONFIG.StillTimeToTrigger then
            stillTimer = -math.huge -- biar gak nge-trigger berkali-kali
            spawnMonsterInFront(char, hrp)
        end
    end)
    return conn
end

-- ==================== INIT ====================
local function main()
    local char, hrp, hum = getCharacter()

    setupAtmosphere()

    task.wait(math.random(CONFIG.ExploreTimeMin, CONFIG.ExploreTimeMax))

    watchForStillness(char, hrp, hum)

    -- respawn handling biar tetep jalan kalau karakter reset
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        despawnMonster()
        task.wait(1)
        local nhrp = newChar:WaitForChild("HumanoidRootPart")
        local nhum = newChar:WaitForChild("Humanoid")
        watchForStillness(newChar, nhrp, nhum)
    end)
end

main()
