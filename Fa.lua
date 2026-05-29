-- [[ 1. HOOK TASK.DELAY (GIỮ NGUYÊN) ]]
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

-- [[ HỆ THỐNG VALIDATOR SÚNG ]]
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
    local v1, v2, v3, v4, v5, v6, v7 = getupvalue(ShootFunction, 15), getupvalue(ShootFunction, 13), getupvalue(ShootFunction, 16), getupvalue(ShootFunction, 17), getupvalue(ShootFunction, 14), getupvalue(ShootFunction, 12), getupvalue(ShootFunction, 18)
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

-- [[ FIX 1: TÌM FRAMEWORK BẰNG REQUIRE (NHANH & KHÔNG BAO GIỜ KẸT) ]]
local CombatFramework = nil
pcall(function()
    CombatFramework = require(LocalPlayer.PlayerScripts:WaitForChild("CombatFramework"))
end)

local function GetFramework()
    if CombatFramework then
        return CombatFramework.activeController
    end
    -- Fallback an toàn nếu require thất bại
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "activeController") then
            return v.activeController
        end
    end
end

-- [[ FIX 2: BỎ SPAM ANIMATOR KHỎI FAST ATTACK GÂY ĐƠ NHÂN VẬT ]]
local function FastAttack()
    pcall(function()
        local ac = GetFramework()
        if ac and ac.equipped then
            ac.hitboxMagnitude = 60 
            ac.timeToNextAttack = 0
            ac.attacking = false
            ac.blocking = false
            ac.increment = 3
            -- ĐÃ XÓA PHẦN AC.ANIMATOR.ANIMS ĐỂ CHỐNG LỖI KẸT LOGIC GAME
        end
    end)
end

-- [ QUÉT MỤC TIÊU - TỐI ƯU SORTING ]
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

-- [ AUTO CLICK SÚNG ]
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
                            if tool:FindFirstChild("MousePos") then tool.MousePos.Value = TargetPos end
                        end
                    end)
                end
            end
        end
    end
end)

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

-- [[ FIX 3: TỐI ƯU LUỒNG GỬI DỮ LIỆU ĐÁNH LAN CHỐNG NGHẼN MẠNG ]]
local lastHitTick = 0
local ATTACK_DELAY = math.random(5, 9) / 100 -- Sẽ giao động từ 0.05s đến 0.09s

task.spawn(function()
    while true do
        task.wait() -- Trả lại task.wait() để giảm tải CPU thay vì bắt ép Heartbeat
        
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if not regHit or not regAttack or not tool or not root or #AllTargets == 0 then continue end
        
        -- Delay giới hạn gói tin gửi lên server
        if tick() - lastHitTick < ATTACK_DELAY then continue end
        lastHitTick = tick()

        ExtremeBypass(tool)
        FastAttack() 

        local toolName = tool.Name:lower()
        local isGuitar = toolName:find("guitar")
        local isAnyGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun") or isGuitar
        local unbanID = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15)

        pcall(function()
            if not isAnyGun then
                local fullHitList = {}
                for j = 1, math.min(#AllTargets, 10) do
                    local monster = AllTargets[j]
                    if monster and monster.Parent and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                        local part = monster:FindFirstChild("UpperTorso") or monster:FindFirstChild("Head")
                        if part then table.insert(fullHitList, {monster, part}) end
                    end
                end
                
                if #fullHitList > 0 then
                    regAttack:FireServer(-math.huge)
                    regHit:FireServer(fullHitList[1][2], fullHitList, nil, nil, unbanID)
                    
                    -- LOGIC LEFTCLICK CHỈ CHẠY CHO BLOX FRUIT
                    if tool.ToolTip == "Blox Fruit" then
                        local leftClick = tool:FindFirstChild("LeftClickRemote", true)
                        if leftClick then
                            local targetPart = fullHitList[1][2]
                            local lookVector = (targetPart.Position - root.Position).Unit
                            if lookVector ~= lookVector then lookVector = Vector3.new(0, 1, 0) end 
                            leftClick:FireServer(lookVector, 1, unbanID)
                        end
                    end
                    tool:Activate()
                end
            else
                local gunHitList = {}
                local shootParts = {}
                local primaryPos = nil

                for j = 1, math.min(#AllTargets, 10) do
                    local monster = AllTargets[j]
                    if monster and monster.Parent and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                        local tPart = monster:FindFirstChild("Head") or monster:FindFirstChild("HumanoidRootPart")
                        if tPart then
                            table.insert(gunHitList, {monster, tPart})
                            table.insert(shootParts, tPart)
                            if not primaryPos then primaryPos = tPart.Position end
                        end
                    end
                end

                if #gunHitList > 0 then
                    regHit:FireServer(gunHitList[1][2], gunHitList, nil, nil, unbanID)
                    
                    if not isGuitar and shootGun and primaryPos then
                        shootGun:FireServer(primaryPos, shootParts, unbanID)
                    end

                    if isGuitar then
                        local remote = tool:FindFirstChild("RemoteEvent", true)
                        if remote then remote:FireServer("TAP", gunHitList[1][2].Position, unbanID) end
                    end
                end
            end
        end)
    end
end)
