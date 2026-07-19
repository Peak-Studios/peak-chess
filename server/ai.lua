ChessAI = {}

local CHECKMATE_SCORE = 1000000
local INFINITY_SCORE = 1000000000
local PIECE_VALUE = {
    p = 100,
    n = 320,
    b = 330,
    r = 500,
    q = 900,
    k = 0,
}

function ChessAI._Evaluate(state)
    local score = 0

    for _, piece in pairs(state.board or {}) do
        local value = PIECE_VALUE[piece.t] or 0
        if piece.c == "w" then
            score = score + value
        else
            score = score - value
        end
    end

    return score
end

function ChessAI._EvaluateForTurn(state)
    local score = ChessAI._Evaluate(state)
    return state.turn == "w" and score or -score
end

function ChessAI._MoveCaptureValue(state, move)
    local capturedPiece = state.board[move.to]

    if move.flag == "enpassant" then
        capturedPiece = { t = "p" }
    end

    return capturedPiece and (PIECE_VALUE[capturedPiece.t] or 0) or 0
end

function ChessAI._OrderMoves(state, moves)
    table.sort(moves, function(leftMove, rightMove)
        return ChessAI._MoveCaptureValue(state, leftMove) > ChessAI._MoveCaptureValue(state, rightMove)
    end)

    return moves
end

function ChessAI._Search(state, depth, alpha, beta, ply, deadline)
    local moves = ChessEngine.allLegalMoves(state)

    if #moves == 0 then
        if ChessEngine.inCheck(state, state.turn) then
            return -CHECKMATE_SCORE + ply
        end
        return 0
    end

    if depth <= 0 then
        return ChessAI._EvaluateForTurn(state)
    end

    ChessAI._OrderMoves(state, moves)

    local bestScore = -INFINITY_SCORE
    for _, move in ipairs(moves) do
        local nextState = ChessEngine.apply(state, move, move.promo)
        local score = -ChessAI._Search(nextState, depth - 1, -beta, -alpha, ply + 1, deadline)

        if score > bestScore then
            bestScore = score
        end

        if bestScore > alpha then
            alpha = bestScore
        end

        if alpha >= beta then
            break
        end

        if deadline and GetGameTimer() > deadline then
            break
        end
    end

    return bestScore
end

function ChessAI.LevelConfig(levelId)
    for _, level in ipairs(Config.AI.levels) do
        if level.id == levelId then
            return level
        end
    end

    return Config.AI.levels[1]
end

function ChessAI.BestMove(state, levelId)
    local level = ChessAI.LevelConfig(levelId)
    local moves = ChessEngine.allLegalMoves(state)

    if #moves == 0 then
        return nil
    end

    if (level.randomness or 0) > 0 and math.random() < level.randomness then
        return moves[math.random(#moves)]
    end

    local deadline = GetGameTimer() + (Config.AI.maxThinkMs or 1500)
    ChessAI._OrderMoves(state, moves)

    local bestMove = moves[1]
    local bestScore = -INFINITY_SCORE
    local searchDepth = math.max(1, level.depth or 1)

    for _, move in ipairs(moves) do
        local nextState = ChessEngine.apply(state, move, move.promo)
        local score = -ChessAI._Search(nextState, searchDepth - 1, -INFINITY_SCORE, INFINITY_SCORE, 1, deadline)

        if score > bestScore then
            bestScore = score
            bestMove = move
        end

        if GetGameTimer() > deadline then
            break
        end
    end

    return bestMove
end
