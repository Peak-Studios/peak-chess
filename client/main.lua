CGame = {
    tables = {},
    blips = {},
    current = nil,
    seated = false,
    color = nil,
    snapshot = nil,
}

local sitDebugOverride = nil
local chairHeightDebugOverride = nil
local sceneCamera = nil
local sceneCameraRunning = false
local lastMoveSoundKey = nil
local lastCheckState = false

function CGame._LoadModel(modelName)
    local modelHash = joaat(modelName)
    RequestModel(modelHash)

    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(0)
    end

    return modelHash
end

function CGame._GroundZ(x, y, z)
    RequestCollisionAtCoord(x, y, z)

    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + Config.Spawn.groundProbe, false)
    local attempts = 0

    while not foundGround and attempts < 25 do
        Wait(40)
        RequestCollisionAtCoord(x, y, z)
        foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + Config.Spawn.groundProbe, false)
        attempts = attempts + 1
    end

    return foundGround and groundZ or z
end

function CGame._SpawnTable(location)
    local x = location.coords.x
    local y = location.coords.y
    local z = location.coords.z + (Config.Spawn.zOffset or 0.0)

    if Config.Spawn.snapToGround then
        z = CGame._GroundZ(x, y, location.coords.z) + (Config.Spawn.zOffset or 0.0)
    end

    local tableModel = CGame._LoadModel(Config.Models.table)
    local tableObject = CreateObject(tableModel, x, y, z, false, false, false)
    SetEntityAsMissionEntity(tableObject, true, true)
    SetEntityHeading(tableObject, location.heading)
    FreezeEntityPosition(tableObject, true)

    local boardModel = CGame._LoadModel(Config.Models.board)
    local boardObject = CreateObject(boardModel, x, y, z + 1.0, false, false, false)
    SetEntityAsMissionEntity(boardObject, true, true)
    SetEntityCollision(boardObject, false, false)
    AttachEntityToEntity(
        boardObject,
        tableObject,
        0,
        Config.Board.onTable.x,
        Config.Board.onTable.y,
        Config.Board.onTable.z,
        0.0,
        0.0,
        0.0,
        false,
        false,
        false,
        false,
        2,
        true
    )

    local chairModel = CGame._LoadModel(Config.Models.chair)
    local chairs = {}

    for color, seat in pairs(Config.Seats) do
        local chairZ = chairHeightDebugOverride or seat.offset.z
        local chairCoords = GetOffsetFromEntityInWorldCoords(tableObject, seat.offset.x, seat.offset.y, chairZ)
        local chairObject = CreateObject(chairModel, chairCoords.x, chairCoords.y, chairCoords.z, false, false, false)

        SetEntityAsMissionEntity(chairObject, true, true)
        SetEntityCollision(chairObject, false, false)
        SetEntityHeading(chairObject, location.heading + seat.heading)
        FreezeEntityPosition(chairObject, true)
        chairs[color] = chairObject
    end

    SetModelAsNoLongerNeeded(tableModel)
    SetModelAsNoLongerNeeded(boardModel)
    SetModelAsNoLongerNeeded(chairModel)

    return {
        coords = vector3(x, y, z),
        heading = location.heading,
        tableObj = tableObject,
        boardObj = boardObject,
        chairs = chairs,
    }
end

function CGame._DeleteTable(tableId)
    local tableData = CGame.tables[tableId]
    if not tableData then
        return
    end

    if Sync then
        Sync.Clear(tableId)
        Sync.ClearAI(tableId)
    end

    if DoesEntityExist(tableData.boardObj) then
        DeleteEntity(tableData.boardObj)
    end

    for _, chairObject in pairs(tableData.chairs) do
        if DoesEntityExist(chairObject) then
            DeleteEntity(chairObject)
        end
    end

    if DoesEntityExist(tableData.tableObj) then
        DeleteEntity(tableData.tableObj)
    end

    CGame.tables[tableId] = nil
end

function CGame.NearestTable()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestTableId = nil
    local nearestDistance = nil

    for tableId, tableData in pairs(CGame.tables) do
        local distance = #(playerCoords - tableData.coords)
        if not nearestDistance or distance < nearestDistance then
            nearestDistance = distance
            nearestTableId = tableId
        end
    end

    return nearestTableId, nearestDistance
end

function CGame.BoardEntity(tableId)
    local tableData = CGame.tables[tableId]
    return tableData and tableData.boardObj or nil
end

function CGame._HelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function CGame._SitOffset()
    if sitDebugOverride then
        return sitDebugOverride.offset, sitDebugOverride.heading
    end

    return Config.Sit.pedOffset, Config.Sit.pedHeading
end

function CGame._SitAtTable(tableId, color)
    local tableData = CGame.tables[tableId]
    if not tableData or not tableData.chairs[color] then
        return
    end

    local pedOffset, pedHeading = CGame._SitOffset()
    local ped = PlayerPedId()

    RequestAnimDict(Config.Anim.dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(Config.Anim.dict) and GetGameTimer() < timeout do
        Wait(0)
    end

    local chairObject = tableData.chairs[color]
    local sitCoords = GetOffsetFromEntityInWorldCoords(chairObject, pedOffset.x, pedOffset.y, pedOffset.z)
    local sitHeading = GetEntityHeading(chairObject) + pedHeading

    ClearPedTasksImmediately(ped)
    DetachEntity(ped, true, true)
    SetEntityCoordsNoOffset(ped, sitCoords.x, sitCoords.y, sitCoords.z, false, false, false)
    SetEntityHeading(ped, sitHeading)
    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, Config.Anim.dict, Config.Anim.idle, 8.0, -8.0, -1, 1, 0.0, false, false, false)
end

function CGame._ClearPed()
    local ped = PlayerPedId()
    DetachEntity(ped, true, true)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

function CGame._StandUp()
    local ped = PlayerPedId()
    DetachEntity(ped, true, true)
    FreezeEntityPosition(ped, false)

    local coords = GetEntityCoords(ped)
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
    if foundGround then
        SetEntityCoords(ped, coords.x, coords.y, groundZ, false, false, false, false)
    end

    local getUpAnim = Config.Anim.getUp
    if getUpAnim and getUpAnim.dict and getUpAnim.clip then
        RequestAnimDict(getUpAnim.dict)
        local timeout = GetGameTimer() + 1000
        while not HasAnimDictLoaded(getUpAnim.dict) and GetGameTimer() < timeout do
            Wait(0)
        end

        if HasAnimDictLoaded(getUpAnim.dict) then
            TaskPlayAnim(ped, getUpAnim.dict, getUpAnim.clip, 4.0, -4.0, getUpAnim.duration or 1100, 0, 0.0, false, false, false)
            Wait(getUpAnim.duration or 1100)
        end

        ClearPedTasks(ped)
        return
    end

    TaskPlayAnim(ped, Config.Anim.dict, Config.Anim.idle, 4.0, 4.0, -1, 1, 0.0, false, false, false)
    Wait(80)
    StopAnimTask(ped, Config.Anim.dict, Config.Anim.idle, 1.5)
    Wait(700)
end

function CGame.SetIdleAnim()
    if not CGame.seated then
        return
    end

    TaskPlayAnim(PlayerPedId(), Config.Anim.dict, Config.Anim.idle, 8.0, -8.0, -1, 1, 0.0, false, false, false)
end

function CGame.PlayMoveAnim()
    if not CGame.seated then
        return
    end

    TaskPlayAnim(PlayerPedId(), Config.Anim.dict, Config.Anim.move, 8.0, -8.0, -1, 0, 0.0, false, false, false)

    CreateThread(function()
        Wait(1200)
        CGame.SetIdleAnim()
    end)
end

function CGame.StartSceneCam(tableId)
    if not Config.Camera.sceneEnabled then
        return
    end

    local tableData = CGame.tables[tableId]
    if not tableData or not tableData.tableObj or not tableData.boardObj then
        return
    end

    CGame.StopSceneCam()

    local scene = Config.Camera.scene
    local tableCoords = GetEntityCoords(tableData.tableObj)
    local boardCoords = GetEntityCoords(tableData.boardObj)

    sceneCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(sceneCamera, scene.fov)
    SetCamCoord(sceneCamera, tableCoords.x + scene.radius, tableCoords.y, tableCoords.z + scene.height)
    PointCamAtCoord(sceneCamera, boardCoords.x, boardCoords.y, boardCoords.z)
    RenderScriptCams(true, true, 600, true, true)
    sceneCameraRunning = true

    CreateThread(function()
        local angle = 0.0

        while sceneCameraRunning and sceneCamera do
            angle = angle + scene.speed * GetFrameTime()
            local radians = math.rad(angle)

            SetCamCoord(
                sceneCamera,
                tableCoords.x + math.cos(radians) * scene.radius,
                tableCoords.y + math.sin(radians) * scene.radius,
                tableCoords.z + scene.height
            )
            PointCamAtCoord(sceneCamera, boardCoords.x, boardCoords.y, boardCoords.z)
            Wait(0)
        end
    end)
end

function CGame.StopSceneCam()
    sceneCameraRunning = false

    if sceneCamera then
        RenderScriptCams(false, true, 400, true, true)
        DestroyCam(sceneCamera, false)
        sceneCamera = nil
    end
end

function CGame._ShouldShowSpotlight()
    local spotlight = Config.Spotlight
    if not spotlight.nightOnly then
        return true
    end

    local hour = GetClockHours()
    if spotlight.nightStart <= spotlight.nightEnd then
        return hour >= spotlight.nightStart and hour < spotlight.nightEnd
    end

    return hour >= spotlight.nightStart or hour < spotlight.nightEnd
end

function CGame._RequestScaleform(name)
    local handle = RequestScaleformMovie(name)
    local timeout = GetGameTimer() + 2000

    while not HasScaleformMovieLoaded(handle) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasScaleformMovieLoaded(handle) and handle or 0
end

function CGame._AddScaleformParam(value)
    if type(value) == "number" then
        if math.type and math.type(value) == "integer" then
            ScaleformMovieMethodAddParamInt(value)
        else
            ScaleformMovieMethodAddParamFloat(value)
        end
    elseif type(value) == "boolean" then
        ScaleformMovieMethodAddParamBool(value)
    else
        _ENV["ScaleformMovieMethodAddParamPlayerNameString"](tostring(value))
    end
end

function CGame._CallScaleform(handle, method, ...)
    BeginScaleformMovieMethod(handle, method)

    for index = 1, select("#", ...) do
        CGame._AddScaleformParam(select(index, ...))
    end

    EndScaleformMovieMethod()
end

function CGame._ShowEndScreen(title, subtitle, seconds)
    CreateThread(function()
        local handle = CGame._RequestScaleform("MISSION_QUIT")
        if handle == 0 then
            return
        end

        CGame._CallScaleform(handle, "SET_TEXT", title or "", subtitle or "")
        CGame._CallScaleform(handle, "TRANSITION_IN", 0)
        CGame._CallScaleform(handle, "TRANSITION_OUT", 3000)

        local expiresAt = GetGameTimer() + math.floor((tonumber(seconds) or 5) * 1000)
        while GetGameTimer() < expiresAt do
            Wait(0)
            DrawScaleformMovieFullscreen(handle, 255, 255, 255, 255)
        end

        SetScaleformMovieAsNoLongerNeeded(handle)
    end)
end

function CGame._GameOverText(data)
    local winner = data.winner
    local reason = data.reason
    local yourColor = data.yourColor
    local checkmateText = Shared.L("res_checkmate")

    if not winner then
        return Shared.L("res_draw"), reason == "stalemate" and Shared.L("res_stalemate") or Shared.L("res_draw_sub")
    end

    if yourColor then
        if winner == yourColor then
            return Shared.L("res_victory"), reason == "resign" and Shared.L("res_opp_resigned") or checkmateText
        end

        return Shared.L("res_defeat"), reason == "resign" and Shared.L("res_you_resigned") or checkmateText
    end

    local title = winner == "white" and Shared.L("res_white_wins") or Shared.L("res_black_wins")
    return title, reason == "resign" and Shared.L("res_by_resignation") or checkmateText
end

CreateThread(function()
    for tableId, location in ipairs(Config.Locations) do
        if location.blip then
            local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(Config.Blip.name)
            EndTextCommandSetBlipName(blip)
            CGame.blips[tableId] = blip
        end
    end

    if not Framework.Target.IsNative() then
        for tableId, location in ipairs(Config.Locations) do
            Framework.Target.Register(tableId, location.coords, function()
                CGame.current = tableId
                if NUI then
                    NUI.OpenLobby(tableId, CGame.snapshot)
                end
            end)
        end
    end

    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())

        for tableId, location in ipairs(Config.Locations) do
            local tableCoords = vector3(location.coords.x, location.coords.y, location.coords.z)
            local distance = #(playerCoords - tableCoords)

            if distance < Config.Spawn.streamDistance then
                if not CGame.tables[tableId] then
                    CGame.tables[tableId] = CGame._SpawnTable(location)
                end
            elseif distance > Config.Spawn.despawnDistance and CGame.tables[tableId] and CGame.current ~= tableId then
                CGame._DeleteTable(tableId)
            end
        end

        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        local waitMs = 500

        if Config.Sit.hideSelf and CGame.seated and CGame.snapshot and CGame.snapshot.status == "playing" then
            waitMs = 0
            SetEntityLocallyInvisible(PlayerPedId())
        end

        Wait(waitMs)
    end
end)

CreateThread(function()
    local spotlight = Config.Spotlight

    while true do
        local waitMs = 500

        if spotlight.enabled
            and CGame.current
            and CGame.tables[CGame.current]
            and CGame.tables[CGame.current].tableObj
            and CGame._ShouldShowSpotlight()
            and ((CGame.snapshot and CGame.snapshot.status == "playing") or (NUI and NUI.IsLobbyOpen())) then
            waitMs = 0
            local coords = GetEntityCoords(CGame.tables[CGame.current].tableObj)
            DrawSpotLight(
                coords.x,
                coords.y,
                coords.z + spotlight.height,
                0.0,
                0.0,
                -1.0,
                spotlight.color[1],
                spotlight.color[2],
                spotlight.color[3],
                spotlight.distance,
                spotlight.brightness,
                spotlight.hardness,
                spotlight.radius,
                spotlight.falloff
            )
        end

        Wait(waitMs)
    end
end)

RegisterNetEvent("peak-chess:self", function(data)
    CGame.current = data.id
    CGame.color = data.color
    CGame.seated = data.color ~= nil
    CGame.snapshot = data.snapshot
    lastMoveSoundKey = nil
    lastCheckState = false

    if CGame.seated then
        CGame._SitAtTable(data.id, data.color)
    end

    NUI.OnSelf(data)

    if Sync then
        Sync.Apply(data.id, data.snapshot)
    end
end)

RegisterNetEvent("peak-chess:sync", function(snapshot)
    if CGame.tables[snapshot.id] and Sync then
        Sync.Apply(snapshot.id, snapshot)
    end

    if snapshot.id ~= CGame.current then
        return
    end

    CGame.snapshot = snapshot
    NUI.OnSync(snapshot)

    if snapshot.lastMove then
        local moveKey = snapshot.lastMove.from .. snapshot.lastMove.to
        if moveKey ~= lastMoveSoundKey then
            lastMoveSoundKey = moveKey
            Sound.Play(snapshot.lastMove.captured and "capture" or "move")
        end
    end

    if snapshot.check and not lastCheckState then
        Sound.Play("check")
    end

    lastCheckState = snapshot.check or false
end)

RegisterNetEvent("peak-chess:gameover", function(data)
    if data.id ~= CGame.current then
        return
    end

    NUI.OnGameOver(data)
    local title, subtitle = CGame._GameOverText(data)
    CGame._ShowEndScreen(title, subtitle, 6)

    if data.winner and data.yourColor then
        Sound.Play(data.winner == data.yourColor and "win" or "lose")
    end
end)

RegisterNetEvent("peak-chess:lobbyState", function(snapshot)
    if not snapshot or snapshot.id ~= CGame.current then
        return
    end

    CGame.snapshot = snapshot
    NUI.UpdateLobby(snapshot)
end)

function CGame.Leave()
    if not CGame.current then
        return
    end

    local tableId = CGame.current
    local wasSeated = CGame.seated

    TriggerServerEvent("peak-chess:leave", tableId)

    if Raycast then
        Raycast.StopCam()
    end

    if Sync then
        Sync.Clear(tableId)
        Sync.ClearAI(tableId)
    end

    NUI.Close()

    CGame.seated = false
    CGame.color = nil
    CGame.current = nil
    CGame.snapshot = nil

    if wasSeated then
        CreateThread(function()
            CGame._StandUp()
        end)
    else
        CGame._ClearPed()
    end
end

if not Framework.Target.IsNative() then
    CreateThread(function()
        local suspended = false

        while true do
            local shouldSuspend = (NUI and NUI.IsLobbyOpen()) or CGame.seated
            if shouldSuspend ~= suspended then
                suspended = shouldSuspend
                if shouldSuspend then
                    Framework.Target.Suspend()
                else
                    Framework.Target.Resume()
                end
            end

            Wait(150)
        end
    end)
end

CreateThread(function()
    local targetKey = Config.Target.key or 38

    while true do
        local waitMs = 1000

        if CGame.seated then
            waitMs = 0

            if CGame.snapshot and CGame.snapshot.status ~= "playing" and IsControlJustReleased(0, targetKey) then
                if NUI then
                    NUI.OpenLobby(CGame.current, CGame.snapshot)
                end
            end

            if IsControlJustReleased(0, Config.Interact.leaveKey) then
                CGame.Leave()
            end
        elseif Framework.Target.IsNative() and (not NUI or not NUI.IsLobbyOpen()) then
            local tableId, distance = CGame.NearestTable()
            if tableId and distance and distance < Config.Interact.sitDistance + 1.5 then
                waitMs = 0
                CGame._HelpText(Shared.L("sit_prompt"))

                if IsControlJustReleased(0, targetKey) then
                    CGame.current = tableId
                    if NUI then
                        NUI.OpenLobby(tableId, CGame.snapshot)
                    end
                end
            end
        end

        Wait(waitMs)
    end
end)

if Config.Debug then
    RegisterCommand("chesssit", function(source, args)
        if not CGame.seated or not CGame.current then
            return
        end

        local defaultOffset = Config.Sit.pedOffset
        local x = tonumber(args[1]) or defaultOffset.x
        local y = tonumber(args[2]) or defaultOffset.y
        local z = tonumber(args[3]) or defaultOffset.z
        local heading = tonumber(args[4]) or Config.Sit.pedHeading

        sitDebugOverride = {
            offset = vector3(x, y, z),
            heading = heading,
        }
        CGame._SitAtTable(CGame.current, CGame.color)
        print(("[chess] pedOffset = vec3(%.3f, %.3f, %.3f), pedHeading = %.1f"):format(x, y, z, heading))
    end, false)

    RegisterCommand("chesscam", function(source, args)
        local height = tonumber(args[1]) or Config.Camera.height
        local distance = tonumber(args[2]) or Config.Camera.distance
        local fov = tonumber(args[3]) or Config.Camera.fov

        Raycast.SetCamOverride({ height = height, distance = distance, fov = fov })
        print(("[chess] camera height=%.2f distance=%.2f fov=%.1f"):format(height, distance, fov))
    end, false)

    RegisterCommand("chesschair", function(source, args)
        if CGame.seated then
            return
        end

        local offsetZ = tonumber(args[1])
        if not offsetZ then
            return
        end

        local tableId = CGame.NearestTable()
        if not tableId or not Config.Locations[tableId] then
            return
        end

        chairHeightDebugOverride = offsetZ
        CGame._DeleteTable(tableId)
        CGame.tables[tableId] = CGame._SpawnTable(Config.Locations[tableId])
        print(("[chess] chair offset.z = %.3f (paste into Config.Seats[*].offset.z)"):format(offsetZ))
    end, false)
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    SetNuiFocus(false, false)

    if Raycast then
        Raycast.StopCam()
    end

    CGame._ClearPed()
    Framework.Target.RemoveAll()

    for tableId, tableData in pairs(CGame.tables) do
        if DoesEntityExist(tableData.boardObj) then
            DeleteEntity(tableData.boardObj)
        end

        for _, chairObject in pairs(tableData.chairs) do
            if DoesEntityExist(chairObject) then
                DeleteEntity(chairObject)
            end
        end

        if DoesEntityExist(tableData.tableObj) then
            DeleteEntity(tableData.tableObj)
        end

        if Sync then
            Sync.Clear(tableId)
            Sync.ClearAI(tableId)
        end
    end

    for _, blip in pairs(CGame.blips) do
        RemoveBlip(blip)
    end
end)
