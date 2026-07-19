function Chess._ExportSeatValue(value)
    if value == "AI" then
        return "AI"
    end

    return type(value) == "number" and value or false
end

function Chess._ExportMatch(match)
    if not match then
        return nil
    end

    return {
        id = match.id,
        status = match.status,
        seats = {
            white = Chess._ExportSeatValue(match.seats.white),
            black = Chess._ExportSeatValue(match.seats.black),
        },
        turn = match.state and match.state.turn or nil,
        bet = {
            white = match.bet.white or 0,
            black = match.bet.black or 0,
        },
        winner = match.result and match.result.winner or nil,
        reason = match.result and match.result.reason or nil,
    }
end

exports("GetMatch", function(tableId)
    tableId = tonumber(tableId)
    if not tableId or not Config.Locations[tableId] then
        return nil
    end

    return Chess._ExportMatch(Chess.Get(tableId))
end)

exports("GetPlayerMatch", function(playerId)
    playerId = tonumber(playerId)
    if not playerId then
        return nil
    end

    for tableId in ipairs(Config.Locations) do
        local match = Chess.Get(tableId)
        local color = Chess._SeatColor(match, playerId)

        if color then
            return {
                tableId = tableId,
                color = color,
                status = match.status,
            }
        end
    end

    return nil
end)

exports("IsPlayerInGame", function(playerId)
    playerId = tonumber(playerId)
    if not playerId then
        return false
    end

    for tableId in ipairs(Config.Locations) do
        local match = Chess.Get(tableId)
        if Chess._SeatColor(match, playerId) and match.status == "playing" then
            return true
        end
    end

    return false
end)

exports("GetActiveMatches", function()
    local activeMatches = {}

    for tableId in ipairs(Config.Locations) do
        local match = Chess.Get(tableId)
        if match.status == "playing" then
            activeMatches[#activeMatches + 1] = {
                tableId = tableId,
                status = match.status,
            }
        end
    end

    return activeMatches
end)

exports("StartAIGame", function(playerId, tableId, side, level, bet)
    playerId = tonumber(playerId)
    tableId = tonumber(tableId)

    if not playerId or not tableId or not Config.Locations[tableId] or not Config.AI.enabled then
        return false
    end

    if side ~= nil and side ~= "white" and side ~= "black" then
        return false
    end

    return Chess.StartAI(playerId, tableId, side, level, bet) == true
end)

exports("ForceEndMatch", function(tableId, winnerColor)
    tableId = tonumber(tableId)
    if not tableId or not Config.Locations[tableId] then
        return false
    end

    if winnerColor ~= nil and winnerColor ~= "white" and winnerColor ~= "black" then
        return false
    end

    local match = Chess.Get(tableId)
    if match.status ~= "playing" then
        return false
    end

    Chess.End(match, winnerColor, "forced")
    return true
end)
