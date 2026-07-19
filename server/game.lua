Chess = {}

local matches = {}
local OPPONENT_COLOR = { white = "black", black = "white" }
local COLOR_TO_TURN = { white = "w", black = "b" }
local TURN_TO_COLOR = { w = "white", b = "black" }

function Chess.IsValidTableId(tableId)
    tableId = tonumber(tableId)
    return tableId ~= nil and Config.Locations[tableId] ~= nil
end

function Chess.IsValidColor(color)
    return color == "white" or color == "black"
end

function Chess.IsValidSquare(square)
    if type(square) ~= "string" or #square ~= 2 then
        return false
    end

    local file, rank = ChessEngine.toFR(square)
    return file ~= nil and rank ~= nil and ChessEngine._OnBoard(file, rank)
end

function Chess.IsValidPromotion(promotion)
    return promotion == nil or promotion == "q" or promotion == "r" or promotion == "b" or promotion == "n"
end

function Chess.IsValidAILevel(levelId)
    if not levelId then
        return true
    end

    for _, level in ipairs(Config.AI.levels or {}) do
        if level.id == levelId then
            return true
        end
    end

    return false
end

function Chess._NewMatch(tableId)
    return {
        id = tableId,
        status = "idle",
        seats = { white = nil, black = nil },
        ready = { white = false, black = false },
        bet = { white = 0, black = 0 },
        aiLevel = nil,
        state = nil,
        lastMove = nil,
        lastMoves = {},
        check = false,
        spectators = {},
        result = nil,
        turnToken = 0,
        aiThinking = false,
    }
end

function Chess.Get(tableId)
    if not Chess.IsValidTableId(tableId) then
        return nil
    end

    if not matches[tableId] then
        matches[tableId] = Chess._NewMatch(tableId)
    end

    return matches[tableId]
end

function Chess._SeatColor(match, playerId)
    if match.seats.white == playerId then
        return "white"
    end

    if match.seats.black == playerId then
        return "black"
    end

    return nil
end

function Chess._PlayersInMatch(match)
    local players = {}

    if type(match.seats.white) == "number" then
        players[#players + 1] = match.seats.white
    end

    if type(match.seats.black) == "number" then
        players[#players + 1] = match.seats.black
    end

    for spectator in pairs(match.spectators) do
        players[#players + 1] = spectator
    end

    return players
end

function Chess._NearbyPlayers(match)
    local location = Config.Locations[match.id]
    if not location then
        return {}
    end

    local tableCoords = vector3(location.coords.x, location.coords.y, location.coords.z)
    local maxDistance = Config.Spawn.despawnDistance or 90.0
    local players = {}

    for _, serverId in ipairs(GetPlayers()) do
        local playerId = tonumber(serverId)
        local ped = GetPlayerPed(playerId)
        if ped and ped ~= 0 then
            local distance = #(GetEntityCoords(ped) - tableCoords)
            if distance < maxDistance then
                players[#players + 1] = playerId
            end
        end
    end

    return players
end

function Chess.Snapshot(match)
    if not match then
        return nil
    end

    return {
        id = match.id,
        status = match.status,
        seats = {
            white = match.seats.white == "AI" and "AI" or match.seats.white ~= nil,
            black = match.seats.black == "AI" and "AI" or match.seats.black ~= nil,
        },
        ready = match.ready,
        bet = match.bet,
        aiLevel = match.aiLevel,
        turn = match.state and match.state.turn or nil,
        board = match.state and ChessEngine.serialize(match.state) or nil,
        castling = match.state and match.state.castling or nil,
        ep = match.state and match.state.enPassant or nil,
        lastMove = match.lastMove,
        lastMoves = match.lastMoves,
        check = match.check,
        result = match.result,
    }
end

function Chess.Broadcast(match)
    local snapshot = Chess.Snapshot(match)
    local sent = {}

    for _, playerId in ipairs(Chess._PlayersInMatch(match)) do
        if not sent[playerId] then
            sent[playerId] = true
            TriggerClientEvent("peak-chess:sync", playerId, snapshot)
        end
    end

    for _, playerId in ipairs(Chess._NearbyPlayers(match)) do
        if not sent[playerId] then
            sent[playerId] = true
            TriggerClientEvent("peak-chess:sync", playerId, snapshot)
        end
    end
end

function Chess._SendSelf(match, playerId)
    TriggerClientEvent("peak-chess:self", playerId, {
        id = match.id,
        color = Chess._SeatColor(match, playerId),
        snapshot = Chess.Snapshot(match),
    })
end

function Chess.Sit(playerId, tableId, color)
    if not Chess.IsValidTableId(tableId) or not Chess.IsValidColor(color) then
        return false, "invalid"
    end

    local match = Chess.Get(tableId)

    if match.status == "playing" or match.status == "over" then
        return false, "in_progress"
    end

    if match.seats[color] then
        return false, "seat_taken"
    end

    local oldColor = Chess._SeatColor(match, playerId)
    if oldColor then
        match.seats[oldColor] = nil
        match.ready[oldColor] = false
        match.bet[oldColor] = 0
    end

    Chess.UnseatEverywhere(playerId, tableId)

    match.seats[color] = playerId
    match.spectators[playerId] = nil
    if match.status == "idle" then
        match.status = "waiting"
    end

    Chess._SendSelf(match, playerId)
    Chess.Broadcast(match)
    return true
end

function Chess.Spectate(playerId, tableId)
    if not Chess.IsValidTableId(tableId) then
        return false
    end

    local match = Chess.Get(tableId)
    if Chess._SeatColor(match, playerId) then
        return false
    end

    match.spectators[playerId] = true
    Chess._SendSelf(match, playerId)
    return true
end

function Chess.UnseatEverywhere(playerId, exceptTableId)
    for tableId, match in pairs(matches) do
        match.spectators[playerId] = nil

        local color = Chess._SeatColor(match, playerId)
        if color and tableId ~= exceptTableId then
            Chess.Leave(playerId, tableId)
        end
    end
end

function Chess.Leave(playerId, tableId)
    local match = matches[tableId]
    if not match then
        return
    end

    local color = Chess._SeatColor(match, playerId)
    match.spectators[playerId] = nil

    if not color then
        Chess._SendSelf(match, playerId)
        return
    end

    if match.status == "playing" then
        Chess.End(match, OPPONENT_COLOR[color], "resign")
        return
    end

    match.seats[color] = nil
    match.ready[color] = false
    match.bet[color] = 0

    if not match.seats.white and not match.seats.black then
        Chess.Reset(match)
    else
        match.status = "waiting"
        Chess.Broadcast(match)
    end

    Chess._SendSelf(match, playerId)
end

function Chess.Reset(match)
    local tableId = match.id
    local spectators = match.spectators
    local formerPlayers = Chess._PlayersInMatch(match)

    matches[tableId] = Chess._NewMatch(tableId)
    matches[tableId].spectators = spectators
    Chess.Broadcast(matches[tableId])

    for _, playerId in ipairs(formerPlayers) do
        if type(playerId) == "number" and not matches[tableId].spectators[playerId] then
            Chess._SendSelf(matches[tableId], playerId)
        end
    end
end

function Chess.StartAI(playerId, tableId, playerColor, aiLevel, betAmount)
    if not Chess.IsValidTableId(tableId) or not Chess.IsValidAILevel(aiLevel) then
        return false, "invalid"
    end

    local match = Chess.Get(tableId)

    if match.status == "playing" or match.status == "over" then
        return false, "in_progress"
    end

    local occupiedWhite = type(match.seats.white) == "number" and match.seats.white ~= playerId
    local occupiedBlack = type(match.seats.black) == "number" and match.seats.black ~= playerId
    if occupiedWhite or occupiedBlack then
        return false, "seat_taken"
    end

    playerColor = playerColor == "black" and "black" or "white"
    betAmount = Chess.SanitizeBet(betAmount)

    if not Betting.CanAfford(playerId, betAmount) or not Betting.EscrowSolo(playerId, betAmount) then
        return false, "broke"
    end

    local spectators = match.spectators
    matches[tableId] = Chess._NewMatch(tableId)
    match = matches[tableId]
    match.spectators = spectators
    match.seats[playerColor] = playerId
    match.seats[OPPONENT_COLOR[playerColor]] = "AI"
    match.aiLevel = aiLevel
    match.bet[playerColor] = betAmount
    match.ready[playerColor] = true
    match.ready[OPPONENT_COLOR[playerColor]] = true

    Chess.Begin(match)
    return true
end

function Chess.SetReady(playerId, tableId, ready, betAmount)
    if not Chess.IsValidTableId(tableId) then
        return false, "invalid"
    end

    local match = Chess.Get(tableId)
    local color = Chess._SeatColor(match, playerId)
    if not color or match.status == "playing" then
        return false
    end

    match.ready[color] = ready and true or false
    match.bet[color] = Chess.SanitizeBet(betAmount)
    Chess.Broadcast(match)

    local bothPlayersSeated = type(match.seats.white) == "number" and type(match.seats.black) == "number"
    local bothReady = match.ready.white and match.ready.black
    if bothPlayersSeated and bothReady then
        local bet = match.bet.white
        if bet ~= match.bet.black then
            match.ready.white = false
            match.ready.black = false
            Framework.Notify(match.seats.white, Shared.L("bet_mismatch"), "error")
            Framework.Notify(match.seats.black, Shared.L("bet_mismatch"), "error")
            Chess.Broadcast(match)
            return false, "mismatch"
        end

        if not Betting.CanAfford(match.seats.white, bet)
            or not Betting.CanAfford(match.seats.black, bet)
            or not Betting.EscrowPvP(match.seats.white, match.seats.black, bet) then
            match.ready.white = false
            match.ready.black = false
            Chess.Broadcast(match)
            return false, "broke"
        end

        Chess.Begin(match)
    end

    return true
end

function Chess.Begin(match)
    match.state = ChessEngine.newGame()
    match.status = "playing"
    match.lastMove = nil
    match.lastMoves = {}
    match.check = false
    match.result = nil
    match.turnToken = (match.turnToken or 0) + 1
    match.aiThinking = false

    TriggerEvent("peak-chess:server:matchStarted", {
        id = match.id,
        white = type(match.seats.white) == "number" and match.seats.white or nil,
        black = type(match.seats.black) == "number" and match.seats.black or nil,
        bet = {
            white = match.bet.white or 0,
            black = match.bet.black or 0,
        },
        ai = match.seats.white == "AI" or match.seats.black == "AI",
    })

    Chess.Broadcast(match)

    for _, playerId in ipairs(Chess._PlayersInMatch(match)) do
        Chess._SendSelf(match, playerId)
    end

    Chess.MaybeAI(match)
end

function Chess.Move(playerId, tableId, fromSquare, toSquare, promotion)
    if not Chess.IsValidTableId(tableId)
        or not Chess.IsValidSquare(fromSquare)
        or not Chess.IsValidSquare(toSquare)
        or not Chess.IsValidPromotion(promotion) then
        return false, "invalid"
    end

    local match = matches[tableId]
    if not match or match.status ~= "playing" or not match.state then
        return false, "no_game"
    end

    local color = Chess._SeatColor(match, playerId)
    if not color then
        return false, "not_seated"
    end

    if COLOR_TO_TURN[color] ~= match.state.turn then
        return false, "not_your_turn"
    end

    return Chess.ApplyMove(match, fromSquare, toSquare, promotion)
end

function Chess.ApplyMove(match, fromSquare, toSquare, promotion)
    local move = ChessEngine.findMove(match.state, fromSquare, toSquare, promotion)
    if not move then
        return false, "illegal"
    end

    local nextState, capturedPiece = ChessEngine.apply(match.state, move, promotion)
    match.state = nextState
    match.turnToken = (match.turnToken or 0) + 1
    match.aiThinking = false

    match.lastMove = {
        from = fromSquare,
        to = toSquare,
        flag = move.flag,
        captured = capturedPiece and (capturedPiece.c .. capturedPiece.t) or nil,
    }
    match.lastMoves[TURN_TO_COLOR[ChessEngine.other(match.state.turn)]] = match.lastMove

    TriggerEvent("peak-chess:server:move", {
        id = match.id,
        color = TURN_TO_COLOR[ChessEngine.other(match.state.turn)],
        from = fromSquare,
        to = toSquare,
        capture = capturedPiece and (capturedPiece.c .. capturedPiece.t) or nil,
    })

    local status = ChessEngine.status(match.state)
    match.check = status == "check" or status == "checkmate"
    Chess.Broadcast(match)

    if status == "checkmate" then
        Chess.End(match, TURN_TO_COLOR[ChessEngine.other(match.state.turn)], "checkmate")
        return true
    end

    if status == "stalemate" then
        Chess.End(match, nil, "stalemate")
        return true
    end

    if match.state.halfmove >= 100 then
        Chess.End(match, nil, "fifty")
        return true
    end

    Chess.MaybeAI(match)
    return true
end

function Chess.MaybeAI(match)
    if match.status ~= "playing" then
        return
    end

    local turnColor = TURN_TO_COLOR[match.state.turn]
    if match.seats[turnColor] ~= "AI" then
        return
    end

    if match.aiThinking then
        return
    end

    match.aiThinking = true
    local turnToken = match.turnToken or 0

    local level = ChessAI.LevelConfig(match.aiLevel)

    CreateThread(function()
        local delay = level.moveDelay
        if type(delay) == "table" then
            delay = math.random(delay[1], delay[2])
        end

        delay = delay or 0
        local startedAt = GetGameTimer()
        local bestMove = ChessAI.BestMove(match.state, match.aiLevel)
        local elapsed = GetGameTimer() - startedAt

        if delay > elapsed then
            Wait(delay - elapsed)
        end

        if match.status ~= "playing" or match.turnToken ~= turnToken or not match.state
            or match.state.turn ~= (turnColor == "white" and "w" or "b") then
            match.aiThinking = false
            return
        end

        if not bestMove then
            match.aiThinking = false
            Chess.End(match, nil, "stalemate")
            return
        end

        match.aiThinking = false
        Chess.ApplyMove(match, bestMove.from, bestMove.to, bestMove.promo)
    end)
end

function Chess.End(match, winnerColor, reason)
    if match.status == "over" then
        return
    end

    match.status = "over"
    match.result = { winner = winnerColor, reason = reason }

    Betting.Settle(match, winnerColor)

    TriggerEvent("peak-chess:server:matchEnded", {
        id = match.id,
        winner = winnerColor,
        reason = reason,
        white = type(match.seats.white) == "number" and match.seats.white or nil,
        black = type(match.seats.black) == "number" and match.seats.black or nil,
        pot = (match.bet.white or 0) + (match.bet.black or 0),
    })

    Chess.Broadcast(match)

    for _, playerId in ipairs(Chess._PlayersInMatch(match)) do
        TriggerClientEvent("peak-chess:gameover", playerId, {
            id = match.id,
            winner = winnerColor,
            reason = reason,
            yourColor = Chess._SeatColor(match, playerId),
        })
    end

    SetTimeout(8000, function()
        if matches[match.id] == match then
            Chess.Reset(match)
        end
    end)
end

function Chess.Resign(playerId, tableId)
    local match = matches[tableId]
    if not match or match.status ~= "playing" then
        return false
    end

    local color = Chess._SeatColor(match, playerId)
    if not color then
        return false
    end

    Chess.End(match, OPPONENT_COLOR[color], "resign")
    return true
end

function Chess.SanitizeBet(amount)
    amount = tonumber(amount) or 0
    if not Betting.IsAvailable() then
        return 0
    end

    amount = math.floor(amount)
    if amount < Config.Betting.min then
        amount = Config.Betting.min
    end

    if amount > Config.Betting.max then
        amount = Config.Betting.max
    end

    return amount
end

function Chess.OnDrop(playerId)
    for tableId, match in pairs(matches) do
        if Chess._SeatColor(match, playerId) then
            Chess.Leave(playerId, tableId)
        end
        match.spectators[playerId] = nil
    end
end

CreateThread(function()
    if GetResourceState("bzzz_chess") ~= "started" then
        print("^1[peak-chess] ^7Required asset pack ^3bzzz_chess ^7is not running.")
        print("^1[peak-chess] ^7Get it here ^5->^7 https://bzzz.tebex.io/package/7496727^0")
    end
end)

CreateThread(function()
    while true do
        print("^2[peak-chess] ^7Script made by Peak Studios^0")
        Wait(math.random(10, 20) * 60000)
    end
end)
