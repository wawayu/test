
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
local rewardExParams = {isnative = true}
local preUpdateTime = -1
local toggleNotifyPos = Vector3.New(65.6,19.4,0)

--[[进阶]]

function M:Awake()
	base.Awake(self)
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.transOffset = self:FindTransform("Offset")

	--
	self.uiEmptyRoot = self:FindGameObject("Empty", self.transOffset)
	self.uiSrollView = self:FindGameObject("Scroll View", self.transOffset)

	--倒计时
	self.textTime = self:FindText("Top/LeftTime/TxtTime", self.transOffset)
	--内容
	self.txtContent = self:FindText("Top/Desc/TxtContent", self.transOffset)
	--跳转按钮
	self.uiBtnGo = self:FindGameObject("Top/BtnGo", self.transOffset)
	self.txtBtnGo = self:FindText("Top/BtnGo/TxtNum", self.transOffset)

	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content", self.transOffset)
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)

	local onCallback = function(_idx)
        self:OnToggle(_idx)
    end
    self.toggles = UITools.BindTogglesEvent(self:FindTransform("Offset/ToggleGroup"), 3, onCallback)
end

function M:Show()
	base.Show(self)
	self.togIndex = 1

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end

	UITools.SetToggleOnIndex(self.toggles, self.togIndex)

	self.txtContent = self.businessTab.desc
end

function M:ResetData()
	local bid = self.data and self.data.id
	if not bid then
		Debugger.LogWarning("uibagroupbuy error no bid")
		return
	end

	self.businessTab = BusinessActivityTable[bid]
	if not self.businessTab then
		Debugger.LogWarning("BusinessActivityTable error no bid:"..tostring(bid))
		return
	end

	local bInfo = self.script:Info()
	self.curChargeNum = (bInfo and bInfo.chargeCount) or 0
	self.chargeNumToday = dataMgr.RechargeData.GetChargeNumToday()

	self.rewardGroup, self.personConfig = self.script:GetPersonReward()
	local targetperson = self.personConfig[self.togIndex] or 0
	self.rewardConfig = self.rewardGroup[targetperson]
	if not self.rewardConfig then
		Debugger.LogWarning("uibagroupbuy error no rewardconfig tog"..tostring(self.togIndex))
		return
	end

	self.uiEmptyRoot:SetActive(false)
	self.uiSrollView:SetActive(true)

	--刷新UILoop
	self.uiItemLoop.ItemsCount = #self.rewardConfig

	--跳转按钮
	self.uiBtnGo:SetActive(self.businessTab.goMenuID ~= nil)
	if self.businessTab.buttonname then
		self.txtBtnGo.text = self.businessTab.buttonname
	end

	--倒计时

	--内容
	--self.txtContent.text = self.businessTab.desc
	local togText
	for i,v in ipairs(self.toggles) do
		togText = self:FindText("Background/Label", self.toggles[i].transform)
		togText.text = string.format("团购%s人", self.personConfig[i])
	end

	self.endTime = BusinessData.GetEndTime(self.data.id)

	for i,v in ipairs(self.toggles) do
		notifyMgr.AddNotify(v, self.script:IsSingleNotify(i), toggleNotifyPos, notifyMgr.NotifyType.Common)
	end
end

function M:IsNotify(index)

end

function M:GetLoopItem(idx)
    return self.rewardConfig[idx]
end

--道具
function M:OnCreateItem(index, coms)
	coms.txtName = self:FindText("TxtActivity", coms.trans)--活动名称
	coms.uiGet = self:FindGameObject("BtnFind", coms.trans)--领取
	coms.uiDone = self:FindGameObject("BtnDone", coms.trans)--已领取
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.textNum = self:FindText("TxtNum", coms.trans)
	coms.goNot = self:FindGameObject("ImgNot", coms.trans)
	coms.rewardContainer = {}

	--领取
	UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
		self:OnChoose(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:OnChoose(index, go)
	local bRewardConfig = self:GetLoopItem(index)
	self.script:SendGetReward(bRewardConfig.id)
end

local str1 = "今日全服首充人数达到%s (<color=#3caa1f>%s/%s</color>)"
local str2 = "今日全服首充人数达到%s (<color=#3caa1f>%s/%s</color>)且个人充值达到<color=#3caa1f>%s</color>元宝"
function M:UpdateItem(index, coms)
	local bRewardConfig = self:GetLoopItem(index)
	--名称,图标
	local tnum = bRewardConfig.personnum
	local tmoney = bRewardConfig.money
	local cnum = self.curChargeNum
	if tmoney == 0 then
		coms.txtName.text = string.format(str1, tnum, cnum, tnum)
	else
		coms.txtName.text = string.format(str2, tnum, cnum, tnum, tmoney)
	end
	
	local status = self.script:Status(bRewardConfig.id)
	coms.uiDone:SetActive(status == 2)
	coms.uiGet:SetActive(status == 1)
	coms.goNot:SetActive(status == 0)

	-- 刷新奖励
	UITools.CopyRewardList({bRewardConfig.reward}, coms.rewardContainer, coms.transRewardItem, rewardExParams)

	--coms.textNum.text = string.format("<color=#00aa00>%s/%s</color>", self.chargeNumToday, bRewardConfig.money)
	coms.textNum.text = ""
end

function M:OnToggle(index)
	self.togIndex = index
	self:ResetData()
end

function M:UpdateChild()
	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
		self:ResetData()
	elseif cmd == LocalCmds.ReCharge then
		self:ResetData()
	end
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnGo" then
		self:OnClickGo()
	elseif btnName == "BtnDesc" then
		--描述按钮
		Hint({rectTransform = go.transform, content = Lan("getback_desc"), alignment = 0})
	end
end

--跳转
function M:OnClickGo()
	if self.businessTab and self.businessTab.goMenuID then
		local MenuEventManager = require "Manager.MenuEventManager"
		MenuEventManager.DoMenu(self.businessTab.goMenuID)
	end
end


return M