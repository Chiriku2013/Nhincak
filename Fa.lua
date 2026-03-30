local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local RANGE = 100 
local AllTargets = {}

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

-- [2. AUTO CLICK (SAFE HOOK) - NÂNG CẤP ĐỘ AN TOÀN]
local lastClick = 0
task.spawn(function()
    while true do
        task.wait() -- Vẫn giữ nhịp check nhanh
        
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if tool and #AllTargets > 0 then
            local toolName = tool.Name:lower()
            local attr = tool:GetAttribute("WeaponType")
            
            -- Điều kiện: Là súng, không phải Guitar
            if (attr == "Gun" or tool.ToolTip == "Gun" or toolName:find("gun")) and not toolName:find("guitar") then
                
                -- GIẢI PHÁP AN TOÀN: Kiểm soát nhịp bấm (Tránh spam input quá dày gây Dangerous)
                if tick() - lastClick > 0.05 then -- Giới hạn khoảng 20 đợt gửi input/giây (vẫn cực nhanh nhưng an toàn hơn)
                    lastClick = tick()
                    
                    pcall(function()
                        -- Tạo mã ID Unban ngay trong phần Hook để khớp với đợt bắn
                        local hookID = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15)
                        
                        -- Thay vì click vào 0,0 (góc màn hình), ta click vào tọa độ ngẫu nhiên nhỏ để bypass quét tọa độ tĩnh
                        local rx, ry = math.random(1, 5), math.random(1, 5)
                        VIM:SendMouseButtonEvent(rx, ry, 0, true, game, 0)
                        VIM:SendMouseButtonEvent(rx, ry, 0, false, game, 0)
                        
                        -- Hook Activated an toàn bằng cách kiểm tra sự tồn tại
                        if tool:FindFirstChild("Activated") then 
                            tool.Activated:Fire() 
                        end
                        
                        -- Ép súng bắn nhưng dùng pcall bảo vệ
                        tool:Activate()
                        
                        -- Gán MousePos chuẩn xác cho mục tiêu
                        if tool:FindFirstChild("MousePos") then
                            tool.MousePos.Value = AllTargets[1]:GetPivot().Position
                        end
                    end)
                end
            end
        end
    end
end)

-- [3. LOGIC TẤN CÔNG LAN (FULL UNBAN)]
RunService.Stepped:Connect(function()
    if #AllTargets == 0 then return end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool or not root then return end

    local Net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
    if not Net then return end

    local toolName = tool.Name:lower()
    local isGuitar = toolName:find("guitar")
    local isAnyGun = (tool:GetAttribute("WeaponType") == "Gun") or (tool.ToolTip == "Gun") or isGuitar
    local unbanID = tostring(LocalPlayer.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15)

    pcall(function()
        if not isAnyGun then
            -- Logic Melee/Sword/Fruit (Giữ nguyên Unban của ông)
            local fullHitList = {}
            for i = 1, math.min(#AllTargets, 10) do
                local monster = AllTargets[i]
                local part = monster:FindFirstChild("UpperTorso") or monster:FindFirstChild("Head")
                if part then table.insert(fullHitList, {monster, part}) end
            end

            if #fullHitList > 0 then
                Net["RE/RegisterAttack"]:FireServer(0)
                Net["RE/RegisterHit"]:FireServer(fullHitList[1][2], fullHitList, nil, nil, unbanID)
                
                if tool:FindFirstChild("LeftClickRemote") then
                    tool.LeftClickRemote:FireServer((AllTargets[1]:GetPivot().Position - root.Position).Unit, 1, unbanID)
                end
            end
        else
            -- Logic Gun/Guitar (Giữ nguyên Unban cho Súng)
            local gunHitList = {}
            local ShootEvent = Net:FindFirstChild("RE/ShootGunEvent")
            
            for i = 1, math.min(#AllTargets, 10) do
                local monster = AllTargets[i]
                local tPart = monster:FindFirstChild("Head") or monster:FindFirstChild("HumanoidRootPart")
                if tPart then
                    table.insert(gunHitList, {monster, tPart})
                    if not isGuitar and ShootEvent then
                        ShootEvent:FireServer(tPart.Position, {tPart}, unbanID)
                    end
                end
            end
            
            if #gunHitList > 0 then
                Net["RE/RegisterHit"]:FireServer(gunHitList[1][2], gunHitList, nil, nil, unbanID)
                if isGuitar then
                    local remote = tool:FindFirstChild("RemoteEvent") or tool:FindFirstChildOfClass("RemoteEvent")
                    if remote then remote:FireServer("TAP", gunHitList[1][2].Position, unbanID) end
                end
            end
        end
    end)
end)
