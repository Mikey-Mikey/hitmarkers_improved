local markerHistory = {}

HITMARKERS_IMPROVED = HITMARKERS_IMPROVED or {}

HITMARKERS_IMPROVED.CVARS = {
    markersEnabled = CreateClientConVar( "hitmarkers_enabled" , "1", true, true, "enable/disable hitmarkers"),
    markersOneOnly = CreateClientConVar( "hitmarkers_oneonly" , "1", true, true, "show only one hitmarker at a time"),
    markersOffsetAngle = CreateClientConVar( "hitmarkers_offset_angle" , "45", true, true, "offset angle of hitmarkers in degrees"),
    markersCount = CreateClientConVar( "hitmarkers_count" , "4", true, true, "number of hitmarkers to show around the crosshair", 1, 360 ),
    markersLifetime = CreateClientConVar( "hitmarkers_lifetime" , "0.5", true, true, "lifetime of hitmarkers in seconds"),
    markersLength = CreateClientConVar( "hitmarkers_length" , "20", true, true, "length of hitmarkers"),
    markersWidth = CreateClientConVar( "hitmarkers_width" , "60", true, true, "width of hitmarkers"),
    markersSpacing = CreateClientConVar( "hitmarkers_spacing" , "10", true, true, "spacing of hitmarkers"),
    markersRotSpeed = CreateClientConVar( "hitmarkers_rotation_speed" , "0", true, true, "rotation speed of hitmarkers"),
    markersSpreadSpeed = CreateClientConVar( "hitmarkers_spread_speed" , "0", true, true, "spread speed of hitmarkers"),
    markersColor = CreateClientConVar( "hitmarkers_color" , "255 255 255", true, true, "color of hitmarkers in RGB format"),
    markersVolume = CreateClientConVar( "hitmarkers_volume" , "1", true, true, "volume of hitmarkers"),
    markersSound = CreateClientConVar( "hitmarkers_sound" , "hitmarkers_improved/hitmarker.ogg", true, true, "sound of hitmarkers"),
    markersHeadSound = CreateClientConVar( "hitmarkers_head_sound" , "hitmarkers_improved/hitmarker_head.ogg", true, true, "sound of headshot hitmarkers"),
    markersKillSound = CreateClientConVar( "hitmarkers_kill_sound" , "hitmarkers_improved/hitmarker_kill.ogg", true, true, "sound of kill hitmarkers"),
    armorEnabled = CreateClientConVar( "hitmarkers_armor_enabled" , "1", true, true, "enable/disable armor symbol"),
    armorX = CreateClientConVar( "hitmarkers_armor_x" , "-0.05", true, true, "x offset of armor symbol" ),
    armorY = CreateClientConVar( "hitmarkers_armor_y" , "0", true, true, "y offset of armor symbol" ),
}


local DEG2RAD = math.pi / 180

local basicHitmarkerMat = Material( "hitmarkers_improved/basic_hitmarker.png"  )
local redHitmarkerMat = Material( "hitmarkers_improved/red_hitmarker.png"  )
local armorMat = Material( "hitmarkers_improved/armor_symbol.png"  )

local function playSound( soundPath, volume )
    sound.PlayFile( "sound/" .. soundPath , "noplay noblock", function( obj )
        if IsValid( obj ) then
            obj:SetVolume( volume )
            obj:Play()
        end
    end )
end


local dmgAccumulated = 0
local dmgAccumLife = 0

local dmgFrame = 0

net.Receive("HitmarkersImproved.Hit", function()
    local dmgTook = net.ReadUInt( 16 )
    local headshot = net.ReadBool()
    local death = net.ReadBool()
    local hadArmor = net.ReadBool()

    dmgAccumulated = dmgAccumulated + dmgTook

    if dmgFrame == FrameNumber() then return end

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
        dmgTook = dmgTook,
        headshot = headshot,
        hadArmor = hadArmor,
        death = death,
        rotationDir = math.random() < 0.5 and -1 or 1,
        life = 1,
        angle = 0,
        spread = 0,
        lifetime = HITMARKERS_IMPROVED.CVARS.markersLifetime:GetFloat(),
    } )

    dmgAccumLife = 1
    dmgFrame = FrameNumber()
end )

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
    local color = HITMARKERS_IMPROVED.CVARS.markersColor:GetString()

    local r, g, b = string.match( color, "(%d+) (%d+) (%d+)" )
    r, g, b = tonumber( r ), tonumber( g ), tonumber( b )

    for i = #markerHistory, 1, -1 do
        local markerData = markerHistory[i]
        local hadArmor = markerData.hadArmor and HITMARKERS_IMPROVED.CVARS.armorEnabled:GetBool()

        if hadArmor then
            surface.SetDrawColor( 0, 127, 255, markerData.life * 255 )
        else
            surface.SetDrawColor( r, g, b, markerData.life * 255 )
        end

        if markerData.headshot and not hadArmor then
            surface.SetMaterial( redHitmarkerMat )
        else
            surface.SetMaterial( basicHitmarkerMat )
        end
        -- Marker Drawing --
        for a = 0, count do
            if a == 0 then continue end
            local ang = a * 360 / count + angleOffset + markerData.angle
            local x, y = math.cos( ang * DEG2RAD ), math.sin( ang * DEG2RAD )

            if markerData.death then
                local offX, offY = math.cos( ( ang + 90 ) * DEG2RAD ), math.sin( ( ang + 90 ) * DEG2RAD )

                local sideSpacing = width * 0.05

                surface.DrawTexturedRectRotated(
                    scrW * 0.5 - ( x * ( spacing + length * 0.5 + markerData.spread ) - offX * sideSpacing ) * screenRatio,
                    scrH * 0.5 - ( y * ( spacing + length * 0.5 + markerData.spread ) - offY * sideSpacing ) * screenRatio,
                    length * screenRatio,
                    width * screenRatio,
                    -ang
                )

                surface.DrawTexturedRectRotated(
                    scrW * 0.5 - ( x * ( spacing + length * 0.5 + markerData.spread ) + offX * sideSpacing ) * screenRatio,
                    scrH * 0.5 - ( y * ( spacing + length * 0.5 + markerData.spread ) + offY * sideSpacing ) * screenRatio,
                    length * screenRatio,
                    width * screenRatio,
                    -ang
                )
            else
                surface.DrawTexturedRectRotated(
                    scrW * 0.5 - x * ( spacing + length * 0.5 + markerData.spread ) * screenRatio,
                    scrH * 0.5 - y * ( spacing + length * 0.5 + markerData.spread ) * screenRatio,
                    length * screenRatio,
                    width * screenRatio,
                    -ang
                )
            end

            
        end

        -- Armor Drawing --
        if hadArmor then
            surface.SetDrawColor( 0, 127, 255, 255 * markerData.life )
            surface.SetMaterial( armorMat )
            surface.DrawTexturedRectRotated(
                scrW * 0.5 + HITMARKERS_IMPROVED.CVARS.armorX:GetFloat() * scrW * 0.5,
                scrH * 0.5 + HITMARKERS_IMPROVED.CVARS.armorY:GetFloat() * scrH * 0.5,
                32 * screenRatio,
                32 * screenRatio,
                0
            )
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
    surface.SetFont( "HudHintTextLarge" )

    surface.SetTextColor( 255, 0, 0, 255 * dmgAccumLife )

    local textW, textH = surface.GetTextSize( tostring( dmgAccumulated ) )

    surface.SetTextPos( scrW * 0.5 + 32 * screenRatio, scrH * 0.5 - textH * 0.5 )
    surface.DrawText( tostring( dmgAccumulated ) )

    dmgAccumLife = dmgAccumLife - FrameTime() / HITMARKERS_IMPROVED.CVARS.markersLifetime:GetFloat()

    if dmgAccumLife <= 0 then
        dmgAccumulated = 0
    end
end)