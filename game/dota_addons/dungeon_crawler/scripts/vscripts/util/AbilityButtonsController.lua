if AbilityButtonsController == nil then
	AbilityButtonsController = {}
	AbilityButtonsController.__index = AbilityButtonsController
end

function AbilityButtonsController:Init()
	-- Listeners
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( AbilityButtonsController, "OnUnitSpawned" ), self )

	-- Create command for event fired from actionscript
	Convars:RegisterCommand( "use_ability", function( cmd, ability_type, ability_index, x, y, z )
			local player = Convars:GetCommandClient()
			if player then
				AbilityButtonsController:UseAbilityInSlot( player, ability_type, ability_index, x, y, z )
			end
		end, "Use ability in given slot", 0
	)
end

function AbilityButtonsController:OnUnitSpawned( keys )
	DelayedExecute( function() self:EnableAbilityBar( keys.entindex ) end )
end

function AbilityButtonsController:EnableAbilityBar( entindex )
	local hero = EntIndexToHScript( entindex )
	if hero and hero:IsRealHero() and PlayerResource:GetPlayer( hero:GetPlayerID() ):GetAssignedHero() == hero then
		FireGameEvent( "update_ability_bar", { pid = hero:GetPlayerID(), ability_slot = 0 } )
		Timers:CreateTimer( 5.0, function()
				FireGameEvent( "update_ability_bar", { pid = hero:GetPlayerID(), ability_slot = 0 } )
			end
		)
	end
end

function AbilityButtonsController:UseAbilityInSlot( player_entity, ability_type, ability_index, x, y, z )
	local hero = player_entity:GetAssignedHero()
	if hero ~= nil then
		local ability = nil
		if type( ability_index ) ~= "Number" then
			ability = hero:GetAbilityByIndex( tonumber( ability_index ) )
		else
			ability = hero:GetAbilityByIndex( ability_index )
		end
		
		if ability and ability:GetLevel() > 0 then
			local mouse_vector = Vector( tonumber( x ), tonumber( y ), tonumber( z ) )
			if ability_type == "POINT" then						-- Cast as point
				if x == nil then								-- Cast at self
					hero:CastAbilityOnPosition( hero:GetAbsOrigin(), ability, hero:GetPlayerID() )
				elseif x ~= nil and y ~= nil and z ~= nil then	-- If length is within cast range, cast there, else cast at the end of mouse vector
					local range = ability:GetCastRange()
					local length = ( mouse_vector - hero:GetAbsOrigin() ):Length2D()
					
					if length <= range then						-- within range
						hero:CastAbilityOnPosition( mouse_vector, ability, hero:GetPlayerID() )
					else										-- cast at the end
						local forwardVec = ( mouse_vector - hero:GetAbsOrigin() ):Normalized()
						hero:CastAbilityOnPosition( hero:GetAbsOrigin() + forwardVec * ( range - 50 ), ability, hero:GetPlayerID() )
					end
				end
			elseif ability_type == "LINE" then					-- Cast as line
				if x == nil then								-- Cast toward the end of forward vector
					local range = ability:GetCastRange()
					hero:CastAbilityOnPosition( hero:GetAbsOrigin() + hero:GetForwardVector() * ( range - 50 ), ability, hero:GetPlayerID() )
				elseif x ~= nil and y ~= nil and z ~= nil then	-- Cast toward the end of mouse vector
					local range = ability:GetCastRange()
					local forwardVec = ( mouse_vector - hero:GetAbsOrigin() ):Normalized()
					hero:CastAbilityOnPosition( hero:GetAbsOrigin() + forwardVec * ( range - 50 ), ability, hero:GetPlayerID() )
				end
			elseif ability_type == "IMMEDIATE" then				-- Cast as immediate
				hero:CastAbilityImmediately( ability, hero:GetPlayerID() )
			elseif ability_type == "CHANNEL" then
				
			end
		end
	end
end

AbilityButtonsController:Init()