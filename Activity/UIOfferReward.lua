local ActivityData = require "Data.ActivityData"
local TeamData = require "Data.TeamData"
local MissionData = require "Data.MissionData"
local PlayerData = require "Data.PlayerData"

local TeamTable = require "Excel.TeamTable"
local MissionTable = require "Excel.MissionTable"
local NpcTable = require "Excel.NpcTable"
local ActivityTable = require "Excel.ActivityTable"

local UIWidgetBase = require("UI.Widgets.UIWidgetBase")


local base = require "UI.UILuaBase"
local M = base:Extend()

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true

local battleNum = 0

--------------悬赏榜

function M:Awake()
    base.Awake(self) 
	
	self.uiOffset = self:FindGameObject("Offset")

	--规则描述
	self.uiRuleDesc = self:FindGameObject("Offset/Panel/Right/RuleDesc")

	--右边
	--榜单信息
	self.uiInfoRoot = self:FindGameObject("Offset/Panel/Right/InfoRoot")
	self.imgCharIcon = self:FindImage("Offset/Panel/Right/InfoRoot/ImgChar/ImgCharBg/ImageIcon")
	self.txtCharName = self:FindText("Offset/Panel/Right/InfoRoot/ImgChar/TxtName")
	--Star
	self.tranStarContent = self:FindTransform("Offset/Panel/Right/InfoRoot/StarRoot")
	self.uiStarPrefab = self:FindGameObject("Offset/Panel/Right/InfoRoot/StarRoot/ImgStar")
	self.uiStarPrefab:SetActive(false)
	--奖励
	self.transRewardItem = self:FindTransform("Offset/Panel/Right/InfoRoot/RewardList/Viewport/Grid/Item")
	--CountDown倒计时
	self.txtCountDownRoot = self:FindGameObject("Offset/Panel/Right/InfoRoot/CountDown")
	self.txtCountDown = self:FindText("Offset/Panel/Right/InfoRoot/CountDown/TxtCountDown")
	--状态条
	self.imgStatus = self:FindImage("Offset/Panel/Right/InfoRoot/ImgChar/ImgStatus")
	self.imgStatus.gameObject:SetActive(false)
	--规则文字
	self.txtRuleDesc = self:FindText("Offset/Panel/Right/RuleDesc")

	--左边
	--底部倒计时
	self.txtAllCountDown = self:FindText("Offset/Panel/Left/TxtDown/TxtCountDown")

    --按钮。Button，ButtonScale
    UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	--UILoop
	self.offerStars = {}
	self.uiLoop = self:FindGameObject("Offset/Panel/Left/Viewport/Content"):GetComponent(typeof(UILoop))
	self:BindLoopEvent(self.uiLoop, M.UpdateItem, nil, function(_self, index, go)
		--创建星星
		local prefab = self:FindGameObject("CharRoot/StarRoot/ImgStar", go.transform)
		local transContent = self:FindTransform("CharRoot/StarRoot", go.transform)
		prefab:SetActive(false)
		local uiOfferStarItems = {}
    	UIWidgetBase.DynamicCreateMore(uiOfferStarItems, 5, prefab, transContent , self , nil)
		for i,v in ipairs(uiOfferStarItems) do
			v.go.name = tostring(i)
		end

    	table.insert(self.offerStars, uiOfferStarItems)

    	--添加事件
        UguiLuaEvent.ButtonClick(go, self, function(_self, _go)
        	self:OnChoose(self.uiLoop:GetItemGlobalIndex(go) + 1, go)                
        end)
	end)

	--ScrollView箭头
	local imgArrow = self:FindGameObject("Offset/Panel/Left/ImgArrow")
    UguiLuaEvent.ScrollRectValueChange(self:FindGameObject("Offset/Panel/Left"), nil, function(go, pos)
		-- print(pos.x)
    	imgArrow:SetActive(pos.x < 1)
    end)

	--生成右侧面板星星
	self:SpawnOfferStar()
end

function M:Show()
	base.Show(self)

	self:TweenOpen(self.uiOffset)

	ActivityData.GetRewardMissionList(true)
	
	--刷新界面
	self:RefreshPanel(true)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
		if msg.cmd == Cmds.GetRewardMissionList.index then
			self:RefreshPanel()
			self:CheckFightTeamWarning()
		end
    end
end

--刷新界面
function M:RefreshPanel(resetScroll)
	self:RefreshDetailPanel()
	self:RefreshOfferInfo(resetScroll)
end

--点击按钮
function M:OnClick(go)
	local btnName = go.name
	--print(btnName)
	if btnName == "ButtonWorld" then
		--世界求助
		local playerOfferInfo = ActivityData.GetPlayerRewardMission()
		if playerOfferInfo ~= nil then
			self:GetHelp(Const.CHAT_CHANNEL_WORLD, nil, MissionTable[playerOfferInfo.missionid])
		end
	elseif btnName == "ButtonGuild" then
		--军团求助
		local playerOfferInfo = ActivityData.GetPlayerRewardMission()
		if playerOfferInfo ~= nil then
			self:GetHelp(Const.CHAT_CHANNEL_GUILD, nil, MissionTable[playerOfferInfo.missionid])
		end
	elseif btnName == "ButtonClose" then
		self:Hide()
	elseif btnName == "BtnDo" then
		--点击右界面，进行任务
		self:OnClickRightPanel()
	end
end

--求助
function M:GetHelp(_channel, isAction, missionTab)
	--非帮派成员无法发送求助
	if _channel == Const.CHAT_CHANNEL_GUILD and not require("Data.GuildData").GetGuildInfo() then
		Tips(Lan("guild_no"))
		return
	end

	if not isAction then
		if not UITools.CanPressButton("recruit", 5) then
			return
		end
	end

	local teamTab = TeamTable[400]

	--是否已经有队伍
	local teamInfo = TeamData.GetCurrentTeamInfo()
	if teamInfo ~= nil then
		--已经有队伍
		if TeamData.IsPlayerTeamLeader() then
			--自己是队长
			if teamInfo.members ~= nil and #teamInfo.members < 5  then
				TeamData.SendTeamRecruitMsg(teamTab.minLevel, teamTab.maxLevel, string.format("%d星悬赏榜", missionTab.stars), "", _channel)
			elseif #teamInfo.members >= 5 then
				Tips("队伍已满，无需求助")
			end
		else
			--自己不是队长
			Tips("只有队长才能求助")
		end
	else
		--非组队。创建队伍，创建好后，再求助
		TeamData.RequestCreateTeam(400, "", function()
			self:GetHelp(_channel, true, missionTab)
		end)
	end
end

----------------------------------------------左边榜单界面

function M:RefreshOfferInfo(resetScroll)
	self.uiLoop.ItemsCount = 20

	if resetScroll then
		--自动重置位置
		local currentHuntIndex = 1
		local curTime = netMgr.mainClient:GetServerTime()
		for i = 1, 20 do
			local info = ActivityData.GetMissionInfoByIndex(i)
			if info and not info.iscomplete and ActivityData.GetMissionInfoTimeout(info) > curTime then
				currentHuntIndex = i
				break
			end
		end
		self.uiLoop:ScrollToGlobalIndex(currentHuntIndex - 1)
	end

	--先计算一次时间
	ActivityData.CalcRewardMissionNextTime()
	--倒计时结束。重新申请
	self:OnCountDown(self.txtAllCountDown, ActivityData.GetNextTimeout() - netMgr.mainClient:GetServerTime())
end

function M:OnChoose(index, go)
	local missionInfo = ActivityData.GetMissionInfoByIndex(index)
	if not missionInfo then
		--没被领取，打开弹窗
		local playerOfferInfo = ActivityData.GetPlayerRewardMission()
		if not playerOfferInfo then
			--判断次数是否已经用完
			if not activityMgr.IsActivityRemainCount(Const.ACTIVITY_ID_MISSION_REWARD, true) then
				return
			end

			--玩家未领取过
			MissionData.RequestAcceptMissionByIndex(index)
		else
			Tips("你已经在本轮中接取过任务，请等待下一轮")
		end
	else
		--已经被人领取过了。如果接取的人是自己
		self:OnClickRightPanel(missionInfo)
	end
end

function M:UpdateItem(index, go)
	local rootTrans = go.transform
	local uiCharRoot = self:FindGameObject("CharRoot", rootTrans)
	local uiNoCharRoot = self:FindGameObject("NoCharRoot", rootTrans)

	local missionInfo = ActivityData.GetMissionInfoByIndex(index)
	if missionInfo ~= nil then
		-- Debugger.LogError("UpdateItem missionInfo error")
		uiNoCharRoot:SetActive(false)
		uiCharRoot:SetActive(true)

		local missionTab = MissionTable[missionInfo.missionid]
		local npcId = missionTab.completeNeed[1].npc
		local npcTab = NpcTable[npcId]
		--图标
		local imgIcon = self:FindImage("CharRoot/ImgChar/ImgCharBg/ImageIcon", rootTrans)
		--名称
		local txtName = self:FindText("CharRoot/ImgChar/TxtName", rootTrans)
		--状态
		local imgStatus = self:FindImage("CharRoot/ImgChar/ImgStatus", rootTrans)
		--猎人
		local txtHunter = self:FindText("CharRoot/Hunter/TxtHunter", rootTrans)

		--活动图标,获得的物品图标。todo
		uiMgr.SetSpriteAsync(imgIcon, Const.atlasName.ItemIcon, npcTab.headIcon)
		--名称
		-- local bIndex = string.find(npcTab.name, ">")
		-- local eIndex = string.find(npcTab.name, "</")
		-- -- print(bIndex, eIndex)
		-- local name = "no"
		-- if eIndex-1 > bIndex+1 then
		-- 	name = string.sub(npcTab.name, bIndex+1 , eIndex-1)
		-- end
		txtName.text = npcTab.name
		-- 猎手名称
		txtHunter.text = missionInfo.huntername
		--状态
		self:SetImgStatus(imgStatus, missionInfo)
		--星级
		local itemList = {}
		for i=1,5 do
			table.insert(itemList,{go = self:FindGameObject(string.format("CharRoot/StarRoot/%d", i), rootTrans)})
		end
		self:RefreshOfferStar(itemList, missionTab)
	else
		--未被人领取
		uiNoCharRoot:SetActive(true)
		uiCharRoot:SetActive(false)
	end
end

function M:SetImgStatus(img, missionInfo)
	if missionInfo.iscomplete then
		-- 已归案
		uiMgr.SetSpriteAsync(img, Const.atlasName.Common, "yiguian")
	else
		if ActivityData.GetMissionInfoTimeout(missionInfo) <= netMgr.mainClient:GetServerTime() then
			-- 已逃脱
			uiMgr.SetSpriteAsync(img, Const.atlasName.Common, "yitaotuo")
		else
			-- 追捕中
			uiMgr.SetSpriteAsync(img, Const.atlasName.Common, "zhuibuzhong")
		end
	end
end

--------------------------------------------右边描述界面

M.SatusName = {"zhuibuzhong","yitaotuo","yiguian"}

--生成星星
function M:SpawnOfferStar()
	--星星
	self.uiOfferStarItems = {}
    UIWidgetBase.DynamicCreateMore(self.uiOfferStarItems, 5, self.uiStarPrefab , self.tranStarContent , self , nil)
end

--刷新右侧面板
function M:RefreshDetailPanel()
	--判断自己是否已经有榜单
	local playerOfferInfo = ActivityData.GetPlayerRewardMission()
	if playerOfferInfo == nil then
		--没有榜单，显示规则
		self:ShowRulePanel()
	else
		--有榜单，显示榜单信息
		self.uiRuleDesc:SetActive(false)
		self.uiInfoRoot:SetActive(true)

		local missionTab = MissionTable[playerOfferInfo.missionid]
		local npcId = missionTab.completeNeed[1].npc
		local npcTab = NpcTable[npcId]

		--角色图标,名称
		uiMgr.SetSpriteAsync(self.imgCharIcon, Const.atlasName.ItemIcon, npcTab.headIcon)
		----名称
		-- local bIndex = string.find(npcTab.name, ">")
		-- local eIndex = string.find(npcTab.name, "</")
		-- -- print(bIndex, eIndex)
		-- local name = "no"
		-- if eIndex-1 > bIndex+1 then
		-- 	name = string.sub(npcTab.name, bIndex+1 , eIndex-1)
		-- end
		self.txtCharName.text = npcTab.name

		--星级
		self:RefreshOfferStar(self.uiOfferStarItems, missionTab)
		--刷新奖励
		if self.rewardGoList == nil then self.rewardGoList = {} end
    	UITools.CopyRewardList({missionTab.reward[1]}, self.rewardGoList, self.transRewardItem)

		--是否完成
		if playerOfferInfo.iscomplete then
			-- 已归案。隐藏倒计时
			-- self.txtCountDownRoot:SetActive(false)
			--显示规则界面
			self:ShowRulePanel()
		else
			local playerTimeout = ActivityData.GetMissionInfoTimeout(playerOfferInfo)
			if playerTimeout <= netMgr.mainClient:GetServerTime() then
				-- 已逃脱
				-- self.txtCountDownRoot:SetActive(false)
				--显示规则界面
				self:ShowRulePanel()
			else
				-- 追捕中
				self.txtCountDownRoot:SetActive(true)
				local time = playerTimeout - netMgr.mainClient:GetServerTime()
				if playerTimeout > ActivityData.GetNextTimeout() then
					time = ActivityData.GetNextTimeout() - netMgr.mainClient:GetServerTime()
				end
				self:OnCountDown(self.txtCountDown, time)
			end
		end
		-- self:SetImgStatus(self.imgStatus, playerOfferInfo)
	end
end
function M:OnClickRightPanel(missionInfo)
	missionInfo = missionInfo or ActivityData.GetPlayerRewardMission()

	if missionInfo ~= nil then
		if missionInfo.hunterid == PlayerData.GetRoleInfo().guid then
			if not missionInfo.iscomplete and ActivityData.GetMissionInfoTimeout(missionInfo) > netMgr.mainClient:GetServerTime()  then
				--玩家的任务，并且未逃脱、未完成
				if dataMgr.TeamData.IsHaveTeam() then
					MissionData.DoMission(missionInfo.missionid)
				else
					self:CheckFightTeamWarning()
				end
			end  
		end
	end
end

function M:ShowRulePanel()
	self.uiRuleDesc:SetActive(true)
	self.uiInfoRoot:SetActive(false)
	self.txtRuleDesc.text = self:GetLeftCount()
end

function M:GetLeftCount()
	local activityTab = ActivityTable[Const.ACTIVITY_ID_MISSION_REWARD]
	local curCount = 5 - ActivityData.GetRecord(activityTab.recordId, activityTab.id)
	if curCount < 0 then
		curCount = 0
	end
	return string.format(Lan("offerreward_desc"), curCount) 
end

function M:OnCountDown(uiTxt, seconds)
	if seconds > 0 then
		TweenText.Begin(uiTxt, seconds, 0, seconds, 0)
		self.tweenTextContent = uiTxt.gameObject:GetComponent(typeof(TweenText))
		self.tweenTextContent.isTime = true
		self.tweenTextContent:SetOnFinished(function()
			self:RefreshPanel()
			ActivityData.GetRewardMissionList(true)
		end)
	end
end

--刷新星级
function M:RefreshOfferStar(itemList, missionTab)
	if itemList then
		for k,v in ipairs(itemList) do
			if k <= missionTab.stars then
				v.go:SetActive(true)
			else
				v.go:SetActive(false)
			end
		end
	end
end

function M:CheckFightTeamWarning()
	local playerOfferInfo = ActivityData.GetPlayerRewardMission()
	if playerOfferInfo and (not playerOfferInfo.iscomplete) then
		if not dataMgr.TeamData.IsHaveTeam() then
			UIMsgbox.ShowChoose(Lan("fight_team_warning"), function(ok, data)
				if ok == true then
					OpenUI("UITeam", {TeamTableId=400, autoRecruit=true})
				end
			end, nil, "提示")
		end
	end
end

return M