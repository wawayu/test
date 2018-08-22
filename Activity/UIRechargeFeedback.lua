local RechargeData = require "Data.RechargeData"
local BusinessData = require "Data.BusinessData"

local ActivityTable = require "Excel.ActivityTable"
local SettingTable = require "Excel.SettingTable"
local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local preUpdateTime = -1

local M = base:Extend()




local bid	-- 活動id
function M.Open(params)
	bid = params and params.id or BusinessData.GetRechargeBackID()
	if bid<0 then
		return
	end
    uiMgr.ShowAsync("UIRechargeFeedback")
end


function M:Awake()
    base.Awake(self)

    self.timeText=self:FindText("Offset/Time/TimeText")
    self.activeDesc=self:FindText("Offset/ActivityDesc/DescText")

    --充值条目
    self.rechargeTab={}
    for i=1, 4 do
    	local tog = self:FindText(string.format("Offset/GoldText/Gold%d", i))
        self.rechargeTab[i] = tog
    end

     --按钮事件
     UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonClose"), self, M.OnClick)
     UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/BtnRecharge"), self, M.OnClick)
end


function M:Show()
    base.Show(self)  	

    self.script = BusinessData.GetScript(bid)
	if not self.script then
		self:Hide()
		return
	end
    self.businessTab = BusinessActivityTable[bid]
    self:ResetData()
end 

function M:OnClick(go)
    if go.name == "ButtonClose" then
		self:Hide()
	elseif go.name == "BtnRecharge" then
		OpenUI("UIRecharge")
	end
end

function M:ResetData()
    -- body
    self.endTime = self.script:GetEndTime()
    self.activeDesc.text= self.businessTab.desc

    for i=1,4 do
        local config=self.businessTab.rewardconfig[i]
        local maxNum=config.limit--最大充值数
        --当前充值数
        local nowRecharge= self.script:GetChargeBackCount(i)
        local residue = maxNum-nowRecharge  

        self.rechargeTab[i].text=string.format("可领<color=#00aa00> %d </color>次)", residue)
        if residue<=0 then
            self.rechargeTab[i].text=string.format("已领取)", residue)
         end        
    end
end


function M:Update()
    base.Update(self)
	if Time.time - preUpdateTime < 1 then
		return
	end
	preUpdateTime = Time.time
	local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
	self.timeText.text = string.format("<color=#2cffee>%s</color>", strTime)
end
return M