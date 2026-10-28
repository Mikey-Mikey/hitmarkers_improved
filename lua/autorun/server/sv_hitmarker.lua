local hadArmor = false
local preHealth = 0
local headshot = false
local tookEnt = nil

util.AddNetworkString("HitmarkersImproved.Hit")

--- Check if it's a headshot
local function ScaleDamage( _, hitgroup, _ )
    if hitgroup == HITGROUP_HEAD then
        headshot = true
    else
        headshot = false
    end
end

hook.Add("ScaleNPCDamage", "HitmarkersImprovedNPCDMG", ScaleDamage )
hook.Add("ScalePlayerDamage", "HitmarkersImprovedPlayerDMG", ScaleDamage )

hook.Add( "EntityTakeDamage", "identifier", function(target, dmg)
    tookEnt = target
    preHealth = target:Health()
    hadArmor = target:IsPlayer() and target:Armor()
end )

hook.Add( "PostEntityTakeDamage", "identifier", function(target, dmginfo)
    if target ~= tookEnt then return end
    if not target:IsPlayer() and not target:IsNPC() and not target:IsNextBot() then return end

    local attacker = dmginfo:GetAttacker()
    if not attacker:IsPlayer() then return end
    local newHealth = target:Health()
    local dmgTook = preHealth - newHealth

    death = newHealth <= 0

    if dmgTook <= 0 then return end

    net.Start("HitmarkersImproved.Hit")
    net.WriteUInt( dmgTook, 16 )
    net.WriteBool( headshot )
    net.WriteBool( death )
    net.WriteBool( hadArmor )
    net.Send( attacker )
end )

resource.AddWorkshop("3824846324")