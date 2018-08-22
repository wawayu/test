--[[
	独立界面，单日累计充值
]]
local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"

local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local preUpdateTime = -999
local rewardExParams = {isnative = true, showQualityEffect = true}

function M:Awake()
	base.Awake(self)
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.transOffset = self:FindTransform("Offset")
	self.recharged = self:FindTransform("Offset/Recharged")

	self.uiSrollView = self:FindGameObject("Scroll View", self.transOffset)
	
	--倒计时
	self.textTime = self:FindText("Time/TextTime", self.transOffset)
	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content", self.transOffset)
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)
end

function M:Show()
	base.Show(self)

	BusinessData.RequestBusinessInfo()

	self.id = BusinessData.GetOpenID(Const.BAGROUP_CHARGE_ACCUMULATE)
	self.businessTab = BusinessActivityTable[self.id]
	
	self.script = BusinessData.GetScript(self.id)
	if not self.script then
		self:Hide()
		return
	end

	self:ResetData()
end

function M:ResetData()
	if not self.id or not self.businessTab  then
		return
	end

	self.activityRewardList = self.script:GetRewards()
	self.chargeNumToday = self.script:GetScore() --dataMgr.RechargeData.GetChargeNumToday()

	--刷新UILoop
	self.uiItemLoop.ItemsCount = #self.activityRewardList

	self.endTime = BusinessData.GetEndTime(self.id)

	UITools.SetMoneyInfo(self.recharged.gameObject, Const.ITEM_ID_VCOIN, self.chargeNumToday, "")
end

function M:GetLoopItem(index) 
	return self.activityRewardList[index]
end

--道具
function M:OnCreateItem(index, coms)
	coms.txtName = self:FindText("TxtActivity", coms.trans)--活动名称
	coms.uiGet = self:FindGameObject("BtnFind", coms.trans)--领取
	coms.uiDone = self:FindGameObject("BtnDone", coms.trans)--已领取
	coms.uiCantGet = self:FindGameObject("ImgCantGet", coms.trans)--未达成
	coms.textNeedCharge = self:FindText("TextNeedCharge", coms.trans)
	
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}

	--领取
	UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
		self:OnChoose(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:OnChoose(index, go)
	local rewardData = self.activityRewardList[index]
	if rewardData ~= nil and not self.script:IsRewardGot(rewardData.id) then
		self.script:SendGetReward(rewardData.id)
	end
end

function M:UpdateItem(index, coms)
	local rewardData = self:GetLoopItem(index)
	if rewardData == nil then
		return
	end
		
	--名称,图标
	coms.txtName.text =string.format("累充%s元宝", rewardData.gold)
	local status = self.script:Status(rewardData.id)

	coms.uiGet:SetActive(status == 1)
	coms.uiDone:SetActive(status == 2)
	coms.uiCantGet:SetActive(status == 0)
	
	local needCharge = rewardData.gold - self.chargeNumToday
	if needCharge > 0 then
		coms.textNeedCharge.text = string.format("再充值<color=#EA2F2FFF>%d</color>元宝即可领取", needCharge)
	else
		coms.textNeedCharge.text = ""
	end

	-- 刷新奖励
	UITools.CopyRewardList({rewardData.rewardid}, coms.rewardContainer, coms.transRewardItem, rewardExParams)
end

function M:Update()
	if Time.time - preUpdateTime < 0.3 then
		return
	end
	preUpdateTime = Time.time
	
	if self.endTime then
		self.textTime.text = string.format("<color=#2cffee>%s</color>", Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime()))
	end
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "ButtonClose" then
		self:Hide()
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Recharge then
		self:ResetData()
	elseif cmd == LocalCmds.Record then
		self:ResetData()
	elseif cmd == LocalCmds.Business then
		self:ResetData()
    end
end


return M