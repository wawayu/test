local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local ActivityData = require "Data.ActivityData"

local ItemTable = require "Excel.ItemTable"
local SettingTable = require "Excel.SettingTable"

local DailyTargetData = dataMgr.DailyTargetData
local SevenDayData = dataMgr.SevenDayData

local base = require "UI.UILuaBase"
local M = base:Extend()
local TP = Const.REWARD_SETTING_TYPE

--[[
七日目标——每日福利
]]
function M:Awake()
	base.Awake(self)

	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem, nil)
end

function M:Show()
	base.Show(self)
	
	self.lv = dataMgr.PlayerData.GetRoleInfo().lv
	self:RefreshPanel()
	self.uiItemLoop:ScrollToGlobalIndex(0)
end

function M:OnLocalMsg(cmd, msg)
	if cmd == LocalCmds.SevenDay then
        self:RefreshPanel()
    end
end

function M:RefreshPanel()
	local selectIndex = self.parent.selectDayIndex 
	self.showFreeReward = SevenDayData.GetSevenDayTable(selectIndex, true, true)
	
	if self.showFreeReward then
		-- 累充单独界面拿出来
		self.tempshowFreeReward = self.showFreeReward
		self.showFreeReward = {}
		for i,data in ipairs(self.tempshowFreeReward) do
			local tp = data.conf.tp
			if tp ~= TP.TARGET_RECHARGE then
				table.insert(self.showFreeReward, data)
			end
		end

		self.uiItemLoop.ItemsCount = #self.showFreeReward
	end
end

--道具
function M:OnCreateItem(index, coms)
	-- print(index)
	-- coms.txtName = self:FindText("TxtName", coms.trans)--等级
	coms.txtDesc = self:FindText("TxtName", coms.trans)--描述
	coms.uiGet = self:FindGameObject("BtnGet", coms.trans)--领取
	coms.uiCharge = self:FindGameObject("BtnCharge", coms.trans)--充值

	--已领取
	coms.uiAlreadyBuy = self:FindGameObject("ImgCantGet", coms.trans)
	-- coms.uiNotAchieve = self:FindGameObject("ImgAchieve", coms.trans)--未达成
	
	--奖励
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)
	coms.rewardContainer = {}

	--按钮事件
	UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
		self:OnClickGet(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms, go)
	end)
	UguiLuaEvent.ButtonClick(coms.uiCharge, nil, function(go)
		self:OnClickGet(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms, go)
	end)
end

function M:OnClickGet(index, coms, go)
	local data = self.showFreeReward[index]
	if not data then
		return
	end
	
	local selectDay = self.parent.selectDayIndex
	local status =  SevenDayData.GetStatus(data)
	if status == 2 then
		return
	end

	if status == 0 then
		dataMgr.SevenDayData.RequestGetLoginTargetRewardReq(selectDay, data.reqtype, data.index)
	elseif data.conf.tp == TP.TARGET_RECHARGE then
		OpenUI("UIRecharge")
	elseif data.conf.tp == TP.TARGET_LV then
		OpenUI("UIActivity")
	end
end

function M:UpdateItem(index, coms)
	local data = self.showFreeReward[index]
	
	local selectDay = self.parent.selectDayIndex
	--名称、描述
	local curPurchase = SevenDayData.GetSevenDayPurchaseByDay(selectDay)
	
	local tp = data.conf.tp
	if tp == TP.TARGET_LOGIN then
		coms.txtDesc.text = "登陆"
	elseif tp == TP.TARGET_LV then
		coms.txtDesc.text = string.format("等级达到(<color=#45CF75>%d</color>/%d)", self.lv, data.reward.lv)
	elseif tp == TP.TARGET_RECHARGE then
		--充值目标
		coms.txtDesc.text = string.format("今日累计充值(<color=#45CF75>%d</color>/%d)", curPurchase, data.reward.num)
	end

	-- 刷新奖励
	if data.reward.rewardid then
		self.rewardExParams = self.rewardExParams or {isnative = true, showQualityEffect = true}
		UITools.CopyRewardList({data.reward.rewardid}, coms.rewardContainer, coms.transRewardItem, self.rewardExParams)
	end

	coms.uiGet:SetActive(false)
	coms.uiCharge:SetActive(false)
	coms.uiAlreadyBuy:SetActive(false)
	local status = dataMgr.SevenDayData.GetStatus(data)
	if status == 2 then
		--已经领取
		coms.uiAlreadyBuy:SetActive(true)
	elseif status == 0 then
		coms.uiGet:SetActive(true)
	else
		coms.uiCharge:SetActive(true)
	end
end

return M