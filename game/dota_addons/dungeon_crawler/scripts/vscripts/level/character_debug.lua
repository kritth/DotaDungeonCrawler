-- Class initialize
if CharacterDebug == nil then
	CharacterDebug = class({})
end

-- Initialize map
function CharacterDebug:InitGameMode()
	-- Game rule configuration
	GameRules:SetTreeRegrowTime( 15.0 )

	-- Game mode configuration
	local mode = GameRules:GetGameModeEntity()
	mode:SetAnnouncerDisabled( true )
	mode:SetFixedRespawnTime( 1.0 )
	mode:SetFogOfWarDisabled( true )
	
	-- Listeners
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( CharacterDebug, "OnUnitSpawned" ), self )
end

--[[
	================================================================================================================
	=========================================Listeners==============================================================
	================================================================================================================
]]

--[[
	======================================Parent Classes============================================================
]]

function CharacterDebug:OnUnitSpawned( keys )
	local unit = EntIndexToHScript( keys.entindex )
	local fxIndex = ParticleManager:CreateParticle( "particles/custom/equipment/generic/generic_wing.vpcf", PATTACH_CUSTOMORIGIN, unit )
	ParticleManager:SetParticleControlEnt( fxIndex, 0, unit, PATTACH_POINT_FOLLOW, "attach_origin", unit:GetAbsOrigin(), true )
end

--[[
	=====================================Children Classes===========================================================
]]