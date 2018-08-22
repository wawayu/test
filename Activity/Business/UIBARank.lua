
local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"

local BusinessActivityTable = require "Excel.BusinessActivityTable"
local rewardExParams = {isnative = true, showQualityEffect = true, showtips = true}

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[进阶]]

function M:Awake()
	base.Awake(self)

    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.transOffset = self:FindTransform("Offset")

	--倒计时
	self.textTime = self:FindText("Top/LeftTime/TxtLeft", self.transOffset)
	--内容
	self.txtContent = self:FindText("Top/Desc/TxtContent", self.transOffset)
	--跳转按钮
	self.uiBtnGo = self:FindGameObject("Top/BtnGo", self.transOffset)
	self.txtBtnGo = self:FindText("Top/BtnGo/Text", self.transOffset)
	--排名
	self.txtMyRank = self:FindText("Top/MyRank/TxtRank", self.transOffset)

	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content", self.transOffset)
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)

	--模型父物体
	self.transModelParent = self:FindTransform("Left/ModelInfo/CameraModel/Model", self.transOffset)
	--模型RenderTexture
	self:LoadRenderTexture("Offset/Left/ModelInfo/CameraModel", "Offset/Left/ModelInfo/RawImage", "RenderTexture0")
	self.transRewardItem = self:FindTransform("Left/RewardList/Viewport/Grid/Item", self.transOffset)
	self.txtGetDesc = self:FindText("Left/TxtDesc", self.transOffset)

	self.top1Scroll = self:FindScrollRect("Left/RewardList", self.transOffset)
	self.top1Content = self:FindTransform("Left/RewardList/Viewport/Grid", self.transOffset)

	self.imageTitle = self:FindImage("Left/ImageTitle", self.transOffset)
	self.textName = self:FindText("Offset/Left/TextName")

	self.lastRequestSkinTime = -999

	self.rewardComs = {}
end

function M:Show()
	base.Show(self)

	self.businessTab = BusinessActivityTable[self.data.id]
	if not self.businessTab then
		self:Hide()
		return
	end
	self.rankRewards = BusinessData.GetRankRewardConfig(self.data.id)

	self:ResetData()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Top then
		self:ResetData()
	elseif cmd == LocalCmds.Friends then
		local servercmd = msg.cmd
		local tp = msg.pb and msg.pb.tp
		if servercmd == Cmds.GetUnitInfo.index and tp == Const.OtherInfoType.Business and self.firstTopData  then
			if self.firstTopData.guid == msg.pb.guid then
				self.firstCharInfo = msg.pb.charinfo
				self:ResetData()
			end
		end
	end
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnGo" then
		local topType = self.businessTab.param1 and self.businessTab.param1.topType
		if topType then
			OpenUI("UITop", {topType = topType})
		end
	elseif btnName == "BtnDesc" then
		--描述按钮
		Hint({rectTransform = go.transform, content = Lan("getback_desc"), alignment = 0})
	elseif btnName == "ImgArrowRight" then
		self.top1Content.anchoredPosition = self.top1Content.anchoredPosition - Vector3.New(270, 0, 0)
	elseif btnName == "ImgArrowLeft" then
		self.top1Content.anchoredPosition = self.top1Content.anchoredPosition + Vector3.New(270, 0, 0)
	end
end

function M:ResetData()
	if not self.data.id or not self.businessTab or not self.rankRewards then
		return
	end

	local topType = self.businessTab.param1 and self.businessTab.param1.topType
	self.topDatas = dataMgr.TopData.GetTopInfos(topType)
	self.firstTopData = self.topDatas[1]
	--[[

	if self.firstTopData then
		local roleInfo = dataMgr.PlayerData.GetRoleInfo()
		self.firstTopData.guid = roleInfo.guid
	end
	]]

	--右边奖励
	self.uiItemLoop.ItemsCount = #self.rankRewards-1

	--跳转按钮
	self.uiBtnGo:SetActive(topType ~= nil)
	if self.businessTab.buttonname then
		self.txtBtnGo.text = self.businessTab.buttonname
	end

	--内容
	self.txtContent.text = self.businessTab.desc
	--排行
	local rank = BusinessData.GetMyRank(self.data.id)
	if rank > 0 then
		self.txtMyRank.text = string.format("第%s名", rank)
	else
		self.txtMyRank.text = "未上榜"
	end
	
	-- 第一名
	self:RefreshModelPanel()
	--奖励
	local mailid = self.rankRewards[1].tab.mailid
	self.top1Items = excelLoader.MailTable[mailid].items
	UITools.CopyRewardListWithItemsEx(self.top1Items, self.rewardComs, self.transRewardItem, rewardExParams)
	--描述，todo
	self.txtGetDesc.text = self.businessTab.getdesc

	self.endTime = BusinessData.GetEndTime(self.data.id)

	local titleid = self.businessTab.param2.titleid
	local titleTab = excelLoader.TitleTable[titleid]
	UITools.SetImageIcon(self.imageTitle, Const.atlasName.HeadInfo, titleTab.icon)
end

--第一名
function M:RefreshModelPanel()
	self.textName.text = ""

	if not self.firstTopData then
		return
	end

	-- 自己的时候请求他人信息会不返还的
	local roleInfo = dataMgr.PlayerData.GetRoleInfo()
	if self.firstTopData.guid == roleInfo.guid then
		self.firstCharInfo = roleInfo
	end

	local isSameGuid = self.firstCharInfo and self.firstCharInfo.guid == self.firstTopData.guid
	if not isSameGuid and Time.time - self.lastRequestSkinTime > 30 then
		self.firstCharInfo = nil
		self.lastRequestSkinTime = Time.time
		dataMgr.FriendData.RequestOtherInfo(self.firstTopData.guid, nil, nil, Const.OtherInfoType.Business)
	end

	--模型
	if isSameGuid then
		UITools.LoadRoleModel(self.firstCharInfo, "businessRank", self.transModelParent)
	else
		UITools.LoadModel(self.firstTopData.guid, "businessRank", self.transModelParent)
	end

	self.textName.text = self.firstTopData.name
end

--道具
function M:OnCreateItem(index, coms)
	coms.txtName = self:FindText("TxtActivity", coms.trans)--活动名称
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}
end

function M:UpdateItem(index, coms)
	if self.rankRewards then
		local rankData = self.rankRewards[index+1]
		if rankData ~= nil then
			--名称,图标
			local str = ""
			if rankData.min == rankData.max then
				str = rankData.min
			else
				str = string.format("%s-%s", rankData.min, rankData.max)
			end
			coms.txtName.text = string.format("第%s名", str)

			-- 刷新奖励
			local mailid = rankData.tab.mailid
			local items = excelLoader.MailTable[mailid].items
			UITools.CopyRewardListWithItems(items, coms.rewardContainer, coms.transRewardItem, rewardExParams)
		end
	end
end


function M:UpdateChild()
	local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
	self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)

	-- 修复第一名右边也有特效遮罩问题, 还是会显示，手动隐藏特效
	local index =  math.floor((self.top1Content.anchoredPosition.x-20) * -1 / 96) 
	index = index + 3
	for i,v in ipairs(self.rewardComs) do
		if not tolua.isnull(v.transEffectQuality) then
			v.transEffectQuality.gameObject:SetActive(i <= index)
		end
	end
end

return M