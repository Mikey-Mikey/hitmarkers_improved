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

hook.Add("PopulateToolMenu", "populate_hitmarkers", function()
    spawnmenu.AddToolMenuOption( "Utilities", "Hitmarkers", "hitmarkers_improved", "Settings", "", "", function( pan )
        pan:SetName( "Hitmarkers" )

        local presetPanel = pan:ToolPresets( "hitmarkers_presets", {
            ["hitmarkers_count"] = 4,
            ["hitmarkers_offset_angle"] = 45,
            ["hitmarkers_lifetime"] = 1,
            ["hitmarkers_length"] = 20,
            ["hitmarkers_width"] = 60,
            ["hitmarkers_spacing"] = 10,
            ["hitmarkers_rotation_speed"] = 0,
            ["hitmarkers_spread_speed"] = 0,
            ["hitmarkers_color"] = "255 255 255",

            ["hitmarkers_volume"] = 1,
            ["hitmarkers_sound"] = "hitmarkers_improved/hitmarker.ogg",
            ["hitmarkers_head_sound"] = "hitmarkers_improved/hitmarker_head.ogg",
            ["hitmarkers_kill_sound"] = "hitmarkers_improved/hitmarker_kill.ogg",

            ["hitmarkers_armor_x"] = -0.05,
            ["hitmarkers_armor_y"] = 0,
        } )

        pan:CheckBox( "Enable Hitmarkers", "hitmarkers_enabled" )
        pan:CheckBox( "Show Only One Hitmarker At A Time", "hitmarkers_oneonly" )

        DividerLabel( pan, "Hitmarker Settings" )
        

        pan:NumSlider( "Count", "hitmarkers_count", 1, 360, 0 )
        pan:NumSlider( "Offset Angle", "hitmarkers_offset_angle", 0, 360, 0 )
        pan:NumSlider( "Lifetime", "hitmarkers_lifetime", 0.1, 5, 2 )
        pan:NumSlider( "Length", "hitmarkers_length", 1, 1000, 2 )
        pan:NumSlider( "Width", "hitmarkers_width", 1, 1000, 2 )
        pan:NumSlider( "Spacing", "hitmarkers_spacing", 1, 1000, 2 )
        pan:NumSlider( "Rotation Speed", "hitmarkers_rotation_speed", 0, 720, 2 )
        pan:NumSlider( "Spread Speed", "hitmarkers_spread_speed", 0, 1000, 2 )

        local markerColorMixer = vgui.Create( "DColorMixer", pan )
        markerColorMixer:Dock( TOP )

        local _onSelect = presetPanel.OnSelect -- Call original function first.
        function presetPanel:OnSelect( id, value, data )
            _onSelect( self, id, value, data )
            if not data then return end
            if not data.hitmarkers_color then return end
            local r, g, b = string.match( data.hitmarkers_color, "(%d+) (%d+) (%d+)" )
            markerColorMixer:SetColor( Color( r, g, b ) )
        end

        local r, g, b = string.match( HITMARKERS_IMPROVED.CVARS.markersColor:GetString(), "(%d+) (%d+) (%d+)" )
        markerColorMixer:SetColor( Color( r, g, b ) )

        function markerColorMixer:ValueChanged( color )
            local r, g, b = color.r, color.g, color.b
            RunConsoleCommand( "hitmarkers_color", r .. " " .. g .. " " .. b )
        end

        DividerLabel( pan, "Armor Icon Settings" )
        
        pan:CheckBox( "Show Armor Icon", "hitmarkers_armor_enabled" )
        pan:NumSlider( "X Offset", "hitmarkers_armor_x", -1, 1, 2 )
        pan:NumSlider( "Y Offset", "hitmarkers_armor_y", -1, 1, 2 )
        pan:ControlHelp( "Offsets are screen percentages. They start in the center at 0." )

        DividerLabel( pan, "Sound Settings" )

        pan:NumSlider( "Volume", "hitmarkers_volume", 0, 2, 2 )

        local hitmarkerSoundEntry = pan:TextEntry( "Basic Sound", "hitmarkers_sound" )
        local hitmarkerHeadSoundEntry = pan:TextEntry( "Headshot Sound", "hitmarkers_head_sound" )
        local hitmarkerKillSoundEntry = pan:TextEntry( "Kill Sound", "hitmarkers_kill_sound" )

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
    end )
end)