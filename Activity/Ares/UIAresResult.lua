--[[
 战神降临--结算
]]
local base = require "UI.UILuaBase"
local M = base:Extend()
local UguiLuaEvent = require "UguiLuaEvent"

local ActivityData = dataMgr.ActivityData
local rankIcons = {"1st", "2nd", "3rd"}

function M.Open(params)
    uiMgr.ShowAsync("UIAresResult")
end

function M:Awake()
    base.Awake(self)

    UITools.AddBtnsListenrList(self:FindTransform("Offset"), self, M.OnClick, Button)

    --guild
    self.transGuildRank = self:FindTransform("Offset/PanelGuild")
    self.transGuildMe = self:FindTransform("Item", self.transGuildRank)
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
    self.transPersonRank = self:FindTransform("Offset/PanelPerson")
	self.textPersonNoTips = self:FindText("TextNoTips", self.transPersonRank)
	self.loopPerson = self:FindLoop("Scroll View/Viewport/Content", self.transPersonRank)

    self:BindLoopEventEx(self.loopPerson, M.OnCreateItem, M.OnUpdateItem)

    --me
    self.transPersonMe = self:FindTransform("Item", self.transPersonRank)
	self.textMyScore = self:FindText("Item/TextScore", self.transPersonRank)
    self.textMyRank = self:FindText("Item/Rank/Text", self.transPersonRank)
	self.imageMyRank = self:FindImage("Item/Rank/Image", self.transPersonRank)
    self.textMyName = self:FindText("Item/TextName", self.transPersonRank)
    self.textMyGuild = self:FindText("Item/TextGuild", self.transPersonRank)
    self.imageGroup = self:FindImage("Item/ImageGroup", self.transPersonRank)
	
    local onToggle = function(_idx)
        self:OnToggle(_idx)
    end
    self.toggles = UITools.BindTogglesEvent(self:FindTransform("Offset/ToggleGroup"), 2, onToggle)
end

function M:Show()
    base.Show(self)
  
    ActivityData.SendGetAresTopInfo()

    self.curTog = 1
    UITools.SetToggleOnIndex(self.toggles, self.curTog)
end

function M:ResetData()
    -- 个人、军团排名信息
    self:ShowPersonRank(self.curTog == 1)
    self:ShowGuildRank(self.curTog == 2)
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityAres then
        self:ResetData()
    end
end

function M:OnClick(go)
    local goName = go.name
    local pName = go.transform.parent.name
    if goName == "ButtonClose" then
        self:Hide()
    end
end

function M:OnToggle(index)
    self.curTog = index
    self:ResetData()
end

function M:ShowPersonRank(isShow)
    self.transPersonRank.gameObject:SetActive(isShow)
    if not isShow then
        return
    end

    -- 我的排名数据
    self.myRankData = ActivityData.GetAresMyRank()

    local rank = self.myRankData and self.myRankData.rank
    local isShow = rank and rank > 0
    self.transPersonMe.gameObject:SetActive(isShow)
    if isShow then
        local roleInfo = dataMgr.PlayerData.GetRoleInfo()
        local guildInfo = dataMgr.GuildData.GetGuildInfo()
        
        self.textMyGuild.text = guildInfo and guildInfo.name or "--"
        self.textMyName.text = roleInfo.name

        self:UpdateRank(self.textMyRank, self.imageMyRank, rank)
        self.textMyScore.text = self.myRankData.score
        UITools.SetPlayerJob(self.imageGroup, roleInfo)
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

    local rank = self.myGuildRankData and self.myGuildRankData.rank
    local isShow = rank and rank > 0
    self.transGuildMe.gameObject:SetActive(isShow)
    if isShow then
        local guildInfo = dataMgr.GuildData.GetGuildInfo()
        self.textGuildName.text = guildInfo and guildInfo.name or "--"
        self.textGuildLeader.text = self.myGuildRankData.name or "--"
        self.textGuildScore.text = self.myGuildRankData.score or "--"
        self.textGuildPerson.text = self.myGuildRankData.count or "--"
        self:UpdateRank(self.textGuildRank, self.imageGuildRank, rank)
    end
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