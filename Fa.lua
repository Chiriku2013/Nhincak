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

-- [[ FIX TRÁNH CACHE CONTROLLER CHẾT KHI RESPAWN ]]
local CachedFramework = nil
local LastCheckedChar = nil

local function GetFramework()
    local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
    
    -- Xóa cache ngay lập tức nếu nhân vật chết
    if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
        CachedFramework = nil
        LastCheckedChar = nil
        return nil
    end
    
    if LastCheckedChar ~= char then
        CachedFramework = nil
        LastCheckedChar = char
    end
    
    if CachedFramework then return CachedFramework end
    
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "activeController") then
            CachedFramework = v.activeController
            return CachedFramework
        end
    end
end

-- [[ BỘ FIX KẸT FRAMEWORK CỰC ĐOAN (CHỐNG SOFT-LOCK 100%) ]]
local function FastAttack()
    pcall(function()
        local ac = GetFramework()
        if ac and ac.equipped then
            ac.hitboxMagnitude = 60 
            ac.timeToNextAttack = 0
            ac.attacking = false
            
            -- Xóa toàn bộ cờ chặn chém của CombatController
            ac.blocking = false 
            ac.active = false 
            ac.currentActivity = "" -- Xóa activity (nguyên nhân chính kẹt chiêu)
            ac.increment = 1 -- Reset chuỗi combo về 1 để tránh lỗi animation nhịp cuối
            
            if ac.animator and ac.animator.anims and ac.animator.anims.basic then
                for _, v in pairs(ac.animator.anims.basic) do
                    -- Chỉ Stop khi đang chạy, tránh spam Stop gây lú Animator
                    if v.IsPlaying then v:Stop() end 
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

-- [2. AUTO CLICK + SPECIAL GUN LOGIC]
local lastClick = 0
task.spawn(function()
    while true do
        task.wait() 
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool and #AllTargets > 0 then
            local toolName = tool.Name
            local attr = tool:GetAttribute("WeaponType")
            if (attr == "Gun" or tool.ToolTip == "Gun" or toolName:lower():find("gun")) then
                local Cooldown = tool:FindFirstChild("Cooldown") and tool.Cooldown.Value or 0.05
                if tick() - lastClick > Cooldown then 
                    lastClick = tick()
                    pcall(function()
                        local firstTarget = AllTargets[1]
                        if firstTarget and firstTarget.Parent and firstTarget:FindFirstChild("Humanoid") and firstTarget.Humanoid.Health > 0 then
                            local TargetPos = firstTarget:GetPivot().Position
                            local ShootType = SpecialShoots[toolName] or "Normal"

                            if ShootType ~= "Normal" then
                                local v9, v7 = GetValidator2()
                                if v9 then GunValidator:FireServer(v9, v7) end
                                
                                if ShootType == "TAP" and tool:FindFirstChild("RemoteEvent") then
                                    tool.RemoteEvent:FireServer("TAP", TargetPos)
                                elseif ShootType == "Position" then
                                    game:GetService("ReplicatedStorage").Modules.Net["RE/ShootGunEvent"]:FireServer(TargetPos)
                                elseif ShootType == "Overheat" then
                                    game:GetService("ReplicatedStorage").Modules.Net["RE/ShootGunEvent"]:FireServer(TargetPos)
                                end
                            else
                                local rx, ry = math.random(1, 5), math.random(1, 5)
                                VIM:SendMouseButtonEvent(rx, ry, 0, true, game, 0)
                                VIM:SendMouseButtonEvent(rx, ry, 0, false, game, 0)
                                
                                local act = tool:FindFirstChild("Activated")
                                if act and act:IsA("BindableEvent") then act:Fire() end
                                tool:Activate()
                            end

                            if tool:FindFirstChild("MousePos") then
                                tool.MousePos.Value = TargetPos
                            end
                        end
                    end)
                end
            end
        end
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

-- [[ BYPASS & HOOK SECTION ]]
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

-- [3. LOGIC TẤN CÔNG LAN LUỒNG X3 (FIX KẸT CỰC HẠN)]
local lastAttackTick = 0
local ATTACK_DELAY = 0.05 

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait() 
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if not regHit or not regAttack or not tool or not root or #AllTargets == 0 then continue end

        if tick() - lastAttackTick < ATTACK_DELAY then continue end
        lastAttackTick = tick()
        ATTACK_DELAY = math.random(5, 8) / 100 

        ExtremeBypass(tool)
        FastAttack() 

        local toolName = tool.Name:lower()
        local isGuitar = toolName:find("guitar")
        local isAnyGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun") or isGuitar

        -- BƯỚC 1: XÁC ĐỊNH MỤC TIÊU DUY NHẤT CHO VŨ KHÍ (TRÁNH KẸT)
        local primaryTarget = AllTargets[1]
        local unbanID_base = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15)

        for i = 1, 3 do 
            task.spawn(function() 
                local unbanID = unbanID_base .. i -- Đảm bảo mỗi gói tin có ID riêng biệt
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
                            -- Gửi DAMAGE (Damage x3)
                            regHit:FireServer(fullHitList[1][2], fullHitList, nil, nil, unbanID)
                            
                            -- CHỈ LUỒNG ĐẦU TIÊN MỚI ĐƯỢC GỬI LỆNH ĐIỀU KHIỂN VŨ KHÍ
                            if i == 1 then
                                regAttack:FireServer(-math.huge)
                                local leftClick = tool:FindFirstChild("LeftClickRemote", true)
                                if leftClick then
                                    local lookVector = (fullHitList[1][2].Position - root.Position).Unit
                                    if lookVector ~= lookVector then lookVector = Vector3.new(0, 1, 0) end 
                                    leftClick:FireServer(lookVector, 1, unbanID_base)
                                end
                                tool:Activate()
                            end
                        end
                    else
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
                            regHit:FireServer(gunHitList[1][2], gunHitList, nil, nil, unbanID)
                            
                            -- CHỈ LUỒNG ĐẦU TIÊN MỚI ĐƯỢC GỬI LỆNH SHOOT
                            if i == 1 then
                                if not isGuitar and shootGun then
                                    shootGun:FireServer(gunHitList[1][2].Position, shootParts, unbanID_base)
                                end
                                if isGuitar then
                                    local remote = tool:FindFirstChild("RemoteEvent", true)
                                    if remote then remote:FireServer("TAP", gunHitList[1][2].Position, unbanID_base) end
                                end
                            end
                        end
                    end
                end)
            end)
        end
    end
end)
