-- [[ 1. HOOK TASK.DELAY (EXCLUDE GUNS) - GIỮ NGUYÊN ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local old
old = hookfunction(task.delay, function(t, f, ...)
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        local isGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun")
        if isGun then return old(t, f, ...) end
    end
    if t > 0.1 then return old(0, f, ...) end
    return old(t, f, ...)
end)

pcall(function()
    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
end)

task.spawn(function()
    while task.wait(0.5) do
        -- Lấy Character chuẩn từ Workspace.Characters hoặc LocalPlayer
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            -- Nếu trong Character chưa có thư mục/value HasBuso thì gọi Remote bật
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

-- Biến hỗ trợ lấy Upvalues để tính Validator
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
    
    -- Cập nhật lại Upvalues để nhịp sau tính tiếp (Quan trọng)
    setupvalue(ShootFunction, 14, v5)
    setupvalue(ShootFunction, 12, v6)
    setupvalue(ShootFunction, 18, v7)
    
    return math.floor(v9 / v4 * 16777215), v7
end

-- [[ FIX LAG: CHỈ QUÉT FRAMEWORK 1 LẦN DUY NHẤT ]]
local CachedFramework = nil
local function GetFramework()
    if CachedFramework then return CachedFramework end
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "activeController") then
            CachedFramework = v.activeController
            return CachedFramework
        end
    end
end

-- [[ KỸ THUẬT ĐỤC FRAMEWORK ]]
local function FastAttack()
    pcall(function()
        local ac = GetFramework()
        if ac and ac.equipped then
            ac.hitboxMagnitude = 60 
            ac.timeToNextAttack = 0
            ac.attacking = false
            ac.increment = 3
            if ac.animator and ac.animator.anims and ac.animator.anims.basic then
                for _, v in pairs(ac.animator.anims.basic) do
                    v:Play(0.01, 0.01, 0.01)
                end
            end
        end
    end)
end

-- [1. QUÉT MỤC TIÊU - GIỮ NGUYÊN]
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local targets = {}
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
            AllTargets = targets
        end
    end
end)

-- [2. AUTO CLICK + SPECIAL GUN LOGIC]
local lastClick = 0
task.spawn(function()
    while true do
        task.wait() 
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool and #AllTargets > 0 then
            local toolName = tool.Name
            local attr = tool:GetAttribute("WeaponType")
            if (attr == "Gun" or tool.ToolTip == "Gun" or toolName:lower():find("gun")) then
                local Cooldown = tool:FindFirstChild("Cooldown") and tool.Cooldown.Value or 0.05
                if tick() - lastClick > Cooldown then 
                    lastClick = tick()
                    pcall(function()
                        local TargetPos = AllTargets[1]:GetPivot().Position
                        local ShootType = SpecialShoots[toolName] or "Normal"

                        -- Nếu là súng cần Method riêng (Guitar, Bazooka, Dragonstorm)
                        if ShootType ~= "Normal" then
                            local v9, v7 = GetValidator2()
                            if v9 then GunValidator:FireServer(v9, v7) end
                            
                            if ShootType == "TAP" and tool:FindFirstChild("RemoteEvent") then
                                tool.RemoteEvent:FireServer("TAP", TargetPos)
                            elseif ShootType == "Position" then
                                game:GetService("ReplicatedStorage").Modules.Net["RE/ShootGunEvent"]:FireServer(TargetPos)
                            elseif ShootType == "Overheat" then
                                -- Logic đặc biệt cho Dragonstorm nếu cần (hiện tại gọi Position tương tự)
                                game:GetService("ReplicatedStorage").Modules.Net["RE/ShootGunEvent"]:FireServer(TargetPos)
                            end
                        else
                            -- SÚNG THƯỜNG: DÙNG VIM NHƯ LOGIC CŨ
                            local rx, ry = math.random(1, 5), math.random(1, 5)
                            VIM:SendMouseButtonEvent(rx, ry, 0, true, game, 0)
                            VIM:SendMouseButtonEvent(rx, ry, 0, false, game, 0)
                            if tool:FindFirstChild("Activated") then tool.Activated:Fire() end
                            tool:Activate()
                        end

                        if tool:FindFirstChild("MousePos") then
                            tool.MousePos.Value = TargetPos
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

-- [[ BYPASS & HOOK SECTION - GIỮ NGUYÊN ]]
local function ExtremeBypass(tool)
    pcall(function()
        if tool:IsA("Tool") then
            tool:SetAttribute("AttackCooldown", 0)
            tool:SetAttribute("LastAttack", 0)
            tool:SetAttribute("State", 0) 
            if not getgenv().Hooked then
                local oldNM = nil
                oldNM = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    if method == "FireServer" and self.Name == "RE/RegisterAttack" then
                        return oldNM(self, -math.huge)
                    end
                    return oldNM(self, ...)
                end)
                getgenv().Hooked = true
            end
        end
    end)
end

-- [3. LOGIC TẤN CÔNG LAN (GIGA SPEED - GIỮ NGUYÊN 100% NHỊP ĐỘ)]
task.spawn(function()
    while true do
        task.wait() 
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if not regHit or not regAttack or not tool or not root or #AllTargets == 0 then continue end

        ExtremeBypass(tool)
        FastAttack() 

        local toolName = tool.Name:lower()
        local isGuitar = toolName:find("guitar")
        local isAnyGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun") or isGuitar

        for i = 1, 5 do 
            task.spawn(function() 
                local unbanID = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15)
                pcall(function()
                    if not isAnyGun then
                        -- LOGIC CẬN CHIẾN / FRUIT (GIỮ NGUYÊN)
                        local fullHitList = {}
                        for j = 1, math.min(#AllTargets, 10) do
                            local monster = AllTargets[j]
                            local part = monster:FindFirstChild("UpperTorso") or monster:FindFirstChild("Head")
                            if part then table.insert(fullHitList, {monster, part}) end
                        end
                        if #fullHitList > 0 then
                            regAttack:FireServer(-math.huge)
                            regHit:FireServer(fullHitList[1][2], fullHitList, nil, nil, unbanID)
                            if tool:FindFirstChild("LeftClickRemote") then
                                tool.LeftClickRemote:FireServer((fullHitList[1][2].Position - root.Position).Unit, 1, unbanID)
                            end
                            tool:Activate()
                        end
                    else
                        -- LOGIC SÚNG LAN (GIỮ NGUYÊN)
                        local gunHitList = {}
                        for j = 1, math.min(#AllTargets, 10) do
                            local monster = AllTargets[j]
                            local tPart = monster:FindFirstChild("Head") or monster:FindFirstChild("HumanoidRootPart")
                            if tPart then
                                table.insert(gunHitList, {monster, tPart})
                                if not isGuitar and shootGun then
                                    shootGun:FireServer(tPart.Position, {tPart}, unbanID)
                                end
                            end
                        end
                        if #gunHitList > 0 then
                            regHit:FireServer(gunHitList[1][2], gunHitList, nil, nil, unbanID)
                            if isGuitar then
                                local remote = tool:FindFirstChild("RemoteEvent")
                                if remote then remote:FireServer("TAP", gunHitList[1][2].Position, unbanID) end
                            end
                        end
                    end
                end)
            end)
        end
    end
end)
