Raycast = {}

local activeCamera = nil
local cameraTableId = nil
local selectedSquare = nil
local legalTargets = {}
local pendingPromotion = nil
local cameraOverride = nil

function Raycast._CameraSettings()
    if not cameraOverride then
        return Config.Camera
    end

    return {
        height = cameraOverride.height or Config.Camera.height,
        distance = cameraOverride.distance or Config.Camera.distance,
        fov = cameraOverride.fov or Config.Camera.fov,
        dragLift = Config.Camera.dragLift,
    }
end

function Raycast._Dot(left, right)
    return left.x * right.x + left.y * right.y + left.z * right.z
end

function Raycast._Normalize(value)
    local length = #value
    if length < 0.000001 then
        return value
    end

    return value / length
end

function Raycast._RotationToDirection(rotation)
    local pitch = math.rad(rotation.x)
    local yaw = math.rad(rotation.z)
    local pitchScale = math.abs(math.cos(pitch))

    return vector3(-math.sin(yaw) * pitchScale, math.cos(yaw) * pitchScale, math.sin(pitch))
end

function Raycast._PlayerTurnColor()
    return CGame.color == "white" and "w" or "b"
end

function Raycast._CanMove(snapshot)
    return snapshot
        and snapshot.status == "playing"
        and snapshot.turn == Raycast._PlayerTurnColor()
end

function Raycast._SnapshotToState(snapshot)
    local board = {}

    for square, pieceCode in pairs(snapshot.board or {}) do
        board[square] = {
            c = pieceCode:sub(1, 1),
            t = pieceCode:sub(2, 2),
        }
    end

    return {
        board = board,
        turn = snapshot.turn,
        castling = snapshot.castling or { wk = false, wq = false, bk = false, bq = false },
        enPassant = snapshot.ep,
        halfmove = 0,
        fullmove = 1,
    }
end

function Raycast._BoardUpVector(boardEntity)
    return Raycast._Normalize(GetOffsetFromEntityInWorldCoords(boardEntity, 0.0, 0.0, 1.0) - GetEntityCoords(boardEntity))
end

function Raycast._BoardPlaneHit(boardEntity)
    local origin = activeCamera and GetCamCoord(activeCamera) or GetGameplayCamCoord()
    local rotation = activeCamera and GetCamRot(activeCamera, 2) or GetGameplayCamRot(2)
    local direction = Raycast._RotationToDirection(rotation)
    local boardCoords = GetEntityCoords(boardEntity)
    local normal = Raycast._BoardUpVector(boardEntity)
    local denominator = Raycast._Dot(direction, normal)

    if math.abs(denominator) < 0.0001 then
        return nil
    end

    local distance = Raycast._Dot(boardCoords - origin, normal) / denominator
    if distance < 0.0 or distance > 20.0 then
        return nil
    end

    return origin + direction * distance
end

function Raycast._WorldToSquare(boardEntity, worldCoords)
    local localCoords = GetOffsetFromEntityGivenWorldCoords(boardEntity, worldCoords.x, worldCoords.y, worldCoords.z)
    local file = math.floor(((localCoords.x - Config.Board.a1Offset.x) / Config.Board.step) + 1.5)
    local rank = math.floor(((localCoords.y - Config.Board.a1Offset.y) / Config.Board.step) + 1.5)

    return ChessEngine.toSq(file, rank)
end

function Raycast._SquareWorld(boardEntity, square)
    local offset = Sync.SquareLocal(square)
    return GetOffsetFromEntityInWorldCoords(
        boardEntity,
        offset.x,
        offset.y,
        offset.z + Config.Interact.markerZ
    )
end

function Raycast._CurrentSquare()
    local boardEntity = CGame.BoardEntity(CGame.current)
    if not boardEntity or not DoesEntityExist(boardEntity) then
        return nil, nil, nil
    end

    local hitCoords = Raycast._BoardPlaneHit(boardEntity)
    if not hitCoords then
        return nil, nil, boardEntity
    end

    return Raycast._WorldToSquare(boardEntity, hitCoords), hitCoords, boardEntity
end

function Raycast._LegalTargetMap(fromSquare)
    local targets = {}
    if not CGame.snapshot or not CGame.snapshot.board then
        return targets
    end

    local state = Raycast._SnapshotToState(CGame.snapshot)
    for _, move in ipairs(ChessEngine.legalMoves(state, fromSquare)) do
        targets[move.to] = move
    end

    return targets
end

function Raycast._ClearSelection()
    selectedSquare = nil
    legalTargets = {}
    pendingPromotion = nil
    if Sync then
        Sync.EndDrag(false)
    end
end

function Raycast._SubmitMove(fromSquare, toSquare, promotion)
    TriggerServerEvent("peak-chess:move", CGame.current, fromSquare, toSquare, promotion)
    CGame.PlayMoveAnim()
    Sync.EndDrag(true)
    selectedSquare = nil
    legalTargets = {}
    pendingPromotion = nil
    Sound.Play("move")
end

function Raycast._SelectSquare(square)
    if not Raycast._CanMove(CGame.snapshot) or not square then
        return
    end

    local pieceCode = CGame.snapshot.board and CGame.snapshot.board[square]

    if not selectedSquare then
        if not pieceCode or pieceCode:sub(1, 1) ~= Raycast._PlayerTurnColor() then
            return
        end

        selectedSquare = square
        legalTargets = Raycast._LegalTargetMap(square)
        Sync.BeginDrag(CGame.current, square)
        Sound.Play("grab")
        return
    end

    local move = legalTargets[square]
    if move then
        if move.flag == "promo" then
            pendingPromotion = {
                from = selectedSquare,
                to = square,
            }
            NUI.OpenPromotion()
        else
            Raycast._SubmitMove(selectedSquare, square, nil)
        end
        return
    end

    if pieceCode and pieceCode:sub(1, 1) == Raycast._PlayerTurnColor() then
        Sync.EndDrag(false)
        selectedSquare = square
        legalTargets = Raycast._LegalTargetMap(square)
        Sync.BeginDrag(CGame.current, square)
        Sound.Play("grab")
        return
    end

    Raycast._ClearSelection()
end

function Raycast._DrawSquareMarker(boardEntity, square, color)
    local coords = Raycast._SquareWorld(boardEntity, square)
    DrawMarker(
        28,
        coords.x,
        coords.y,
        coords.z,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        Config.Board.step * 0.45,
        Config.Board.step * 0.45,
        0.004,
        color[1],
        color[2],
        color[3],
        color[4],
        false,
        false,
        2,
        false,
        nil,
        nil,
        false
    )
end

function Raycast._DrawMarkers(boardEntity, hoverSquare)
    if CGame.snapshot and CGame.snapshot.lastMove then
        Raycast._DrawSquareMarker(boardEntity, CGame.snapshot.lastMove.from, Config.Interact.colors.lastMove)
        Raycast._DrawSquareMarker(boardEntity, CGame.snapshot.lastMove.to, Config.Interact.colors.lastMove)
    end

    if selectedSquare then
        Raycast._DrawSquareMarker(boardEntity, selectedSquare, Config.Interact.colors.selected)

        for square, move in pairs(legalTargets) do
            local color = (move.flag == "capture" or move.flag == "enpassant") and Config.Interact.colors.capture or Config.Interact.colors.legal
            Raycast._DrawSquareMarker(boardEntity, square, color)
        end
    end

    if hoverSquare then
        Raycast._DrawSquareMarker(boardEntity, hoverSquare, Config.Interact.colors.hover)
    end
end

function Raycast.StopCam()
    if activeCamera then
        RenderScriptCams(false, true, 400, true, true)
        DestroyCam(activeCamera, false)
        activeCamera = nil
        cameraTableId = nil
    end
end

function Raycast.RefreshCam()
    if not CGame.current then
        return
    end

    local boardEntity = CGame.BoardEntity(CGame.current)
    if not boardEntity or not DoesEntityExist(boardEntity) then
        return
    end

    local settings = Raycast._CameraSettings()
    local sideDistance = CGame.color == "black" and settings.distance or -settings.distance
    local cameraCoords = GetOffsetFromEntityInWorldCoords(boardEntity, 0.0, sideDistance, settings.height)
    local targetCoords = GetEntityCoords(boardEntity)

    if not activeCamera or cameraTableId ~= CGame.current then
        Raycast.StopCam()
        activeCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        cameraTableId = CGame.current
        RenderScriptCams(true, true, 400, true, true)
    end

    SetCamFov(activeCamera, settings.fov)
    SetCamCoord(activeCamera, cameraCoords.x, cameraCoords.y, cameraCoords.z)
    PointCamAtCoord(activeCamera, targetCoords.x, targetCoords.y, targetCoords.z)
end

function Raycast.SetCamOverride(settings)
    cameraOverride = settings
    Raycast.RefreshCam()
end

function Raycast.CompletePromo(piece)
    if pendingPromotion then
        Raycast._SubmitMove(pendingPromotion.from, pendingPromotion.to, piece or "q")
    end
end

function Raycast.CancelPromo()
    pendingPromotion = nil
    Raycast._ClearSelection()
end

CreateThread(function()
    while true do
        local waitMs = 500

        if CGame.seated and CGame.snapshot and CGame.snapshot.status == "playing" then
            waitMs = 0
            Raycast.RefreshCam()

            DisableControlAction(0, Config.Interact.selectKey, true)
            DisableControlAction(0, Config.Interact.cancelKey, true)

            local hoverSquare, hitCoords, boardEntity = Raycast._CurrentSquare()
            if boardEntity then
                Raycast._DrawMarkers(boardEntity, hoverSquare)
            end

            if selectedSquare and hitCoords then
                local settings = Raycast._CameraSettings()
                Sync.DragGhostTo(vector3(hitCoords.x, hitCoords.y, hitCoords.z + (settings.dragLift or 0.03)))
            end

            if IsDisabledControlJustReleased(0, Config.Interact.selectKey) then
                Raycast._SelectSquare(hoverSquare)
            elseif IsDisabledControlJustReleased(0, Config.Interact.cancelKey) then
                Raycast._ClearSelection()
                Sound.Play("select")
            end
        else
            if activeCamera then
                Raycast.StopCam()
            end
            Raycast._ClearSelection()
        end

        Wait(waitMs)
    end
end)
