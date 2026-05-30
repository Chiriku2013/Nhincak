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

local RANGE = 1000 
local GUN_AIM_RANGE = 1000 
local AllTargets = {}

-- [[ HỆ THỐNG DỮ LIỆU SÚNG ]]
local SpecialFireModes = {
    ["Skull Guitar"] = "TAP", 
    ["Bazooka"] = "Position", 
    ["Cannon"] = "Position", 
    ["Dragonstorm"] = "Overheat"
}
local BulletsPerTarget = {
    ["Dual Flintlock"] = 2
}
local GunHeatStats = {
    ["Dragonstorm"] = {MaxOverheat = 3, Cooldown = 0, TotalOverheat = 0, Distance = 350, Shooting = false}
}
local GunValidator = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Validator2")

local ShootFunction = nil
pcall(function()
    ShootFunction = getupvalue(require(ReplicatedStorage.Controllers.CombatController).Attack, 9)
end)

-- [[ HÀM VALIDATOR ]]
local function GrabGunSecurityData()
    if not ShootFunction then return nil end
    local up1 = getupvalue(ShootFunction, 15)
    local up2 = getupvalue(ShootFunction, 13)
    local up3 = getupvalue(ShootFunction, 16)
    local up4 = getupvalue(ShootFunction, 17)
    local up5 = getupvalue(ShootFunction, 14)
    local up6 = getupvalue(ShootFunction, 12)
    local up7 = getupvalue(ShootFunction, 18)
    
    local up8 = up6 * up2
    local up9 = (up5 * up2 + up6 * up1) % up3
    up9 = (up9 * up3 + up8) % up4
    up5 = math.floor(up9 / up3)
    up6 = up9 - up5 * up3
    up7 = up7 + 1
    
    setupvalue(ShootFunction, 15, up1)
    setupvalue(ShootFunction, 13, up2)
    setupvalue(ShootFunction, 16, up3)
    setupvalue(ShootFunction, 17, up4)
    setupvalue(ShootFunction, 14, up5)
    setupvalue(ShootFunction, 12, up6)
    setupvalue(ShootFunction, 18, up7)
    
    return math.floor(up9 / up4 * 16777215), up7
end

-- [[ LOGIC TÍNH COMBO ]]
local LastComboTime = 0
local CurrentM1Combo = 0
local function AdvancedGetCombo()
    local Combo = (tick() - LastComboTime) <= 0.3 and CurrentM1Combo or 0
    Combo = Combo >= 4 and 1 or Combo + 1
    LastComboTime = tick()
    CurrentM1Combo = Combo
    return Combo
end

-- [[ FIX TRÁNH CACHE CONTROLLER TỐI ƯU BỘ NHỚ - GIỮ NGUYÊN ]]
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

-- [[ BỘ FIX KẸT FRAMEWORK CỰC ĐOAN - GIỮ NGUYÊN ]]
local function FastAttack()
    pcall(function()
        local ac = GetFramework()
        if ac and ac.equipped then
            ac.hitboxMagnitude = 60 
            ac.timeToNextAttack = 0
            ac.attacking = false
            ac.blocking = false 
            ac.increment = 1 
            ac.active = false 
            ac.focusStart = 0
            ac.currentActivity = "" 
            if ac.animator and ac.animator.anims and ac.animator.anims.basic then
                for _, v in pairs(ac.animator.anims.basic) do
                    if v.IsPlaying then v:Stop() end 
                end
            end
        end
    end)
end

-- [1. QUÉT MỤC TIÊU ĐỒNG BỘ CHUẨN VỊ TRÍ - GIỮ NGUYÊN]
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

-- [[ BYPASS & HOOK SECTION - GIỮ NGUYÊN ]]
local oldNM = nil
local function ExtremeBypass(tool)
    pcall(function()
        if tool:IsA("Tool") then
            tool:SetAttribute("AttackCooldown", 0)
            tool:SetAttribute("LastAttack", 0)
            tool:SetAttribute("State", 0) 
            if not getgenv().Hooked then
                oldNM = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    if method == "FireServer" and self.Name == "RE/RegisterAttack" then
                        if oldNM then return oldNM(self, -math.huge) end
                    end
                    if oldNM then return oldNM(self, ...) end
                end)
                getgenv().Hooked = true
            end
        end
    end)
end

-- [3. LOGIC TẤN CÔNG LAN LUỒNG X3 & GUN LOGIC TÍCH HỢP]
local lastAttackTick = 0
local ATTACK_DELAY = 0.01
local LastGunFireTick = 0 

local function CoreAttackExecution()
    local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local tool = char and char:FindFirstChildOfClass("Tool")
    
    if not regHit or not regAttack or not tool or not root or #AllTargets == 0 then return end

    if tick() - lastAttackTick < ATTACK_DELAY then return end
    lastAttackTick = tick()

    ExtremeBypass(tool)
    FastAttack() 

    local exactName = tool.Name
    local toolName = exactName:lower()
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
                    -- [ LOGIC MELEE/SWORD/FRUIT TÁCH BIỆT ]
                    local fullHitList = {}
                    for j = 1, math.min(#AllTargets, 10) do
                        local monster = AllTargets[j]
                        if monster and monster.Parent and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                            local part = monster:FindFirstChild("UpperTorso") or monster:FindFirstChild("Head")
                            if part then table.insert(fullHitList, {monster, part}) end
                        end
                    end
                    
                    if #fullHitList > 0 then
                        regHit:FireServer(fullHitList[1][2], fullHitList, nil, nil, unbanID)
                        
                        if i == 1 then
                            if isFruit then
                                local leftClick = tool:FindFirstChild("LeftClickRemote", true)
                                if leftClick then
                                    local comboTrack = AdvancedGetCombo()
                                    local lookVector = (fullHitList[1][2].Position - root.Position).Unit
                                    if lookVector ~= lookVector then lookVector = Vector3.new(0, 1, 0) end 
                                    leftClick:FireServer(lookVector, comboTrack, unbanID_base)
                                end
                            else
                                regAttack:FireServer(-math.huge)
                            end
                        end
                    end
                else
                    -- [ GUN LOGIC - GIỮ NGUYÊN SÁT THƯƠNG LAN + UNBAN ID ]
                    local gunTargetsList = {}
                    local shootHitboxParts = {}
                    local autoAimPos = nil 

                    for j = 1, math.min(#AllTargets, 10) do
                        local monster = AllTargets[j]
                        if monster and monster.Parent and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                            local tPart = monster:FindFirstChild("Head") or monster:FindFirstChild("HumanoidRootPart")
                            if tPart then
                                table.insert(gunTargetsList, {monster, tPart})
                                table.insert(shootHitboxParts, tPart)
                                
                                if not autoAimPos then
                                    if (tPart.Position - root.Position).Magnitude <= GUN_AIM_RANGE then
                                        autoAimPos = tPart.Position
                                    end
                                end
                            end
                        end
                    end

                    if #gunTargetsList > 0 then
                        if not autoAimPos then
                            autoAimPos = root.Position + (root.CFrame.LookVector * 100)
                        end

                        if tool:FindFirstChild("MousePos") then
                            tool.MousePos.Value = autoAimPos
                        end

                        -- SÁT THƯƠNG LAN (AOE) + UNBAN ID CHO SÚNG
                        regHit:FireServer(gunTargetsList[1][2], gunTargetsList, nil, nil, unbanID)
                        
                        if i == 1 then
                            local cDelay = tool:FindFirstChild("Cooldown") and tool.Cooldown.Value or 0.3
                            if tick() - LastGunFireTick >= cDelay then
                                LastGunFireTick = tick()
                                
                                task.spawn(function()
                                    local fireType = SpecialFireModes[exactName] or "Normal"
                                    local shotsAmt = BulletsPerTarget[exactName] or 1
                                    
                                    for bullet = 1, shotsAmt do
                                        if fireType == "Position" or (fireType == "TAP" and tool:FindFirstChild("RemoteEvent")) then
                                            
                                            tool:SetAttribute("LocalTotalShots", (tool:GetAttribute("LocalTotalShots") or 0) + 1)
                                            local secVal, secTick = GrabGunSecurityData()
                                            if secVal then GunValidator:FireServer(secVal, secTick) end
                                            
                                            if fireType == "TAP" then
                                                tool.RemoteEvent:FireServer("TAP", autoAimPos, unbanID_base)
                                            else
                                                if shootGun then shootGun:FireServer(autoAimPos, shootHitboxParts, unbanID_base) end
                                            end
                                        else
                                            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                                            task.wait(0.05)
                                            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
            end)
        end)
        task.wait(0.01) 
    end
end

-- Vòng lặp chính thực thi đòn đánh liên tục dựa trên RunService
task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        CoreAttackExecution()
    end
end)

-- [[ PHẦN HOOK GC ]]
for _, registryValue in pairs(getgc(true)) do
    if typeof(registryValue) == "function" and iscclosure(registryValue) then
        local internalFunctionName = debug.getinfo(registryValue).name
        if internalFunctionName == "Attack" or internalFunctionName == "attack" or internalFunctionName == "RegisterHit" then
            hookfunction(registryValue, function(...)
                CoreAttackExecution()
                return registryValue(...)
            end)
        end
    end
end
