--[[
	超值礼盒-元宝购买的
]]
local BusinessData = dataMgr.BusinessData

local base = require "UI.UILuaBase"
local M = base:Extend()
local preUpdateTime = -1
local rewardExParams = {isnative = true, isShowName = true, showQualityEffect = true}
local toggleNotifyPos = Vector3.New(52,43,0)
local effectName = "2d_libao_1"
-- 中间宝箱图标/顶部ads1 /顶部ads2/元宝数量
local imageConfig = {{"chaozhi1", "bg_czlb08", "bg_czlb05", "bg_czlb04"}, {"chaozhi2", "bg_czlb07", "bg_czlb06", "bg_czlb14"}, {"4113", "bg_czlb08", "bg_czlb05", "bg_czlb04"}}

function M:Awake()
	base.Awake(self)
	
	self.effectDot = self:FindTransform("Offset/Center/Detail/EffectDot")
	
	self.transTime = self:FindTransform("Offset/Time")
	self.textTime = self:FindText("TextTime", self.transTime)
	self.textButtonText = self:FindText("Offset/Bottom/ButtonOK/Text")
	self.transCost = self:FindTransform("Offset/Bottom/ButtonOK/Cost")
	self.textCostPrice = self:FindText("Offset/Bottom/ButtonOK/Cost/TextPrice")
	self.imageCostIcon = self:FindImage("Offset/Bottom/ButtonOK/Cost/ImageIcon")
	self.imageButtonOK = self:FindImage("Offset/Bottom/ButtonOK")
	
	self.transDetail = self:FindTransform("Offset/Center/Detail")
	self.transDetail2 = self:FindTransform("Offset/Center/Detail2")
	self.imageBox = self:FindImage("ImageBox", self.transDetail)
	self.transEffectDot = self:FindTransform("EffectDot", self.transDetail)
	self.imageGold = self:FindImage("Offset/Center/Right/ImageGold")
	
	self.imageAds1 = self:FindImage("Offset/Top/Image1")
	self.imageAds2 = self:FindImage("Offset/Top/Image2")

	self.textTips = self:FindText("Offset/Bottom/TextTips")

	self.transQuick = self:FindTransform("Offset/Bottom/ButtonOK")
	UguiLuaEvent.ButtonClick(self.transQuick.gameObject, nil, function(go)
		self:OnClickOK(go)
	end)
	
	self.goButtonClose = self:FindGameObject("Offset/ButtonClose")
	UguiLuaEvent.ButtonClick(self.goButtonClose.gameObject, self, self.Hide)

	self.transRewardList = self:FindTransform("Offset/Center/RewardList/Viewport/Grid/Item")
	
	local onCallback = function(_idx)
		self.selectIndex = _idx
		self:ResetData()
    end
	self.toggles = UITools.BindTogglesEvent(self:FindTransform("Offset/ToggleGroup"), 3, onCallback)

	self.itemBoxContainer = {}
	self.data = {}
end

function M:Show()
	base.Show(self)

	self.data.id = BusinessData.GetOpenID(Const.BAGROUP_BESTGIFT_GOLD)
	self.script =  BusinessData.GetScript(self.data.id)
	if not self.script then
		Tips(Lan("activity_end"))
		self:Hide()
		return
	end

	BusinessData.RequestSingleInfo(self.data.id)

	UITools.SetToggleOnIndex(self.toggles, 1)

	if not self.effectTrans or tolua.isnull(self.effectTrans) then
		self.effectTrans = effectMgr:SpawnToUI(effectName, Vector3.zero, self.transEffectDot, 0)
	end
end

function M:ResetData()
	local bid = self.data.id
	self.bconfig = excelLoader.BusinessActivityTable[bid]
	self.rewardConfig = self.bconfig.rewardconfig

	self.endTime = self.script:GetActivityEndTime()

	self.selectIndex = self.selectIndex or 1

	if self.selectIndex == 3 then
		Tips("暂未开放")
		UITools.SetToggleOnIndex(self.toggles, self.lastSelectIndex)
		return
	end

	self.lastSelectIndex = self.selectIndex
	self:UpdateItem(self.selectIndex)

	self:UpdateNotifys()

	preUpdateTime = -999
end

function M:GetLoopItem(idx)
    return self.rewardConfig[idx]
end

function M:UpdateItem(index)
	local data = self:GetLoopItem(index)
	self.curRewardConfig = self.rewardConfig[index]
	local finalRewardID = self.curRewardConfig.rewardid[2]
	self.finalReward = dataMgr.ItemData.GetRewardList({finalRewardID})[1]
	self.firstRewardID = self.curRewardConfig.rewardid[1]

	local images = imageConfig[index]
	UITools.SetImageIcon(self.imageBox, "ChaoZhiLiBao", images[1], true)
	UITools.SetImageIcon(self.imageAds1, "ChaoZhiLiBao", images[2], true)
	UITools.SetImageIcon(self.imageAds2, "ChaoZhiLiBao", images[3], true)
	UITools.SetImageIcon(self.imageGold, "ChaoZhiLiBao", images[4], true)

	self.transCost.gameObject:SetActive(false)
	self.transTime.gameObject:SetActive(false)
	self.textTips.text = ""
	self.getRewardEndTime = nil

	local rewardInfo = self.script:GetRewardInfo(index)
	self.textButtonText.text = ""
	local curTime = netMgr.mainClient:GetServerTime()
	local getReward2Time = self.script:GetRewardEndTime(index)
	if rewardInfo.progress == 0 then
		if data.lv then
			self.textButtonText.text = data.lv.."级领取"
		else
			self.transCost.gameObject:SetActive(true)
			self.textCostPrice.text = data.cost.num
		end
		self.transTime.gameObject:SetActive(true)
	elseif rewardInfo.progress == 1 then
		if curTime < getReward2Time then
			self.textButtonText.text = "领取"
			self.getRewardEndTime = getReward2Time
		else
			self.textButtonText.text = "领取"
			local gold = self.finalReward and self.finalReward.num or 0
			self.textTips.text = string.format("可领取%s元宝", gold)
		end
	else
		self.textButtonText.text = "已领取"
	end
	
	local canGetReward = self.script:CanGetReward(index)
	UITools.SetImageGrey(self.imageButtonOK, not canGetReward)

	-- 刷新奖励
	UITools.CopyRewardList({self.firstRewardID}, self.itemBoxContainer, self.transRewardList, rewardExParams)
end

function M:OnClickOK(go)
	if self.script then
		self.script:SendGetReward(self.selectIndex)
	end
end

function M:UpdateNotifys()
	if not self.script then
		return
	end
    for i,v in ipairs(self.toggles) do
        notifyMgr.AddNotify(self.toggles[i], self.script:IsIndexNotify(i), toggleNotifyPos, notifyMgr.NotifyType.Common)
    end
end

function M:Update()
	base.Update(self)

	if Time.time - preUpdateTime < 1 then
		return
	end
	preUpdateTime = Time.time

	local curTime = netMgr.mainClient:GetServerTime()

	if self.endTime then
		local remainTime = self.endTime - curTime
		if remainTime > -1 then
			local strTime = Utility.GetVaryTimeFormat(remainTime)
			self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
		else
			self.textTime.text = "已结束"
		end
	end

	if self.getRewardEndTime  then
		local gold = self.finalReward and self.finalReward.num or 0
		local remainTime = self.getRewardEndTime - curTime
		local rt = Utility.GetVaryTimeFormat(remainTime)
		self.textTips.text = string.format("%s后可领取%s元宝", rt, gold)

		self.preRemainTime = self.preRemainTime or remainTime
		if self.preRemainTime >= 0 and remainTime < 0 then
			self:ResetData()
		end
		self.preRemainTime = remainTime
	end

	local id = self.data and self.data.id
	if id and not BusinessData.IsBusinessActivityOpen(id) then
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