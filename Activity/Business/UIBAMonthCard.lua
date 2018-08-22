--[[
	月卡
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"
local RechargeData = dataMgr.RechargeData

local base = require "UI.UILuaBase"
local M = base:Extend()
local itemLen = 2

function M:Awake()
	base.Awake(self)

	self.coms = {}
	for i = 1,itemLen do
		self.coms[i] = {}
		self.coms[i].trans = self:FindTransform(string.format("Offset/Item (%s)", i))
		self:OnCreateItem(i, self.coms[i])
	end

	self.textDesc = self:FindText("Offset/TextDesc")
end

function M:Show()
	base.Show(self)

	-- {{money = , chargeid = }, {}}
	self.cardConfigs = BusinessData.GetCardStaticConfig(1601)
	if not self.cardConfigs then 
		Debugger.LogWarning("self.cardConfigs error")
		return
	end

	self:ResetData()
end

function M:ResetData()
	for i = 1,itemLen do
		self:UpdateItem(i, self.coms[i])
	end
end

function M:GetLoopItem(idx)
    return self.cardConfigs[idx]
end

function M:OnCreateItem(index, coms)
	local trans = coms.trans
	coms.transBtnBuy = self:FindTransform("BtnBuy", coms.trans)
	coms.transBtnDone = self:FindTransform("BtnDone", coms.trans)
	coms.transBtnGet = self:FindTransform("BtnGet", coms.trans)
	coms.textBtnGet = self:FindText("BtnBuy/Text", coms.trans)
	coms.textRemain = self:FindText("TxtLeft", coms.trans)
	
	UguiLuaEvent.ButtonClick(coms.transBtnBuy.gameObject, nil, function()
        self:OnBuyItem(index, coms)
    end)

	UguiLuaEvent.ButtonClick(coms.transBtnGet.gameObject, nil, function()
        self:OnGetItem(index, coms)
    end)
end

function M:OnBuyItem(index, coms)
	local cardConfig = self.cardConfigs[index]
	require("SDK.PayOrderRequest").RequestOrder(cardConfig.chargeid)
end

function M:OnGetItem(index, coms)
	local cardConfig = self:GetLoopItem(index)
	local getStatus = RechargeData.IsTodayRechargeRewardGetted(cardConfig.chargeid)

	if getStatus then
		Tips("已领取过了")
		return
	end
	
	RechargeData.RequestGetRechargeReward(cardConfig.chargeid)
end

function M:UpdateItem(index, coms)
	-- {money=28, days=30,goldday = 100, goldnow = 280}
	local cardConfig = self:GetLoopItem(index)
	local chargeid = cardConfig.chargeid
	
	coms.textBtnGet.text = string.format("%s元购买", cardConfig.money)

	local buyInfo = RechargeData.GetRechargeInfoById(chargeid)

	local getStatus = RechargeData.IsTodayRechargeRewardGetted(chargeid)

	coms.transBtnBuy.gameObject:SetActive(not buyInfo)
	if buyInfo then
		coms.transBtnGet.gameObject:SetActive(not getStatus)
		coms.transBtnDone.gameObject:SetActive(getStatus)
	else
		coms.transBtnGet.gameObject:SetActive(false)
		coms.transBtnDone.gameObject:SetActive(false)
	end

	--剩余
	local left = RechargeData.GetRechargeRewardLeftDay(chargeid) - 1
	if left >= 0 then
		if (left == 0 and getStatus) or left > 36500 then
			coms.textRemain.text = ""
		else
			coms.textRemain.text = string.format("剩余<color=#00FF00>%d</color>天", left) 
		end
	elseif left < 0 then
		coms.textRemain.text = ""
	end

	--最后一天 -已经领了，那么重新显示购买按钮
	-- --超过了，重新显示购买按钮
	if (left == 0 and getStatus) or  left < 0 then
		coms.transBtnBuy.gameObject:SetActive(true)
		coms.transBtnGet.gameObject:SetActive(false)
		coms.transBtnDone.gameObject:SetActive(false)
	end
end

function M:OnClick(go)
	local goname = go.name
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.GetRechargeReward then
		self:ResetData()
	elseif cmd == LocalCmds.Recharge then
		self:ResetData()
	elseif cmd == LocalCmds.Business then
		self:ResetData()
    end
end

return M