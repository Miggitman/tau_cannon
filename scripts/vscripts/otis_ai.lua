----------------------------------------------------------------------------------------------------
-- Example script for entity control in HL:A Workshop sample content
----------------------------------------------------------------------------------------------------
attacking = false
mag = 17


--function Precache(context)
--    Precache("particles/tracer_fx/mg_heavy_tracer.vpcf", context)
--end

function shoot()
	if mag > 0 then
		mag = mag - 1
		local attachg = thisEntity:ScriptLookupAttachment("gunattach")
		local startPosition = thisEntity:GetAttachmentOrigin(attachg)
		local direction = thisEntity:GetAttachmentForward(attachg)
		local endPosition = startPosition + direction * 10000

		local damageTrace = {startpos = startPosition, endpos = endPosition, mask = nil, ignore = thisEntity}
		TraceLine(damageTrace)
		if damageTrace.hit and damageTrace.enthit then
			damageTrace.enthit:TakeDamage(CreateDamageInfo(thisEntity, thisEntity, damageTrace.normal, damageTrace.pos, 20, 1))
		end
		if damageTrace.hit then
			local btracer = ParticleManager:CreateParticle("particles/tracer_fx/mg_heavy_tracer.vpcf", attachg, thisEntity)
			ParticleManager:SetParticleControl(btracer, 0, startPosition)
			ParticleManager:SetParticleControl(btracer, 1, damageTrace.pos)
			ParticleManager:SetParticleControlForward(btracer, 1, damageTrace.normal)
		end
		--debug
		DebugDrawLine(startPosition, endPosition, 0, 255, 0, false, 100)
	else	
		thisEntity:SetGraphParameter("reload", true)
		mag = 17
	end
	print(mag)
end

function loseEnemy()
	attacking=false
end

function attack(enemy)
	attacking = true
	thisEntity:SetGraphParameter("b_gun", true)
end

function Spawn() 
	-- Registers a function to get called each time the entity updates, or "thinks"
	thisEntity:SetContextThink(nil, MainThinkFunc, 0)
end

--=============================
-- Activate is called by the engine after Spawn() and, if Spawn() occurred 
-- during a map's initial load, after all other entities have been spawned too.  
-- Any setup code that requires interacting with other entities should go here
--=============================
function Activate()
	-- Register a function to receive callbacks from the AnimGraph of this entity
	-- when Status Tags are emitted by the graph.  This must be called in Activate
	-- because the AnimGraph has not been loaded yet when Spawn is called
	thisEntity:RegisterAnimTagListener( AnimTagListener )
end

--=============================
-- Callback function for AnimGraph Tag events.  Only Status tags can be received 
-- by scripts, and the callback function must be registered with the graph before 
-- it will start receiving events.  
-- The first parameter is the string name of the tag, and the second one is its status.  
-- nStatus == 0 == Fired: The tag activated then deactivated during this update
-- nStatus == 1 == Start: The tag became active
-- nStatus == 2 == End: The tag is no longer active
--=============================
--function AnimTagListener( sTagName, nStatus )
	--print( " AnimTag: ", sTagName, " Status: ", nStatus )
--end

--=============================
-- Script configuration parameters
--=============================
-- How long to wait between calls to create a new path. 
-- Creating a path can be expensive because it performs a lot of traces to check 
-- for collisions with other objects and characters.  So this code puts a time 
-- limit on how frequently a new path can be calculated to help prevent spamming 
-- the path system
local flRepathTime = 1.0

-- The last game time a new path was created
local flLastPathTime = 0.0

-- The closest that the entity should get to the player
local flMinPlayerDist = 100

-- The farthest the entity should get to the player
local flMaxPlayerDist = 250

-- The maximum distance away from the navigation goal that a path can be considered successful
local flNavGoalTolerance = 250

-- Whether the player should walk or run when following a path.  
-- This choice affects the target speed that is passed to the AnimGraph,
-- and how much curve the pathing system should use when creating corners.
-- The walk and run speeds of characters are defined in the Movement Settings
-- node on the model in ModelDoc
local bShouldRun = false

function AnimTagListener( sTagName, nStatus )
    --print( " AnimTag: ", sTagName, " Status: ", nStatus )
	--if sTagName == "fireBullet" and thisEntity:getCycle() == 0.10 then
	if sTagName == "fireBullet" and nStatus == 0 then
		shoot()	
	end
end

--=============================
-- Think function for the script, called roughly every 0.1 seconds.
--=============================
function MainThinkFunc() 
	local localPlayer = Entities:GetLocalPlayer()
	if localPlayer ~= nil then

		-- Set the look target on the AnimGraph to be the position of the players eyes.  
		thisEntity:SetGraphLookTarget( localPlayer:EyePosition() )

		-- If the entity is too close to the player and still has an active path, then
		-- cancel the path to make it stop moving
		local flDistToPlayer = ( localPlayer:GetAbsOrigin() - thisEntity:GetAbsOrigin() ):Length()

		if ( flDistToPlayer < flMinPlayerDist ) and ( thisEntity:NpcNavGoalActive() ) then
				thisEntity:NpcNavClearGoal()
		end

		-- If the entity is too far from the player...
		if ( flDistToPlayer > flMaxPlayerDist ) then
			
			-- If the entity does not already have a path
			if ( not thisEntity:NpcNavGoalActive() ) then

				-- Create a path that ends near the player
				CreatePathToPlayer(localPlayer)
			else
				local vCurrentGoalPos = thisEntity:NpcNavGetGoalPosition()
				local flDistPlayerToGoal = ( localPlayer:GetAbsOrigin() - vCurrentGoalPos ):Length()
				local flTimeSincePath = Time() - flLastPathTime

				-- If the player has moved away from the path goal and we haven't changed the path recently
				-- then calculate a new path
				if ( flDistPlayerToGoal > flMinPlayerDist ) and ( flTimeSincePath > flRepathTime ) then
					CreatePathToPlayer(localPlayer)
				end
			end
		end
		--shooting
		--if attacking == true then
		--	shoot()
		--end
	end

	-- Return the amount of time to wait before calling this function again.
	return 0.1
end


--=============================
-- Create a path to a point that is flMinPlayerDist from the player
-- Note: Always try to create a path to where you want to entity to stop, rather than cancelling the path
-- when it gets close enough.  This allows the AnimGraph to anticipate the goal and choose to play a stopping
-- animation if one is available
--=============================
function CreatePathToPlayer( localPlayer ) 

	-- Find the vector from this entity to the player
	local vVecToPlayerNorm = ( localPlayer:GetAbsOrigin() - thisEntity:GetAbsOrigin() ):Normalized()

	-- Then find the point along that vector that is flMinPlayerDist from the player
	local vGoalPos = localPlayer:GetAbsOrigin() - ( vVecToPlayerNorm * flMinPlayerDist );

	-- Create a path to that goal.  This will replace any existing path
	-- The path gets sent to the AnimGraph, and its up to the graph to make the character
	-- walk along the path
	thisEntity:NpcForceGoPosition( vGoalPos, bShouldRun, flNavGoalTolerance )

	flLastPathTime = Time()
end