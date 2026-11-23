local markerHistory = {}

HITMARKERS_IMPROVED = HITMARKERS_IMPROVED or {}

HITMARKERS_IMPROVED.CVARS = {
    markersEnabled = CreateClientConVar( "hitmarkers_enabled", "1", true, false, "enable/disable hitmarkers"),
    markersOneOnly = CreateClientConVar( "hitmarkers_oneonly", "1", true, false, "show only one hitmarker at a time"),
    markersOffsetAngle = CreateClientConVar( "hitmarkers_offset_angle", "45", true, false, "offset angle of hitmarkers in degrees"),
    markersCount = CreateClientConVar( "hitmarkers_count", "4", true, false, "number of hitmarkers to show around the crosshair", 1, 360 ),
    markersLifetime = CreateClientConVar( "hitmarkers_lifetime", "0.5", true, false, "lifetime of hitmarkers in seconds"),
    markersLength = CreateClientConVar( "hitmarkers_length", "20", true, false, "length of hitmarkers"),
    markersWidth = CreateClientConVar( "hitmarkers_width", "60", true, false, "width of hitmarkers"),
    markersSpacing = CreateClientConVar( "hitmarkers_spacing", "10", true, false, "spacing of hitmarkers"),
    markersRotSpeed = CreateClientConVar( "hitmarkers_rotation_speed", "0", true, false, "rotation speed of hitmarkers"),
    markersSpreadSpeed = CreateClientConVar( "hitmarkers_spread_speed", "0", true, false, "spread speed of hitmarkers"),
    markersColor = CreateClientConVar( "hitmarkers_color", "255 255 255", true, false, "color of hitmarkers in RGB format"),
    markersHeadshotColor = CreateClientConVar( "hitmarkers_headshot_color", "255 255 255", true, false, "color of headshot hitmarkers in RGB format"),
    markersKillColor = CreateClientConVar( "hitmarkers_kill_color", "255 0 0", true, false, "color of kill hitmarkers in RGB format"),
    markersVolume = CreateClientConVar( "hitmarkers_volume", "1", true, false, "volume of hitmarkers"),
    markersSound = CreateClientConVar( "hitmarkers_sound", "hitmarkers_improved/hitmarker.ogg", true, false, "sound of hitmarkers"),
    markersHeadSound = CreateClientConVar( "hitmarkers_head_sound", "hitmarkers_improved/hitmarker_head.ogg", true, false, "sound of headshot hitmarkers"),
    markersKillSound = CreateClientConVar( "hitmarkers_kill_sound", "hitmarkers_improved/hitmarker_kill.ogg", true, false, "sound of kill hitmarkers"),
    armorEnabled = CreateClientConVar( "hitmarkers_armor_enabled", "1", true, false, "enable/disable armor indication"),
    armorSymbol = CreateClientConVar( "hitmarkers_armor_symbol", "0", true, false, "enable/disable armor symbol"),
    armorX = CreateClientConVar( "hitmarkers_armor_x", "-0.05", true, false, "x offset of armor symbol" ),
    armorY = CreateClientConVar( "hitmarkers_armor_y", "0", true, false, "y offset of armor symbol" ),
    fontSize = CreateClientConVar( "hitmarkers_fontsize", "8", true, false, "size of the damage text" ),
}

local function CreateMarkerFont()
    local n = HITMARKERS_IMPROVED.CVARS.fontSize:GetFloat()
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

local function AddDamageNumber(dmg, entID, death)
    if #dmgNumTable > 6 and dmgNumTable[#dmgNumTable] then
        dmgNumTable[#dmgNumTable].shouldRemove = true
    end

    local oldNumber = GetDamageNumber(entID)


    if oldNumber then
        oldNumber.life = 1
        oldNumber.dmg = oldNumber.dmg + dmg
        oldNumber.death = death
    else
        table.insert( dmgNumTable, 1, {
            entID = entID,
            dmg = dmg,
            death = death,
            life = 1,
            shouldRemove = false
        } )
    end
end

net.Receive("hitmarkers_improved_hit", function()
    local dmgTook = net.ReadUInt( 16 )
    local headshot = net.ReadBool()
    local death = net.ReadBool()
    local hadArmor = net.ReadBool()
    local entID = net.ReadUInt(4) -- per-attacker target slot, must match SLOT_BITS on the server

    AddDamageNumber(dmgTook, entID, death)

    -- Multiple hits in one frame (shotgun pellets): merge into the last marker
    -- so a kill/headshot from a later pellet isn't lost.
    if dmgFrame == FrameNumber() then
        local last = markerHistory[#markerHistory]
        if last then
            if death and not last.death then
                playSound( HITMARKERS_IMPROVED.CVARS.markersKillSound:GetString(), HITMARKERS_IMPROVED.CVARS.markersVolume:GetFloat() )
            elseif headshot and not last.headshot and not last.death then
                playSound( HITMARKERS_IMPROVED.CVARS.markersHeadSound:GetString(), HITMARKERS_IMPROVED.CVARS.markersVolume:GetFloat() )
            end
            last.death = last.death or death
            last.headshot = last.headshot or headshot
            last.hadArmor = last.hadArmor or hadArmor
        end
        return
    end

    if death then
        playSound( HITMARKERS_IMPROVED.CVARS.markersKillSound:GetString(), HITMARKERS_IMPROVED.CVARS.markersVolume:GetFloat() )
    elseif headshot then
        playSound( HITMARKERS_IMPROVED.CVARS.markersHeadSound:GetString(), HITMARKERS_IMPROVED.CVARS.markersVolume:GetFloat() )
    else
        playSound( HITMARKERS_IMPROVED.CVARS.markersSound:GetString(), HITMARKERS_IMPROVED.CVARS.markersVolume:GetFloat() )
    end

    if HITMARKERS_IMPROVED.CVARS.markersOneOnly:GetBool() then
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
        lifetime = HITMARKERS_IMPROVED.CVARS.markersLifetime:GetFloat(),
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

hook.Add("HUDPaint", "HitmarkersImprovedHUD", function()
    if not HITMARKERS_IMPROVED.CVARS.markersEnabled:GetBool() then return end

    local scrW, scrH = ScrW(), ScrH()
    local screenRatio = ScrH() / 1080
    local count = HITMARKERS_IMPROVED.CVARS.markersCount:GetInt()
    local angleOffset = HITMARKERS_IMPROVED.CVARS.markersOffsetAngle:GetFloat()
    local length = HITMARKERS_IMPROVED.CVARS.markersLength:GetFloat()
    local width = HITMARKERS_IMPROVED.CVARS.markersWidth:GetFloat()
    local spacing = HITMARKERS_IMPROVED.CVARS.markersSpacing:GetFloat()
    local rotSpeed = HITMARKERS_IMPROVED.CVARS.markersRotSpeed:GetFloat()
    local spreadSpeed = HITMARKERS_IMPROVED.CVARS.markersSpreadSpeed:GetFloat()
    local color = string.ToColor( HITMARKERS_IMPROVED.CVARS.markersColor:GetString() )
    local headshotColor = string.ToColor( HITMARKERS_IMPROVED.CVARS.markersHeadshotColor:GetString() )
    local killColor = string.ToColor( HITMARKERS_IMPROVED.CVARS.markersKillColor:GetString() )

    for i = #markerHistory, 1, -1 do
        local markerData = markerHistory[i]
        local hadArmor = markerData.hadArmor and HITMARKERS_IMPROVED.CVARS.armorEnabled:GetBool()
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

            if HITMARKERS_IMPROVED.CVARS.armorSymbol:GetBool() then
                surface.SetMaterial( armorMat )
                surface.DrawTexturedRectRotated(
                    scrW * 0.5 + HITMARKERS_IMPROVED.CVARS.armorX:GetFloat() * scrW * 0.5,
                    scrH * 0.5 + HITMARKERS_IMPROVED.CVARS.armorY:GetFloat() * scrH * 0.5,
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

        local textW, textH = surface.GetTextSize( tostring( dmgNumber.dmg ) )

        surface.SetTextPos( scrW * 0.5 + 32 * screenRatio, scrH * 0.5 - textH * 0.5 + dmgYOffset )
        surface.DrawText( tostring( dmgNumber.dmg ) )

        dmgYOffset = dmgYOffset + textH * ( 1 - ( 1 - dmgNumber.life )^10 )

        dmgNumber.life = math.max( 0, dmgNumber.life - FrameTime() * ( dmgNumber.shouldRemove and 2 or 0.5 ) )

        if dmgNumber.life <= 0 then
            table.remove( dmgNumTable, i )
        end
    end
end)
