
local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"
local IdRule = require "IdRule"

local BusinessActivityTable = require "Excel.BusinessActivityTable"
local rewardExParams = {isnative = true, showQualityEffect = true, showtips = true}
local rankIcons = {"1st", "2nd", "3rd"}
local sexIconName = {"boy", "girl"}

local base = require "UI.UILuaBase"
local M = base:Extend()
local preUpdateTime = -1
local requestTimeGap = 0

M.fixedInfoData = {
	isShow = true,
	showPos = Vector2.zero,
	ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}

--[[消费排行]]

function M:Awake()
	base.Awake(self)

	self.offset = self:FindGameObject("Offset")

    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)

	self.transRight = self:FindTransform("Offset/Right")
	--倒计时
	self.textTime = self:FindText("Top/LeftTime/TxtLeft", self.transRight)
	--内容
	self.textContent = self:FindText("Top/Desc/TxtContent", self.transRight)
	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content", self.transRight)
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem, M.OnChooseItem)
	--模型父物体
	self.transModelParent = self:FindTransform("Left/ModelInfo/CameraModel/Model", self.transRight)
	--模型RenderTexture
	self:LoadRenderTexture("Offset/Right/Left/ModelInfo/CameraModel", "Offset/Right/Left/ModelInfo/RawImage", "RenderTexture0")

	self.uiLoopLeft = self:FindLoop("Offset/Left/Scroll View/Viewport/Content")
	self:BindLoopEventEx(self.uiLoopLeft, M.OnCreateItemLeft, M.UpdateItemLeft)

	self.textMyRank = self:FindText("Offset/Right/Item/Rank/Text")
	self.imageMyRank = self:FindImage("Offset/Right/Item/Rank/Image")
	self.textDesc = self:FindText("Offset/Right/Item/TxtDesc")

	self.textSelectRank = self:FindText("Offset/Right/Left/TextRank")
	self.textSelectName = self:FindText("Offset/Right/Left/TextName")
	self.imageSelectSex = self:FindImage("Offset/Right/Left/TextName/Image")

	self.transTips = self:FindTransform("Offset/Tips")
	self.textTitleTips = self:FindText("Offset/Tips/TextTitle")
	self.itemTips = self:FindTransform("Offset/Tips/RewardList/Viewport/Grid/Item")
	self.transTipsBg = self:FindTransform("Offset/Tips/bg")

	self.textNoTips = self:FindText("Offset/Right/TextNoTips")
	self.transLeft = self:FindTransform("Offset/Right/Left")

	UguiLuaEvent.ExternalOnDown(self.transTipsBg.gameObject, self, function()
		self.transTips.gameObject:SetActive(false)
	end)

	self.lastRequestSkinTime = -999
	self.rewardTipsComs = {}
end

function M:Show()
	base.Show(self)

	self.data = {}
	self.data.id = BusinessData.GetOpenID(Const.BAGROUP_RANKCOST)
	if self.data.id < 0 then
		self:Hide()
		return
	end
	self.businessTab = BusinessActivityTable[self.data.id]
	if not self.businessTab then
		self:Hide()
		return
	end
	self.curSelectRight = 1
	self.rankRewards = BusinessData.GetRankRewardConfig(self.data.id)

	self.transTips.gameObject:SetActive(false)

	self.cacheUnitInfos = {}

	self:ResetData()
	self:TweenOpen(self.offset)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Top then
		self:ResetData()
	elseif cmd == LocalCmds.Friends then
		local servercmd = msg.cmd
		local tp = msg.pb and msg.pb.tp
		if servercmd == Cmds.GetUnitInfo.index and tp == Const.OtherInfoType.Business and self.firstTopData  then
			if self.firstTopData.guid == msg.pb.guid then
				self.cacheUnitInfos[msg.pb.guid] = msg.pb.charinfo
				self:ResetData()
			end
		end
	end
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnGo" then
		OpenUI("UIShop")
	elseif btnName == "ButtonTips" then
		if self.businessTab then
			Hint({rectTransform = go.transform, content = self.businessTab.getdesc, alignment = 0})
		end
	elseif btnName == "ButtonSearch" then
		if self.firstTopData then
			dataMgr.FriendData.RequestOtherInfo(self.firstTopData.guid)
		end
	elseif btnName == "ButtonClose" then
		self:Hide()
	end
end

function M:ResetData()
	if not self.data.id or not self.businessTab or not self.rankRewards then
		return
	end

	local topType = self.businessTab.param1 and self.businessTab.param1.topType
	self.topDatas = dataMgr.TopData.GetTopInfos(topType) or {}
	--右边奖励
	self.uiLoopLeft.ItemsCount = #self.rankRewards-1
	--内容
	self.textContent.text = self.businessTab.desc
	--排行
	local rank = BusinessData.GetMyRank(self.data.id)
	self:UpdateRank(self.textMyRank, self.imageMyRank, rank)
	self.textDesc.text = BusinessData.GetBAComonRankDesc(self.data.id, "再消费<color=#00bb00>%s</color>元宝可升上第<color=#00bb00>%s</color>名")

	-- 选择的人
	if self.topDatas[self.curSelectRight] == nil then self.curSelectRight = 1 end
	self.firstTopData = self.topDatas[self.curSelectRight]
	self.textSelectRank.text = string.format("第%s名", self.curSelectRight)
	self:RefreshModelPanel()
	
	self.transLeft.gameObject:SetActive(self.firstTopData ~= nil)
	self.textNoTips.gameObject:SetActive(self.firstTopData == nil)
	
	-- 其他人
	self.uiItemLoop.ItemsCount = #self.topDatas

	self.endTime = BusinessData.GetEndTime(self.data.id)
end

--第一名
function M:RefreshModelPanel()
	self.textSelectName.text = ""
	UITools.SetImageEmpty(self.imageSelectSex)

	local data = self.firstTopData
	if not data then
		return
	end

	-- 自己的时候请求他人信息会不返还的
	local roleInfo = dataMgr.PlayerData.GetRoleInfo()
	if data.guid == roleInfo.guid then
		self.firstCharInfo = roleInfo
	else
		self.firstCharInfo = self:GetOtherInfo(data.guid)
	end

	--模型
	if self.firstCharInfo then
		UITools.LoadRoleModel(self.firstCharInfo, "businessRankCost", self.transModelParent)
	else
		UITools.LoadModel(data.guid, "businessRankCost", self.transModelParent)
	end

	local sex = IdRule.Guid2Sex(data.guid)
	self.textSelectName.text = UITools.FormatPlayerName(data.name)
	UITools.SetImageIcon(self.imageSelectSex, Const.atlasName.Common, sexIconName[sex])
end

function M:GetOtherInfo(guid)
	if not self.cacheUnitInfos then
		return
	end
	if self.cacheUnitInfos[guid] then
		return self.cacheUnitInfos[guid]
	end

	self.lastRequestSkinTime = self.lastRequestSkinTime or Time.time
	if Time.time - self.lastRequestSkinTime > requestTimeGap then
		self.firstCharInfo = nil
		self.lastRequestSkinTime = Time.time
		dataMgr.FriendData.RequestOtherInfo(guid, nil, nil, Const.OtherInfoType.Business)
	end
end

function M:GetLoopItem(index)
	return self.topDatas[index]
end

function M:OnChooseItem(index, coms)
	self.curSelectRight = index
	self:ResetData()
end
--道具
function M:OnCreateItem(index, coms)
	coms.textMyRank = self:FindText("Rank/Text", coms.trans)
	coms.imageMyRank = self:FindImage("Rank/Image", coms.trans)
	coms.textName = self:FindText("TextName", coms.trans)
	coms.imageSex = self:FindImage("TextName/Image", coms.trans)
	coms.textDesc = self:FindText("TextDesc", coms.trans)
	coms.imageSelect = self:FindImage("ImageSelect", coms.trans)
	coms.textCost = self:FindText("#004TextCost", coms.trans)
end

function M:UpdateItem(index, coms)
	local data = self:GetLoopItem(index)

	local sex = IdRule.Guid2Sex(data.guid)
	local curCost = data.score
	local rankCfg = self.rankRewards[index]
	coms.textName.text = data.name
	UITools.SetImageIcon(coms.imageSex, Const.atlasName.Common, sexIconName[sex])
	coms.textCost.text = curCost
	if index < 4 and rankCfg and rankCfg.tab.min then
		local color = curCost >= rankCfg.tab.min and Const.Colors.green or Const.Colors.redMid
		coms.textDesc.text = string.format("<color=#%s>最低消费元宝%s</color>", color, rankCfg.tab.min)
	else
		coms.textDesc.text = ""
	end

	self:UpdateRank(coms.textMyRank, coms.imageMyRank, index)

	coms.imageSelect.gameObject:SetActive(index == self.curSelectRight)
end

--道具
function M:OnCreateItemLeft(index, coms)
	local trans = coms.trans
    coms.image = self:FindImage("Image", trans)
	coms.image2 = self:FindImage("Image2", trans)
	coms.textName = self:FindText("TextName", trans)
	coms.buttonMore = self:FindButton("ButtonMore", coms.trans)
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)
	coms.rewardContainer = {}
	coms.itemsList = {}

	UguiLuaEvent.ButtonClick(coms.buttonMore.gameObject, nil, function(_go)
        self:ShowTips(self.uiLoopLeft:GetItemGlobalIndex(trans.gameObject) + 1, _go)
    end)
end

function M:UpdateItemLeft(index, coms)
	local rankData = self.rankRewards and self.rankRewards[index]
	if not rankData then
		return
	end

	coms.image.gameObject:SetActive(index%2 == 0)
	coms.image2.gameObject:SetActive(index%2 == 1)
	
	local str = ""
	if rankData.min == rankData.max then
		str = rankData.min
	else
		str = string.format("%s-%s", rankData.min, rankData.max)
	end
	coms.textName.text = string.format("第%s名", str)

	-- 刷新奖励
	local mailid = rankData.tab.mailid
	local items = excelLoader.MailTable[mailid].items
	for i=1,2 do
		coms.itemsList[i] = items[i]
	end
	UITools.CopyRewardListWithItemsEx(coms.itemsList, coms.rewardContainer, coms.transRewardItem, rewardExParams)
end

function M:ShowTips(index, go)
	local rankData = self.rankRewards and self.rankRewards[index]
	if not rankData then
		return
	end
	
	self.transTips.gameObject:SetActive(true)
	self:AutoDock(self.transTips, go.transform)

	local str = ""
	if rankData.min == rankData.max then
		str = rankData.min
	else
		str = string.format("%s-%s", rankData.min, rankData.max)
	end
	self.textTitleTips.text = string.format("第%s名奖励", str)

	local mailid = rankData.tab.mailid
	local items = excelLoader.MailTable[mailid].items
	UITools.CopyRewardListWithItemsEx(items, self.rewardTipsComs, self.itemTips, rewardExParams)
end

function M:UpdateRank(textRank, imageRank, rank)
    if rank and rank <= 3 and rank > 0 then
        textRank.text = ""
        imageRank.gameObject:SetActive(true)
        UITools.SetImageIcon(imageRank, Const.atlasName.Common, rankIcons[rank])
    else
        textRank.text = (rank and rank > 0) and rank or "未上榜"
        imageRank.gameObject:SetActive(false)
    end
end

function M:Update()
	base.Update(self)

	if Time.time - preUpdateTime < 1 then
		return
	end
	preUpdateTime = Time.time

	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
	end
end

return M