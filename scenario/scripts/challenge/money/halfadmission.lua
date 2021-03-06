-- halfadmission.lua
-- functions for the grantmoney scenario

include "scenario/scripts/ui.lua";
include "scenario/scripts/entity.lua";
include "scenario/scripts/economy.lua";
include "scenario/scripts/misc.lua";

function validate()
	BFLOG(SYSTRACE, "halfadmission validate");
	
	if ((donealready == nil) or (donealready ~= "true") and (countTypeDirect("animal") > 0) and (not isActivatedByName("Admission Price Free"))) then
		BFLOG(SYSTRACE, "Giving halfadmission challenge");
		local mgr = queryObject("BFScenarioMgr");
		if (mgr) then
			mgr:BFS_ADDSCENARIO("scenario/goals/challenge/halfadmission.xml");	
		end
					
		return 1;
	end
	
	return 0;
end


-- gives you half price admission promotion challenge
-- 8/20 revised implementation
-- Set admissions to free
-- Give the player $2500 in cash (grant)
-- Set timer for 1 month. (not 6)
-- Track the admissions they would have received (either at the previous setting the player had, or if necessary, just choose the middle price)
-- During the 1 month, monitor for sickness... any sick animal, challenge failed immediately.

-- On failure:
-- Confiscate the sick animal (e.g. just take it away).  We'll take only one -- don't want to hose them too badly but if there is more than one sick animal, pick the "sickest" 

-- On success: 
-- Give player another $2500 cash grant
-- Give player the "lost" admissions

function evalhalfadmission(comp)
	
	challenge = getglobalvar("challenge");
	
	if (challenge == "accept") then
		local mgr = queryObject("BFScenarioMgr");	
		if (mgr) then
			mgr:BFS_SHOWRULE("halfadmission");
		end
	
		setchallengeactive();
			
		local mgr = queryObject("BFScenarioMgr");
		if(mgr) then
			BFLOG(SYSNOTE, "Disabling UI");
			local uimgr = queryObject("UIRoot");
			if(uimgr) then
				-- Determine what their admission price is
				if(isActivatedByName("Admission Price Cheap")) then
					BFLOG(SYSNOTE, "Setting Comp.Price to CHEAP");
					comp.price = 10;
				elseif(isActivatedByName("Admission Price Moderate")) then
					BFLOG(SYSNOTE, "Setting Comp.Price to Moderate");
					comp.price = 20;
				elseif(isActivatedByName("Admission Price Expensive"))then
					BFLOG(SYSNOTE, "Setting Comp.Price to Expensive");
					comp.price = 50
				else
					comp.price = 20;
				end
			
				-- Set the Admission price
				local freeButton = uimgr:UI_GET_CHILD("Admission Price Free");
				if(freeButton) then
					freeButton:UI_ACTIVATE_ON();
				end
				disableAdmissions();
			end
			uiDisabled = 1;
		end	
		
		-- Give the cash grant
		giveCash(2500);
		
		-- Set the timers to tick off 1 month
		comp.endMonth = getCurrentMonth() + 1;
		comp.endTimeOfDay = getCurrentTimeOfDay();
		
		-- Get the starting guest count, we need to use lifetime so we can use time of day resolution
		comp.startGuests = getNumGuests(-1);
		BFLOG(SYSNOTE, "Starting Guests: "..comp.startGuests);
		
		comp.accept = 1;
		
	elseif (challenge == "decline") then
		BFLOG(SYSTRACE, "You declined!");
		
		declinenotfail = 1;
				
		return -1;
	end
	
	if (comp.accept == nil) then
		if (challenge == nil) then
			local showchallengepanel = showchallengepanel("Challengetext:CHgrantmoney");
			BFLOG(SYSTRACE, "I'm waiting for you to click accept or decline!");
			setglobalvar("challenge", "waiting");
		end	
	end
	
	if (comp.accept == 1) then
		-- Do a redundant check to make sure that if they save/load they can't reset admission prices
		if(uiDisabled == nil) then
			local uimgr = queryObject("UIRoot");
			if(uimgr) then
				-- Set the Admission price
				local freeButton = uimgr:UI_GET_CHILD("Admission Price Free");
				if(freeButton) then
					freeButton:UI_ACTIVATE_ON();
				end
				disableAdmissions();
			end
			uiDisabled = 1;
		end
	
		-- Monitor the zoo for animal sickness
		local entity = getSickestAnimal();
		if(entity)then
			-- We found a sick entity, this is a challenge failure
			BFLOG(SYSNOTE, "Found a sick animal, you fail!");

			local thetype = entity:BFG_GET_BINDER_TYPE();
			
			-- Remove the _Adult_X from the string
			thetype = getSpeciesFromType(thetype);
			BFLOG(SYSNOTE, "Animal Type: "..thetype);
			
			replacement = getlocidfromspecies(thetype);

			-- Take away the sick animal
			deleteEntity(entity);
			enableAdmissions(comp.price);		 
			return -1;
		end
		
		--[[ Check to make sure they didn't get rid of their animal or crate it
		if(countTypeDirect("animal") == 0)then
			BFLOG(SYSNOTE, "No Animals Detected!");
			enableAdmissions();
			return -1;
		end --]]
		
		-- Check Timers
		local month = getCurrentMonth();
		local timeOfDay = getCurrentTimeOfDay();
		
		if((month >= comp.endMonth) and (timeOfDay >= comp.endTimeOfDay))then
			--Time is up and no animals were sick so they win
			local admissionCount = getNumGuests(-1) - comp.startGuests;
			
			-- Multiply the admissionCount by the price that they had selected
			gCashReward = 2500 + admissionCount * comp.price
			enableAdmissions(comp.price);
			return 1
		end
	
	end
	
	BFLOG(SYSTRACE, "evalhalfadmission");
	
	return 0;
end

function completehalfadmission(comp)

	BFLOG(SYSTRACE, "WE DID IT");
	
	showchallengewin("Challengetext:CHgrantmoneySuccess");
	
	resetchallengeoverandcomplete("animalawarenessday");
	
	incrementglobalchallenges();
	
	giveCash(gCashReward);

	return 1;
end

function failhalfadmission(comp)
	if ((declinenotfail == nil) or (declinenotfail ~= 1)) then
		BFLOG(SYSNOTE, "Failed...popping up the challengefail window");
			
		local stringdat = getLocID("Challengetext:CHgrantmoneyFailureShort");
		local showme = string.format(stringdat, replacement);
		setalttext("halfadmission", "failure", showme);
		
		stringdat = getLocID("Challengetext:CHgrantmoneyFailure");
		showme = string.format(stringdat, replacement);
		setaltoverviewtext("halfadmission", "failure", showme);
	
		showchallengefailtext(showme);
	end
	
	declinenotfail = nil
	resetchallengeover("halfadmission");
	return -1;
end