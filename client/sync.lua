Sync = {}

local boardPieces = {}
local capturedPieces = {}
local aiPeds = {}
local aiPedColors = {}
local dragState = nil
local INITIAL_PIECES = {
    w = { p = 8, r = 2, n = 2, b = 2, q = 1, k = 1 },
    b = { p = 8, r = 2, n = 2, b = 2, q = 1, k = 1 },
}
local CAPTURE_ORDER = { "q", "r", "b", "n", "p" }

function Sync._LoadModel(modelName)
    if type(modelName) ~= "string" or modelName == "" then
        return nil
    end

    local modelHash = joaat(modelName)
    if not IsModelValid(modelHash) or not IsModelInCdimage(modelHash) then
        return nil
    end

    RequestModel(modelHash)

    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasModelLoaded(modelHash) and modelHash or nil
end

function Sync.SquareLocal(square)
    local file = string.byte(square, 1) - 96
    local rank = tonumber(square:sub(2, 2))

    return vector3(
        Config.Board.a1Offset.x + (file - 1) * Config.Board.step,
        Config.Board.a1Offset.y + (rank - 1) * Config.Board.step,
        Config.Board.a1Offset.z
    )
end

function Sync._PieceCode(piece)
    if type(piece) == "string" then
        return piece
    end

    if type(piece) == "table" and piece.c and piece.t then
        return piece.c .. piece.t
    end

    return nil
end

function Sync._PieceModel(pieceCode)
    local color = pieceCode:sub(1, 1)
    local pieceType = pieceCode:sub(2, 2)
    return Config.Models.pieces[color] and Config.Models.pieces[color][pieceType] or nil
end

function Sync._DeleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

function Sync._CreateAttachedPiece(boardEntity, offset, pieceCode)
    local modelName = Sync._PieceModel(pieceCode)
    if not modelName then
        return nil
    end

    local modelHash = Sync._LoadModel(modelName)
    if not modelHash then
        return nil
    end
    local boardCoords = GetEntityCoords(boardEntity)
    local pieceEntity = CreateObject(modelHash, boardCoords.x, boardCoords.y, boardCoords.z + 1.0, false, false, false)

    if not pieceEntity or pieceEntity == 0 then
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end

    SetEntityAsMissionEntity(pieceEntity, true, true)
    SetEntityCollision(pieceEntity, false, false)
    AttachEntityToEntity(
        pieceEntity,
        boardEntity,
        0,
        offset.x,
        offset.y,
        offset.z,
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
    SetModelAsNoLongerNeeded(modelHash)

    return pieceEntity
end

function Sync._EnsureBoardState(tableId)
    boardPieces[tableId] = boardPieces[tableId] or {}
    capturedPieces[tableId] = capturedPieces[tableId] or {}
end

function Sync._DeleteCaptured(tableId)
    if not capturedPieces[tableId] then
        return
    end

    for _, entity in ipairs(capturedPieces[tableId]) do
        Sync._DeleteEntity(entity)
    end

    capturedPieces[tableId] = {}
end

function Sync._BoardCounts(board)
    local counts = {
        w = { p = 0, r = 0, n = 0, b = 0, q = 0, k = 0 },
        b = { p = 0, r = 0, n = 0, b = 0, q = 0, k = 0 },
    }

    for _, piece in pairs(board or {}) do
        local pieceCode = Sync._PieceCode(piece)
        if pieceCode then
            local color = pieceCode:sub(1, 1)
            local pieceType = pieceCode:sub(2, 2)
            counts[color][pieceType] = (counts[color][pieceType] or 0) + 1
        end
    end

    return counts
end

function Sync._RenderCaptured(tableId, boardEntity, board)
    Sync._DeleteCaptured(tableId)

    local currentCounts = Sync._BoardCounts(board)

    for color, initialCounts in pairs(INITIAL_PIECES) do
        local trayStart = Config.Models.captureTray[color]
        local placed = 0

        for _, pieceType in ipairs(CAPTURE_ORDER) do
            local missing = initialCounts[pieceType] - (currentCounts[color][pieceType] or 0)

            for _ = 1, missing do
                local perRow = Config.Models.capturePerRow or 5
                local row = math.floor(placed / perRow)
                local column = placed % perRow
                local inward = color == "w" and 1.0 or -1.0
                local offset = vector3(
                    trayStart.x + inward * row * (Config.Models.captureRowGap or 0.055),
                    trayStart.y + column * (Config.Board.captureGap or 0.055),
                    trayStart.z
                )
                local entity = Sync._CreateAttachedPiece(boardEntity, offset, color .. pieceType)
                if entity then
                    capturedPieces[tableId][#capturedPieces[tableId] + 1] = entity
                end
                placed = placed + 1
            end
        end
    end
end

function Sync._SpawnAIPed(tableId, color)
    local tableData = CGame.tables[tableId]
    if not tableData or not tableData.chairs or not tableData.chairs[color] then
        return nil
    end

    local pedModels = Config.AI.peds or { "a_m_y_business_01" }
    local modelHash = Sync._LoadModel(pedModels[math.random(#pedModels)])
    local chair = tableData.chairs[color]
    local offset = Config.Sit.pedOffset
    local position = GetOffsetFromEntityInWorldCoords(chair, offset.x, offset.y, offset.z)
    local heading = GetEntityHeading(chair) + (Config.Sit.pedHeading or 0.0)
    local ped = CreatePed(4, modelHash, position.x, position.y, position.z, heading, false, false)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    RequestAnimDict(Config.Anim.dict)

    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(Config.Anim.dict) and GetGameTimer() < timeout do
        Wait(0)
    end

    TaskPlayAnim(ped, Config.Anim.dict, Config.Anim.idle, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    return ped
end

function Sync._SyncAI(tableId, snapshot)
    local aiColor = nil

    if snapshot and snapshot.seats then
        if snapshot.seats.white == "AI" then
            aiColor = "white"
        elseif snapshot.seats.black == "AI" then
            aiColor = "black"
        end
    end

    if not aiColor then
        Sync.ClearAI(tableId)
        return
    end

    if aiPeds[tableId] and aiPedColors[tableId] ~= aiColor then
        Sync._DeleteEntity(aiPeds[tableId])
        aiPeds[tableId] = nil
    end

    if not aiPeds[tableId] or not DoesEntityExist(aiPeds[tableId]) then
        aiPeds[tableId] = Sync._SpawnAIPed(tableId, aiColor)
        aiPedColors[tableId] = aiPeds[tableId] and aiColor or nil
    end
end

function Sync.ClearAI(tableId)
    Sync._DeleteEntity(aiPeds[tableId])
    aiPeds[tableId] = nil
    aiPedColors[tableId] = nil
end

function Sync.Apply(tableId, snapshot)
    Sync._EnsureBoardState(tableId)
    Sync._SyncAI(tableId, snapshot)

    local boardEntity = CGame.BoardEntity(tableId)
    if not boardEntity or not DoesEntityExist(boardEntity) then
        return
    end

    local board = snapshot and snapshot.board or {}

    for square, pieceData in pairs(boardPieces[tableId]) do
        local nextCode = Sync._PieceCode(board[square])
        if not nextCode or nextCode ~= pieceData.code or not DoesEntityExist(pieceData.entity) then
            Sync._DeleteEntity(pieceData.entity)
            boardPieces[tableId][square] = nil
        end
    end

    for square, piece in pairs(board) do
        local pieceCode = Sync._PieceCode(piece)
        if pieceCode and not boardPieces[tableId][square] then
            local entity = Sync._CreateAttachedPiece(boardEntity, Sync.SquareLocal(square), pieceCode)
            if entity then
                boardPieces[tableId][square] = { code = pieceCode, entity = entity }
            end
        end
    end

    Sync._RenderCaptured(tableId, boardEntity, board)
end

function Sync.PieceObj(tableId, square)
    local pieces = boardPieces[tableId]
    return pieces and pieces[square] and pieces[square].entity or nil
end

function Sync.BeginDrag(tableId, square)
    local entity = Sync.PieceObj(tableId, square)
    local boardEntity = CGame.BoardEntity(tableId)
    if not entity or not DoesEntityExist(entity) or not boardEntity then
        return false
    end

    dragState = {
        tableId = tableId,
        square = square,
        entity = entity,
        boardEntity = boardEntity,
    }

    DetachEntity(entity, true, true)
    SetEntityAlpha(entity, 200, false)
    return true
end

function Sync.DragGhostTo(worldCoords)
    if not dragState or not dragState.entity or not DoesEntityExist(dragState.entity) then
        return
    end

    SetEntityCoordsNoOffset(dragState.entity, worldCoords.x, worldCoords.y, worldCoords.z, false, false, false)
end

function Sync.EndDrag(success)
    if not dragState then
        return
    end

    local entity = dragState.entity
    if entity and DoesEntityExist(entity) then
        ResetEntityAlpha(entity)

        if not success and dragState.boardEntity and DoesEntityExist(dragState.boardEntity) then
            local offset = Sync.SquareLocal(dragState.square)
            AttachEntityToEntity(entity, dragState.boardEntity, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        end
    end

    dragState = nil
end

function Sync.Clear(tableId)
    if boardPieces[tableId] then
        for _, pieceData in pairs(boardPieces[tableId]) do
            Sync._DeleteEntity(pieceData.entity)
        end
    end

    boardPieces[tableId] = nil
    Sync._DeleteCaptured(tableId)
    capturedPieces[tableId] = nil
end
