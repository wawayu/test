local ArtifactTable = excelLoader.ArtifactTable
local AttrTable = excelLoader.AttrTable
local ArtifactData = require "Data.ArtifactData"
local PlayerData = require "Data.PlayerData"
local SevenDayData = require "Data.SevenDayData"
local ItemData = require "Data.ItemData"
local ActivityData = require "Data.ActivityData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"

local RewardTable = require "Excel.RewardTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[7日登陆]]
function M.Open(params)
    OpenUI("UIReward", {panelIndex = 2})
end

local dayNotifyPos = Vector3.New(40,57,0)

function M:Awake()
	base.Awake(self)
	
    --按钮。Button
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)

	----------------------------顶部

	--第几天，这天描述图片
	self.txtCurDay = self:FindText("Top/ImgDay/TxtDay")
	self.imgDesc = self:FindImage("Top/ImgDesc")

	self.txtDesc = self:FindText("Top/Bg/TxtDesc")

	--奖励物品
	self.transRewardItem = self:FindTransform("Top/Grid/Item")

	--模型
	self.modelParent = self:FindTransform("Top/Award/ModelImage/CameraModel/Model")
	self:LoadRenderTexture("Top/Award/ModelImage/CameraModel", "Top/Award/ModelImage/RawImage", "RenderTexture0")

	self.modelParent2 = self:FindTransform("Top/Award/ModelImage/CameraModel2/Model")
	self:LoadRenderTexture("Top/Award/ModelImage/CameraModel2", "Top/Award/ModelImage/RawImage2", "RenderTexture1")
	

	self.uiAward = self:FindGameObject("Top/Award")
	self.uiNoAward = self:FindGameObject("Top/ImgNoModel")

	--按钮
	self.uiBtnGet = self:FindGameObject("Top/BtnRoot/BtnGet")
	self.uiBtnAlreadyGet = self:FindGameObject("Top/BtnRoot/BtnAlreadyGet")
	self.uiBtnCantGet = self:FindGameObject("Top/BtnRoot/BtnCantGet")
	self.txtBtnCantGet = self:FindText("Top/BtnRoot/BtnCantGet/Text")

	----------------------------底部

	--UIloop
	self.uiRewardLoop = self:FindLoop("Buttom/Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiRewardLoop, M.OnCreateItem, M.OnUpdateItem, M.OnChooseItem)

	self.tranSelect = self:FindTransform("Buttom/Scroll View/Viewport/ImgSelect")
end

function M:Show()
	base.Show(self)

	self:RefreshPanel(true)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.RecordUpdate then

		self:RefreshPanel(true)
    end
end

function M:RefreshPanel(resetSelect)
	if resetSelect or not self.selectDay then
		self.selectDay = 7
		self.selectArrow = 7
		for i = 1, 7 do
			if not SevenDayData.IsSevenLoginRewardGetByDay(i) then
				self.selectDay = i
				self.selectArrow = i
				break
			end
		end
	end

	self.uiRewardLoop.ItemsCount = #SevenDayData.GetSevenLoginTable()

	self:RefreshTopPanel()
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnGet" then
		--领取
		SevenDayData.RequestGetLoginSevenDayRewardReq(self.selectDay)
	elseif btnName == "BtnDesc" then
		--描述按钮
		Hint({rectTransform = go.transform, content = Lan("getback_desc"), alignment = 0})
	end
end

-------------------------底部

--道具
function M:OnCreateItem(index, coms)
	--第几天
	coms.txtName = self:FindText("TxtDay", coms.trans)
	--奖励物品
	coms.transRewardItem = self:FindTransform("Item", coms.trans)

	--图片icon
	coms.imgIcon = self:FindImage("Item/Info/ImageIcon", coms.trans)
	--打勾
	coms.uiChoose = self:FindGameObject("Item/Info/ImgChoose", coms.trans)
	--箭头
	coms.uiArrow = self:FindGameObject("ImgArrow", coms.trans)
	--背景
	coms.transBg = self:FindTransform("Bg", coms.trans)
end

function M:OnChooseItem(index, coms)
	 if self.selectDay == index then
		return
	end

    self.selectDay = index

	--刷新界面
	self:RefreshPanel()
end

function M:OnUpdateItem(index, coms)
	local dayReward = SevenDayData.GetSevenLoginTable()[index]
	local rewardData = ItemData.GetRewardSingle(dayReward.rewardid)

	--奖励的第一个道具
	if rewardData then
		UITools.SetItemInfo(coms.transRewardItem, rewardData, false, false)
	end

	--第几天
	coms.txtName.text = string.format("第 <color=#2A9E1A>%d</color> 天", index)

	local getStatus = SevenDayData.IsSevenLoginRewardGetByDay(index)
	if getStatus then
		--这天已领取
		UITools.SetImageGrey(coms.imgIcon, true)
		coms.uiChoose:SetActive(true)
	else
		--未领取
		UITools.SetImageGrey(coms.imgIcon, false)
		coms.uiChoose:SetActive(false)	
	end
    
    --设置选中框
    if self.selectDay == index then
        self:SetSelectedBound(coms.transBg.gameObject, self.tranSelect)
    elseif self.tranSelect.parent == coms.transBg then
        self.tranSelect.anchoredPosition = Vector2.New(99999, 99999)
    end

	--箭头
	if index == self.selectArrow then
		--现在的
		coms.uiArrow:SetActive(true)
	else
		coms.uiArrow:SetActive(false)
	end

	--红点
	notifyMgr.AddNotify(coms.go, notifyMgr.IsSevenLoginNotifyByDay(index), dayNotifyPos, notifyMgr.NotifyType.Common)
end

-- 设置选中框
function M:SetSelectedBound(parentGo, boundTrans)
    UITools.AddChild(parentGo, boundTrans.gameObject, false)
	boundTrans.anchoredPosition3D = Vector3.zero
	boundTrans.gameObject:SetActive(true)
    boundTrans:SetSiblingIndex(0)
end

---------------------------顶部

function M:RefreshTopPanel()
	local dayReward = SevenDayData.GetSevenLoginTable()[self.selectDay]

	if self.rewardGoList == nil then self.rewardGoList = {} end
	self.rewardExParams = self.rewardExParams or {isnative = false, showQualityEffect = true}
	UITools.CopyRewardList({dayReward.rewardid}, self.rewardGoList, self.transRewardItem, self.rewardExParams)

	--第几天
	self.txtCurDay.text = string.format("第%d天", self.selectDay)

	--每一天都是不同的图片和描述
	local rewardTab = RewardTable[dayReward.rewardid]
	if rewardTab then
		UITools.SetImageIcon(self.imgDesc, rewardTab.atlas or Const.atlasName.Background, rewardTab.rewardUi, false)
		self.txtDesc.text = rewardTab.name
	end

	--模型
	local rewardData = ItemData.GetRewardSingle(dayReward.rewardid)
	local itemTab = ItemTable[rewardData.itemid]
	if itemTab.param and itemTab.param.heroid then
		self.uiAward:SetActive(true)
		self.uiNoAward:SetActive(false)
		local hero = dataMgr.HeroData.CreateHero(itemTab.param.heroid)
		hero.awake = itemTab.param.awake or hero.awake
		hero.rank = itemTab.param.rank or hero.rank
		hero.quality = itemTab.param.quality or hero.quality
		HeroTool.LoadHeroModel(hero, "SevenLogin", self.modelParent, function(tmpunit)
		end, Layer.UIModel)	
		--如果有隐藏神器
		if self.art then
			self.art.gameObject:SetActive(false)
		end
	elseif itemTab.models and itemTab.models[1] ~= 50 then
		--该道具有模型
		self.uiAward:SetActive(true)
		self.uiNoAward:SetActive(false)
		UITools.LoadModel(rewardData.itemid, "SevenLogin", self.modelParent, nil, Layer.UIModel, nil, nil)
		--如果有隐藏神器
		if self.art then
			self.art.gameObject:SetActive(false)
		end
	elseif itemTab.param and itemTab.tp == 42 then
		local job = dataMgr.PlayerData.GetRoleInfo().job
		local id = itemTab.param[job]
		--local artifactinfo = ArtifactData.GetArtifactInfo(id) 
		self.art=UITools.LoadArtifact(ArtifactData.NewArtifactInfo(id), self.modelParent2) 
		--隐藏Module
		UITools.LoadModel(nil, "SevenLogin", self.modelParent, nil, Layer.UIModel, nil, nil)      
	else
		if self.art then
			self.art.gameObject:SetActive(false)
		end
		-- print("该道具没有模型")
		self.uiAward:SetActive(true)
		self.uiNoAward:SetActive(false)

		--显示宝箱模型
		UITools.LoadModel(352206, "SevenLogin", self.modelParent, nil, Layer.UIModel, nil, nil)
	end
	
	local getStatus = SevenDayData.IsSevenLoginRewardGetByDay(self.selectDay)
	if getStatus then
		--已领取
		self.uiBtnGet:SetActive(false)
		self.uiBtnAlreadyGet:SetActive(true)
		self.uiBtnCantGet:SetActive(false)
	else
		--未领取
		if self.selectDay > SevenDayData.GetLoginDay() then
			--未来
			self.uiBtnGet:SetActive(false)
			self.uiBtnAlreadyGet:SetActive(false)
			self.uiBtnCantGet:SetActive(true)
			self.txtBtnCantGet.text = string.format("第 %d 天领", self.selectDay)
		else
			--现在或之前
			self.uiBtnGet:SetActive(true)
			self.uiBtnAlreadyGet:SetActive(false)
			self.uiBtnCantGet:SetActive(false)
		end
	end
end

return M