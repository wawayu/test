--[[
 战神降临
]]
local base = require "UI.UILuaBase"
local M = base:Extend()
local UguiLuaEvent = require "UguiLuaEvent"

local ActivityData = dataMgr.ActivityData
local preUpdateTime = -999
local rankIcons = {"1st", "2nd", "3rd"}
local stageSliderImg = {"ProgressBar1", "ProgressBar2", "ProgressBar3"}
local stageImg = {"zhanshen_diyijieduan", "zhanshen_dierjieduan", "zhanshen_disanjieduan"}

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID =  {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_SHENGWANG}
}

function M.Open(params)
    if not ActivityData.CanJoinAres(true) then
        return
    end

    uiMgr.ShowAsync("UIAresCome")
end

function M:Awake()
    base.Awake(self)

    UITools.AddBtnsListenrList(self:FindTransform("Offset"), self, M.OnClick, Button)

    self.slider = self:FindSlider("Offset/Left/Slider")
    self.imageSliderFill = self:FindImage("Offset/Left/Slider/Fill Area/Fill")
	self.txtProcess = self:FindText("Offset/Left/Slider/TxtProcess")
	self.textScore = self:FindText("Offset/Left/Score/Text")
	self.txtTime = self:FindText("Offset/Left/Time/TxtTime")
	self.imageStage = self:FindImage("Offset/Left/Stage/Image")
	self.textWorld = self:FindText("Offset/Left/ScrollInfo/TextWorld")
	self.textMe = self:FindText("Offset/Left/ScrollInfo/TextMe")
    --guild
    self.transGuildRank = self:FindTransform("Offset/Right/GuildRank")
	self.textGuildNoTips = self:FindText("TextNoTips", self.transGuildRank)
	self.textGuildRank = self:FindText("Item/Rank/Text", self.transGuildRank)
	self.imageGuildRank = self:FindImage("Item/Rank/Image", self.transGuildRank)
	self.textGuildName = self:FindText("Item/TextGuild", self.transGuildRank)
	self.textGuildLeader = self:FindText("Item/TextName", self.transGuildRank)
	self.textGuildScore = self:FindText("Item/TextScore", self.transGuildRank)
	self.textGuildPerson = self:FindText("Item/TextPerson", self.transGuildRank)
	self.loopGuild = self:FindLoop("Scroll View/Viewport/Content", self.transGuildRank)

    self:BindLoopEventEx(self.loopGuild, M.OnCreateItem_Guild, M.OnUpdateItem_Guild)
	
    --person
    self.transPersonRank = self:FindTransform("Offset/Right/PersonRank")
	self.textPersonNoTips = self:FindText("TextNoTips", self.transPersonRank)
	self.loopPerson = self:FindLoop("Scroll View/Viewport/Content", self.transPersonRank)

    self:BindLoopEventEx(self.loopPerson, M.OnCreateItem, M.OnUpdateItem)

    --me
	self.textMyScore = self:FindText("Offset/Right/TextMyScore")
    self.textMyRank = self:FindText("Offset/Right/MyRank/Text")
	self.imageMyRank = self:FindImage("Offset/Right/MyRank/Image")

    local onToggle = function(_idx)
        self:OnToggle(_idx)
    end
    self.toggles = UITools.BindTogglesEvent(self:FindTransform("Offset/Right/ToggleGroup"), 2, onToggle)

    self.transRobOK = self:FindTransform("Offset/Right/ButtonsRob/ButtonYellow")
	self.transRobNot = self:FindTransform("Offset/Right/ButtonsRob/ImgNot")
    self.textRobNot = self:FindText("Text", self.transRobNot)
    self.transChaOK = self:FindTransform("Offset/Right/ButtonsChallenge/ButtonGreen")
    self.transChaNot = self:FindTransform("Offset/Right/ButtonsChallenge/ImgNot")
    self.textChaNot = self:FindText("Text", self.transChaNot)

    self.textWorldNoTips = self:FindText("Offset/Left/ScrollInfo/TextWorldNoTips")
	self.textMeNoTips = self:FindText("Offset/Left/ScrollInfo/TextMeNoTips")
end

function M:Show()
    base.Show(self)
    
    ActivityData.AresGapSendRequest(true)
    self.realStart, self.realEnd = ActivityData.GetAresTime()

    self.curTog = 1
    UITools.SetToggleOnIndex(self.toggles, self.curTog)
end

function M:ResetData()
    -- boss 信息
    self.bossInfo = ActivityData.GetAresBossInfo()
    if not self.bossInfo then
        return
    end
    self.bossPB = self.bossInfo.serverInfo
    self.curTime = netMgr.mainClient:GetServerTime()

    -- 活动时间
    preUpdateTime = -999
    self.txtTime.text = ""
    self.endtime = self.realEnd

    -- boss 信息
    local sliderImg = stageSliderImg[self.bossInfo.stage]
    UITools.SetImageIcon(self.imageSliderFill, Const.atlasName.Common, sliderImg)
    self.slider.value = self.bossInfo.rate

    local strStage = stageImg[self.bossInfo.stage]
    UITools.SetImageIcon(self.imageStage, Const.atlasName.Common, strStage)
    
    self.textScore.text = "积分x"..self.bossInfo.scoreAdd

    local process = self.bossInfo.rate * 100
    if process > 1 then
        process = Mathf.Floor(process)
    elseif process > 0 then
        process = Mathf.Floor(process*100)/100
    else
        process = 0
    end
    self.txtProcess.text = string.format("%s%%", process)

    -- 世界、个人对战信息
    local textListWorld, textListMe = ActivityData.GetAresTextList()
    local strWorld = ""
    for i,v in ipairs(textListWorld) do
        strWorld = textBuilder.AppendTrim(strWorld, v)
    end
    local strMe = ""
    for i,v in ipairs(textListMe) do
        strMe = textBuilder.AppendTrim(strMe, v)
    end
    self.textWorld.text = strWorld
    self.textMe.text = strMe
    self.textWorldNoTips.text = string.isEmpty(strWorld) and "暂无信息" or ""
	self.textMeNoTips.text = string.isEmpty(strMe) and "暂无信息" or ""

    -- 挑战信息
    local isShowRob = self.curTime >= self.bossPB.cd_rob
    self.transRobNot.gameObject:SetActive(not isShowRob)
    self.transRobOK.gameObject:SetActive(isShowRob)
    self.timeCdRob = nil
    if not isShowRob then self.timeCdRob = self.bossPB.cd_rob end

    local isShowCha = self.curTime >= self.bossPB.cd_boss
    self.transChaNot.gameObject:SetActive(not isShowCha)
    self.transChaOK.gameObject:SetActive(isShowCha)
    self.timeCdCha = nil
    if not isShowCha then self.timeCdCha = self.bossPB.cd_boss end

    -- 我的排名数据
    self.myRankData = ActivityData.GetAresMyRank() or {}
    self:UpdateRank(self.textMyRank, self.imageMyRank, self.myRankData.rank)
    self.textMyScore.text = self.myRankData.score

    -- 个人、军团排名信息
    self:ShowPersonRank(self.curTog == 1)
    self:ShowGuildRank(self.curTog == 2)
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityAres then
        self:ResetData()
    elseif cmd == LocalCmds.TimeActivity then
        self:ResetData()
    end
end

function M:OnClick(go)
    local goName = go.name
    local pName = go.transform.parent.name
    if pName == "ButtonsRob" then
        --单人活动
        local funs = function ()  OpenUI("UIAresRob") end   
        dataMgr.TeamData.ShowNoTeamActionDialog(funs)   
    elseif pName == "ButtonsChallenge" then
        --战神降临需要单人
        local fun = function ()  ActivityData.SendAresChallenge() end
        dataMgr.TeamData.ShowNoTeamActionDialog(fun)

    elseif goName == "ButtonClose" then
        self:Hide()
        
    elseif goName == "ButtonTips" then
        Hint({content = Lan("rule_ares_come") , rectTransform = go.transform, alignment = 0})
    end
end

function M:Update()
    if Time.realtimeSinceStartup - preUpdateTime < 1 then
        return
    end
    preUpdateTime = Time.realtimeSinceStartup

    ActivityData.AresGapSendRequest()

    local curTime = netMgr.mainClient:GetServerTime()
    if self.endtime then
        self.txtTime.text = Utility.GetVaryTimeFormat(self.endtime - curTime)
        
        if curTime > self.endtime then
            self:Hide()
            Tips("活动已结束")
            return
        end
    end

    if self.timeCdCha then
        if curTime < self.timeCdCha  then
            self.textChaNot.text = string.format( "<size=20>挑战战神\n%s</size>", Utility.GetVaryTimeFormat(self.timeCdCha - curTime))
        else
            self:ResetData()
        end
    end

    if self.timeCdRob then
        if curTime < self.timeCdRob  then
            self.textRobNot.text = string.format( "<size=20>抢夺积分\n%s</size>", Utility.GetVaryTimeFormat(self.timeCdRob - curTime))
        else
            self:ResetData()
        end
    end
end

function M:OnToggle(index)
    self.curTog = index
    self:ResetData()
end
-------- 以上为固定的

function M:ShowPersonRank(isShow)
    self.transPersonRank.gameObject:SetActive(isShow)
    if not isShow then
        return
    end
    -- 排名信息
    self.personRankDatas = ActivityData.GetAresPersonRank() or {}
    self.loopPerson.ItemsCount = #self.personRankDatas
    
    self.textPersonNoTips.gameObject:SetActive(#self.personRankDatas == 0)
end

function M:ShowGuildRank(isShow)
    self.transGuildRank.gameObject:SetActive(isShow)
    if not isShow then
        return
    end
    self.guildRankDatas = ActivityData.GetAresGuildRank() or {}
    self.loopGuild.ItemsCount = #self.guildRankDatas

    self.textGuildNoTips.gameObject:SetActive(#self.guildRankDatas == 0)

    self.myGuildRankData = ActivityData.GetAresMyGuildRank()

    local guildInfo = dataMgr.GuildData.GetGuildInfo()
    self.textGuildName.text = guildInfo and guildInfo.name or "--"

    local rank = self.myGuildRankData and self.myGuildRankData.rank
    local isShow = guildInfo and rank and rank > 0
    self.textGuildLeader.text = isShow and self.myGuildRankData.name or "--"
    self.textGuildScore.text = isShow and self.myGuildRankData.score or "--"
    self.textGuildPerson.text = isShow and self.myGuildRankData.count or "--"
    self:UpdateRank(self.textGuildRank, self.imageGuildRank, rank)
end

function M:GetLoopItem(idx)
    return self.personRankDatas[idx]
end

function M:OnCreateItem(index, coms)
    local trans = coms.trans
    coms.image = self:FindImage("Image", trans)
	coms.image2 = self:FindImage("Image2", trans)
	coms.textRank = self:FindText("Rank/Text", trans)
	coms.imageRank = self:FindImage("Rank/Image", trans)
	coms.textName = self:FindText("TextName", trans)
	coms.textScore = self:FindText("TextScore", trans)
	coms.textGuild = self:FindText("TextGuild", trans)
	coms.imageJob = self:FindImage("ImageGroup", trans)
end

function M:OnUpdateItem(index, coms)
    local data = self:GetLoopItem(index)
    coms.image.gameObject:SetActive(index%2 == 0)
    coms.image2.gameObject:SetActive(index%2 == 1)
    
    coms.textName.text = data.name
    coms.textScore.text = data.score
    coms.textGuild.text = data.guildname

    local pTableid, pTableData = unitMgr.UnpackUnitGuid(data.guid)
	UITools.SetUnitJob(coms.imageJob, pTableData.job)

    self:UpdateRank(coms.textRank, coms.imageRank, index)
end

function M:UpdateRank(textRank, imageRank, rank)
    if rank and rank <= 3 and rank > 0 then
        textRank.text = ""
        imageRank.gameObject:SetActive(true)
        UITools.SetImageIcon(imageRank, Const.atlasName.Common, rankIcons[rank])
    else
        textRank.text = (rank and rank > 0) and rank or "--"
        imageRank.gameObject:SetActive(false)
    end
end
------------GUILD
function M:GetLoopItem_Guild(idx)
   return self.guildRankDatas[idx]
end

function M:OnCreateItem_Guild(index, coms)
    local trans = coms.trans
    coms.image = self:FindImage("Image", trans)
	coms.image2 = self:FindImage("Image2", trans)
	coms.textRank = self:FindText("Rank/Text", trans)
	coms.imageRank = self:FindImage("Rank/Image", trans)
	coms.textName = self:FindText("TextName", trans)
	coms.textScore = self:FindText("TextScore", trans)
	coms.textGuild = self:FindText("TextGuild", trans)
    coms.textPerson = self:FindText("TextPerson", trans)
end

function M:OnUpdateItem_Guild(index, coms)
    local data = self:GetLoopItem_Guild(index)
    coms.image.gameObject:SetActive(index%2 == 0)
    coms.image2.gameObject:SetActive(index%2 == 1)
    
    coms.textName.text = data.name
    coms.textScore.text = data.score
    coms.textGuild.text = data.guildname
    coms.textPerson.text = data.count

    self:UpdateRank(coms.textRank, coms.imageRank, index)
end

return M