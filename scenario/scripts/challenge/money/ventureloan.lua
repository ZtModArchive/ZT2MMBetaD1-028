-- ventureloan.lua
-- functions for the ventureloan challenge

include "scenario/scripts/ui.lua";
include "scenario/scripts/entity.lua";
include "scenario/scripts/economy.lua";
include "scenario/scripts/misc.lua";

function validate()
	BFLOG(SYSTRACE, "ventureloan validate");
	
	local donealready = getglobalvar("ventureloan_over");
	if (donealready == nil) or (donealready ~= "true") then
		BFLOG(SYSTRACE, "Giving ventureloan challenge");
		local mgr = queryObject("BFScenarioMgr");
		if (mgr) then
			mgr:BFS_ADDSCENARIO("scenario/goals/challenge/ventureloan.xml");
		end

		return 1;
	end
	
	return 0;
end


-- gives you venture capitalist loan challenge
function evalventureloan(comp)

	BFLOG(SYSTRACE, "evalventureloan");

	challenge = getglobalvar("challenge")
	if (challenge == "accept") then
		BFLOG(SYSTRACE, "*******You accepted!")
		local mgr = queryObject("BFScenarioMgr");
		if (mgr) then
			mgr:BFS_SHOWRULE("ventureloan");
		end
		
		--[[
		setglobalvar("challengeactive", "true");
		setglobalvar("challenge", nil);
		--]]
		
		setchallengeactive();
		
		-- INIT THE LOAN
		if comp.loanactive == nil then
			-- Initialize the loan info
			comp.loanactive = 1;
			comp.loanpayback = 12000;
			comp.loanskim = .4;
			comp.loanmonth = getCurrentMonth();
			comp.prevMonthPaid = 0;
			
			-- Get the starting donations
			comp.prevDonations = getDonationsAllAnimals() + getDonations("Education");

			BFLOG(SYSTRACE, "Loan initialized - size: 10000  payback: "..comp.loanpayback.." skim: "..comp.loanskim..".");

			-- Give them their money
			giveCash(10000);	
		end
		
		comp.accept = 1;
		
	elseif (challenge == "decline") then
		BFLOG(SYSTRACE, "You declined!");
		--setglobalvar("challenge", nil);
		
		--setglobalvar("ventureloan_over", "true");
		return -1;
	end		
	
	if comp.accept == nil then
		if (challenge == nil) then
			local showchallengepanel = showchallengepanel("Challengetext:CHgrantmoney2");
			BFLOG(SYSTRACE, "I'm waiting for you to click accept or decline!");
			setglobalvar("challenge", "waiting");
		end	
	end

	if comp.accept == 1 then
		
		-- MAINTAIN THE LOAN
		
		BFLOG(SYSTRACE, "Checking loan...");
		-- Only if they currently have a loan
		if comp.loanactive ~= nil then
			local curMonth = getCurrentMonth();
			
			BFLOG(SYSTRACE, "Last loan month: "..comp.loanmonth.." current month: "..curMonth..".");
	
	
			-- Only take the cash if they haven't paid everything back
			if (comp.loanpayback > 0) then
				-- Find any new donations and subtract them from the total
				local currentDonations = getDonationsAllAnimals() + getDonations("Education");
				local skimamount = (currentDonations - comp.prevDonations) * comp.loanskim;
				comp.prevDonations = currentDonations;
				comp.prevMonthPaid = comp.prevMonthPaid + skimamount;
				comp.loanpayback = comp.loanpayback - skimamount;
			
				BFLOG(SYSNOTE, "Skim: "..skimamount.."  MonthTotal: "..comp.prevMonthPaid.."  LoanBalance: "..comp.loanpayback);
			
				-- Subtract this skim from their cash and loan payback
				takeCashNoPopup(skimamount);
			end

			-- If we have a new month to process
			if (curMonth > comp.loanmonth) then
				-- If they have paid back their fair share
				if comp.loanpayback < 0 then

					-- Give them back the overpay
					local overpay = 0 - comp.loanpayback;
					giveCashNoPopup(overpay);

					-- Now cancel the loan
					comp.loanactive = nil;
					BFLOG(SYSTRACE, "Loan has been completely repaid!");
				
					return 1;
				end
				if(comp.prevMonthPaid ~= 0)then
					showgivecash("Challengetext:GenericMoneyLoss", (0 - comp.prevMonthPaid));
				end
				comp.prevMonthPaid = 0;
				-- If it's not paid off yet, then update the month
				comp.loanmonth = curMonth;
			end
		end
	end
	
	return 0;
end


function completeventureloan(comp)

	BFLOG(SYSTRACE, "WE DID IT");
	
	showchallengewin("Challengetext:CHgrantmoney2Success");
	
	resetchallengeoverandcomplete("ventureloan");
	
	incrementglobalchallenges();
	
	--[[
	setglobalvar("challengeactive", "false");
	
	-- Don't hit this challenge again.
	setglobalvar("ventureloan_over", "true");
	
	-- Increment the number of challenges completed
	local num = getglobalvar("numchallcomplete");
	if (num == nil) then
		num = 0;
	end
	local newnum = tonumber(num) + 1;
	BFLOG(SYSTRACE, "Setting number of challenges complete to: "..newnum..".");
	setglobalvar("numchallcomplete", tostring(newnum));
	--]]

end

function failventureloan(comp)
	BFLOG(SYSTRACE, "DECLINED");
	
	resetchallengeover("ventureloan");	
	
	--[[
	setglobalvar("challengeactive", "false");
	
	-- Don't hit this challenge again.
	setglobalvar("ventureloan_over", "true");
	--]]
end