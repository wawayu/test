
local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"

local BusinessActivityTable = require "Excel.BusinessActivityTable"
local rewardExParams = {showtips = true, isnative = true, showQualityEffect = true}

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[积分排行]]

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
	self.textMyRank = self:FindText("Top/TextRank", self.transOffset)
	self.textScore = self:FindText("Top/TextScore", self.transOffset)

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

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end
	
	self.businessTab = BusinessActivityTable[self.data.id]
	if not self.businessTab then
		self:Hide()
		return
	end
	self.rankRewards = self.script:GetRewardConfig()

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
	elseif btnName == "ButtonTips" then
		if self.businessTab then
			Hint({rectTransform = go.transform, content = self.businessTab.getdesc, alignment = 0})
		end
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

	self.moduleName = self.businessTab.buttonname

	local topType = self.businessTab.param1 and self.businessTab.param1.topType
	self.topDatas = dataMgr.TopData.GetTopInfos(topType)
	self.firstTopData = self.topDatas[1]

	--右边奖励
	self.uiItemLoop.ItemsCount = #self.rankRewards-1

	--跳转按钮
	self.uiBtnGo:SetActive(topType ~= nil)
	if self.businessTab.buttonname then
		self.txtBtnGo.text = self.businessTab.buttonname.."榜"
	end

	--内容
	self.txtContent.text = self.businessTab.desc
	--排行
	local rank = BusinessData.GetMyRank(self.data.id)
	if rank > 0 then
		self.textMyRank.text = string.format("当前排名:第%s名", rank)
	else
		self.textMyRank.text = "当前排名:未上榜"
	end

	self.score = self.script:GetScoreValue(self.data.id)

	self.textScore.text = string.format("%s:%s", self.moduleName, self.score)
	
	-- 第一名
	self:RefreshModelPanel()
	--奖励
	local mailid = self.rankRewards[1].tab.mailid
	self.top1Items = excelLoader.MailTable[mailid].items
	UITools.CopyRewardListWithItemsEx(self.top1Items, self.rewardComs, self.transRewardItem, rewardExParams)

	self.endTime = self.script:GetEndTime()

	local titleid = self.businessTab.param2.titleid
	local titleTab = excelLoader.TitleTable[titleid]
	UITools.SetImageIcon(self.imageTitle, Const.atlasName.HeadInfo, titleTab.icon)
end

--第一名
function M:RefreshModelPanel()
	self.textName.text = ""
	self.txtGetDesc.text = ""
	local rewardConf = self.rankRewards and self.rankRewards[1] and self.rankRewards[1].tab
	if rewardConf and rewardConf.min then
		self.txtGetDesc.text = string.format("最低%s需%s", self.moduleName, rewardConf.min)
	end

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
	coms.textCond = self:FindText("TextCond", coms.trans)
	
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
			coms.txtName.text = string.format("%s第%s名", self.moduleName,  str)
	
			-- 刷新奖励
			local mailid = rankData.tab.mailid
			local items = excelLoader.MailTable[mailid].items
			UITools.CopyRewardListWithItems(items, coms.rewardContainer, coms.transRewardItem, rewardExParams)

			if rankData.tab.min then
				coms.textCond.text = string.format("最低%s需%s", self.moduleName, rankData.tab.min)
			else
				coms.textCond.text = ""
			end
		end
	end
end

function M:UpdateChild()
	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#00ff00>%s</color>", strTime)
	end
	
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