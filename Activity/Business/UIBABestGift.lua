--[[
	超值礼包
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local preUpdateTime = -1
local panelLen = 2		-- 礼包奖励长度
local rewardExParams = {isnative = true, showQualityEffect = true}

function M:Awake()
	base.Awake(self)

	self.textTime = self:FindText("Offset/Top/TextTime")

	self.coms = {}
	for i = 1,panelLen do
		self.coms[i] = {}
		self.coms[i].trans = self:FindTransform(string.format("Offset/Panel (%s)", i))
		self:OnCreateItem(i, self.coms[i])
	end

	self.transHead = self:FindTransform("Offset/Panel (1)/Head")
	self.transHead2 = self:FindTransform("Offset/Panel (2)/Head")
	effectMgr:SpawnToUI("2d_jchd_czlb", Vector3.zero, self.transHead, 0)
	effectMgr:SpawnToUI("2d_jchd_czlb", Vector3.zero, self.transHead2, 0)
end

function M:Show()
	base.Show(self)

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end
	
	self:ResetData()
end

function M:ResetData()
	local bid = self.data and self.data.id
	if not bid then
		Debugger.LogWarning("uibabastgift error no bid")
		return
	end

	local bconfig = excelLoader.BusinessActivityTable[bid]
	if bconfig == nil then
		Debugger.LogWarning("BusinessActivityTable has no id"..tostring(bid))
		return
	end

	self.rewardConfig = bconfig.rewardconfig
	if #self.rewardConfig ~= panelLen then
		Debugger.LogWarning("uibabastgift #rewardconfig ~= "..tostring(panelLen))
		return
	end

	for i = 1,panelLen do
		self:UpdateItem(i, self.coms[i])
	end

	self.endTime = BusinessData.GetEndTime(self.data.id)
end

function M:GetLoopItem(idx)
    return self.rewardConfig[idx]
end

function M:OnCreateItem(index, coms)
	local trans = coms.trans
	coms.transRewardList = self:FindTransform("RewardList/Viewport/Grid/Item", trans)
	coms.transOK = self:FindTransform("ButtonOK", trans)
	coms.textOK = self:FindText("ButtonOK/Text", trans)
	coms.transOKDone = self:FindTransform("ImageDone", coms.transOK)
	coms.rewardContainer = {}
	
	UguiLuaEvent.ButtonClick(coms.transOK.gameObject, nil, function()
        self:OnChooseItem(index, coms)
    end)
end

function M:OnChooseItem(index, coms)
	local reward = self:GetLoopItem(index)
	local isBuy = self.script:IsBestGiftBuy(reward.chargeid)
	if isBuy then
		Tips("已卖完")
		return
	end
	
	require("SDK.PayOrderRequest").RequestOrder(reward.chargeid)
end

function M:UpdateItem(index, coms)
	local reward = self:GetLoopItem(index)
	
	local chargeTab = excelLoader.ChargeTable[reward.chargeid] or error("no chargeid"..tostring(reward.chargeid))
	coms.textOK.text = string.format("%s元抢购" ,math.ceil(chargeTab.rmb/100))

	-- 刷新奖励
	local item1 = chargeTab.reward and chargeTab.reward.itemid
	local itemTab = item1 and excelLoader.ItemTable[item1]
	local rewardid = itemTab and itemTab.effect and itemTab.effect[1]
	if not rewardid then
		Debugger.LogWarning("uibabestgift error")
		return
	end
	UITools.CopyRewardList({rewardid}, coms.rewardContainer, coms.transRewardList, rewardExParams)

	local isBuy = self.script:IsBestGiftBuy(reward.chargeid)
	coms.transOKDone.gameObject:SetActive(isBuy)
end

function M:UpdateChild()
	local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
	self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Shop then
		self:ResetData()
	elseif cmd == LocalCmds.Recharge then
		self:ResetData()
    end
end

return M