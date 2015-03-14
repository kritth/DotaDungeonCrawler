function Debug( txt )
	if DEBUG == 1 then
		print( txt )
	end
end

function DebugTable( tab )
	if DEBUG == 1 then
		for k, v in pairs( tab ) do
			print( k, v )
		end
	end
end

-- This will run function after a delay
function DelayedExecute( func_to_run )
	Timers:CreateTimer( FRAME, func_to_run )
end