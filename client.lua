local binocularsActive = false
local binocularsCamera = nil
local binocularsScaleform = false
local playerPedCoords = nil

local binocularsPitch = 0.0
local binocularsHeading = 0.0

local binocularsZoom = 70.0
local binocularsMinZoom = 0.0
local binocularsMaxZoom = 70.0

local lastBinocularsUsage = 0
local binocularsUsageCooldown = 5000

local Config = {
    command = "jumelles",
    binocularsSpeed = 2.0,
    binocularsZoomSpeed = 2.0,
    playerPedFollowsCamera = false
}

local ShowNotification = function(text)
    SetNotificationTextEntry("STRING")
	AddTextComponentString(text)
	DrawNotification(true, true)
end

local CanUseBinoculars = function()
    local playerPed = PlayerPedId()

    if IsPedInAnyVehicle(playerPed, false) then
        ShowNotification("Vous ne pouvez pas utiliser vos jumelles dans un véhicule.")
        return false
    elseif IsEntityInWater(playerPed) then
        ShowNotification("Vous ne pouvez pas utiliser vos jumelles dans l'eau.")
        return false
    end

    return true
end

local EnterBinocularsMode = function()
    binocularsScaleform = true
    SetCurrentPedWeapon(PlayerPedId(), GetHashKey("WEAPON_UNARMED"), true)
    ShowNotification(("Faites /%s pour ranger vos jumelles."):format(Config.command))

    binocularsPitch = 0.0
    binocularsHeading = GetEntityHeading(PlayerPedId())

    playerPedCoords = GetEntityCoords(PlayerPedId())
    binocularsCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)

    SetCamCoord(binocularsCamera, playerPedCoords.x, playerPedCoords.y, playerPedCoords.z + 1.0)
    SetCamActive(binocularsCamera, true)
    RenderScriptCams(true, false, 0, true, true)

    TriggerServerEvent("simple_v:binoculars_enabled")
end

local ExitBinocularsMode = function()
    binocularsScaleform = false
    ClearPedTasks(PlayerPedId())
    
    if binocularsCamera ~= nil then
        SetCamActive(binocularsCamera, false)
        DestroyCam(binocularsCamera, false)
        RenderScriptCams(false, true, 500, true, true)
        binocularsCamera = nil
    end

    TriggerServerEvent("simple_v:binoculars_disabled")
end

RegisterCommand(Config.command, function()

    local currentTime = GetGameTimer()

    if currentTime - lastBinocularsUsage >= binocularsUsageCooldown then
        lastBinocularsUsage = currentTime

        if CanUseBinoculars() then

            binocularsActive = not binocularsActive

            if binocularsActive then
                TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_BINOCULARS", 0, true)
                Citizen.Wait(1000)
                EnterBinocularsMode()
            else
                ExitBinocularsMode()
            end
        end
    else
        local countTime = math.floor((lastBinocularsUsage + binocularsUsageCooldown - currentTime) / 1000)
        if countTime > 0 then
            ShowNotification(("Vous devez attendre %s seconde(s) pour utiliser cette commande."):format(countTime))
        elseif countTime == 0 then
            ShowNotification("Attendez encore un petit instant...")
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if binocularsScaleform then
            local scaleform = RequestScaleformMovie("BINOCULARS")
			while not HasScaleformMovieLoaded(scaleform) do
				Citizen.Wait(1)
			end
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
        end

        if binocularsActive then

            local playerPed = PlayerPedId()
            local isInVehicle = IsPedInAnyVehicle(playerPed, false)
            local isInWater = IsEntityInWater(playerPed)

            if isInVehicle or isInWater then
                binocularsActive = false
                ExitBinocularsMode()
            end

            HudWeaponWheelIgnoreSelection()
            DisableControlAction(1, 37, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 199, true)

            local pitchChange = -GetDisabledControlNormal(0, 2) * Config.binocularsSpeed
            local yawChange = -GetDisabledControlNormal(0, 1) * Config.binocularsSpeed

            binocularsPitch = math.max(-80.0, math.min(80.0, binocularsPitch + pitchChange))
            binocularsHeading = binocularsHeading + yawChange

            local scrollEnabled = 0
            if IsControlJustReleased(0, 96) then
                scrollEnabled = 1
            elseif IsControlJustReleased(0, 97) then
                scrollEnabled = -1
            end
   
            local newZoom = binocularsZoom

            if scrollEnabled > 0 then
                newZoom = math.max(binocularsMinZoom, binocularsZoom - Config.binocularsZoomSpeed)
            elseif scrollEnabled < 0 then
                newZoom = math.min(binocularsMaxZoom, binocularsZoom + Config.binocularsZoomSpeed)
            end

            if newZoom ~= binocularsZoom then
                binocularsZoom = newZoom
                SetCamFov(binocularsCamera, binocularsZoom)
            end

            SetCamRot(binocularsCamera, binocularsPitch, 0.0, binocularsHeading, 2)

            if binocularsHeading ~= 0.0 and Config.playerPedFollowsCamera then
                SetEntityHeading(playerPed, binocularsHeading)
            end
        end
    end
end)