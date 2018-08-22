local PlayerData = require "Data.PlayerData"
local PVPData = require "Data.PVPData"
local ItemData = require "Data.ItemData"
local TeamData = require "Data.TeamData"
local ActivityData = require "Data.ActivityData"
local FriendData = require "Data.FriendData"

local TopData = dataMgr.TopData

local GradeTable = require "Excel.GradeTable"
local SettingTable = require "Excel.SettingTable"
local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local RewardTable = require "Excel.RewardTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

--M.needPlayShowSE = true

------------------巅峰斗技（匹配对战）

--默认选中1v1
local selectMatch = 1
local topType = 1

function M.Open(param)
	selectMatch = param or 1

	topType = ActivityData.GetTopType(selectMatch or 1)
	-- print(selectMatch)
    uiMgr.ShowAsync("UIBattleMatch")
end

function M:Awake()
	base.Awake(self)
	
	self.uiOffset = self:FindGameObject("Offset")

	self.txtPanelName = self:FindText("Offset/Title")

	----------------------------------战绩界面

	self.uiScorePanel = self:FindTransform("Offset/Panel (1)", self.rectTransform)

    self.transHelp = self:FindTransform("Right/Help", self.uiScorePanel)

	--段位
	self.imgGrade = self:FindImage("Right/Top/ImgGradeBg/ImgGrade", self.uiScorePanel)
	self.imgGradeNum = self:FindImage("Right/Top/ImgGradeBg/ImgGradeNum", self.uiScorePanel)
	--胜场
	self.txtWinCount = self:FindText("Right/Top/WinCount/TxtWinCount", self.uiScorePanel)
	--胜率
	self.txtWinRate = self:FindText("Right/Top/WinRate/TxtWinRate", self.uiScorePanel)
	--积分
	self.txtScore = self:FindText("Right/Top/Point/ImgPoint/TxtPoint", self.uiScorePanel)
	--战功
	self.txtZhanGong = self:FindText("Right/Top/ZhanGong/TxtWinCount", self.uiScorePanel)

	--首战礼包
	self.txtBattleChest = self:FindText("Right/Top/BattleChest/TxtWin", self.uiScorePanel)
	self.uiBattleChestEffect = self:FindGameObject("Right/Top/BattleChest/ImgBg/Effect", self.uiScorePanel)
	self.imgBattleChest = self:FindImage("Right/Top/BattleChest/ImgBg/ImgChest", self.uiScorePanel)
	self.uiBattleChestEffect:SetActive(false)
	--首胜礼包
	self.txtWinChest = self:FindText("Right/Top/WinChest/TxtWin", self.uiScorePanel)
	self.uiWinChestEffect = self:FindGameObject("Right/Top/WinChest/ImgBg/Effect", self.uiScorePanel)
	self.imgWinChest = self:FindImage("Right/Top/WinChest/ImgBg/ImgChest", self.uiScorePanel)
	self.uiWinChestEffect:SetActive(false)
	--战斗图片，名称
	self.imgBattle = self:FindImage("Right/Middle/ImageBg/ImgIcon", self.uiScorePanel)
	--uiLoop界面
	self.uiScrollView = self:FindGameObject("Left/Scroll View", self.uiScorePanel)
	self.uiNoData = self:FindGameObject("Left/NoData", self.uiScorePanel)
	self.txtDesc = self:FindText("Left/NoData/TxtDesc", self.uiScorePanel)

	-------------------------------------段位界面

	self.uiGradePanel = self:FindTransform("Offset/Panel (2)", self.rectTransform)

	--段位ScrollView
	self.tranGradeContent = self:FindTransform("Scroll View/Viewport/Content", self.uiGradePanel)
	self.uiGradePrefab = self:FindGameObject("Scroll View/Viewport/Content/Item", self.uiGradePanel)
	self.uiGradePrefab:SetActive(false)

	--ScrollView箭头
	local imgArrow = self:FindGameObject("ButtonRight", self.uiGradePanel)
    UguiLuaEvent.ScrollRectValueChange(self:FindGameObject("Scroll View", self.uiGradePanel), nil, function(go, pos)
		-- print(pos.x)
    	imgArrow:SetActive(pos.x < 1)
    end)

	--当前段位
	self.imgCurGrade = self:FindImage("Buttom/GradeRoot/ImgGrade", self.uiGradePanel)
	self.imgCurGradeNum = self:FindImage("Buttom/GradeRoot/ImgGrade/ImgGradeNum", self.uiGradePanel)

    --按钮。Button，ButtonScale
    UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	--Toggle事件。好友榜、段位榜
	self.toggles = {}
    for i=1,2 do
        local tog = self:FindToggle(string.format("Offset/Panel (1)/ToggleTop/Toggle (%d)" , i))
        table.insert(self.toggles, tog)
        UguiLuaEvent.ToggleClick(tog.gameObject, self, function(_self, _go, _isOn)
        	if _isOn then
        		if i == 1 then
        			--段位榜
        			self.curTab = 2
        		elseif i == 2 then
        			--好友榜
        			self.curTab = 1
        		end

				self:RefreshBoard()
        	end
        end)
    end

    --Tab，战绩、段位
    self.toggleTabs = {}
    for i=1,2 do
        local tog = self:FindToggle(string.format("Offset/ToggleGroup/Toggle (%d)" , i))
        table.insert(self.toggleTabs, tog)
        UguiLuaEvent.ToggleClick(tog.gameObject, self, function(_self, _go, _isOn)
        	if _isOn then
        		self:SwitchPanel(i)
        	end
        end)
    end

    --UILoop，好友榜、段位榜
	self.uiLoop = self:FindGameObject("Offset/Panel (1)/Left/Scroll View/Viewport/Content"):GetComponent(typeof(UILoop))
	self:BindLoopEvent(self.uiLoop, M.UpdateItem, M.OnChoose, nil)
	UguiLuaEvent.ScrollRectValueChange(self:FindGameObject("Offset/Panel (1)/Left/Scroll View"), nil, function(go, pos)
        if pos.y < 0 then
            TopData.LoadNextPageDatas(topType)
        end
    end)

	--变量
	self.curPanel = 1	--战绩界面
	self.curTab = 2		--段位榜

	self:SpawnGradeRewardItem()
end

function M:Show()
	base.Show(self)

	self:TweenOpen(self.uiOffset)

	--战斗类型，1——1v1，2——3v3，3——5v5
	self.selectBattleType = selectMatch
	if selectMatch == 1 then
		self.txtPanelName.text = "巅峰斗技"
	elseif selectMatch == 2 then
		self.txtPanelName.text = "桃园称雄"
	elseif selectMatch == 3 then
		self.txtPanelName.text = "铜雀争锋"
	end

	--默认打开战绩界面
	if self.toggleTabs[1].isOn == true then
		self:SwitchPanel(1)
	else
		self.toggleTabs[1].isOn = true
	end
end

--点击Tab切换界面
function M:SwitchPanel(_type)
	--print("SwitchPanel ", _type)

	self.curPanel = _type
	if _type == 1 then
		--战绩界面
		self.uiScorePanel.gameObject:SetActive(true)
		self.uiGradePanel.gameObject:SetActive(false)

		--刷新
		self:RefreshScorePanel()
		--默认好友榜
		self.toggles[1].isOn = true
	elseif _type == 2 then
		--段位界面
		self.uiScorePanel.gameObject:SetActive(false)
		self.uiGradePanel.gameObject:SetActive(true)

		--当前段位
		self:RefreshGradePanel()
		--奖励
		self:RefreshReward()
	end
end

function M:OnLocalMsg(cmd, msg)
	if cmd == LocalCmds.Friends then
		if msg and msg.cmd then
			if msg.cmd == Cmds.GetFriendDoujiScore.index then
				--得到好友积分信息
				self:RefreshBoard()
			elseif msg.cmd == Cmds.GetFriendList.index then
				--得到所有好友信息
				self:RefreshBoard()
			end
		end
    end

	--段位榜
	if cmd == LocalCmds.Top then
		self:RefreshBoard()
    end

	--record更新
	if cmd == LocalCmds.RecordUpdate then
		self:RefreshScorePanel()
    end
end

--点击按钮
function M:OnClick(go)
	local btnName = go.name
	--print(btnName)
	if btnName == "ButtonClose" then
		self:Hide()
	elseif btnName == "BattleChest" then
		--战斗次数礼包
		local status, settingTab, count = self:IsNextChestOpen(self.selectBattleType, 2)
		if status == 1 then
			--可领取。发包领取
			ActivityData.RequestGetDoujiChestReward(self.selectBattleType, 2)
		elseif status == 2 then
			--已经到最高礼包
		elseif status == 3 then
			Tips(string.format( "当前总战斗次数:%d次，需要达到%d次，才可领取该礼包",count, settingTab[1]))
		end
	elseif btnName == "WinChest" then
		--胜利次数礼包
		local status, settingTab, count = self:IsNextChestOpen(self.selectBattleType, 1)
		if status == 1 then
			--可领取。发包领取
			ActivityData.RequestGetDoujiChestReward(self.selectBattleType, 1)
		elseif status == 2 then
			--已经到最高礼包
		elseif status == 3 then
			Tips(string.format( "当前连胜:%d场，再接再励，连胜达到%d场，即可领取该礼包",count, settingTab[1]) )
		end
	elseif btnName == "BtnShop" then
		--商店
		OpenUI("UIShop")
		--测试
		--uiMgr.ShowAsync("UIBattleResult")
	elseif btnName == "BtnMatch" then
		--匹配
		self:OnClickMatch(self.selectBattleType)
	elseif btnName == "Help" then
		self:OnClickHelp()
	elseif btnName == "ImgGradeBg" then
		self:OnClickGradeDesc(go)
	end
end

--点击匹配
function M:OnClickMatch(type)
	--单人情况下，离开队伍
	if not activityMgr.CheckActivityJoinable(Const.ACTIVITY_ID_BATTLE_MATCH_1V1, nil, function ()
	end) then
		return
	end
	ActivityData.RequestStartMatch(1)
end

-------------------------------------------------战绩界面--------------------------------------------------

--刷新整个战绩界面
function M:RefreshScorePanel()
	--print("RefreshScorePanel")
	self:RefreshBoard()
	self:RefreshPlayerGrade()
	self:RefreshChest()
end

--刷新好友榜或段位榜
function M:RefreshBoard()
	local count = 0
	local desc = ""
	if self.curTab == 1 then
		--好友榜
		self.sortFriendList = ActivityData.GetSortFriendList(self.selectBattleType)
		count = #self.sortFriendList
		desc = "没有好友"
	elseif self.curTab == 2 then
		--段位榜
		self.topInfos = TopData.GetTopInfos(topType)
		count = #self.topInfos
		desc = "没有排行榜信息"
	end
	-- print(count, desc)
	if count == 0 then
		self.uiScrollView:SetActive(false)
		self.uiNoData:SetActive(true)
		self.txtDesc.text = desc
	else
		--有数据
		self.uiScrollView:SetActive(true)
		self.uiNoData:SetActive(false)
		self.uiLoop.ItemsCount = count
	end
end

--1v1，3v3图片,5v5图片，名称
M.BattleIcon = {"dfdj_bg1", "dfdj_bg2", "dfdj_bg3"}

--刷新玩家段位信息
function M:RefreshPlayerGrade()
	--段位
	local gradeTab, index = ActivityData.GetPlayerGradeTable(self.selectBattleType)
	uiMgr.SetSpriteAsync(self.imgGrade, Const.atlasName.Common, gradeTab.icon)
	--九阶
	uiMgr.SetSpriteAsync(self.imgGradeNum, Const.atlasName.NumIcon, "j"..index)

	--依次为，胜场、胜率、积分、荣誉
	self.txtWinCount.text = ActivityData.GetPlayerWinCount(self.selectBattleType)
	self.txtWinRate.text = string.format("%d%%", ActivityData.GetPlayerWinRate(self.selectBattleType))
	self.txtScore.text = ActivityData.GetDouJiScore(self.selectBattleType)
	local honor, honorLimit = ActivityData.GetPlayerHonor(self.selectBattleType)
	self.txtZhanGong.text = string.format("%d/%d", honor, honorLimit)

	--图片icon，名称
	uiMgr.SetSpriteAsync(self.imgBattle, Const.atlasName.BattleMatch, M.BattleIcon[self.selectBattleType])
end

--点击item
function M:OnChoose(index, go)
    --点击事件
    -- print("aaaa")
    -- local signTab = SignTable[index]
	-- if signTab ~= nil then
    --     local itemTab = ItemTable[signTab.rewardid.itemid]
    --     require ("Data.ItemData").ShowItemDetail(nil, itemTab, go.transform)
	-- end
end

--更新好友榜、段位榜
function M:UpdateItem(index, go)
	local trans = go.transform

	local roleInfo = nil
	local score, rate
	if self.curTab == 1 then
		-- 好友榜,friendInfo
		roleInfo = self.sortFriendList[index]
		local scoreInfo = roleInfo["doujiscore"..self.selectBattleType]
		score, rate = scoreInfo.score, scoreInfo.rate
	elseif self.curTab == 2 then
		-- 段位榜,topInfo
		roleInfo = self.topInfos[index]
		score, rate = roleInfo.douji_score.score, roleInfo.douji_score.rate
	end

	if roleInfo ~= nil then
		--头像
		local headIcon = self:FindImage("HeadIcon/ImgBg/ImgHead", trans)
		-- local tableID, tableData = unitMgr.UnpackUnitGuid(roleInfo.guid)
		-- if tableData ~= nil then
		-- 	uiMgr.SetSpriteAsync(headIcon, Const.atlasName.PhotoIcon, tableData.headIcon)
		-- end
		UITools.SetPlayerIcon(headIcon, roleInfo)
		UITools.SetPlayerHeadFrame(self:FindImage("HeadIcon/ImgBg/ImageFrame", trans), roleInfo)
		--名称、等级
		self:FindText("HeadIcon/ImgBg/ImgLvBg/TxtLv", trans).text = tostring(roleInfo.lv)
		self:FindText("HeadIcon/Name/TxtName", trans).text = roleInfo.name
		self:FindText("HeadIcon/BattleValue/Text", trans).text = tostring(score)
		--胜率
		self:FindText("BattleInfo/TxtWin/TxtWinRate", trans).text = string.format("%d%%", rate)
		--段位
		local gradeIcon = self:FindImage("BattleInfo/ImgGrade", trans)
		local gradeTab = ActivityData.GetGradeTable(score, self.selectBattleType)
		uiMgr.SetSpriteAsync(gradeIcon, Const.atlasName.Common, gradeTab.icon)

		--前四名皇冠
		local imgRank = self:FindImage("Rank/Icon", trans)
		local txtRank = self:FindText("Rank/Text", trans)
		if index <= 3 then
			uiMgr.SetSpriteAsync(imgRank, Const.atlasName.Common, "dfdj_"..index)
			imgRank.gameObject:SetActive(true)
			txtRank.gameObject:SetActive(false)
		else
			txtRank.text = index
			imgRank.gameObject:SetActive(false)
			txtRank.gameObject:SetActive(true)
		end
	end
end

--刷新礼包
function M:RefreshChest()
	--战斗场次礼包（count, 2）、胜利场次礼包（win, 1）
	self.uiBattleChestEffect:SetActive(false)
	self.uiWinChestEffect:SetActive(false)
	self:ShowChest(self.selectBattleType, 1, self.uiWinChestEffect,self.txtWinChest, self.imgWinChest)
	self:ShowChest(self.selectBattleType, 2, self.uiBattleChestEffect, self.txtBattleChest, self.imgBattleChest)
end

--战斗场次礼包（count, 2）、胜利场次礼包（win, 1）。格式：{{1,401106},{3,401106},{5,401106}}，战斗、胜利场数——奖励ItemId
function M:ShowChest(battleTp, rewardTp, effect, txtName, imgIcon)
	local status, settingTab = self:IsNextChestOpen(battleTp, rewardTp)

	--礼包
	if settingTab then
		local rewardTab = RewardTable[settingTab[2]]
		if rewardTab == nil then
			return
		end

		local atlas = rewardTab.atlas
		if not atlas then
			atlas = Const.atlasName.Common
		end
		uiMgr.SetSpriteAsync(imgIcon, atlas, rewardTab.rewardui)
		txtName.text = rewardTab.name
	end

	if status == 1 then
		--下一个礼包可领取特效
		effect:SetActive(true)
		UITools.SetImageGrey(imgIcon, false)
	elseif status == 2 then
		--已经是最后一个礼包了，关闭特效，变灰
		effect:SetActive(false)
		UITools.SetImageGrey(imgIcon, true)
	end
end

--SettingTable
M.BattleSetting = {"douji1v1_win_num", "douji1v1_battle_num", "douji3v3_win_num", "douji3v3_battle_num", "douji5v5_win_num", "douji5v5_battle_num"}
--RecordTable
M.BattleRecord = {"douji_win_day", "douji_count_day"}

--下一个礼包是否开启
function M:IsNextChestOpen(battleTp, rewardTp)
	--已经领取几次了
	local getCount = ActivityData.GetRecord("douji_reward_flag", ActivityData.GenerateDoujiId(battleTp, rewardTp))
	local settingIndex = M.BattleSetting[(battleTp - 1)*2 + rewardTp]
	local doujiSetting = SettingTable[settingIndex]

	--下一个礼包
	local nextSettingTab = doujiSetting[getCount + 1]
	--战斗或连胜次数
	local tempCount = ActivityData.GetRecord(M.BattleRecord[rewardTp], battleTp)

	if nextSettingTab then
		if tempCount >= nextSettingTab[1]  then
			--可领取
			return 1, nextSettingTab, tempCount
		else
			--不可领取
			return 3, nextSettingTab, tempCount
		end
	else
		--已经达到最高礼包
		return 2, doujiSetting[getCount], tempCount
	end
end


---------------------------------------------------段位界面------------------------------------

local originHeight = 120
local heightDelta = 30

function M:SpawnGradeRewardItem()
	--选中框
	self.tranSelect = self:FindTransform("Offset/Panel (2)/Scroll View/Viewport/ImgSelect")
	--UILoop
	self.uiGradeLoop = self:FindGameObject("Offset/Panel (2)/Scroll View/Viewport/Content"):GetComponent(typeof(UILoop))
	self:BindLoopEvent(self.uiGradeLoop, M.UpdateGradeItem, nil, function(_self, index, go)
		--print(index, go)
		--点击自己
		UguiLuaEvent.ButtonClick(go, nil, function(_go)
        	self.selectGradeIndex = self.uiGradeLoop:GetItemGlobalIndex(_go) + 1
			self:SetSelectedBound(_go, self.tranSelect)
			self:RefreshReward()
        end)
	end)
	--奖励列表
	self.uiRewardItem = self:FindTransform("Offset/Panel (2)/Buttom/GradeReward/#105RewardList/Viewport/Grid/Item")
end

function M:UpdateGradeItem(index, go)
	-- print("UpdateGradeItem")
	--动态改变高度
	local tranRoot = self:FindTransform("CharRoot", go.transform)
	local rootX = tranRoot.sizeDelta.x
	local rootY = originHeight + (index - 1)*heightDelta
	tranRoot.sizeDelta = Vector2.New(rootX, rootY)

	--图标、分数
	local gradeTab = ActivityData.GetDoujiGradeTableByType(self.selectBattleType)[index]
	if gradeTab ~= nil then
		self:FindText("CharRoot/ImgPoint/TxtPoint", go.transform).text = gradeTab.score
		uiMgr.SetSpriteAsync(self:FindImage("CharRoot/ImgGrade", go.transform), Const.atlasName.Common, gradeTab.icon)
		uiMgr.SetSpriteAsync(self:FindImage("CharRoot/ImgGradeNum", go.transform), Const.atlasName.NumIcon, "j"..index)
	end

	--选中框
	if self.selectGradeIndex == index then
		self:SetSelectedBound(go, self.tranSelect)
	elseif self.tranSelect.parent == go.transform then
		--因为瀑布流，所以相同的物体会用于多个index。
		--当选中框的父物体物体是当前物体，说明该物体下面有选中框，但是该物体并没被选中
  		self.tranSelect.anchoredPosition = Vector2.New(99999, 99999)
	end
end

-- 设置选中框
function M:SetSelectedBound(parentGo, boundTrans)
	UITools.AddChild(self:FindTransform("CharRoot", parentGo.transform), boundTrans.gameObject, false)
	boundTrans.anchorMin = Vector3.zero
	boundTrans.offsetMax = Vector3.zero
	boundTrans.gameObject:SetActive(true)
	boundTrans:SetSiblingIndex(0)
end

--刷新奖励
function M:RefreshReward()
	local mailData = SettingTable["rank_rewards_1v1"][self.selectGradeIndex]
	if mailData then
		local mailTab = excelLoader.MailTable[mailData.mailid]
		if mailTab then
			if self.rewardGoList == nil then self.rewardGoList = {} end
			-- local rewardId = ActivityData.GetDoujiGradeTable()[self.selectGradeIndex].rewarditem
			UITools.CopyRewardListWithItems(mailTab.items, self.rewardGoList, self.uiRewardItem)
		end
	end

	-- self.selectBattleType
end

function M:GetSettingTabByBattleType(tp)
	if tp == 1 then
		return SettingTable["rank_rewards_1v1"]
	elseif tp == 2 then
		return SettingTable["rank_rewards_3v3"]
	elseif tp == 3 then
		return SettingTable["rank_rewards_5v5"]
	end
end

--刷新段位界面
function M:RefreshGradePanel()
	--当前段位
	local gradeTab, index = ActivityData.GetPlayerGradeTable(self.selectBattleType)
	uiMgr.SetSpriteAsync(self.imgCurGrade, Const.atlasName.Common, gradeTab.icon)
	--九阶
	uiMgr.SetSpriteAsync(self.imgCurGradeNum, Const.atlasName.NumIcon, "j"..index)

	--选中哪一个
	-- print(index)
	self.selectGradeIndex = index
	
	--刷新
	self.uiGradeLoop.ItemsCount = #ActivityData.GetDoujiGradeTableByType(self.selectBattleType)
	--调到这个位置
	self.uiGradeLoop:ScrollToGlobalIndex(self.selectGradeIndex)
end

function M:OnClickHelp()
	if selectMatch == 1 then
    	Hint({rectTransform = self.transHelp, content = Lan("dfdj_rule_1v1"), alignment = 0, preferredWidth = 600})
	elseif selectMatch == 2 then

	elseif selectMatch == 3 then

	end
end

function M:OnClickGradeDesc(go)
	--当前段位
	local gradeTab, index = ActivityData.GetPlayerGradeTable(self.selectBattleType)
	local score = ActivityData.GetDouJiScore(self.selectBattleType)

	local curName = gradeTab.gradename
	local curRewards = ""
	local rewards = excelLoader.RewardTable[gradeTab.rewarditem[1]]
	for i2, v2 in ipairs(rewards.showreward) do
		local params = v2[1]
		local itemid = params[2]
		local num = params[3]
		if curRewards ~= "" then
			curRewards = curRewards.."\n"
		end
		curRewards = curRewards..UITools.FormatItemColorName(itemid).." <color=#00ff00>+"..tostring(num).."</color>"
	end

	--下一段位
	local nextGradeTab = ActivityData.GetDoujiGradeTableByType(self.selectBattleType)[index + 1]
	local nextName = nextGradeTab and nextGradeTab.gradename or "无"
	local nextRewards = ""
	if nextGradeTab then
		local rewards = excelLoader.RewardTable[nextGradeTab.rewarditem[1]]
		for i2, v2 in ipairs(rewards.showreward) do
			local params = v2[1]
			local itemid = params[2]
			local num = params[3]
			if nextRewards ~= "" then
				nextRewards = nextRewards.."\n"
			end
			nextRewards = nextRewards..UITools.FormatItemColorName(itemid).." <color=#00ff00>+"..tostring(num).."</color>"
		end
	end

	local format = "当前阶段：%s\n挑战可获得奖励：\n%s\n下一阶段位：%s\n%s\n\n<color=#AE8265>段位的级别越高，每次挑战的奖励越多，赛季奖励越丰富。</color>"
	local desc = string.format(format, curName, curRewards, nextName, nextRewards)
    Hint({rectTransform = go.transform, alignment = 0, preferredWidth = 300, 
    	content = desc,
    	iconAtlas = Const.atlasName.Common, 
    	iconName = gradeTab.icon,
    	name = string.format("段位分：%d", score),
    })
end

return M