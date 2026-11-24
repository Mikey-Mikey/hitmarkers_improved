HITMARKERS_IMPROVED = HITMARKERS_IMPROVED or {}
HITMARKERS_IMPROVED.CVARS = {}

local cfg = {}

local cvarReaders = {
    bool = function( cvar ) return cvar:GetBool() end,
    int = function( cvar ) return cvar:GetInt() end,
    float = function( cvar ) return cvar:GetFloat() end,
    string = function( cvar ) return cvar:GetString() end,
    color = function( cvar ) return string.ToColor( cvar:GetString() ) end,
}

local function AddConVar( key, kind, name, default, help, min, max )
    local cvar = CreateClientConVar( name, default, true, false, help, min, max )
    local read = cvarReaders[kind]

    HITMARKERS_IMPROVED.CVARS[key] = cvar
    cfg[key] = read( cvar )

    cvars.AddChangeCallback( name, function() cfg[key] = read( cvar ) end, "HitmarkersImprovedCache" )
end

AddConVar( "markersEnabled", "bool", "hitmarkers_enabled", "1", "enable/disable hitmarkers" )
AddConVar( "markersOneOnly", "bool", "hitmarkers_oneonly", "1", "show only one hitmarker at a time" )
AddConVar( "markersOffsetAngle", "float", "hitmarkers_offset_angle", "45", "offset angle of hitmarkers in degrees" )
AddConVar( "markersCount", "int", "hitmarkers_count", "4", "number of hitmarkers to show around the crosshair", 1, 360 )
AddConVar( "markersLifetime", "float", "hitmarkers_lifetime", "0.5", "lifetime of hitmarkers in seconds" )
AddConVar( "markersLength", "float", "hitmarkers_length", "20", "length of hitmarkers" )
AddConVar( "markersWidth", "float", "hitmarkers_width", "60", "width of hitmarkers" )
AddConVar( "markersSpacing", "float", "hitmarkers_spacing", "10", "spacing of hitmarkers" )
AddConVar( "markersRotSpeed", "float", "hitmarkers_rotation_speed", "0", "rotation speed of hitmarkers" )
AddConVar( "markersSpreadSpeed", "float", "hitmarkers_spread_speed", "0", "spread speed of hitmarkers" )
AddConVar( "markersColor", "color", "hitmarkers_color", "255 255 255", "color of hitmarkers in RGB format" )
AddConVar( "markersHeadshotColor", "color", "hitmarkers_headshot_color", "255 255 255", "color of headshot hitmarkers in RGB format" )
AddConVar( "markersKillColor", "color", "hitmarkers_kill_color", "255 0 0", "color of kill hitmarkers in RGB format" )
AddConVar( "markersVolume", "float", "hitmarkers_volume", "1", "volume of hitmarkers" )
AddConVar( "markersSound", "string", "hitmarkers_sound", "hitmarkers_improved/hitmarker.ogg", "sound of hitmarkers" )
AddConVar( "markersHeadSound", "string", "hitmarkers_head_sound", "hitmarkers_improved/hitmarker_head.ogg", "sound of headshot hitmarkers" )
AddConVar( "markersKillSound", "string", "hitmarkers_kill_sound", "hitmarkers_improved/hitmarker_kill.ogg", "sound of kill hitmarkers" )
AddConVar( "armorEnabled", "bool", "hitmarkers_armor_enabled", "1", "enable/disable armor indication" )
AddConVar( "armorSymbol", "bool", "hitmarkers_armor_symbol", "0", "enable/disable armor symbol" )
AddConVar( "armorX", "float", "hitmarkers_armor_x", "-0.05", "x offset of armor symbol" )
AddConVar( "armorY", "float", "hitmarkers_armor_y", "0", "y offset of armor symbol" )
AddConVar( "fontSize", "float", "hitmarkers_fontsize", "8", "size of the damage text" )
AddConVar( "numbersWorldSpace", "bool", "hitmarkers_worldspace_numbers", "0", "show the damage numbers in worldspace" )
AddConVar( "numberOutline", "bool", "hitmarkers_number_outline", "1", "enable/disable outlines on the damage numbers" )
AddConVar( "numberOutlineColor", "color", "hitmarkers_number_outlinecolor", "0 0 0 50", "outline color for the damage numbers" )

local function CreateMarkerFont()
    local n = HITMARKERS_IMPROVED.CVARS.fontSize:GetFloat() -- read directly: callback order vs. the cfg cache isn't guaranteed
    if n <= 0 then n = 8 end

    surface.CreateFont("hitmarkers_improved_markerfont", {
        font = "Oxanium ExtraLight",
        weight = 300,
        size = ScreenScaleH(n)
    })
end

CreateMarkerFont()

cvars.AddChangeCallback("hitmarkers_fontsize", CreateMarkerFont, "HitmarkersImprovedFont")
hook.Add("OnScreenSizeChanged", "HitmarkersImprovedFont", CreateMarkerFont)


local DEG2RAD = math.pi / 180

local basicHitmarkerMat = Material( "hitmarkers_improved/basic_hitmarker.png"  )
local headshotHitmarkerInsideMat = Material( "hitmarkers_improved/hitmarker_inside.png"  )
local armorMat = Material( "hitmarkers_improved/armor_symbol.png"  )

local function playSound( soundPath, volume )
    sound.PlayFile( "sound/" .. soundPath, "noplay noblock", function( obj )
        if IsValid( obj ) then
            obj:SetVolume( volume )
            obj:Play()
        end
    end )
end


local dmgFrame = 0

local dmgNumTable = {}

local function GetDamageNumber(entID)
    for i = #dmgNumTable, 1, -1 do
        if dmgNumTable[i].entID == entID then
            return dmgNumTable[i]
        end
    end
end

local function AddDamageNumber(dmg, entID, death, dmgPos)
    if #dmgNumTable > 6 and dmgNumTable[#dmgNumTable] then
        dmgNumTable[#dmgNumTable].shouldRemove = true
    end

    local oldNumber = GetDamageNumber(entID)


    if oldNumber then
        oldNumber.life = 1
        oldNumber.dmg = oldNumber.dmg + dmg
        oldNumber.dmgPos = dmgPos
        oldNumber.death = death
    else
        table.insert( dmgNumTable, 1, {
            entID = entID,
            dmg = dmg,
            dmgPos = dmgPos,
            death = death,
            life = 1,
            shouldRemove = false
        } )
    end
end

local markerHistory = {}
net.Receive("hitmarkers_improved_hit", function()
    local dmgTook = net.ReadUInt( 16 )
    local headshot = net.ReadBool()
    local death = net.ReadBool()
    local hadArmor = net.ReadBool()
    local entID = net.ReadUInt(4) -- per-attacker target slot, must match SLOT_BITS on the server
    local dmgPos = net.ReadVector()

    AddDamageNumber(dmgTook, entID, death, dmgPos)

    -- Multiple hits in one frame (shotgun pellets): merge into the last marker
    -- so a kill/headshot from a later pellet isn't lost.
    if dmgFrame == FrameNumber() then
        local last = markerHistory[#markerHistory]
        if last then
            if death and not last.death then
                playSound( cfg.markersKillSound, cfg.markersVolume )
            elseif headshot and not last.headshot and not last.death then
                playSound( cfg.markersHeadSound, cfg.markersVolume )
            end
            last.death = last.death or death
            last.headshot = last.headshot or headshot
            last.hadArmor = last.hadArmor or hadArmor
        end
        return
    end

    if death then
        playSound( cfg.markersKillSound, cfg.markersVolume )
    elseif headshot then
        playSound( cfg.markersHeadSound, cfg.markersVolume )
    else
        playSound( cfg.markersSound, cfg.markersVolume )
    end

    if cfg.markersOneOnly then
        markerHistory = {}
    end

    table.insert( markerHistory, {
        headshot = headshot,
        hadArmor = hadArmor,
        death = death,
        rotationDir = math.random() < 0.5 and -1 or 1,
        life = 1,
        angle = 0,
        spread = 0,
        lifetime = cfg.markersLifetime,
    } )

    dmgFrame = FrameNumber()
end )

local function DrawHitmarker( x, y, length, width, rotation, headshot )
    surface.SetMaterial( basicHitmarkerMat )
    surface.DrawTexturedRectRotated(
        x,
        y,
        length,
        width,
        rotation
    )
    if headshot then
        local prevColor = surface.GetDrawColor()
        surface.SetMaterial( headshotHitmarkerInsideMat )
        surface.SetDrawColor(255, 255, 255, prevColor.a)
        surface.DrawTexturedRectRotated(
            x,
            y,
            length,
            width,
            rotation
        )
        surface.SetDrawColor(prevColor)
    end
end

local outlineColor = Color( 0, 0, 0 )
hook.Add("HUDPaint", "HitmarkersImprovedHUD", function()
    if not cfg.markersEnabled then return end

    if #markerHistory == 0 and #dmgNumTable == 0 then return end

    local scrW, scrH = ScrW(), ScrH()
    local screenRatio = scrH / 1080
    local count = cfg.markersCount
    local angleOffset = cfg.markersOffsetAngle
    local length = cfg.markersLength
    local width = cfg.markersWidth
    local spacing = cfg.markersSpacing
    local rotSpeed = cfg.markersRotSpeed
    local spreadSpeed = cfg.markersSpreadSpeed
    local color = cfg.markersColor
    local headshotColor = cfg.markersHeadshotColor
    local killColor = cfg.markersKillColor
    local armorEnabled = cfg.armorEnabled
    local worldspaceNumbers = cfg.numbersWorldSpace
    local numberOutline = cfg.numberOutline
    local numberOutlineColor = cfg.numberOutlineColor

    for i = #markerHistory, 1, -1 do
        local markerData = markerHistory[i]
        local hadArmor = markerData.hadArmor and armorEnabled
        local showHeadshot = markerData.headshot
        local death = markerData.death

        local alpha = math.ease.OutQuint(markerData.life) * 255

        if hadArmor then
            surface.SetDrawColor( 0, 127, 255, alpha )
        elseif showHeadshot then
            surface.SetDrawColor( headshotColor.r, headshotColor.g, headshotColor.b, alpha )
        else
            surface.SetDrawColor( color.r, color.g, color.b, alpha )
        end

        if death then
            surface.SetDrawColor( killColor.r, killColor.g, killColor.b, alpha )
        end

        -- Marker Drawing --
        for a = 1, count do
            local ang = a * 360 / count + angleOffset + markerData.angle
            local x, y = math.cos( ang * DEG2RAD ), math.sin( ang * DEG2RAD )

            if showHeadshot then
                local offX, offY = math.cos( ( ang + 90 ) * DEG2RAD ), math.sin( ( ang + 90 ) * DEG2RAD )

                local sideSpacing = width * 0.05

                DrawHitmarker(
                    scrW * 0.5 - ( x * ( spacing + length * 0.5 + markerData.spread ) - offX * sideSpacing ) * screenRatio,
                    scrH * 0.5 - ( y * ( spacing + length * 0.5 + markerData.spread ) - offY * sideSpacing ) * screenRatio,
                    length * screenRatio,
                    width * screenRatio,
                    -ang,
                    showHeadshot
                )

                DrawHitmarker(
                    scrW * 0.5 - ( x * ( spacing + length * 0.5 + markerData.spread ) + offX * sideSpacing ) * screenRatio,
                    scrH * 0.5 - ( y * ( spacing + length * 0.5 + markerData.spread ) + offY * sideSpacing ) * screenRatio,
                    length * screenRatio,
                    width * screenRatio,
                    -ang,
                    showHeadshot
                )
            else
                DrawHitmarker(
                    scrW * 0.5 - x * ( spacing + length * 0.5 + markerData.spread ) * screenRatio,
                    scrH * 0.5 - y * ( spacing + length * 0.5 + markerData.spread ) * screenRatio,
                    length * screenRatio,
                    width * screenRatio,
                    -ang,
                    showHeadshot
                )
            end


        end

        -- Armor Drawing --
        if hadArmor then
            surface.SetDrawColor( 0, 127, 255, alpha )

            if cfg.armorSymbol then
                surface.SetMaterial( armorMat )
                surface.DrawTexturedRectRotated(
                    scrW * 0.5 + cfg.armorX * scrW * 0.5,
                    scrH * 0.5 + cfg.armorY * scrH * 0.5,
                    32 * screenRatio,
                    32 * screenRatio,
                    0
                )
            end
        end

        markerData.life = markerData.life - FrameTime() / math.max( 0.01, markerData.lifetime )
        markerData.angle = markerData.angle + rotSpeed * markerData.rotationDir * FrameTime()
        markerData.spread = markerData.spread + spreadSpeed * FrameTime()

        if markerData.life <= 0 then
            table.remove( markerHistory, i )
        end
    end

    -- Damage Number Drawing --
    draw.NoTexture()
    surface.SetFont( "hitmarkers_improved_markerfont" )

    local dmgYOffset = 0
    for i = #dmgNumTable, 1, -1 do
        local dmgNumber = dmgNumTable[i]
        local death = dmgNumber.death
        local dmgAlpha = math.Remap( 1 - ( 1 - dmgNumber.life )^10, 0.8, 1, 0, 1 ) * 255
        if death then
            surface.SetTextColor( killColor.r, killColor.g, killColor.b, dmgAlpha )
        else
            surface.SetTextColor( color.r, color.g, color.b, dmgAlpha )
        end

        outlineColor.r = numberOutlineColor.r
        outlineColor.g = numberOutlineColor.g
        outlineColor.b = numberOutlineColor.b
        outlineColor.a = numberOutlineColor.a * dmgAlpha / 255

        local screenDmgPos = (dmgNumber.dmgPos):ToScreen()

        local textW, textH = surface.GetTextSize( tostring( dmgNumber.dmg ) )
        if worldspaceNumbers and screenDmgPos.visible then
            draw.SimpleText( tostring( dmgNumber.dmg ), "hitmarkers_improved_markerfont", screenDmgPos.x, screenDmgPos.y, surface.GetTextColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            if numberOutline then
                draw.SimpleTextOutlined( tostring( dmgNumber.dmg ), "hitmarkers_improved_markerfont", screenDmgPos.x, screenDmgPos.y, surface.GetTextColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, outlineColor )
            end
        elseif not worldspaceNumbers then
            draw.SimpleText(
                tostring( dmgNumber.dmg ),
                "hitmarkers_improved_markerfont",
                scrW * 0.5 + 32 * screenRatio, scrH * 0.5 - textH * 0.5 + dmgYOffset,
                surface.GetTextColor(),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )
            if numberOutline then
                draw.SimpleTextOutlined(
                    tostring( dmgNumber.dmg ),
                    "hitmarkers_improved_markerfont",
                    scrW * 0.5 + 32 * screenRatio, scrH * 0.5 - textH * 0.5 + dmgYOffset,
                    surface.GetTextColor(),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                    1, outlineColor
                )
            end
        end

        dmgYOffset = dmgYOffset + textH * ( 1 - ( 1 - dmgNumber.life )^10 )

        dmgNumber.life = math.max( 0, dmgNumber.life - FrameTime() * ( dmgNumber.shouldRemove and 2 or 0.5 ) )

        if dmgNumber.life <= 0 then
            table.remove( dmgNumTable, i )
        end
    end
end)
