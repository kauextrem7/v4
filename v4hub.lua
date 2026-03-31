-- ==================== LOOP PRINCIPAL COM SUAVIZAÇÃO OFF-SCREEN ====================
-- Tabela para guardar a posição suavizada de cada jogador
local offScreenSmooth = {}

RunService.RenderStepped:Connect(function()
    -- Atualizar FOV seguindo o mouse
    if fovCircle then
        local mousePos = UserInputService:GetMouseLocation()
        fovCircle.Position = mousePos
        fovCircle.Radius = FOV_RADIUS
        fovCircle.Visible = FOV_ENABLED
        fovCircle.Transparency = FOV_TRANSPARENCY
    end

    local viewportX, viewportY = Camera.ViewportSize.X, Camera.ViewportSize.Y
    local centerX, centerY = viewportX / 2, viewportY / 2
    local smoothFactor = 0.25 -- quanto menor, mais suave (0.1 = muito suave, 0.5 = mais rápido)

    for plr, esp in pairs(ESPs) do
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local dist = (Camera.CFrame.Position - hrp.Position).Magnitude

            if dist <= ESP_DISTANCE then
                local vec, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local screenX, screenY, visible = vec.X, vec.Y, (onScreen and vec.Z > 0)

                -- Determina cor e texto da distância
                local color
                local distanceText = SHOW_DISTANCE and (math.floor(dist) .. "m") or ""
                if isDead(plr) then
                    color = Color3.fromRGB(128, 128, 128)
                    distanceText = "Morto"
                elseif Whitelist[plr.Name:lower()] then
                    color = Color3.fromRGB(0, 255, 0)
                elseif TEAMCHECK_ENABLED and (plr.Team == LocalPlayer.Team or (function()
                    local leaderstats = plr:FindFirstChild("leaderstats")
                    if leaderstats then
                        for _, stat in ipairs(leaderstats:GetChildren()) do
                            if (stat.Name:lower():find("fac") or stat.Name:lower():find("job")) then
                                local val = tostring(stat.Value):lower()
                                for _, kw in ipairs(BLOCKED_TEAMS) do
                                    if val:find(kw) then return true end
                                end
                            end
                        end
                    end
                    return false
                end)()) then
                    color = Color3.fromRGB(0, 255, 120)
                else
                    color = Color3.fromRGB(255, 60, 60)
                end

                if visible then
                    -- Na tela: desenha normalmente
                    local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.5, 0))
                    local bottom = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.5, 0))
                    local height = math.abs(top.Y - bottom.Y)
                    local width = height * 0.6

                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = Vector2.new(screenX - width/2, screenY - height/2)
                    esp.Box.Color = color
                    esp.Box.Visible = ESP_ENABLED

                    esp.Line.From = Vector2.new(centerX, centerY)
                    esp.Line.To = Vector2.new(screenX, screenY)
                    esp.Line.Color = color
                    esp.Line.Visible = ESPLINE_ENABLED

                    esp.Name.Text = SHOW_NAME and plr.Name or ""
                    esp.Name.Position = Vector2.new(screenX, screenY - height/2 - 25)
                    esp.Name.Color = color
                    esp.Name.Visible = ESP_ENABLED and SHOW_NAME

                    esp.Distance.Text = distanceText
                    esp.Distance.Position = Vector2.new(screenX, screenY - height/2 - 8)
                    esp.Distance.Color = isDead(plr) and Color3.fromRGB(100, 150, 255) or color
                    esp.Distance.Visible = ESP_ENABLED and (SHOW_DISTANCE or isDead(plr))

                    -- Limpa a posição suavizada quando está na tela
                    offScreenSmooth[plr] = nil
                else
                    -- Fora da tela: calcula posição alvo na borda
                    local direction = (hrp.Position - Camera.CFrame.Position).unit
                    local angle = math.atan2(direction.Y, direction.X)
                    local targetX = centerX + math.cos(angle) * (viewportX / 2)
                    local targetY = centerY + math.sin(angle) * (viewportY / 2)

                    -- Clamp para garantir que fique dentro da tela
                    targetX = math.clamp(targetX, 10, viewportX - 10)
                    targetY = math.clamp(targetY, 10, viewportY - 10)

                    -- Suavização
                    local current = offScreenSmooth[plr]
                    if current then
                        current.X = current.X + (targetX - current.X) * smoothFactor
                        current.Y = current.Y + (targetY - current.Y) * smoothFactor
                    else
                        current = Vector2.new(targetX, targetY)
                        offScreenSmooth[plr] = current
                    end

                    local smoothX, smoothY = current.X, current.Y

                    -- Desenha quadrado suavizado
                    local boxSize = 20
                    esp.Box.Size = Vector2.new(boxSize, boxSize)
                    esp.Box.Position = Vector2.new(smoothX - boxSize/2, smoothY - boxSize/2)
                    esp.Box.Color = color
                    esp.Box.Visible = ESP_ENABLED

                    esp.Line.From = Vector2.new(centerX, centerY)
                    esp.Line.To = Vector2.new(smoothX, smoothY)
                    esp.Line.Color = color
                    esp.Line.Visible = ESPLINE_ENABLED

                    esp.Name.Text = SHOW_NAME and plr.Name or ""
                    esp.Name.Position = Vector2.new(smoothX, smoothY - 20)
                    esp.Name.Color = color
                    esp.Name.Visible = ESP_ENABLED and SHOW_NAME

                    esp.Distance.Text = distanceText
                    esp.Distance.Position = Vector2.new(smoothX, smoothY + 10)
                    esp.Distance.Color = isDead(plr) and Color3.fromRGB(100, 150, 255) or color
                    esp.Distance.Visible = ESP_ENABLED and (SHOW_DISTANCE or isDead(plr))
                end
            else
                -- Fora da distância: esconde tudo e limpa suavização
                for _, obj in pairs(esp) do obj.Visible = false end
                offScreenSmooth[plr] = nil
            end
        else
            for _, obj in pairs(esp) do obj.Visible = false end
            offScreenSmooth[plr] = nil
        end
    end

    -- Aimbot com FOV baseado no mouse
    local target = getClosestToMouseFOV()
    if target then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
    end
end)