resource.AddWorkshop( "3824846324" )

util.AddNetworkString( "hitmarkers_improved_hit" )

local npcHeadshot = false
local preHealth = 0
local tookEnt = nil
local hadArmor = false

local function IsSentient( ent )
    return ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()
end

-- Small per-attacker target ID, unique across their last 16 targets
local SLOT_BITS = 4
local SLOT_COUNT = 2 ^ SLOT_BITS

local function getTargetSlot( attacker, ent )
    attacker.hmi_slots = attacker.hmi_slots or {}
    local slots = attacker.hmi_slots

    for id = 0, SLOT_COUNT - 1 do
        if slots[id] == ent then return id end
    end

    local id = attacker.hmi_nextSlot or 0
    slots[id] = ent
    attacker.hmi_nextSlot = ( id + 1 ) % SLOT_COUNT

    return id
end

hook.Add( "ScaleNPCDamage", "HitmarkersImprovedNPCDMG", function( _, hitgroup )
    npcHeadshot = hitgroup == HITGROUP_HEAD
end )

hook.Add( "EntityTakeDamage", "HitmarkersImproved", function( ent )
    if not IsSentient( ent ) then return end

    tookEnt = ent
    preHealth = ent:Health()
    hadArmor = ent:IsPlayer() and ent:Armor() > 0
end )

hook.Add( "PostEntityTakeDamage", "HitmarkersImproved", function( ent, dmginfo, took )
    if not took then return end
    if tookEnt ~= ent then return end
    if not IsSentient( ent ) then return end

    local currentHealth = math.max( ent:Health(), 0 )
    local dmgTook = preHealth - currentHealth
    if dmgTook <= 0 then return end

    local attacker = dmginfo:GetAttacker()
    if not IsValid( attacker ) then return end
    if attacker:IsVehicle() and IsValid( attacker:GetDriver() ) then attacker = attacker:GetDriver() end
    if not attacker:IsPlayer() then return end

    local inflictor = dmginfo:GetInflictor()
    if inflictor == ent or attacker == ent then return end

    local isHeadshot
    if ent:IsPlayer() then
        isHeadshot = ent:LastHitGroup() == HITGROUP_HEAD
    else
        isHeadshot = npcHeadshot
    end
    npcHeadshot = false

    net.Start( "hitmarkers_improved_hit", true )
    net.WriteUInt( math.min( math.ceil( dmgTook ), 65535 ), 16 )
    net.WriteBool( isHeadshot )
    net.WriteBool( currentHealth <= 0 )
    net.WriteBool( ent:IsPlayer() and hadArmor or false )
    net.WriteUInt( getTargetSlot( attacker, ent ), SLOT_BITS )
    net.WriteVector( dmginfo:IsExplosionDamage() and ent:WorldSpaceCenter() or dmginfo:GetDamagePosition() )
    net.Send( attacker )
end )
