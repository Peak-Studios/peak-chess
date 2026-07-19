ChessEngine = {}

local FILES = { "a", "b", "c", "d", "e", "f", "g", "h" }
local FILE_INDEX = { a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8 }
local KNIGHT_OFFSETS = {
    { 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 },
    { -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 },
}
local BISHOP_DIRECTIONS = { { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } }
local ROOK_DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local KING_DIRECTIONS = {
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
    { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 },
}

function ChessEngine._OnBoard(file, rank)
    return file >= 1 and file <= 8 and rank >= 1 and rank <= 8
end

function ChessEngine.toSq(file, rank)
    if not ChessEngine._OnBoard(file, rank) then
        return nil
    end

    return FILES[file] .. rank
end

function ChessEngine.toFR(square)
    if type(square) ~= "string" or #square ~= 2 then
        return nil, nil
    end

    local file = FILE_INDEX[square:sub(1, 1)]
    local rank = tonumber(square:sub(2, 2))
    if not file or not rank or not ChessEngine._OnBoard(file, rank) then
        return nil, nil
    end

    return file, rank
end

function ChessEngine.other(color)
    return color == "w" and "b" or "w"
end

function ChessEngine.clone(state)
    local board = {}

    for square, piece in pairs(state.board or {}) do
        board[square] = { c = piece.c, t = piece.t }
    end

    return {
        board = board,
        turn = state.turn,
        castling = {
            wk = state.castling and state.castling.wk or false,
            wq = state.castling and state.castling.wq or false,
            bk = state.castling and state.castling.bk or false,
            bq = state.castling and state.castling.bq or false,
        },
        enPassant = state.enPassant,
        halfmove = state.halfmove or 0,
        fullmove = state.fullmove or 1,
    }
end

function ChessEngine.newGame()
    local board = {}
    local backRank = { "r", "n", "b", "q", "k", "b", "n", "r" }

    for file = 1, 8 do
        board[ChessEngine.toSq(file, 1)] = { c = "w", t = backRank[file] }
        board[ChessEngine.toSq(file, 2)] = { c = "w", t = "p" }
        board[ChessEngine.toSq(file, 7)] = { c = "b", t = "p" }
        board[ChessEngine.toSq(file, 8)] = { c = "b", t = backRank[file] }
    end

    return {
        board = board,
        turn = "w",
        castling = { wk = true, wq = true, bk = true, bq = true },
        enPassant = nil,
        halfmove = 0,
        fullmove = 1,
    }
end

function ChessEngine._PieceAtFR(state, file, rank)
    local square = ChessEngine.toSq(file, rank)
    return square and state.board[square] or nil
end

function ChessEngine._AddMove(moves, fromSquare, toSquare, flag, promotion)
    moves[#moves + 1] = {
        from = fromSquare,
        to = toSquare,
        flag = flag,
        promo = promotion,
    }
end

function ChessEngine.isAttacked(state, square, byColor)
    local file, rank = ChessEngine.toFR(square)
    if not file or not rank then
        return false
    end

    local pawnDirection = byColor == "w" and 1 or -1
    for _, fileOffset in ipairs({ -1, 1 }) do
        local piece = ChessEngine._PieceAtFR(state, file + fileOffset, rank - pawnDirection)
        if piece and piece.c == byColor and piece.t == "p" then
            return true
        end
    end

    for _, offset in ipairs(KNIGHT_OFFSETS) do
        local piece = ChessEngine._PieceAtFR(state, file + offset[1], rank + offset[2])
        if piece and piece.c == byColor and piece.t == "n" then
            return true
        end
    end

    for _, offset in ipairs(KING_DIRECTIONS) do
        local piece = ChessEngine._PieceAtFR(state, file + offset[1], rank + offset[2])
        if piece and piece.c == byColor and piece.t == "k" then
            return true
        end
    end

    for _, direction in ipairs(BISHOP_DIRECTIONS) do
        local scanFile = file + direction[1]
        local scanRank = rank + direction[2]

        while ChessEngine._OnBoard(scanFile, scanRank) do
            local piece = ChessEngine._PieceAtFR(state, scanFile, scanRank)
            if piece then
                return piece.c == byColor and (piece.t == "b" or piece.t == "q")
            end

            scanFile = scanFile + direction[1]
            scanRank = scanRank + direction[2]
        end
    end

    for _, direction in ipairs(ROOK_DIRECTIONS) do
        local scanFile = file + direction[1]
        local scanRank = rank + direction[2]

        while ChessEngine._OnBoard(scanFile, scanRank) do
            local piece = ChessEngine._PieceAtFR(state, scanFile, scanRank)
            if piece then
                return piece.c == byColor and (piece.t == "r" or piece.t == "q")
            end

            scanFile = scanFile + direction[1]
            scanRank = scanRank + direction[2]
        end
    end

    return false
end

function ChessEngine.kingSquare(state, color)
    for square, piece in pairs(state.board or {}) do
        if piece.c == color and piece.t == "k" then
            return square
        end
    end

    return nil
end

function ChessEngine.inCheck(state, color)
    local kingSquare = ChessEngine.kingSquare(state, color)
    if not kingSquare then
        return false
    end

    return ChessEngine.isAttacked(state, kingSquare, ChessEngine.other(color))
end

function ChessEngine._AddStepMove(state, moves, fromSquare, file, rank, ownColor)
    local toSquare = ChessEngine.toSq(file, rank)
    if not toSquare then
        return
    end

    local targetPiece = state.board[toSquare]
    if not targetPiece then
        ChessEngine._AddMove(moves, fromSquare, toSquare, "quiet")
    elseif targetPiece.c ~= ownColor then
        ChessEngine._AddMove(moves, fromSquare, toSquare, "capture")
    end
end

function ChessEngine._AddSlidingMoves(state, moves, fromSquare, fromFile, fromRank, ownColor, directions)
    for _, direction in ipairs(directions) do
        local file = fromFile + direction[1]
        local rank = fromRank + direction[2]

        while ChessEngine._OnBoard(file, rank) do
            local toSquare = ChessEngine.toSq(file, rank)
            local targetPiece = state.board[toSquare]

            if not targetPiece then
                ChessEngine._AddMove(moves, fromSquare, toSquare, "quiet")
            else
                if targetPiece.c ~= ownColor then
                    ChessEngine._AddMove(moves, fromSquare, toSquare, "capture")
                end
                break
            end

            file = file + direction[1]
            rank = rank + direction[2]
        end
    end
end

function ChessEngine._PseudoMoves(state, fromSquare)
    local piece = state.board[fromSquare]
    if not piece then
        return {}
    end

    local moves = {}
    local fromFile, fromRank = ChessEngine.toFR(fromSquare)
    local ownColor = piece.c
    local enemyColor = ChessEngine.other(ownColor)

    if piece.t == "p" then
        local direction = ownColor == "w" and 1 or -1
        local startRank = ownColor == "w" and 2 or 7
        local promotionRank = ownColor == "w" and 8 or 1
        local oneStepSquare = ChessEngine.toSq(fromFile, fromRank + direction)

        if oneStepSquare and not state.board[oneStepSquare] then
            if fromRank + direction == promotionRank then
                ChessEngine._AddMove(moves, fromSquare, oneStepSquare, "promo", "q")
            else
                ChessEngine._AddMove(moves, fromSquare, oneStepSquare, "push")
            end

            local twoStepSquare = ChessEngine.toSq(fromFile, fromRank + direction * 2)
            if fromRank == startRank and twoStepSquare and not state.board[twoStepSquare] then
                ChessEngine._AddMove(moves, fromSquare, twoStepSquare, "double")
            end
        end

        for _, fileOffset in ipairs({ -1, 1 }) do
            local captureSquare = ChessEngine.toSq(fromFile + fileOffset, fromRank + direction)
            if captureSquare then
                local targetPiece = state.board[captureSquare]
                if targetPiece and targetPiece.c == enemyColor then
                    if fromRank + direction == promotionRank then
                        ChessEngine._AddMove(moves, fromSquare, captureSquare, "promo", "q")
                    else
                        ChessEngine._AddMove(moves, fromSquare, captureSquare, "capture")
                    end
                elseif captureSquare == state.enPassant then
                    ChessEngine._AddMove(moves, fromSquare, captureSquare, "enpassant")
                end
            end
        end
    elseif piece.t == "n" then
        for _, offset in ipairs(KNIGHT_OFFSETS) do
            ChessEngine._AddStepMove(state, moves, fromSquare, fromFile + offset[1], fromRank + offset[2], ownColor)
        end
    elseif piece.t == "k" then
        for _, offset in ipairs(KING_DIRECTIONS) do
            ChessEngine._AddStepMove(state, moves, fromSquare, fromFile + offset[1], fromRank + offset[2], ownColor)
        end

        local homeRank = ownColor == "w" and 1 or 8
        local kingSideRight = ownColor == "w" and state.castling.wk or state.castling.bk
        local queenSideRight = ownColor == "w" and state.castling.wq or state.castling.bq
        local kingSquare = ChessEngine.toSq(5, homeRank)
        local kingSideRook = state.board[ChessEngine.toSq(8, homeRank)]
        local queenSideRook = state.board[ChessEngine.toSq(1, homeRank)]

        if fromSquare == kingSquare and not ChessEngine.inCheck(state, ownColor) then
            if kingSideRight
                and kingSideRook and kingSideRook.c == ownColor and kingSideRook.t == "r"
                and not state.board[ChessEngine.toSq(6, homeRank)]
                and not state.board[ChessEngine.toSq(7, homeRank)]
                and not ChessEngine.isAttacked(state, ChessEngine.toSq(6, homeRank), enemyColor)
                and not ChessEngine.isAttacked(state, ChessEngine.toSq(7, homeRank), enemyColor) then
                ChessEngine._AddMove(moves, fromSquare, ChessEngine.toSq(7, homeRank), "castle_k")
            end

            if queenSideRight
                and queenSideRook and queenSideRook.c == ownColor and queenSideRook.t == "r"
                and not state.board[ChessEngine.toSq(4, homeRank)]
                and not state.board[ChessEngine.toSq(3, homeRank)]
                and not state.board[ChessEngine.toSq(2, homeRank)]
                and not ChessEngine.isAttacked(state, ChessEngine.toSq(4, homeRank), enemyColor)
                and not ChessEngine.isAttacked(state, ChessEngine.toSq(3, homeRank), enemyColor) then
                ChessEngine._AddMove(moves, fromSquare, ChessEngine.toSq(3, homeRank), "castle_q")
            end
        end
    elseif piece.t == "b" then
        ChessEngine._AddSlidingMoves(state, moves, fromSquare, fromFile, fromRank, ownColor, BISHOP_DIRECTIONS)
    elseif piece.t == "r" then
        ChessEngine._AddSlidingMoves(state, moves, fromSquare, fromFile, fromRank, ownColor, ROOK_DIRECTIONS)
    elseif piece.t == "q" then
        ChessEngine._AddSlidingMoves(state, moves, fromSquare, fromFile, fromRank, ownColor, BISHOP_DIRECTIONS)
        ChessEngine._AddSlidingMoves(state, moves, fromSquare, fromFile, fromRank, ownColor, ROOK_DIRECTIONS)
    end

    return moves
end

function ChessEngine._ClearCastlingForRookSquare(state, square)
    if square == "a1" then
        state.castling.wq = false
    elseif square == "h1" then
        state.castling.wk = false
    elseif square == "a8" then
        state.castling.bq = false
    elseif square == "h8" then
        state.castling.bk = false
    end
end

function ChessEngine.apply(state, move, promotionOverride)
    local nextState = ChessEngine.clone(state)
    local movingPiece = nextState.board[move.from]
    if not movingPiece then
        return nextState, nil
    end

    local fromFile, fromRank = ChessEngine.toFR(move.from)
    local toFile, toRank = ChessEngine.toFR(move.to)
    local capturedPiece = nextState.board[move.to]

    nextState.enPassant = nil
    nextState.board[move.to] = movingPiece
    nextState.board[move.from] = nil

    if move.flag == "double" then
        nextState.enPassant = ChessEngine.toSq(fromFile, math.floor((fromRank + toRank) / 2))
    elseif move.flag == "enpassant" then
        local capturedSquare = ChessEngine.toSq(toFile, fromRank)
        capturedPiece = nextState.board[capturedSquare]
        nextState.board[capturedSquare] = nil
    elseif move.flag == "promo" then
        nextState.board[move.to] = { c = movingPiece.c, t = promotionOverride or move.promo or "q" }
    elseif move.flag == "castle_k" then
        local rookFrom = ChessEngine.toSq(8, fromRank)
        local rookTo = ChessEngine.toSq(6, fromRank)
        nextState.board[rookTo] = nextState.board[rookFrom]
        nextState.board[rookFrom] = nil
    elseif move.flag == "castle_q" then
        local rookFrom = ChessEngine.toSq(1, fromRank)
        local rookTo = ChessEngine.toSq(4, fromRank)
        nextState.board[rookTo] = nextState.board[rookFrom]
        nextState.board[rookFrom] = nil
    end

    if movingPiece.t == "k" then
        if movingPiece.c == "w" then
            nextState.castling.wk = false
            nextState.castling.wq = false
        else
            nextState.castling.bk = false
            nextState.castling.bq = false
        end
    end

    ChessEngine._ClearCastlingForRookSquare(nextState, move.from)
    ChessEngine._ClearCastlingForRookSquare(nextState, move.to)

    if movingPiece.t == "p" or capturedPiece then
        nextState.halfmove = 0
    else
        nextState.halfmove = (nextState.halfmove or 0) + 1
    end

    if movingPiece.c == "b" then
        nextState.fullmove = (nextState.fullmove or 1) + 1
    end

    nextState.turn = ChessEngine.other(movingPiece.c)
    return nextState, capturedPiece
end

function ChessEngine.legalMoves(state, fromSquare)
    local piece = state.board[fromSquare]
    if not piece or piece.c ~= state.turn then
        return {}
    end

    local moves = {}
    for _, move in ipairs(ChessEngine._PseudoMoves(state, fromSquare)) do
        local nextState = ChessEngine.apply(state, move, move.promo)
        if not ChessEngine.inCheck(nextState, piece.c) then
            moves[#moves + 1] = move
        end
    end

    return moves
end

function ChessEngine.allLegalMoves(state)
    local moves = {}

    for square, piece in pairs(state.board or {}) do
        if piece.c == state.turn then
            for _, move in ipairs(ChessEngine.legalMoves(state, square)) do
                moves[#moves + 1] = move
            end
        end
    end

    return moves
end

function ChessEngine.findMove(state, fromSquare, toSquare, promotion)
    for _, move in ipairs(ChessEngine.legalMoves(state, fromSquare)) do
        if move.to == toSquare then
            if move.flag == "promo" and promotion then
                move.promo = promotion
            end
            return move
        end
    end

    return nil
end

function ChessEngine.status(state)
    local hasLegalMove = #ChessEngine.allLegalMoves(state) > 0
    local inCheck = ChessEngine.inCheck(state, state.turn)

    if not hasLegalMove then
        return inCheck and "checkmate" or "stalemate"
    end

    return inCheck and "check" or "ongoing"
end

function ChessEngine.serialize(state)
    local board = {}

    for square, piece in pairs(state.board or {}) do
        board[square] = piece.c .. piece.t
    end

    return board
end

return ChessEngine
