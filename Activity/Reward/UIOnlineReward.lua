
local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local ActivityData = require "Data.ActivityData"

local ItemTable = require "Excel.ItemTable"
local SettingTable = require "Excel.SettingTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[
在线礼包
]]
function M:Awake()
	base.Awake(self)
	
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)

	--什么时候可领取
	self.imgRing = self:FindImage("ImgBg/ImgRing")
	self.txtTime = self:FindText("ImgBg/ImgRing/TxtTime")

	self.uiAlreadyGet = self:FindGameObject("ImgBg/TxtAlreadyGet")
	self.uiBtnGet = self:FindGameObject("ImgBg/BtnGet")

	-- PrintTable(self.imgRing)

	--在线时长
	self.txtOnlineTime = self:FindText("ImgBg/TxtOnline/TxtOnlineTime")

	--每个Item
	self.uiItemList = {}
    for i = 1, 6 do
		local rootTrans = self:FindTransform(string.format("ImgBg/Root/Item (%d)", i))

		local itemContainer = {
			txtName = self:FindText("TxtName", rootTrans),
			imgIcon = self:FindImage("ImgIcon", rootTrans),
			txtTime = self:FindText("TxtNum", rootTrans),
			uiGou = self:FindGameObject("ImgGou", rootTrans),
			uiMask = self:FindGameObject("Bg", rootTrans),
			uiCanGet = self:FindGameObject("ImgOK", rootTrans),
		}
		-- PrintTable(itemContainer)
		table.insert(self.uiItemList, itemContainer)
    end

	self.onlineReward = SettingTable["online_reward"]
	self.lastOnlineTab = self.onlineReward[#self.onlineReward]
	self.singleDeltaRate = 1/#self.onlineReward
	self.rateList = {}
	for k,v in ipairs(self.onlineReward) do
		local rate = v.time/self.lastOnlineTab.time
		self.rateList[k] = rate
	end
end

function M:Show()
	base.Show(self)

	self:RefreshPanel()
end

function M:OnLocalMsg(cmd, msg)
	if ActivityData.CheckRecordUpdate(cmd, msg, nil, "reward") then
        self:RefreshPanel()
    end
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnGet" then
		--点击可领取按钮，发包
		if self.curIndex then
			-- print(self.curIndex)
			RewardData.RequestGetOnelineReward(self.curIndex)
		end
	end
end

function M:RefreshPanel()
	local allGet, canGet, nextOnlineTabIndex = self:RefreshAllItems()
	-- print(allGet, canGet, nextOnlineTabIndex)
	local onlineTime = activityMgr.GetOnlineTime()
	if allGet then
		--都已经领了
		self.uiAlreadyGet:SetActive(true)
		self.uiBtnGet:SetActive(false)
		self.imgRing.gameObject:SetActive(false)
	elseif canGet then
		--可领取
		self.uiAlreadyGet:SetActive(false)
		self.uiBtnGet:SetActive(true)
		self.imgRing.gameObject:SetActive(false)
	else
		--没有可领取
		self.uiAlreadyGet:SetActive(false)
		self.uiBtnGet:SetActive(false)
		self.imgRing.gameObject:SetActive(true)

		--倒计时
		if nextOnlineTabIndex then
			local nextOnlineTab = self.onlineReward[nextOnlineTabIndex]
			if nextOnlineTab then
				local deltaTime = nextOnlineTab.time - onlineTime
				-- print(nextOnlineTab.time/60)
				M.OnCountDown(self.txtTime, deltaTime, 0, function()
					--倒计时结束回调
					self:RefreshPanel()
				end)
	
				--圆形进度条
				local preTime = 0
				local initRate = 0
				local preOnlineTab = self.onlineReward[nextOnlineTabIndex - 1]
				if preOnlineTab then
					preTime = preOnlineTab.time
					initRate = (nextOnlineTabIndex - 1)*self.singleDeltaRate
				end

				if onlineTime >= preTime and onlineTime <= nextOnlineTab.time then
					-- print(onlineTime/60, preTime/60, nextOnlineTab.time/60)
					local relateRate = (onlineTime - preTime )/(nextOnlineTab.time - preTime)
					local totolRate = initRate + self.singleDeltaRate*relateRate
					if totolRate > 1 then
						totolRate = 1
					elseif totolRate < 0 then
						totolRate = 0
					end
					
					self.imgRing.fillAmount = totolRate
				else
					print(onlineTime/60, preTime/60, nextOnlineTab.time/60)
					print("时间出错")
				end
			end
		end
	end

	--在线时长
	M.OnCountDown(self.txtOnlineTime, onlineTime, 150000)
end

function M.OnCountDown(_text, from, to, _callBack)
	local tween = TweenText.Begin(_text, from, to, math.abs(to - from), 0)
	tween.isTime = true
	tween:SetOnFinished(function()
		if _callBack then
			_callBack()
		end
	end)
end

function M:RefreshAllItems()
	local allGet = true
	local canGet = false
	local nextOnlineTabIndex = nil
	self.curIndex = nil
	local onlineTime = activityMgr.GetOnlineTime()
	-- print(onlineTime/60)
	for k,v in ipairs(self.uiItemList) do
		local coms = v
		local onlineTab = self.onlineReward[k]
		if onlineTab ~= nil then
			--根据在线时间
			if RewardData.IsOnlineRewardAchieved(k) then
				--已领取
				coms.uiGou:SetActive(true)
				coms.uiMask:SetActive(true)
				coms.uiCanGet:SetActive(false)
			else
				allGet = false
				--未领取
				if onlineTime >= onlineTab.time then
					--可领取
					-- print("可领取", onlineTab.time/60)
					canGet = true
					self.curIndex = self.curIndex or k
					coms.uiGou:SetActive(false)
					coms.uiMask:SetActive(false)
					coms.uiCanGet:SetActive(true)
				else
					--未达成
					-- print("未达成", onlineTab.time/60)
					nextOnlineTabIndex = nextOnlineTabIndex or k
					coms.uiGou:SetActive(false)
					coms.uiMask:SetActive(false)
					coms.uiCanGet:SetActive(false)
				end
			end

			--名称，图片
			local rewards = require("Data.ItemData").GetRewardList({onlineTab.rewardid})
			-- PrintTable(rewards)
			local num = #rewards
			if num >= 1 then
				-- print("在线奖励物品多余1个")
				local itemTab = ItemTable[rewards[1].itemid]
				if itemTab then
					-- print(itemTab.name)
					--名称
					coms.txtName.text = string.format("%sx%d", itemTab.name, rewards[1].num)
					--图片
					UITools.SetImageIcon(coms.imgIcon, Const.atlasName.ItemIcon, itemTab.icon, true)
				end
			end

			--时间
			coms.txtTime.text = string.format("%d分", onlineTab.time / 60)
		end
	end

	return allGet, canGet, nextOnlineTabIndex
end

return M