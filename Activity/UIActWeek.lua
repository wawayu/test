local ActivityTable = require "Excel.ActivityTable"
local RecordTable = require "Excel.RecordTable"
local SettingTable = require "Excel.SettingTable"
local RewardTable = require "Excel.RewardTable"
local ActivityCalendarTable = require "Excel.ActivityCalendarTable"
local ConfRule = require "ConfRule"
local TimeSync = require "TimeSync"

local PlayerData = require "Data.PlayerData"
local ActivityData = require "Data.ActivityData"

local UIWidgetBase = require("UI.Widgets.UIWidgetBase")

local base          = require "UI.UILuaBase"
local M             = base:Extend()
local DayInfo = {"时间", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"}

function M:Awake()
    base.Awake(self)  

    if self.patchInited then
		return
	end
	self.patchInited = true
    
    self.uiPatchContent = self:FindTransform("Scroll View/Viewport/Content")

	self.uiPatchPrefab = self:FindGameObject("Scroll View/Viewport/Content/Patch")
	self.uiItemPrefab = self:FindGameObject("Scroll View/Viewport/Content/Item")
	self.uiPatchPrefab:SetActive(false)
    self.uiItemPrefab:SetActive(false)
    


	--创建patch
	self.activityPatchlist = {}
	self.patchItemList = {}
	UIWidgetBase.DynamicCreateMore(self.activityPatchlist, #ActivityCalendarTable + 1, self.uiPatchPrefab, self.uiPatchContent, self, nil)

	for k, v in ipairs(self.activityPatchlist) do
		local itemList = {}
		UIWidgetBase.DynamicCreateMore(itemList, #DayInfo, self.uiItemPrefab, v.go.transform, self, nil)
		--缓存组件
		for k, v in ipairs(itemList) do
			v.imgBg = v.go:GetComponent(typeof(UnityEngine.UI.Image))
			v.txtName = self:FindText("TxtName", v.cacheTrans)
			v.goHighlight = self:FindGameObject("ImgHighlight", v.cacheTrans)
		end
	    self.patchItemList[k] = {patch = v, itemList = itemList}
    end
    
    	--按钮。Button
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
	--ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)
end



function M:Show()
    base.Show(self) 

    --ScrollView位置
	self.uiPatchContent.anchoredPosition3D = Vector3.zero
		
	--刷新周历
	self:RefreshActivityPatch()
end


--点击按钮
function M:OnClick(go)
	local btnName = go.name
	--print(btnName)
	if btnName == "ButtonClose" then
		self:Hide()
	elseif btnName == "ButtonGet" then
		--领取双倍点数
		ActivityData.RequestDoublePointOpt(1)
	elseif btnName == "ButtonFreeze" then
		--冻结双倍点数
		ActivityData.RequestDoublePointOpt(2)
	elseif btnName == "ButtonLiveSkill" then
		--生活技能。打开生活技能分页
		OpenUI("UIPlayerSkill", {panelIndex = 3})
	elseif btnName == "ButtonActiveDesc" then
		--活力值
		Hint({rectTransform = go.transform, content = LivenessDesc, alignment = 0})
	elseif btnName == "ButtonDouble" then
		--双倍点数
		Hint({rectTransform = go.transform, content = DoubleDesc, alignment = 0})
	end
end


--刷新周历
function M:RefreshActivityPatch()
	local week = TimeSync.week_day(netMgr.mainClient:GetServerTime())
	for k, v in ipairs(self.patchItemList) do
		for i, j in ipairs(v.itemList) do
			--非标题行，且刚好是今天则高亮
			if k > 1 and week == i - 1 then
				j.goHighlight:SetActive(true)
			else
				j.goHighlight:SetActive(false)
			end
		end

		if k == 1 then
			--标题
			self:RefreshActivityPatchLine(v.itemList, DayInfo, k)
		else
			--周历
			self:RefreshActivityPatchLine(v.itemList, ActivityCalendarTable[k-1], k)
		end
	end
end

local titleHeight = 75
local itemHeight = 50
local defaultColumeWidth = 117
local firstColumnWidth = 117
local titleBg = "frame_TextBg3"
local contentSingleBg = "frame_TextBg1"
local contentDoubleBg = "frame_TextBg2"

--刷新一行周历
function M:RefreshActivityPatchLine(_itemList, _data, _index)
	for k, v in ipairs(_itemList) do
		v.txtName.text = self:GetActivityPatchName(_data[k], k)
		
		local width = defaultColumeWidth
		local height = itemHeight
		if k == 1 then
			--时间列，宽度小一点
			width = firstColumnWidth
		end
		if _index == 1 then
			--标题，背景大小，背景框
			height = titleHeight
			--背景框
			uiMgr.SetSpriteAsync(v.imgBg, Const.atlasName.Common, titleBg)
		else
			--周历,间隔一行的背景颜色不同
			height = itemHeight 
			local x = _index%2
			if x == 1 then
				--单数
				uiMgr.SetSpriteAsync(v.imgBg, Const.atlasName.Common, contentSingleBg)
			elseif x == 0 then
				--双数
				uiMgr.SetSpriteAsync(v.imgBg, Const.atlasName.Common, contentDoubleBg)
			end
		end
		--大小
		v.cacheTrans.sizeDelta = Vector2.New(width,height)
	end
end

---周历显示名称
function M:GetActivityPatchName(name, itemIndex)
	local doujiName = excelLoader.ActivityTable[Const.ACTIVITY_ID_BATTLE_MATCH_1V1].name
	if doujiName == name then
		local weekIndex = itemIndex - 1
		local weekStartTime = activityMgr.thisWeekStartTime
		local weekdayStartTime = weekStartTime + (weekIndex - 1) * 86400
		if not activityMgr.IsDoujiSeasonOpen(weekdayStartTime, false) then
			return ""
		end
	end
	return name
end

return M