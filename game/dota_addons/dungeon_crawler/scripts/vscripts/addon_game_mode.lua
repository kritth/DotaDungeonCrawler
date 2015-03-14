require( 'util/constants' )
require( 'util/utilities' )
require( 'util/CosmeticLib' )
require( 'util/timers' )
require( 'level/character_debug' )

if DungeonCrawler == nil then
	DungeonCrawler = class({})
end

--[[ 
	Precaching base on file
	Only models and particles for now that will be precache
]]
function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "model_folder", "models/folder", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
	local precache_table = LoadKeyValues( "scripts/tables/precache.txt" )
	for precache_type, v in pairs( precache_table ) do
		for _, path in pairs( v ) do
			PrecacheResource( precache_type, path, context )
		end
	end
end

-- Create the game mode when we activate
function Activate()
	GameRules.Addon = DungeonCrawler()
	GameRules.Addon:InitGameMode()
end

--[[
	================================================================================================================
	=======================================Initialization===========================================================
	================================================================================================================
]]

function DungeonCrawler:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	
	-- Load tables
	self.equipments = {}
	self.equipments[ "npc_dota_hero_drow_ranger" ] = LoadKeyValues( "scripts/tables/sharpshooter/equipments_table.txt" )
	
	-- Logic for each specific map will go to the map instead of DungeonCrawler
	if GetMapName() == "character_debug" then
		GameRules.Map = CharacterDebug()
		GameRules.Map:InitGameMode()
	end
	
	-- Listeners
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( DungeonCrawler, "OnUnitSpawned" ), self )
end

-- Evaluate the state of the game
function DungeonCrawler:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION then
		CreateHeroForPlayer( "npc_dota_hero_drow_ranger", PlayerResource:GetPlayer( 0 ) )
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "Template addon script is running." )
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end

--[[
	================================================================================================================
	=========================================Listeners==============================================================
	================================================================================================================
]]

--[[
	======================================Parent Classes============================================================
]]

function DungeonCrawler:OnUnitSpawned( keys )
	DelayedExecute( function() self:DefaultWearables( keys.entindex ) end )
end

--[[
	=====================================Children Classes===========================================================
]]

-- This will remove all wearables from hero
function DungeonCrawler:DefaultWearables( entindex )
	local hero = EntIndexToHScript( entindex )
end

--[[
	================================================================================================================
	=================================Custom Console Commands========================================================
	================================================================================================================
]]