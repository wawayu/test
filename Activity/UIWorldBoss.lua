local ActivityData = require "Data.ActivityData"
local TeamData = require "Data.TeamData"
local PlayerData = require "Data.PlayerData"

local WorldBossTable = require "Excel.WorldBossTable"
local PosTable = require "Excel.PosTable"
local SceneTable = require "Excel.SceneTable"
local NpcTable = require "Excel.NpcTable"
local ActivityTable = require "Excel.ActivityTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true

local battleNum = 0

--[[
1.每天前6次挑战可获得物品奖励
2.所有首领共享物品奖励次数
3.物品奖励次数每天5点更新
4.挑战失败不扣除挑战次数
--]]

--------------悬赏榜

function M:Awake()
    base.Awake(self)
    	
	self.uiOffset = self:FindGameObject("Offset")

	--boss信息。名称、描述
	self.txtBossName = self:FindText("Offset/Panel/Left/Name/Text")
	self.txtBossDesc = self:FindText("Offset/Panel/Left/Desc/TxtDesc")
	--模型父物体
	self.transModelParent = self:FindTransform("Offset/Panel/Left/Model/CameraModel/Model")
	--奖励物品
	self.transRewardItem = self:FindTransform("Offset/Panel/Left/DropReward/RewardList/Viewport/Grid/Item")

	--可获得物品次数
	self.txtLeftCount = self:FindText("Offset/Panel/Right/AchieveRoot/ImgBg/Text/TextCount")
	--倒计时
	self.TxtCountDown = self:FindText("Offset/Panel/Right/AchieveRoot/CountDownRoot/Text/TxtCountDown")
	--选中框
	self.tranSelect = self:FindTransform("Offset/Panel/Right/Scroll View/Viewport/ImgSelect")
	self.uiContent = self:FindTransform("Offset/Panel/Right/Scroll View/Viewport/Content")

    --按钮。Button，ButtonScale
    UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	--uiLoop商品
	self.uiLoop = self:FindLoop("Offset/Panel/Right/Scroll View/Viewport/Content")
	self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.UpdateItem, nil)

	--模型RenderTexture
	self:LoadRenderTexture("Offset/Panel/Left/Model/CameraModel", "Offset/Panel/Left/Model/RawImage", "RenderTexture0")

	self.bossList = ActivityData.GetCurrentWolrdBoss()
end

function M:Show()
	base.Show(self)

	self:TweenOpen(self.uiOffset)

	--刷新界面
	self.selectIndex = 1
	self:RefreshBossList()
	self:RefreshBossInfo()
	ActivityData.RequestGetWorldBossList()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
		if msg.cmd == Cmds.GetWorldBossList.index then
			-- print("bbbbbbbbbb")
			self:RefreshBossList()
		end
    end
end

--点击按钮
function M:OnClick(go)
	if go.name == "ButtonClose" then
		self:Hide()
	elseif go.name == "ButtonDesc" then
		Hint({rectTransform = go.transform, content = Lan("worldboss_desc") , alignment = 0})
	end
end

function M:GetLeftCount()
	local activityTab = ActivityTable[Const.ACTIVITY_ID_WORLDBOSS]
	local curCount = 6 - ActivityData.GetRecord(activityTab.recordId, activityTab.id)
	if curCount < 0 then
		curCount = 0
	end
	return curCount
end

----------------------------------------------Boss列表

function M:RefreshBossList()
	--刷新UILoop
	self.uiLoop.ItemsCount = #self.bossList
	self.selectBossTab = self.bossList[self.selectIndex]
	-- self.selectBossTab = self.bossList[1401]
	
	--归位
	self.uiContent.anchoredPosition3D = Vector3.zero

	--剩余获得物品次数
	self.txtLeftCount.text = self:GetLeftCount()

	--倒计时
	local time = activityMgr.GetNextRefreshTime("boss_refreshtime") - netMgr.mainClient:GetServerTime()
	self:OnCountDown(self.TxtCountDown, time, function()
		--倒计时结束回调
		ActivityData.CountDownOver()
		self:RefreshBossList()
	end)
end

function M:OnCreateItem(index, coms)
	--名称
	coms.txtName = self:FindText("HeadIcon/TxtName", coms.trans)
	--等级
	coms.txtLv = self:FindText("TxtLv", coms.trans)
	--已完成
	coms.uiDone = self:FindGameObject("ImgDone", coms.trans)
	--传送按钮
	coms.uiBtnGo = self:FindGameObject("BtnDeliver", coms.trans)
	--地点
	coms.txtWhare = self:FindText("TxtWhere", coms.trans)

	--按钮

	UguiLuaEvent.ButtonClick(coms.go, nil, function(go)
		self:OnClickItem(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms, 1)
	end)

	--传送按钮
	UguiLuaEvent.ButtonClick(coms.uiBtnGo, nil, function(go)
		self:OnClickItem(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms, 2)
	end)
end

function M:OnClickItem(index, coms, type)
	local bossTab = self.bossList[index]
	if bossTab ~= nil then
		if type == 1 then
			if self.selectIndex == index then
				return
			end

			--点击item
			self.selectBossTab = bossTab
			self:RefreshBossInfo()

			--设置选中框
			self.selectIndex = index
			self:SetSelectedBound(coms.go, self.tranSelect)
		elseif type == 2 then
			--点击传送按钮
			if sceneMgr.RequestPosByCheckLeaveCopy(bossTab.transferpos) then
	            --关闭所有独占UI
	            uiMgr.HideAllMonopolizes()
			end
		end
	end
end

function M:UpdateItem(index, coms)
	-- print("UpdateItem", index)
	local worldBossTab = self.bossList[index]
	if worldBossTab == nil then
		Debugger.LogError("UpdateItem error")
		return
	end

	--名称
	-- local npcTab = NpcTable[worldBossTab.npcid]
	coms.txtName.text = worldBossTab.name

	--等级
	coms.txtLv.text = worldBossTab.lv
	--地点
	local posTab = PosTable[worldBossTab.transferpos]
	local sceneTab = SceneTable[posTab.sceneID]
	coms.txtWhare.text = sceneTab.name
	--状态
	if ActivityData.IsNpcKilled(worldBossTab.npcid) then
		--该Boss已经死亡
		coms.uiDone:SetActive(true)
		coms.uiBtnGo:SetActive(false)
	else
		coms.uiDone:SetActive(false)
		coms.uiBtnGo:SetActive(true)
	end 

	--设置选中框
	if self.selectIndex == index then
		self:SetSelectedBound(coms.go, self.tranSelect)
	elseif self.tranSelect.parent == coms.trans then
		--因为瀑布流，所以相同的物体会用于多个index。
		--当选中框的父物体物体是当前物体，说明该物体下面有选中框，但是该物体并没被选中
  		self.tranSelect.anchoredPosition = Vector2.New(99999, 99999)
	end
end

-- 设置选中框
function M:SetSelectedBound(parentGo, boundTrans)
	UITools.AddChild(parentGo, boundTrans.gameObject, false)
	boundTrans.anchoredPosition3D = Vector3.zero
	boundTrans.gameObject:SetActive(true)
end

--倒计时
function M:OnCountDown(_text, _second, _callBack)
	TweenText.Begin(_text, _second, 0, _second, 0)
	local tweenTextContent = _text.gameObject:GetComponent(typeof(TweenText))
	-- self.tweenTextContent.format = format
	tweenTextContent.isTime = true
	tweenTextContent:SetOnFinished(function()
		--倒计时结束
		if _callBack then
			_callBack()
		end
		-- self:Hide()
	end)
end

--------------------------------------------描述

--刷新左侧面板
function M:RefreshBossInfo()
	if self.selectBossTab ~= nil then
		local npcId = self.selectBossTab.npcid
		local npcTab = NpcTable[npcId]

		--名称、等级
		self.txtBossName.text =string.format( "%s	   %d级", npcTab.name, self.selectBossTab.lv) 
		self.txtBossDesc.text = self.selectBossTab.des

		--刷新模型
		UITools.LoadModel(npcId, "worldBoss", self.transModelParent)

		--刷新奖励
		if self.rewardGoList == nil then self.rewardGoList = {} end
		self.rewardExParams = self.rewardExParams or {isnative = false}
    	UITools.CopyRewardList({self.selectBossTab.reward}, self.rewardGoList, self.transRewardItem, self.rewardExParams)
	end
end

return M