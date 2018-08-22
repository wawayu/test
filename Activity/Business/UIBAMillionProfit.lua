--[[
	一本万利
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"
local RechargeData = require "Data.RechargeData"

local rewardExParams = {isnative = true, showQualityEffect = true}

local base = require "UI.UILuaBase"
local M = base:Extend()
local itemLen = 7
local profitType = 2

function M.Open()
	OpenUI("UIReward", {panelIndex=7})
end

function M:Awake()
	base.Awake(self)

	self.coms = {}
	for i = 1,itemLen do
		self.coms[i] = {}
		self.coms[i].trans = self:FindTransform(string.format("Offset/Scroll View/Viewport/Content/Item (%s)", i))
		self:OnCreateItem(i, self.coms[i])
	end

	self.textNeedMoney = self:FindText("Offset/Top/ButtonsStatus/ButtonGreen/Text")
	self.transMoneyGreen = self:FindTransform("Offset/Top/ButtonsStatus/ButtonGreen")
	self.transMoneyNot = self:FindTransform("Offset/Top/ButtonsStatus/ImgNot")

	UguiLuaEvent.ButtonClick(self.transMoneyGreen.gameObject, nil, function()
        self:OnClickRecharge()
    end)
end

function M:OnClickRecharge()
	if self.isBought then
		Tips("已经充值")
	else
		if self.rechargeTab then
			--充值
			require("SDK.PayOrderRequest").RequestOrder(self.rechargeTab.id)
		end
	end
end
function M:Show()
	base.Show(self)

	self:ResetData()
end

function M:ResetData()

	self.rechargeTab = RechargeData.GetProfitChargeTableByType(profitType)
	local info = RechargeData.GetRechargeInfoById(self.rechargeTab.id)

	-- info--已购买
	self.isBought = info ~= nil	
	-- -- rewardgrouppluustable 中一本万利 {id, type, lv=天数,rewardid}
	self.rewardConfig = RechargeData.GetProfitTableByType(profitType)

	local costMoney = math.ceil(self.rechargeTab.rmb / 100 )
	if costMoney then
		self.textNeedMoney.text = string.format("%s 元购买", costMoney)
	end

	self.transMoneyGreen.gameObject:SetActive(not self.isBought)
	self.transMoneyNot.gameObject:SetActive(self.isBought)

	for i = 1,itemLen do
		self:UpdateItem(i, self.coms[i])
	end

	--notifyMgr.AddNotify(self.toggles[2], notifyMgr.IsProfitWanLiNotify(), toggleNotifyPos, notifyMgr.NotifyType.Common)
	self.parent:CheckActive()
end

function M:GetLoopItem(idx)
    return self.rewardConfig[idx]
end

function M:OnCreateItem(index, coms)
	local trans = coms.trans
	coms.textName = self:FindText("TxName", coms.trans)
	coms.transGetGreen = self:FindTransform("BtnGet", coms.trans)
	coms.transGetGrey = self:FindTransform("BtnAlreadyGet", coms.trans)
	coms.transDone = self:FindTransform("BtnDone", coms.trans)
	coms.transRewardItem = self:FindTransform("#105RewardList/Viewport/Grid/Item", coms.trans)
	coms.rewardContainer = {}
	
	UguiLuaEvent.ButtonClick(coms.transGetGreen.gameObject, nil, function()
        self:OnChooseItem(index, coms)
    end)
end

function M:OnChooseItem(index, coms)
	local isGot = RechargeData.IsRechargeRewardGetted(self.rechargeTab.id, index)

	if isGot then
		Tips("已领取")
		return
	end

	local reward = self:GetLoopItem(index)
	if reward ~= nil then
		--领取
		RechargeData.RequestGetRechargeReward(self.rechargeTab.id, 
			index)
	end

	self:ResetData()
end

function M:UpdateItem(index, coms)
	-- rewardgrouppluustable 中一本万利
	local reward = self:GetLoopItem(index)
	
	coms.textName.text = string.format("第%s天", index)
	
	-- 刷新奖励
	UITools.CopyRewardList({reward.rewardid}, coms.rewardContainer, coms.transRewardItem, rewardExParams)

	local isRewardGot = RechargeData.IsRechargeRewardGetted(self.rechargeTab.id, index)
	--未领取
	local left = RechargeData.GetRechargeRewardLeftDay(self.rechargeTab.id)
	local day = self.rechargeTab.daynum - left + 1
	-- print(day, left)
	local isDayEnough = day >= index

	coms.transGetGreen.gameObject:SetActive(not isRewardGot and self.isBought and isDayEnough)
	coms.transDone.gameObject:SetActive(isRewardGot)
	coms.transGetGrey.gameObject:SetActive(not self.isBought or not isDayEnough)
end

function M:OnClick(go)

end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.GetRechargeReward then
		self:ResetData()
	elseif cmd == LocalCmds.Recharge then
		self:ResetData()
    end
end

return M