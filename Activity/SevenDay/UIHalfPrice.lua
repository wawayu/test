local ActivityData = require "Data.ActivityData"

local ItemTable = require "Excel.ItemTable"
local SevenDayData = dataMgr.SevenDayData

local base = require "UI.UILuaBase"
local M = base:Extend()

--------------首冲

function M:Awake()
	base.Awake(self)
	--奖励物品
	self.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item")

	--前往充值、领取奖励按钮
	self.uiBtnCharge = self:FindGameObject("BtnRoot/BtnBuy")
	self.imageBtnCharge = self:FindImage("BtnRoot/BtnBuy")
	self.uiBtnGet = self:FindGameObject("BtnRoot/TxtAlreadyBuy")
	UguiLuaEvent.ButtonClick(self.uiBtnCharge, self, M.OnClick)

	--原价、现价
	self.imgOriPriceIcon = self:FindImage("OriPrice/ImgIcon")
	self.txtOriName = self:FindText("OriPrice/ImgIcon/TxtNum")
	self.imgCurPriceIcon = self:FindImage("CurPrice/ImgIcon")
	self.txtCurName = self:FindText("CurPrice/ImgIcon/TxtNum")

	self.textNum = self:FindText("NumText")

	--设置表
	self.settingHalfPrice = excelLoader.RewardSettingTable[Const.REWARD_SETTING_TYPE.TARGET_HALFPRICE]
end

function M:Show()
	base.Show(self)

	self:RefreshPanel()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.SevenDay then
		self:RefreshPanel()
    end
end

function M:GetRewardData(day)
	return self.settingHalfPrice[day].reward
end

--点击按钮
function M:OnClick(go)
	if go.name == "BtnBuy" then
		local remain, maxnum = SevenDayData.GetHalfPriceRemain(self.parent.selectDayIndex)
		if remain == 0 then
			Tips("物品已售罄")
			return
		end
		--前往充值
		self.curHalfPriceData = self:GetRewardData(self.parent.selectDayIndex)
		local curItemTab = ItemTable[self.curHalfPriceData.halfprice.itemid]
		if curItemTab then
			local itemCount = dataMgr.PlayerData.GetItemCount(self.curHalfPriceData.halfprice.itemid)
			if itemCount >= self.curHalfPriceData.halfprice.num then
				--消耗足够
				dataMgr.SevenDayData.RequestGetLoginTargetRewardReq(self.parent.selectDayIndex, 2, 1)
			else
				Tips("元宝不足")
				--打开充值界面
				OpenUI("UIRecharge")
			end
		end
	end
end

--刷新界面按钮
function M:RefreshPanel()
	self.curHalfPriceData = self:GetRewardData(self.parent.selectDayIndex)
	
	--刷新奖励
	if self.rewardGoList == nil then self.rewardGoList = {} end
	UITools.CopyRewardList({self.curHalfPriceData.rewardid}, self.rewardGoList, self.transRewardItem, false)
	
	--原价
	local oriItemTab = ItemTable[self.curHalfPriceData.price.itemid]
	if oriItemTab then
	UITools.SetImageIcon(self.imgOriPriceIcon, Const.atlasName.ItemIcon, oriItemTab.icon, true)
		self.txtOriName.text = self.curHalfPriceData.price.num
	end

	--现价
	local curItemTab = ItemTable[self.curHalfPriceData.halfprice.itemid]
	if curItemTab then
		UITools.SetImageIcon(self.imgCurPriceIcon, Const.atlasName.ItemIcon, curItemTab.icon, true)
		self.txtCurName.text = self.curHalfPriceData.halfprice.num
	end

	local remain, maxnum = SevenDayData.GetHalfPriceRemain(self.parent.selectDayIndex)
	local color = remain == 0 and "aa0000" or "00aa00"
	local str = "今日全服限购次数：<color=#00aa00>%s</color> (剩余:<color=#%s>%s</color>)"
	self.textNum.text = string.format(str, maxnum, color, remain)

	--半价是在第二位
	local gotReward = SevenDayData.IsRewardGetByDayAndIndex(self.parent.selectDayIndex, 2)
	-- print(gotReward)
	if gotReward then
		--已经领取
		self.uiBtnCharge:SetActive(false)
		self.uiBtnGet:SetActive(true)
	else
		--未领取
		self.uiBtnCharge:SetActive(true)
		self.uiBtnGet:SetActive(false)

		UITools.SetImageGrey(self.imageBtnCharge, remain == 0)
	end
end

return M