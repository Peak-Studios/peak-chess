Sound = {}

function Sound.Play(soundKey)
    if not Config.Sound or not Config.Sound.enabled then
        return
    end

    local sound = Config.Sound[soundKey]
    if not sound then
        return
    end

    PlaySoundFrontend(-1, sound[1], sound[2], true)
end
