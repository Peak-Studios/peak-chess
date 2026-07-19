RegisterNetEvent("peak-chess:sit", function(tableId, color)
    local playerId = source
    tableId = tonumber(tableId)
    if not Chess.IsValidTableId(tableId) or not Chess.IsValidColor(color) then
        return
    end

    local success, reason = Chess.Sit(playerId, tableId, color)
    if not success and reason == "seat_taken" then
        Framework.Notify(playerId, Shared.L("seat_taken"), "error")
    end
end)

RegisterNetEvent("peak-chess:spectate", function(tableId)
    local playerId = source
    tableId = tonumber(tableId)
    if not Chess.IsValidTableId(tableId) then
        return
    end

    Chess.Spectate(playerId, tableId)
end)

RegisterNetEvent("peak-chess:requestState", function(tableId)
    local playerId = source
    tableId = tonumber(tableId)
    if not Chess.IsValidTableId(tableId) then
        return
    end

    TriggerClientEvent("peak-chess:lobbyState", playerId, Chess.Snapshot(Chess.Get(tableId)))
end)

RegisterNetEvent("peak-chess:leave", function(tableId)
    local playerId = source
    tableId = tonumber(tableId)
    if not Chess.IsValidTableId(tableId) then
        return
    end

    Chess.Leave(playerId, tableId)
end)

RegisterNetEvent("peak-chess:startAI", function(tableId, side, level, bet)
    local playerId = source
    tableId = tonumber(tableId)
    if not Chess.IsValidTableId(tableId) or not Config.AI.enabled then
        return
    end

    if side ~= nil and not Chess.IsValidColor(side) then
        return
    end

    if not Chess.IsValidAILevel(level) then
        return
    end

    local success, reason = Chess.StartAI(playerId, tableId, side, level, bet)
    if not success and reason == "broke" then
        Framework.Notify(playerId, Shared.L("not_enough_money"), "error")
    end
end)

RegisterNetEvent("peak-chess:setReady", function(tableId, ready, bet)
    local playerId = source
    tableId = tonumber(tableId)
    if not Chess.IsValidTableId(tableId) then
        return
    end

    local success, reason = Chess.SetReady(playerId, tableId, ready, bet)
    if not success and reason == "broke" then
        Framework.Notify(playerId, Shared.L("not_enough_money"), "error")
    end
end)

RegisterNetEvent("peak-chess:move", function(tableId, fromSquare, toSquare, promotion)
    local playerId = source
    tableId = tonumber(tableId)
    if not Chess.IsValidTableId(tableId)
        or not Chess.IsValidSquare(fromSquare)
        or not Chess.IsValidSquare(toSquare)
        or not Chess.IsValidPromotion(promotion) then
        return
    end

    local success, reason = Chess.Move(playerId, tableId, fromSquare, toSquare, promotion)
    if not success and reason == "illegal" then
        Framework.Notify(playerId, Shared.L("illegal_move"), "error")
    elseif not success and reason == "not_your_turn" then
        Framework.Notify(playerId, Shared.L("not_your_turn"), "error")
    end
end)

RegisterNetEvent("peak-chess:resign", function(tableId)
    local playerId = source
    tableId = tonumber(tableId)
    if not Chess.IsValidTableId(tableId) then
        return
    end

    Chess.Resign(playerId, tableId)
end)

AddEventHandler("playerDropped", function()
    Chess.OnDrop(source)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
end)
