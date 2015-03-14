--[[
	Author: kritth
	Date: 12.03.2015
	TODO:
	- Particle on swap
	- Default
	- Misc swap
	- Courier swap
	- Ward swap
]]

--[[
====================================================================================================================
============================================Init Functions==========================================================
====================================================================================================================
]]

if CosmeticLib == nil then
	print( '[CosmeticLib] Creating Cosmetics Manager' )
	CosmeticLib = {}
	CosmeticLib.__index = CosmeticLib
end

-- Initialize the library, should be called only once
function CosmeticLib:Init()
	if not CosmeticLib.bHasInitialized then
		-- Set flag so it cannot initialize twice
		CosmeticLib.bHasInitialized = true
		
		-- Disable combine models
		SendToServerConsole( "dota_combine_models 0" )
		SendToConsole( "dota_combine_models 0" )
		
		-- Create the tables
		CosmeticLib:_CreateTables()
		
		-- Add console command
		Convars:RegisterCommand( "get_item_set_id_for_hero", function( cmd, player_id ) 
				return CosmeticLib:GetSetsIDForHero( PlayerResource:GetPlayer( tonumber( player_id ) ) )
			end, "Get set item for hero", 0
		)
		Convars:RegisterCommand( "equip_item_set", function( cmd, player_id, set_number ) 
				return CosmeticLib:EquipSetForHero( PlayerResource:GetPlayer( tonumber( player_id ) ), set_number )
			end, "Equip set item for hero", 0
		)
		Convars:RegisterCommand( "get_available_players", function( cmd )
				local players = {}
				for i = 0, 9 do
					local player = PlayerResource:GetPlayer( i )
					if player ~= nil and player:GetAssignedHero() ~= nil then
						table.insert( players, i )
					end
				end
				DebugTable( players )
			end, "Get all available players", 0
		)
	end
end

-- Create table in the structure specified above
function CosmeticLib:_CreateTables()
	-- Load in values
	local kvLoadedTable = LoadKeyValues( "scripts/items/items_game.txt" )
	CosmeticLib._AllItemsByID = kvLoadedTable[ "items" ]
	
	-- Create these tables for faster lookup time
	if CosmeticLib._NameToID == nil then CosmeticLib._NameToID = {} end						-- Structure table[ "item_name" ] = item_id
	for CosmeticID, CosmeticTable in pairs( CosmeticLib._AllItemsByID ) do					-- Extract only from items block
		if CosmeticTable[ "prefab" ] ~= nil	then	
			if CosmeticTable[ "prefab" ] == "default_item" and CosmeticTable[ "used_by_heroes" ] ~= nil
					and type( CosmeticTable[ "used_by_heroes" ] ) == "table" then			-- Insert default items
				CosmeticLib:_InsertIntoDefaultTable( CosmeticID )
				CosmeticLib._NameToID[ CosmeticTable[ "name" ] ] = CosmeticID
			elseif CosmeticTable[ "prefab" ] == "wearable" and CosmeticTable[ "used_by_heroes" ] ~= nil
					and type( CosmeticTable[ "used_by_heroes" ] ) == "table" then			-- Insert wearable items
				CosmeticLib:_InsertIntoWearableTable( CosmeticID )
				CosmeticLib._NameToID[ CosmeticTable[ "name" ] ] = CosmeticID
			elseif CosmeticTable[ "prefab" ] == "courier" then								-- Insert couriers
				CosmeticLib:_InsertIntoCourierTable( CosmeticID )
				CosmeticLib._NameToID[ CosmeticTable[ "name" ] ] = CosmeticID
			elseif CosmeticTable[ "prefab" ] == "ward" then
				CosmeticLib:_InsertIntoWardTable( CosmeticID )
				CosmeticLib._NameToID[ CosmeticTable[ "name" ] ] = CosmeticID
			end
		end
	end
	
	-- Run second time for bundle
	for CosmeticID, CosmeticTable in pairs( CosmeticLib._AllItemsByID ) do					-- Extract only from items block
		if CosmeticTable[ "prefab" ] ~= nil	then	
			if CosmeticTable[ "prefab" ] == "bundle" and CosmeticTable[ "used_by_heroes" ] ~= nil and type( CosmeticTable[ "used_by_heroes" ] ) == "table" then
				CosmeticLib:_InsertIntoBundleTable( CosmeticID )
				CosmeticLib._NameToID[ CosmeticTable[ "name" ] ] = CosmeticID
			end
		end
	end
	
end

--[[
====================================================================================================================
========================================Custom console commands=====================================================
====================================================================================================================
]]

function CosmeticLib:GetSetsIDForHero( player )
	local hero = player:GetAssignedHero()
	local hero_sets = CosmeticLib:GetAllSetsForHero( hero:GetName() )
	print( "Available set for " .. hero:GetName() .. " are" )
	for _, item_id in pairs( hero_sets ) do
		print( item_id )
	end
end

function CosmeticLib:EquipSetForHero( player, set_number )
	local hero = player:GetAssignedHero()
	CosmeticLib:EquipHeroSet( hero, set_number )
end

--[[
====================================================================================================================
========================================Create Table Functions======================================================
====================================================================================================================
]]

-- Create sub table with new key value, return true if it existed or is able to create one
function CosmeticLib:_CheckSubTable( new_key, table_to_insert )
	if new_key ~= nil and table_to_insert ~= nil and type( table_to_insert ) == "table" then
		if table_to_insert[ new_key ] == nil then
			table_to_insert[ new_key ] = {}
		end
		return true
	else
		return false
	end
end

-- Insert element into the default wearable table
function CosmeticLib:_InsertIntoDefaultTable( CosmeticID )
	if CosmeticLib._DefaultForHero == nil then
		CosmeticLib._DefaultForHero = {}
	end
	CosmeticLib:_InsertIntoCosmeticTable( CosmeticID, CosmeticLib._DefaultForHero )
end

-- Insert element into the non-default wearable table
function CosmeticLib:_InsertIntoWearableTable( CosmeticID )
	if CosmeticLib._WearableForHero == nil then
		CosmeticLib._WearableForHero = {}
	end
	CosmeticLib:_InsertIntoCosmeticTable( CosmeticID, CosmeticLib._WearableForHero )
end

--[[
	This function will put cosmetics into table
	Structure is
	table[ "hero_name" ][ "item_slot" ][ "item_name" ] = item_id
]]
function CosmeticLib:_InsertIntoCosmeticTable( CosmeticID, table_to_insert )
	-- All cosmetic will be store in this two tables
	if CosmeticLib._SlotToName == nil then CosmeticLib._SlotToName = {} end			-- Structure table[ "slot_name" ][ "item_name" ] = item_id
	if CosmeticLib._ModelNameToID == nil then CosmeticLib._ModelNameToID = {} end	-- Structure table[ "model_name" ] = item_id

	-- Check if it can be used by heroes
	local selected_item = CosmeticLib._AllItemsByID[ "" .. CosmeticID ]
	if selected_item[ "used_by_heroes" ] == nil or selected_item[ "model_player" ] == nil then return end
	local usable_by_heroes = selected_item[ "used_by_heroes" ]
	
	for hero_name, _ in pairs( usable_by_heroes ) do
		if CosmeticLib:_CheckSubTable( hero_name, table_to_insert ) then						-- Check on hero name
			local item_slot = selected_item[ "item_slot" ]
			if item_slot == nil then
				item_slot = "weapon"
			end
			if CosmeticLib:_CheckSubTable( item_slot, table_to_insert[ hero_name ] ) then		-- Check on item slot
				local item_name = selected_item[ "name" ]
				if item_name ~= nil then														-- Check on item name
					table_to_insert[ hero_name ][ item_slot ][ item_name ] = CosmeticID
					CosmeticLib._ModelNameToID[ selected_item[ "model_player" ] ] = CosmeticID
					
					if CosmeticLib:_CheckSubTable( item_slot, CosmeticLib._SlotToName ) then	-- Check to add into _SlotToName
						CosmeticLib._SlotToName[ item_slot ][ item_name ] = CosmeticID
					end
				end
			end
		end
	end
end

-- Insert new data into courier table
function CosmeticLib:_InsertIntoCourierTable( CosmeticID )
	if CosmeticLib._Couriers == nil then
		CosmeticLib._Couriers = {}
	end
	
	local selected_item = CosmeticLib._AllItemsByID[ "" .. CosmeticID ]
	
	if CosmeticLib:_CheckSubTable( selected_item[ "name" ], CosmeticLib._Couriers ) then
		CosmeticLib._Couriers[ selected_item[ "name" ] ] = CosmeticID 
	end
end

-- Insert new data into ward table
function CosmeticLib:_InsertIntoWardTable( CosmeticID )
	if CosmeticLib._Wards == nil then
		CosmeticLib._Wards = {}
	end
	
	local selected_item = CosmeticLib._AllItemsByID[ "" .. CosmeticID ]
	
	if CosmeticLib:_CheckSubTable( selected_item[ "name" ], CosmeticLib._Wards ) then
		CosmeticLib._Wards[ selected_item[ "name" ] ] = CosmeticID
	end
end

-- Insert new data into bundle/set table
function CosmeticLib:_InsertIntoBundleTable( CosmeticID )
	if CosmeticLib._Sets == nil and CosmeticLib._SetByHeroes == nil then
		CosmeticLib._Sets = {}
		CosmeticLib._SetByHeroes = {}
	end
	
	local selected_item = CosmeticLib._AllItemsByID[ "" .. CosmeticID ]
	
	if CosmeticLib:_CheckSubTable( selected_item[ "name" ], CosmeticLib._Sets ) then
		-- For hero name lookup
		for hero_name, enabled in pairs( selected_item[ "used_by_heroes" ] ) do
			if CosmeticLib:_CheckSubTable( hero_name, CosmeticLib._SetByHeroes ) then
				CosmeticLib._SetByHeroes[ hero_name ][ selected_item[ "name" ] ] = CosmeticID
			end
		end
		-- For set name lookup
		for cosmetic_name, enabled in pairs( selected_item[ "bundle" ] ) do
			local item_set_id = CosmeticLib:GetIDByName( cosmetic_name )
			if item_set_id ~= nil then
				local item = CosmeticLib._AllItemsByID[ item_set_id ]
				if item ~= nil then
					if item[ "item_slot" ] ~= nil then
						CosmeticLib._Sets[ selected_item[ "name" ] ][ item[ "item_slot" ] ] = item_set_id
					elseif item[ "prefab" ] == "wearable" or item[ "prefab" ] == "default_item" then
						CosmeticLib._Sets[ selected_item[ "name" ] ][ "weapon" ] = item_set_id
					end
				end
			end
		end
	end
end

--[[
====================================================================================================================
===========================================Getter Functions=========================================================
====================================================================================================================
]]

--[[
	Get available cosmetics for given hero
	@param
	unit		: hscript
	slot_name	: slot name
	@return table[ item_name ] = item_id
]]
function CosmeticLib:GetAvailableSlotForHero( hero_name )
	if hero_name ~= nil then
		if CosmeticLib._WearableForHero[ hero_name ] ~= nil then
			local toReturn = {}
			for item_slot, _ in pairs( CosmeticLib._WearableForHero[ hero_name ] ) do
				table.insert( toReturn, item_slot )
			end
			table.sort( toReturn )
			return toReturn
		end
	end
	print( '[CosmeticLib:GetAvailableSlotForHero] Error: Invalid input' )
end

--[[
	Get available cosmetics for hero in given slot
	@param
	unit		: hscript
	slot_name	: slot name
	@return table[ item_name ] = item_id
]]
function CosmeticLib:GetAllAvailableForHeroInSlot( hero_name, slot_name )
	if hero_name ~= nil then
		if CosmeticLib._WearableForHero[ hero_name ][ slot_name ] ~= nil then
			local toReturn = {}
			for item_name, _ in pairs( CosmeticLib._WearableForHero[ hero_name ][ slot_name ] ) do
				table.insert( toReturn, item_name )
			end
			table.sort( toReturn )
			return toReturn
		end
	end
	print( '[CosmeticLib:GetAllAvailableForHeroInSlot] Error: Invalid input' )
end


-- Get all available cosmetics name
function CosmeticLib:GetAllAvailableWearablesName()
	if CosmeticLib._NameToID ~= nil then
		local toReturn = {}
		for k, v in pairs( CosmeticLib._NameToID ) do
			table.insert( toReturn, k )
		end
		table.sort( toReturn )
		return toReturn
	else
		print( '[CosmeticLib] Error: No cosmetic table found. Please verify that you have item_games.txt in your vpk' )
		return nil
	end
end

-- Get all available cosmetics id
function CosmeticLib:GetAllAvailableWearablesID()
	if CosmeticLib._NameToID ~= nil then
		local toReturn = {}
		for k, v in pairs( CosmeticLib._NameToID ) do
			table.insert( toReturn, tonumber( v ) )
		end
		table.sort( toReturn )
		return toReturn
	else
		print( '[CosmeticLib] Error: No cosmetic table found. Please verify that you have item_games.txt in your vpk' )
		return nil
	end
end

-- Get all sets
function CosmeticLib:GetSetByName( set_name )
	return CosmeticLib._Sets[ set_name ]
end

-- Get all set for hero
function CosmeticLib:GetAllSetsForHero( hero_name )
	return CosmeticLib._SetByHeroes[ hero_name ]
end

-- Get ID by item name
function CosmeticLib:GetIDByName( cosmetic_name )
	if CosmeticLib._NameToID[ cosmetic_name ] ~= nil then
		return "" .. CosmeticLib._NameToID[ cosmetic_name ]
	else
		return nil
	end
end

-- Get ID by model name
function CosmeticLib:GetIDByModelName( model_name )
	if CosmeticLib._ModelNameToID[ model_name ] ~= nil then
		return "" .. CosmeticLib._ModelNameToID[ model_name ]
	else
		return nil
	end
end

-- Filter the cosmetics by name


--[[
====================================================================================================================
=============================================Swap Functions=========================================================
====================================================================================================================
]]

-- Check if the table existed
function CosmeticLib:_Identify( unit )
	if unit:entindex() ~= nil then
		if unit._cosmeticlib_wearables_slots == nil then
			unit._cosmeticlib_wearables_slots = {}
			-- Fill the table
			local wearable = unit:FirstMoveChild()
			while wearable ~= nil do
				if wearable:GetClassname() == "dota_item_wearable" then
					local id = CosmeticLib:GetIDByModelName( wearable:GetModelName() )
					local item = CosmeticLib._AllItemsByID[ id ]
					if item ~= nil then
						-- Structure table[ item_slot ] = { handle entindex, item_id }
						if item[ "item_slot" ] ~= nil then
							unit._cosmeticlib_wearables_slots[ item[ "item_slot" ] ] = { handle = wearable, item_id = id }
						else
							unit._cosmeticlib_wearables_slots[ "weapon" ] = { handle = wearable, item_id = id }
						end
					end
				end
				wearable = wearable:NextMovePeer()
			end
		end
		return true
	else
		print( '[CosmeticLib:Swap] Error: Input is not entity' )
		return false
	end
end

-- Random in all slots
function CosmeticLib:AllRandom( unit )
	if CosmeticLib:_Identify( unit ) then
		
	end
end

-- Random in all slots from cosmetics available for given hero_name
function CosmeticLib:AllRandomFromHero( unit, hero_name, guaranteed )
	if CosmeticLib:_Identify( unit ) then
		
	end
end

-- Random selected slot with cosmetic from all cosmetics with respect to slot_name and hero_name
function CosmeticLib:RandomFromHeroInSlot( unit, hero_name, slot_name, guaranteed, respect )
	if CosmeticLib:_Identify( unit ) then
		
	end
end

-- Swap with respect to equipping hero
function CosmeticLib:Swap( unit, hero_name, item_name )
	if CosmeticLib:_Identify( unit ) then
		
	end
end

-- Swap hero back to default
function CosmeticLib:DefaultHeroSwap( hero )
	if hero ~= nil and hero:IsRealHero() then
		CosmeticLib:DefaultSwap( hero, hero:GetName() )
		return
	end
	
	print( "[CosmeticLib:DefaultHeroSwap] Error: Invalid input." )
end

-- Swap any unit back to default based on hero_name
function CosmeticLib:DefaultSwap( unit, hero_name )
	if unit ~= nil and hero_name ~= nil then
		return
	end
	
	print( "[CosmeticLib:DefaultSwap] Error: Invalid input." )
end

-- Swap with check respect to slot name
function CosmeticLib:ForceSwapWithSlotName( unit, slot_name, new_item_id )
	if unit ~= nil and slot_name ~= nil and new_item_id ~= nil and CosmeticLib:_Identify( unit ) == true then
		local handle_table = unit._cosmeticlib_wearables_slots[ slot_name ]
		if handle_table ~= nil and type( handle_table ) == "table" then
			local item = CosmeticLib._AllItemsByID[ "" .. new_item_id ]
			handle_table[ "handle" ]:SetModel( item[ "model_player" ] )
			handle_table[ "item_id" ] = new_item_id
			return
		end
	end
	
	print( "[CosmeticLib:ForceSwap] Error: Invalid input." )
end

-- Swap with check respect to old item_id
function CosmeticLib:ForceSwapWithItemID( unit, old_item_id, new_item_id )
	if unit ~= nil and slot_name ~= nil and new_item_id ~= nil and CosmeticLib:_Identify( unit ) == true then
		for slot_name, handle_table in pairs( unit._cosmeticlib_wearables_slots ) do
			if handle_table[ "item_id" ] == old_item_id then
				local item = CosmeticLib._AllItemsByID[ "" .. new_item_id ]
				handle_table[ "handle" ]:SetModel( item[ "model_player" ] )
				handle_table[ "item_id" ] = old_item_id
				return
			end
		end
	end

	print( "[CosmeticLib:ForceSwap] Error: Invalid input." )
end

-- Equip set for hero
function CosmeticLib:EquipHeroSet( hero, set_id )
	CosmeticLib:EquipSet( hero, hero:GetName(), set_id )
end

-- Equip set
function CosmeticLib:EquipSet( unit, hero_name, set_id )
	if unit ~= nil and hero_name ~= nil and set_id ~= nil and CosmeticLib:_Identify( unit ) == true then
		local selected_item = CosmeticLib._AllItemsByID[ set_id ]
		if selected_item ~= nil and CosmeticLib._SetByHeroes[ hero_name ] ~= nil
				and CosmeticLib._SetByHeroes[ hero_name ][ selected_item[ "name" ] ] ~= nil then
			for slot_name, item_id in pairs ( CosmeticLib._Sets[ selected_item[ "name" ] ] ) do
				CosmeticLib:ForceSwapWithSlotName( unit, slot_name, item_id )
			end
			return
		end
	end
	
	print( "[CosmeticLib:EquipSet] Error: Invalid input." )
end

--[[
====================================================================================================================
====================================================================================================================
====================================================================================================================
]]

CosmeticLib:Init()