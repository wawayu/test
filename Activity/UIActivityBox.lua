local base = require "UI.UILuaBase"
local M = base:Extend()

local activityTab
function M.Open(activityID)
    activityTab = excelLoader.ActivityTable[activityID] or error("Invalid activity id: "..tostring(activityID))

    uiMgr.ShowAsync("UIActivityBox")
end

function M:Awake()
	base.Awake(self)

    self.frame = self:FindGameObject("Frame")

    self.imgIcon = self:FindImage("Frame/Icon/Image")
    self.txtName = self:FindText("Frame/TxtName")
    self.txtNum = self:FindText("Frame/Count/Text")
	self.uiNumRoot = self:FindGameObject("Frame/Count")
	self.uiNoNumRoot = self:FindGameObject("Frame/NoCount")

    --活动时间、任务形式、等级限制、活动描述
    self.txtTimeDesc = self:FindText("Frame/Time/Text")
    self.txtMissionType = self:FindText("Frame/MissionType/Text")
    self.txtLevelLimit = self:FindText("Frame/LevelLimit/Text")
    self.txtMissionDesc = self:FindText("Frame/Description/Text")

	--奖励
    self.transRewardItem = self:FindTransform("Frame/Reward/List/Item")

    --点击其他地方自动关闭
    UguiLuaEvent.ExternalOnDown(self.frame, self, M.Hide)
end

function M:Show()
    base.Show(self)

    self:RefreshPanel()

    self:TweenOpen(self.frame)
end

function M:RefreshPanel()
    uiMgr.SetSpriteAsync(self.imgIcon, Const.atlasName.ItemIcon, activityTab.icon)
    self.txtName.text = activityTab.name

	local totalCount = 0
	local recordTab = excelLoader.RecordTable[activityTab.recordId]
	if recordTab then
		totalCount = recordTab.max
	end
	if totalCount == 0 then
		--RecordTable中max值为0时表示不限次数,不显示次数
		self.uiNumRoot:SetActive(false)
		self.uiNoNumRoot:SetActive(true)
	else
		local curCount = dataMgr.ActivityData.GetRecord(activityTab.recordId, activityTab.id) or 0

		local num, max = dataMgr.ActivityData.GetRecordInstance():ActivityRewardCount(activityTab.id)
		if num then
			self.txtNum.text = string.format("<color=#13FF00>%d/%d</color>", num, max)
		else
			self.txtNum.text = string.format("<color=#13FF00>%d/%d</color>", curCount, totalCount)
		end
		self.uiNumRoot:SetActive(true)
		self.uiNoNumRoot:SetActive(false)
	end

	--活动时间、队伍限制、等级限制、活动描述
	self.txtTimeDesc.text = activityTab.openDesc
	self.txtMissionType.text = activityTab.missionTypeDesc
	self.txtMissionDesc.text = activityTab.desc
	self.txtLevelLimit.text = string.format("%d级以上", activityTab.limit.lv)

	--刷新奖励
	if self.rewardGoList == nil then self.rewardGoList = {} end
	UITools.CopyRewardList({activityTab.reward}, self.rewardGoList, self.transRewardItem)
end

return M