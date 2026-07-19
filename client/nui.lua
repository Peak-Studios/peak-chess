NUI = {}

local lobbyOpen = false

function NUI._ConfigPayload()
    local aiLevels = {}

    for _, level in ipairs(Config.AI.levels) do
        aiLevels[#aiLevels + 1] = level.id
    end

    return {
        betEnabled = Config.Betting.enabled and Framework.HasMoneyProvider(),
        betPresets = Config.Betting.presets,
        betMin = Config.Betting.min,
        betMax = Config.Betting.max,
        aiEnabled = Config.AI.enabled,
        aiLevels = aiLevels,
        account = Config.Betting.account,
    }
end

function NUI._LocalePayload()
    return Shared.Locale[Config.Locale] or Shared.Locale.en
end

function NUI._SetFocus(enabled)
    SetNuiFocus(enabled, enabled)
end

function NUI.IsLobbyOpen()
    return lobbyOpen
end

CreateThread(function()
    Wait(500)
    lobbyOpen = false
    NUI._SetFocus(false)
    SendNUIMessage({ action = "closeAll" })
end)

function NUI.OpenLobby(tableId, snapshot)
    lobbyOpen = true
    NUI._SetFocus(true)
    CGame.StartSceneCam(tableId)
    Sound.Play("open")

    SendNUIMessage({
        action = "lobby",
        data = {
            visible = true,
            id = tableId,
            snapshot = snapshot or {
                id = tableId,
                status = "idle",
                seats = { white = false, black = false },
            },
            config = NUI._ConfigPayload(),
            locale = NUI._LocalePayload(),
        },
    })

    TriggerServerEvent("peak-chess:requestState", tableId)
end

function NUI.UpdateLobby(snapshot)
    if not lobbyOpen then
        return
    end

    SendNUIMessage({
        action = "lobby",
        data = {
            visible = true,
            snapshot = snapshot,
            color = CGame.color,
        },
    })
end

function NUI.Close()
    lobbyOpen = false
    NUI._SetFocus(false)
    CGame.StopSceneCam()
    SendNUIMessage({ action = "closeAll" })
end

function NUI.OnSelf(data)
    local snapshot = data.snapshot

    if snapshot and snapshot.status == "playing" then
        lobbyOpen = false
        NUI._SetFocus(false)
        CGame.StopSceneCam()

        SendNUIMessage({
            action = "lobby",
            data = { visible = false },
        })
        SendNUIMessage({
            action = "hud",
            data = {
                visible = true,
                snapshot = snapshot,
                color = data.color,
                locale = NUI._LocalePayload(),
            },
        })
        return
    end

    if lobbyOpen then
        SendNUIMessage({
            action = "lobby",
            data = {
                visible = true,
                snapshot = snapshot,
                color = data.color,
            },
        })
    end
end

function NUI.OnSync(snapshot)
    if snapshot.status == "playing" then
        if lobbyOpen then
            lobbyOpen = false
            NUI._SetFocus(false)
            CGame.StopSceneCam()
            SendNUIMessage({
                action = "lobby",
                data = { visible = false },
            })
        end

        SendNUIMessage({
            action = "hud",
            data = {
                visible = true,
                snapshot = snapshot,
                color = CGame.color,
                locale = NUI._LocalePayload(),
            },
        })
        return
    end

    if snapshot.status == "waiting" or snapshot.status == "idle" then
        if lobbyOpen then
            SendNUIMessage({
                action = "lobby",
                data = {
                    visible = true,
                    snapshot = snapshot,
                    color = CGame.color,
                },
            })
        end

        SendNUIMessage({
            action = "hud",
            data = { visible = false },
        })
    elseif snapshot.status == "over" then
        SendNUIMessage({
            action = "hud",
            data = { visible = false },
        })
    end
end

function NUI.OnGameOver(data)
    NUI._SetFocus(false)

    if Raycast.CancelPromo then
        Raycast.CancelPromo()
    end

    SendNUIMessage({
        action = "promotion",
        data = { visible = false },
    })
    SendNUIMessage({
        action = "hud",
        data = { visible = false },
    })
    SendNUIMessage({
        action = "gameover",
        data = {
            data = data,
            locale = NUI._LocalePayload(),
        },
    })
end

function NUI.OpenPromotion()
    NUI._SetFocus(true)
    SendNUIMessage({
        action = "promotion",
        data = {
            visible = true,
            color = CGame.color,
        },
    })
end

RegisterNUICallback("sit", function(data, callback)
    if CGame.current then
        TriggerServerEvent("peak-chess:sit", CGame.current, data.color)
    end

    Sound.Play("confirm")
    callback({})
end)

RegisterNUICallback("spectate", function(data, callback)
    if CGame.current then
        TriggerServerEvent("peak-chess:spectate", CGame.current)
    end

    lobbyOpen = false
    NUI._SetFocus(false)
    CGame.StopSceneCam()
    SendNUIMessage({
        action = "lobby",
        data = { visible = false },
    })
    Sound.Play("select")
    callback({})
end)

RegisterNUICallback("startAI", function(data, callback)
    if CGame.current then
        TriggerServerEvent("peak-chess:startAI", CGame.current, data.side, data.level, tonumber(data.bet) or 0)
    end

    Sound.Play("confirm")
    callback({})
end)

RegisterNUICallback("setReady", function(data, callback)
    if CGame.current then
        TriggerServerEvent("peak-chess:setReady", CGame.current, data.ready == true, tonumber(data.bet) or 0)
    end

    Sound.Play("confirm")
    callback({})
end)

RegisterNUICallback("resign", function(data, callback)
    if CGame.current then
        TriggerServerEvent("peak-chess:resign", CGame.current)
    end

    Sound.Play("select")
    callback({})
end)

RegisterNUICallback("promote", function(data, callback)
    NUI._SetFocus(false)
    Raycast.CompletePromo(data.piece or "q")
    Sound.Play("confirm")
    callback({})
end)

RegisterNUICallback("leave", function(data, callback)
    CGame.Leave()
    Sound.Play("select")
    callback({})
end)

RegisterNUICallback("closeLobby", function(data, callback)
    lobbyOpen = false
    NUI._SetFocus(false)
    CGame.StopSceneCam()
    SendNUIMessage({
        action = "lobby",
        data = { visible = false },
    })
    Sound.Play("select")
    callback({})
end)
