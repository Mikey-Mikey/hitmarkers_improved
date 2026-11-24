local function DividerLabel( parent, text )
    local divider = vgui.Create( "DLabel", parent )
    divider:Dock( TOP )
    divider:SetContentAlignment( 5 )
    divider:SetFont( "DermaDefaultBold" )
    divider:SetTextColor( Color( 0, 0, 127, 180 ) )
    divider:DockMargin( 0, 20, 0, -10 )
    divider:SetAutoStretchVertical( true )
    divider:SetText( text )

    return divider
end

local function CreateColorMixer( panel, cvarName )
    local colorMixer = vgui.Create( "DColorMixer", panel )
    colorMixer:Dock( TOP )
    colorMixer:DockMargin( 10, 10, 20, 0 )
    colorMixer:SetLabel("Basic Color")

    function colorMixer:ValueChanged( color )
        local r, g, b = color.r, color.g, color.b
        RunConsoleCommand( cvarName, r .. " " .. g .. " " .. b )
    end

    return colorMixer
end

local last_menu = nil

local function OpenHitmarkersMenu(icon, window)
    if IsValid( last_menu ) then last_menu:Close() end

    window = vgui.Create( "DFrame" )
    window:SetSize( ScrW() * 0.3, ScrH() * 0.9 )
    window:Center()
    window:SetTitle("Hitmarker Settings")
    window:SetSizable(true)
    window:MakePopup()

    last_menu = window

    local scrollPanel = vgui.Create("DScrollPanel", window)
    scrollPanel:Dock(FILL)

    local pan = vgui.Create("ControlPanel", scrollPanel)
    pan:Dock(FILL)

    function pan:Paint( w, h )
        draw.RoundedBox(2, 0, 0, w, h, Color(236, 236, 236))
    end

    pan:SetName( "" )
    pan:SetHeaderHeight(0)

    local presetDefaults = {}
    for _, cvarName in ipairs( {
        "hitmarkers_enabled",
        "hitmarkers_oneonly",

        "hitmarkers_count",
        "hitmarkers_offset_angle",
        "hitmarkers_lifetime",
        "hitmarkers_length",
        "hitmarkers_width",
        "hitmarkers_spacing",
        "hitmarkers_rotation_speed",
        "hitmarkers_spread_speed",
        "hitmarkers_color",
        "hitmarkers_headshot_color",
        "hitmarkers_kill_color",

        "hitmarkers_volume",
        "hitmarkers_sound",
        "hitmarkers_head_sound",
        "hitmarkers_kill_sound",

        "hitmarkers_armor_enabled",
        "hitmarkers_armor_x",
        "hitmarkers_armor_y",

        "hitmarkers_fontsize",
        "hitmarkers_worldspace_numbers",
        "hitmarkers_number_outline",
        "hitmarkers_number_outlinecolor",
    } ) do
        local cvar = GetConVar( cvarName )
        if cvar then presetDefaults[cvarName] = cvar:GetDefault() end
    end

    local presetPanel = pan:ToolPresets( "hitmarkers_presets", presetDefaults )

    pan:CheckBox( "Enable Hitmarkers", "hitmarkers_enabled" )
    pan:CheckBox( "Show Only One Hitmarker At A Time", "hitmarkers_oneonly" )
    pan:CheckBox( "Indicate Armor Damage", "hitmarkers_armor_enabled" )

    DividerLabel( pan, "Hitmarker Settings" )


    pan:NumSlider( "Count", "hitmarkers_count", 1, 360, 0 )
    pan:NumSlider( "Offset Angle", "hitmarkers_offset_angle", 0, 360, 0 )
    pan:NumSlider( "Lifetime", "hitmarkers_lifetime", 0.1, 5, 2 )
    pan:NumSlider( "Length", "hitmarkers_length", 1, 1000, 2 )
    pan:NumSlider( "Width", "hitmarkers_width", 1, 1000, 2 )
    pan:NumSlider( "Spacing", "hitmarkers_spacing", 1, 1000, 2 )
    pan:NumSlider( "Rotation Speed", "hitmarkers_rotation_speed", 0, 720, 2 )
    pan:NumSlider( "Spread Speed", "hitmarkers_spread_speed", 0, 1000, 2 )

    local markerColorMixer = CreateColorMixer( pan, "hitmarkers_color" )
    markerColorMixer:SetLabel("Basic Color")

    local headshotMarkerColorMixer = CreateColorMixer( pan, "hitmarkers_headshot_color" )
    headshotMarkerColorMixer:SetLabel("Headshot Color")

    local killMarkerColorMixer = CreateColorMixer( pan, "hitmarkers_kill_color" )
    killMarkerColorMixer:SetLabel("Kill Color")

    pan:CheckBox("Number Outlines", "hitmarkers_number_outline")
    local numberOutlineColorMixer = CreateColorMixer( pan, "hitmarkers_number_outlinecolor" )
    numberOutlineColorMixer:SetLabel("Number Outline Color")


    local _onSelect = presetPanel.OnSelect -- Call original function first.
    function presetPanel:OnSelect( id, value, data )
        _onSelect( self, id, value, data )
        if not data then return end
        markerColorMixer:SetColor( string.ToColor( data.hitmarkers_color ) )
        headshotMarkerColorMixer:SetColor( string.ToColor( data.hitmarkers_headshot_color ) )
        killMarkerColorMixer:SetColor( string.ToColor( data.hitmarkers_kill_color ) )
        numberOutlineColorMixer:SetColor( string.ToColor( data.hitmarkers_number_outlinecolor ) )
    end

    markerColorMixer:SetColor( string.ToColor( HITMARKERS_IMPROVED.CVARS.markersColor:GetString() ) )
    headshotMarkerColorMixer:SetColor( string.ToColor( HITMARKERS_IMPROVED.CVARS.markersHeadshotColor:GetString() ) )
    killMarkerColorMixer:SetColor( string.ToColor( HITMARKERS_IMPROVED.CVARS.markersKillColor:GetString() ) )
    numberOutlineColorMixer:SetColor( string.ToColor( HITMARKERS_IMPROVED.CVARS.numberOutlineColor:GetString() ) )

    DividerLabel( pan, "Armor Icon Settings" )

    pan:CheckBox( "Show Armor Icon", "hitmarkers_armor_symbol" )
    pan:NumSlider( "X Offset", "hitmarkers_armor_x", -1, 1, 2 )
    pan:NumSlider( "Y Offset", "hitmarkers_armor_y", -1, 1, 2 )
    pan:ControlHelp( "Offsets are screen percentages. They start in the center at 0." )

    DividerLabel( pan, "Font Settings" )
    pan:NumSlider("Font Size", "hitmarkers_fontsize", 4, 32, 0)
    pan:CheckBox("Worldspace Numbers", "hitmarkers_worldspace_numbers")

    DividerLabel( pan, "Sound Settings" )

    pan:NumSlider( "Volume", "hitmarkers_volume", 0, 2, 2 )

    pan:TextEntry( "Basic Sound", "hitmarkers_sound" )
    pan:TextEntry( "Headshot Sound", "hitmarkers_head_sound" )
    pan:TextEntry( "Kill Sound", "hitmarkers_kill_sound" )

    local lastSound = nil

    -- Sound Browser --
    local soundBrowser = vgui.Create( "DFileBrowser", pan )
    soundBrowser:SetTall( 300 )
    soundBrowser:Dock( TOP )
    soundBrowser:SetPath( "GAME" )
    soundBrowser:SetBaseFolder( "sound" )
    soundBrowser:SetOpen( true, true )
    soundBrowser:DockMargin( 10, 5, 10, 0 )

    local stopSoundBtn = vgui.Create( "DButton", soundBrowser )
    stopSoundBtn:SetText( "Stop Sound" )
    stopSoundBtn:Dock( BOTTOM )
    stopSoundBtn.DoClick = function()
        if lastSound then
            lastSound:Stop()
        end
    end

    function soundBrowser:OnSelect( path, pnl )
        if lastSound then
            lastSound:Stop()
        end

        path = string.Replace( path, "sound/", "" )
        lastSound = CreateSound( LocalPlayer(), path )
        lastSound:Play()
    end

    function soundBrowser:OnRightClick( path, pnl )
        local menu = DermaMenu()
        menu:AddOption( "Copy to Clipboard", function()
            path = string.Replace( path, "sound/", "" )
            SetClipboardText( path )
        end ):SetIcon( "icon16/page_copy.png" )
        menu:Open()
    end
end

list.Set( "DesktopWindows", "Customizable Hitmarkers Menu", {
	title = "Hitmarkers",
	icon = "hitmarkers_improved/vgui/menu_icon.png",
	init = OpenHitmarkersMenu
} )