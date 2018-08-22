--[[
	单笔充值
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local preUpdateTime = -1
local rewardExParams = {isnative = true, isShowName = true, showQualityEffect = true}

function M:Awake()
	base.Awake(self)
	
	self.textTime = self:FindText("Offset/Time/TextTime")
	self.textPrice = self:FindText("Offset/Bottom/OriPrice/TextPrice")
	self.transRewardList = self:FindTransform("Offset/RewardList/Viewport/Grid/Item")

	self.transQuick = self:FindTransform("Offset/Bottom/ButtonOK")
	UguiLuaEvent.ButtonClick(self.transQuick.gameObject, self, self.OnClickOK)
	
	self.goButtonClose = self:FindGameObject("Offset/ButtonClose")
	UguiLuaEvent.ButtonClick(self.goButtonClose.gameObject, self, self.Hide)

	self.offset = self:FindGameObject("Offset")

	self.data = {}
	self.rewardContainer = {}
end

function M:Show()
	base.Show(self)

	self.data.id = BusinessData.GetOpenID(Const.BAGROUP_DISCOUNT_BUY)
	self.script =  BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end

	self:TweenOpen(self.offset)

	BusinessData.RequestSingleInfo(self.data.id)

	self:ResetData()
end

function M:ResetData()
	local bid = self.data and self.data.id
	if not bid then
		Debugger.LogWarning("uibasinglecharge error no bid")
		return
	end

	local bconfig = excelLoader.BusinessActivityTable[bid]
	if bconfig == nil then
		Debugger.LogWarning("BusinessActivityTable has no id"..tostring(bid))
		return
	end

	self.endTime = BusinessData.GetEndTime(self.data.id)
	if not BusinessData.Is18YuanOpen() then
		Tips("活动结束")
		self:Hide()
		return
	end

	local moneyCfg = self.script:GetLimitBuyMoneyConfig()
	self.moneyCfg = moneyCfg
	if moneyCfg == nil then
		Debugger.LogWarning("uibadiscountbuy error no shopid/chargeid")
		return
	end
	self.chargeid = moneyCfg.chargeid

	self.textPrice.text = moneyCfg.oriGold

	local chargeTab = excelLoader.ChargeTable[self.chargeid]
	local itemid = self.script:GetLimitBuyMoneyItem(self.chargeid)
	local itemTabCharge = excelLoader.ItemTable[itemid]

	local rewardid = dataMgr.ItemData.GetItemToReward(itemid)
	local rewards = dataMgr.ItemData.GetRewardList({rewardid})
    UITools.CopyRewardListWithItemsEx(rewards, self.rewardContainer, self.transRewardList, rewardExParams)
end

function M:OnClickOK()
	if not self.chargeid or not self.script then
		return
	end

	local isBuyed = self.script:IsMoneyItemBuyed()
	if isBuyed then
		Tips("今日已经购买过了")
		return
	end

	require("SDK.PayOrderRequest").RequestOrder(self.chargeid)
end

local preUpdateTime = -999
function M:Update()
	base.Update(self)

	if Time.time - preUpdateTime < 1 then
		return
	end
	preUpdateTime = Time.time

    if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
	end

	if self.data and self.data.id and not BusinessData.IsBusinessActivityOpen(self.data.id) then
		Tips("活动已结束")
        self:Hide()
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
		self:ResetData()
    end
end

return M