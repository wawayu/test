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

M.fixedInfoData = {
	isShow = true,
	showPos = Vector2.zero,
	ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}

local PREVIEW_IMAGE_NAME = {
	{"bg_dbcz08", "bg_dbcz012"},
	{"bg_dbcz09", "bg_dbcz08"},
	{"bg_dbcz010", "bg_dbcz08"},
	{"bg_dbcz011", "bg_dbcz08"},
}

function M:Awake()
	base.Awake(self)
	
	self.offset = self:FindGameObject("Offset")

	self.textName = self:FindText("Offset/Detail/TextName")
	self.effectDot = self:FindTransform("Offset/Detail/EffectDot")
	self.textCost = self:FindText("Offset/Detail/TextCost")
	self.textLimit = self:FindText("Offset/Detail/TextLimit")
	self.imageBox = self:FindImage("Offset/Detail/ImageBox")
	
	self.textTime = self:FindText("Offset/Time/TextTime")

	self.transQuick = self:FindTransform("Offset/Bottom/ButtonQuick")
	UguiLuaEvent.ButtonClick(self.transQuick.gameObject, nil, function()
		self:Hide()
        OpenUI("UIRecharge")
	end)
	
	self.goButtonClose = self:FindGameObject("Offset/ButtonClose")
	UguiLuaEvent.ButtonClick(self.goButtonClose.gameObject, self, self.Hide)

	self.transItemsBox = self:FindTransform("Offset/ItemsBox")
	self.transRewardList = self:FindTransform("RewardList/Viewport/Grid/Item", self.transItemsBox)
	self.transRect = self:FindTransform("RewardList/Viewport/Grid", self.transItemsBox)
	
	local v3zero = Vector3.New(-18.5, -0.07, 0)
	local onCallback = function(_idx)
		self.selectIndex = _idx
		self.transRect.anchoredPosition = v3zero
		self:ResetData()
    end
	self.toggles = UITools.BindTogglesEvent(self:FindTransform("Offset/ToggleGroup"), 4, onCallback)
	self.textToggleName = {}
	self.transEffToggle = {}
	for i,v in ipairs(self.toggles) do
		self.textToggleName[i] = self:FindText("Label", v.transform)
		self.transEffToggle[i] = self:FindTransform("EffectDot", v.transform)
	end

	self.mailIdToReward = {}
	self.itemBoxContainer = {}
	self.data = {}
	self.effectTable = {}

	self.imageItemPreview = {
		self:FindImage("Offset/Detail/ItemPreview1"),
		self:FindImage("Offset/Detail/ItemPreview2"),
	}

	effectMgr:SpawnToUI("2d_dbcz_anniu", Vector3.zero, self.transQuick , 0)
end

function M:Show()
	base.Show(self)

	self.transItemsBox.gameObject:SetActive(false)

	self.data.id = BusinessData.GetOpenID(Const.BAGROUP_SINGLE_CHARGE)
	self.script =  BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end

	BusinessData.RequestSingleInfo(self.data.id)

	self.isToggleDone = false
	UITools.SetToggleOnIndex(self.toggles, 1)
	self:TweenOpen(self.offset)
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

	if not self.isToggleDone then
		for i,v in ipairs(self.toggles) do
			local itemConf = self:GetItemConf(i)
			self.textToggleName[i].text = itemConf.name
		end
		self.isToggleDone = true
	end

	self.endTime = BusinessData.GetEndTime(self.data.id)
	if self.endTime <= 0 then
		Tips("活动结束")
		self:Hide()
	end

	self.selectIndex = self.selectIndex or 1
	self:UpdateItem(self.selectIndex)

	local imagename = PREVIEW_IMAGE_NAME[self.selectIndex]
	for i=1, #imagename do
		UITools.SetActive(self.imageItemPreview[i], true)
		UITools.SetImageIcon(self.imageItemPreview[i], Const.atlasName.DanBiLiBao, imagename[i])
	end
	for i=#imagename+1, #self.imageItemPreview do
		UITools.SetActive(self.imageItemPreview[i], false)
	end
end

function M:GetLoopItem(idx)
    return self.rewardConfig[idx]
end

function M:GetItemConf(index)
	local reward = self:GetLoopItem(index)
	if not reward then Debugger.LogError(index) end
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
	return showItemConf, mailReward.rewardid
end

function M:UpdateItem(index)
	local reward = self:GetLoopItem(index)
	local showItemConf, rewardid = self:GetItemConf(index)
	if not showItemConf then
		return
	end
	self.textName.text = showItemConf.name

	local chargeTab = excelLoader.ChargeTable[reward.chargeid] or error("no chargeid"..tostring(reward.chargeid))
	self.textCost.text = math.ceil(chargeTab.rmb/100)

	local num = self.script:GetSingleChargeCount(index)
	num = math.min(num, reward.limit)
	self.textLimit.text = string.format( "%s/%s", num, reward.limit)

	UITools.SetImageIcon(self.imageBox, Const.atlasName.ItemIcon, showItemConf.icon, false)

	for i=1,panelLen do
		local eff = self.effectTable[i]
		if eff and not tolua.isnull(eff) then
			eff.gameObject:SetActive(self.selectIndex == i)
		elseif self.selectIndex == i then
			self.effectTable[i] = effectMgr:SpawnToUI("2d_libao_"..i, Vector3.zero, self.effectDot, 0)
		end
	end

	local transTog = self.transEffToggle[self.selectIndex]
	if tolua.isnull(self.transEffSelect) then
		self.transEffSelect = effectMgr:SpawnToUI("2d_danbilibao_1", Vector3.zero, transTog, 0)
	end
	UITools.AddChildSimply(self.transEffSelect, transTog)

	self.transItemsBox.gameObject:SetActive(true)
	-- 刷新奖励
	UITools.CopyRewardList({rewardid}, self.itemBoxContainer, self.transRewardList, rewardExParams)
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