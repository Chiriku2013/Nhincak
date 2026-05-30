-- [[ 1. HOOK TASK.DELAY (EXCLUDE GUNS) - GIỮ NGUYÊN ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local old
old = hookfunction(task.delay, function(t, f, ...)
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        local isGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun")
        if isGun and old then return old(t, f, ...) end
    end
    if t > 0.1 and old then return old(0, f, ...) end
    if old then return old(t, f, ...) end
end)

pcall(function()
    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
end)

task.spawn(function()
    while task.wait(0.5) do
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            if not char:FindFirstChild("HasBuso") then
                pcall(function()
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
                end)
            end
        end
    end
end)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")

local RANGE = 1000       -- Phạm vi Fast Attack
local AIM_RANGE = 350    -- Phạm vi Auto Aim Skills/Đạn
local AllTargets = {}

-- [[ HỆ THỐNG VALIDATOR SÚNG & SPECIAL METHODS ]]
local SpecialShoots = {
    ["Skull Guitar"] = "TAP", 
    ["Bazooka"] = "Position", 
    ["Cannon"] = "Position", 
    ["Dragonstorm"] = "Overheat"
}
local GunValidator = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Validator2")

local ShootFunction = nil
pcall(function()
    ShootFunction = getupvalue(require(ReplicatedStorage.Controllers.CombatController).Attack, 9)
end)

local function GetValidator2()
    if not ShootFunction then return nil end
    local v1 = getupvalue(ShootFunction, 15)
    local v2 = getupvalue(ShootFunction, 13)
    local v3 = getupvalue(ShootFunction, 16)
    local v4 = getupvalue(ShootFunction, 17)
    local v5 = getupvalue(ShootFunction, 14)
    local v6 = getupvalue(ShootFunction, 12)
    local v7 = getupvalue(ShootFunction, 18)
    
    local v8 = v6 * v2
    local v9 = (v5 * v2 + v6 * v1) % v3
    v9 = (v9 * v3 + v8) % v4
    v5 = math.floor(v9 / v3)
    v6 = v9 - v5 * v3
    v7 = v7 + 1
    
    setupvalue(ShootFunction, 14, v5)
    setupvalue(ShootFunction, 12, v6)
    setupvalue(ShootFunction, 18, v7)
    
    return math.floor(v9 / v4 * 16777215), v7
end

-- [[ FIX TRÁNH CACHE CONTROLLER TỐI ƯU BỘ NHỚ ]]
local CachedFramework = nil
local LastCheckedChar = nil
local LastEquippedTool = nil 

local function GetFramework()
    local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
    
    if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
        CachedFramework = nil
        LastCheckedChar = nil
        LastEquippedTool = nil
        return nil
    end
    
    local currentTool = char:FindFirstChildOfClass("Tool")
    
    if LastCheckedChar ~= char or LastEquippedTool ~= currentTool then
        CachedFramework = nil
        LastCheckedChar = char
        LastEquippedTool = currentTool
    end
    
    if CachedFramework then return CachedFramework end
    
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "activeController") then
            CachedFramework = v.activeController
            return CachedFramework
        end
    end
end

-- [[ BỘ FIX KẸT FRAMEWORK CHỐNG LAG PING/FPS ]]
local function FastAttack()
    pcall(function()
        local ac = GetFramework()
        if ac and ac.equipped then
            ac.hitboxMagnitude = 60 
            ac.timeToNextAttack = 0
            
            -- Không hard-reset 'attacking' mù quáng, chỉ reset activity nếu an toàn
            if ac.currentActivity == "Attacking" or ac.currentActivity == "Reloading" or ac.currentActivity == "GunAttacking" then
                ac.currentActivity = "" 
            end

            -- Chống khựng Animation khi lag FPS
            if ac.animator and ac.animator.anims and ac.animator.anims.basic then
                for _, v in pairs(ac.animator.anims.basic) do
                    if v.IsPlaying and v.Speed < 100 then
                        v:AdjustSpeed(math.huge) 
                    end
                end
            end
        end
    end)
end

-- [1. QUÉT MỤC TIÊU ĐỒNG BỘ CHUẨN VỊ TRÍ]
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local targets = {} 
        
        if root then
            local folders = {workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Characters")}
            for _, folder in pairs(folders) do
                if folder then
                    for _, v in ipairs(folder:GetChildren()) do
                        if v:IsA("Model") and v ~= char and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            local tPart = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("UpperTorso")
                            if tPart and (tPart.Position - root.Position).Magnitude < RANGE then
                                table.insert(targets, v)
                            end
                        end
                    end
                end
            end
            
            table.sort(targets, function(a, b)
                local aPart = a:FindFirstChild("HumanoidRootPart") or a:FindFirstChild("UpperTorso")
                local bPart = b:FindFirstChild("HumanoidRootPart") or b:FindFirstChild("UpperTorso")
                if aPart and bPart then
                    return (aPart.Position - root.Position).Magnitude < (bPart.Position - root.Position).Magnitude
                end
                return false
            end)
        end
        AllTargets = targets 
    end
end)

-- [[ HÀM TÌM MỤC TIÊU CHO AUTO AIM (GIỚI HẠN 350M) ]]
local function GetAimTarget()
    local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    for _, v in ipairs(AllTargets) do
        if v and v.Parent and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            local tPart = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("UpperTorso")
            if tPart and (tPart.Position - root.Position).Magnitude <= AIM_RANGE then
                return tPart
            end
        end
    end
    return nil
end

-- [[ BỘ HOOK TỐI THƯỢNG: EXTREME BYPASS + GLOBAL AUTO AIM CỰC CHUẨN ]]
local oldNM = nil
if not getgenv().Hooked then
    oldNM = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        -- Chỉ can thiệp nếu gói tin xuất phát từ Game (không chặn gói tin từ Script này gửi)
        if not checkcaller() then
            if method == "FireServer" or method == "InvokeServer" then
                
                -- 1. EXTREME BYPASS CỦA BẠN (GIỮ NGUYÊN)
                if self.Name == "RE/RegisterAttack" then
                    return oldNM(self, -math.huge)
                end

                -- 2. HỆ THỐNG AUTO AIM 350M (Đánh chặn mọi kỹ năng ném ra tọa độ)
                -- Loại trừ CommF_ để không vô tình kẹt mua bán/quest
                if self.Name ~= "CommF_" and typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                    local aimPart = GetAimTarget()
                    if aimPart then
                        local modified = false
                        for i, arg in ipairs(args) do
                            if typeof(arg) == "Vector3" then
                                args[i] = aimPart.Position
                                modified = true
                            elseif typeof(arg) == "CFrame" then
                                args[i] = aimPart.CFrame
                                modified = true
                            end
                        end
                        if modified then
                            return oldNM(self, unpack(args))
                        end
                    end
                end
            end
        end
        return oldNM(self, ...)
    end)
    getgenv().Hooked = true
end

-- [ ĐỢI REMOTE LOAD XONG MỚI CHẠY ]
local Net, regHit, regAttack, shootGun
repeat
    task.wait(0.5)
    pcall(function()
        Net = ReplicatedStorage:FindFirstChild("Modules"):FindFirstChild("Net")
        regHit = Net:FindFirstChild("RE/RegisterHit")
        regAttack = Net:FindFirstChild("RE/RegisterAttack")
        shootGun = Net:FindFirstChild("RE/ShootGunEvent")
    end)
until Net and regHit and regAttack

-- Cập nhật State liên tục cho Tool
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function()
                tool:SetAttribute("AttackCooldown", 0)
                tool:SetAttribute("LastAttack", 0)
                tool:SetAttribute("State", 0) 
            end)
        end
    end
end)

-- [3. LOGIC TẤN CÔNG LAN LUỒNG X3 - ĐÃ TÁCH BIỆT MELEE VÀ BLOX FRUIT]
local lastAttackTick = 0
local ATTACK_DELAY = 0.12 

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait() 
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if not regHit or not regAttack or not tool or not root or #AllTargets == 0 then continue end

        if tick() - lastAttackTick < ATTACK_DELAY then continue end
        lastAttackTick = tick()

        FastAttack() 

        local toolName = tool.Name:lower()
        local isGuitar = toolName:find("guitar")
        local toolTip = tool.ToolTip
        local isAnyGun = (tool:GetAttribute("WeaponType") == "Gun") or (toolTip == "Gun") or isGuitar
        local isFruit = (toolTip == "Blox Fruit")

        local unbanID_base = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15)

        for i = 1, 3 do 
            task.spawn(function() 
                local unbanID = unbanID_base .. i 
                pcall(function()
                    if not isAnyGun then
                        local fullHitList = {}
                        for j = 1, math.min(#AllTargets, 7) do
                            local monster = AllTargets[j]
                            if monster and monster.Parent and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                                local part = monster:FindFirstChild("UpperTorso") or monster:FindFirstChild("Head")
                                if part then table.insert(fullHitList, {monster, part}) end
                            end
                        end
                        
                        if #fullHitList > 0 then
                            regHit:FireServer(fullHitList[1][2], fullHitList, nil, nil, unbanID)
                            
                            -- CHỈ LUỒNG ĐẦU MỚI GỬI LỆNH ĐỂ TRÁNH QUÁ TẢI (KẸT LAG PING)
                            if i == 1 then
                                -- TÁCH RIÊNG LOGIC THEO ĐÚNG Ý BẠN
                                if isFruit then
                                    -- Logic riêng rẽ chỉ dành cho Blox Fruit
                                    local leftClick = tool:FindFirstChild("LeftClickRemote", true)
                                    if leftClick then
                                        local lookVector = (fullHitList[1][2].Position - root.Position).Unit
                                        if lookVector ~= lookVector then lookVector = Vector3.new(0, 1, 0) end 
                                        leftClick:FireServer(lookVector, 1, unbanID_base)
                                    end
                                else
                                    -- Logic dành cho Melee / Sword thuần túy (Không dính LeftClickRemote)
                                    regAttack:FireServer(-math.huge)
                                end
                            end
                        end
                    else
                        -- LOGIC SÚNG & GUITAR
                        local gunHitList = {}
                        local shootParts = {}
                        for j = 1, math.min(#AllTargets, 7) do
                            local monster = AllTargets[j]
                            if monster and monster.Parent and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                                local tPart = monster:FindFirstChild("Head") or monster:FindFirstChild("HumanoidRootPart")
                                if tPart then
                                    table.insert(gunHitList, {monster, tPart})
                                    table.insert(shootParts, tPart)
                                end
                            end
                        end

                        if #gunHitList > 0 then
                            local targetPos = gunHitList[1][2].Position
                            regHit:FireServer(gunHitList[1][2], gunHitList, nil, nil, unbanID)
                            
                            if i == 1 then
                                if not isGuitar and shootGun then
                                    shootGun:FireServer(targetPos, shootParts, unbanID_base)
                                end
                                if isGuitar then
                                    -- Đã fix truyền đúng targetPos thực tế của quái
                                    local remote = tool:FindFirstChild("RemoteEvent", true)
                                    if remote then remote:FireServer("TAP", targetPos, unbanID_base) end
                                end
                            end
                        end
                    end
                end)
            end)
            task.wait(0.01) 
        end
    end
end)
