--[[
	单笔充值
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local commonParamsTable = {}
local preUpdateTime = -1
local panelLen = 4
local rewardExParams = {isnative = true, isShowName = true, showQualityEffect = true}

function M:Awake()
	base.Awake(self)
	self.coms = {}
	for i = 1,panelLen do
		self.coms[i] = {}
		self.coms[i].trans = self:FindTransform(string.format("Offset/Content/Item (%s)", i))
		self:OnCreateItem(i, self.coms[i])
	end

	self.textTime = self:FindText("Offset/Top/TextTime")

	self.transQuick = self:FindTransform("Offset/Bottom/ButtonQuick")
	UguiLuaEvent.ButtonClick(self.transQuick.gameObject, nil, function()
        OpenUI("UIRecharge")
    end)

	self.transItemsBox = self:FindTransform("ItemsBox")
	self.transRewardList = self:FindTransform("RewardList/Viewport/Grid/Item", self.transItemsBox)
	UguiLuaEvent.ButtonClick(self:FindGameObject("ButtonClose", self.transItemsBox ), nil, function()
        self.transItemsBox.gameObject:SetActive(false)
    end)

	self.mailIdToReward = {}
	self.itemBoxContainer = {}

	effectMgr:SpawnToUI("2d_dbcz_anniu", Vector3.zero, self.transQuick , 0)
end

function M:Show()
	base.Show(self)

	self.transItemsBox.gameObject:SetActive(false)

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
		Debugger.LogWarning("uibasinglecharge error no bid")
		return
	end

	local bconfig = excelLoader.BusinessActivityTable[bid]
	if bconfig == nil then
		Debugger.LogWarning("BusinessActivityTable has no id"..tostring(bid))
		return
	end

	self.rewardConfig = bconfig.rewardconfig
	if #self.rewardConfig ~= panelLen then
		Debugger.LogWarning("uibasinglecharge #rewardConfig ~= panelLen")
		return
	end

	for i = 1,panelLen do
		self:UpdateItem(i, self.coms[i])
	end

	self.endTime = BusinessData.GetEndTime(self.data.id)
	if self.endTime <= 0 then
		Tips("活动结束")
		self:Hide()
	end
end

function M:GetLoopItem(idx)
    return self.rewardConfig[idx]
end

function M:OnCreateItem(index, coms)
	local trans = coms.trans
	coms.imageBox = self:FindImage("Image", trans)
	coms.textName = self:FindText("TextName", trans)
	coms.textCost = self:FindText("TextCost", trans)
	coms.textLimit = self:FindText("TextLimit", trans)
	coms.transFlag = self:FindTransform("Flag", trans)
	
	UguiLuaEvent.ButtonClick(trans.gameObject, nil, function()
        self:OnChooseItem(index, coms)
    end)

	effectMgr:SpawnToUI("2d_libao_"..index, Vector3.zero, trans, 0)
end

function M:OnChooseItem(index, coms)
	local reward = self:GetLoopItem(index)
	local mailReward = self.mailIdToReward[reward.mailid]
	if mailReward.rewardid then
		self:ShowItemDetail(mailReward.rewardid)
	end
end

function M:UpdateItem(index, coms)
	local reward = self:GetLoopItem(index)
	if not self.mailIdToReward[reward.mailid] then
		local _rewardid,itemConf = dataMgr.ItemData.GetMailToReward(reward.mailid)
		self.mailIdToReward[reward.mailid] = {rewardid = _rewardid , itemConf = itemConf}
	end
	local mailReward = self.mailIdToReward[reward.mailid]
	if not mailReward.rewardid then
		Debugger.LogError("UIBASingleCharge mail id has no reward:"..tostring(reward.mailid))
		return
	end
	local showItemConf = mailReward.itemConf
	local rewardConfig = excelLoader.RewardTable[mailReward.rewardid]
	coms.textName.text = showItemConf.name

	local chargeTab = excelLoader.ChargeTable[reward.chargeid] or error("no chargeid"..tostring(reward.chargeid))
	coms.textCost.text = math.ceil(chargeTab.rmb/100)

	local num = self.script:GetSingleChargeCount(index)
	num = math.min(num, reward.limit)
	coms.textLimit.text = string.format( "%s/%s", num, reward.limit)

	UITools.SetImageIcon(coms.imageBox, Const.atlasName.ItemIcon, showItemConf.icon, true)

	coms.transFlag.gameObject:SetActive(index == panelLen)
end

function M:ShowItemDetail(rewardid)
	self.transItemsBox.gameObject:SetActive(true)
	-- 刷新奖励
	UITools.CopyRewardList({rewardid}, self.itemBoxContainer, self.transRewardList, rewardExParams)
end	

function M:UpdateChild()
	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#00aa00>%s</color>", strTime)
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
		self:ResetData()
    end
end

return M