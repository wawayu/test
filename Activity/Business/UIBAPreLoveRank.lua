--[[
	幸福姻缘
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"
local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local rewardExParams = {isnative = true, showQualityEffect = true}

local rankIcons = {"1st", "2nd", "3rd"}
local M = base:Extend()

local SHOWCOUNT = 10

local bid	-- 活動id

function M:Awake()
    base.Awake(self)
	self.transOffset = self:FindTransform("Offset")
	self.marryNum=self:FindText("Offset/MarryText/MarryNum/marryNum")
	self.selfNum=self:FindText("Offset/MarryText/SelfNum/selfNum")

	self.btnGet=self:FindGameObject("Offset/ButRoot/BtnGo")
	self.btnNot=self:FindGameObject("Offset/ButRoot/BtnNot")
	self.btnAlreadyGet = self:FindGameObject("Offset/ButRoot/AlreadyGetBtn")

	self.notNum=self:FindText("Offset/Background/NotNum")
	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content",self.transOffset)
	self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)
	
	--奖励
    self.transRewardItem = self:FindTransform("Offset/#105RewardList/Viewport/Grid/Item")
    --领取事件
	UguiLuaEvent.ButtonClick(self.btnGet, self, M.GetRewardOnClick)

	--结婚按钮
	self.btnMarry = self:FindGameObject("Offset/BtnMarry")

end



function M:Show()
	base.Show(self)

	bid = self.data.id
	self.script = BusinessData.GetScript(bid)
	if not self.script then
		self:Hide()
		return
	end
	--请求数据
	self.script:RequestLoveRankRecord()
	self.script:RequestSelfLoveRankRecord()
	self.businessTab = BusinessActivityTable[bid]
	self:ResetData()
end


function M:GetLoopItem(index)
	return self.topDatas[index]
end

--道具
function M:OnCreateItem(index, coms)
		coms.textMyRank = self:FindText("Rank/Text", coms.trans)
		coms.imageMyRank = self:FindImage("Rank/Image", coms.trans)
		coms.textName = self:FindText("TextName", coms.trans)
		coms.imageSelect = self:FindImage("ImageSelect", coms.trans)
		coms.titleImage = self:FindImage("TitleImage", coms.trans)
end


function M:UpdateItem(index, coms)
		local data = self:GetLoopItem(index)
		local name1=data.couple[1].name
		local name2=data.couple[2].name
		coms.textName.text = string.format("%s    %s", name1,name2)
		self:UpdateRank(coms.textMyRank, coms.imageMyRank,coms.titleImage,index)
end

function M:UpdateRank(textRank, imageRank,titleImage,rank)
    if rank and rank <= 3 and rank > 0 then
        textRank.text = ""
		imageRank.gameObject:SetActive(true)
		titleImage.gameObject:SetActive(true)
        UITools.SetImageIcon(imageRank, Const.atlasName.Common, rankIcons[rank])
    else
        textRank.text = (rank and rank > 0) and rank or "未上榜"
        imageRank.gameObject:SetActive(false)
    end
end


--监听本地
function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
        self:ResetData()
    end
end

--领取奖励按钮
function M:GetRewardOnClick()
	if not self.script:IsLoveGiftGot() then   
		self.script:SendLoveGift() 
		self:ResetData()
	end

end

--结婚
function M.MarryEnter()
	--寻路到月老处
	sceneMgr.FindPathByUnitKey(dataMgr.MarriageData.GetMarryNpcID())
end


function M:ResetData()
	if not self.data.id or not self.businessTab  then
		return
	end

	--如果不曾结婚
	if not dataMgr.MarriageData.IsPlayerMarried() then
		self.btnMarry:SetActive(true)
		UguiLuaEvent.ButtonClick(self.btnMarry, self,M.MarryEnter)
	else
		self.btnMarry:SetActive(false)
	end


	self.topDatas = self.script:AllMarryInfo()
	self.allNum = self.script:AllMarryNum()
	--限定显示人数
	if self.topDatas then
		if #self.topDatas<=SHOWCOUNT then
			self.uiItemLoop.ItemsCount = #self.topDatas
		else
			self.uiItemLoop.ItemsCount=SHOWCOUNT
		end
		
	
	end
	--当前结婚人数特殊情况
	if self.allNum==0 then
		self.notNum.gameObject:SetActive(true)
	else
		self.notNum.gameObject:SetActive(false)
	end
	if self.allNum>=100 then
		self.allNum=100
	end
	self.marryNum.text=string.format("%d/100",self.allNum)
	
	--幸福姻缘奖励
    self.rewardList = self.script:GetLoveRankReward(1)
    self.endTime = self.script:GetEndTime()
    --空表
    if self.rewardGoList == nil then
			self.rewardGoList = {} 
	end
    local data = self.rewardList
	-- 刷新奖励
	UITools.CopyRewardList({data.rewardid}, self.rewardGoList, self.transRewardItem, rewardExParams)
	--第一个礼包前三可以领
	local trans=self.rewardGoList[1].transform
	local transRank = self:FindTransform("Info/imageSingle", trans)
	transRank.gameObject:SetActive(true)
	
	--获得自身排行
	local selfrank = self.script:SelfMarryInfo()
	self.selfNum.text = (selfrank and selfrank > 0 and selfrank<=100) and selfrank or "未上榜"
	--判断Button状态

	local state=self.script:GetLoveGiftStatus()
        self.btnAlreadyGet:SetActive(false)
        if state==0 then
            self.btnNot:SetActive(true)
            self.btnGet:SetActive(false)
        elseif state==1 then
            self.btnNot:SetActive(false)
            self.btnGet:SetActive(true)
        else
            self.btnNot:SetActive(false)
            self.btnGet:SetActive(false)
            self.btnAlreadyGet:SetActive(true)
        end

end


return M