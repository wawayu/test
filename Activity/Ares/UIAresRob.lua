--[[
 战神降临--抢夺
]]
local base = require "UI.UILuaBase"
local M = base:Extend()
local UguiLuaEvent = require "UguiLuaEvent"

local ActivityData = dataMgr.ActivityData
local rankIcons = {"1st", "2nd", "3rd"}
local preUpdateTime = -999

function M.Open(params)
    uiMgr.ShowAsync("UIAresRob")
end

function M:Awake()
    base.Awake(self)

    UITools.AddBtnsListenrList(self:FindTransform("Offset"), self, M.OnClick, Button)

    self.textNoTips = self:FindText("Offset/Panel/TextNoTips")
	self.uiLoop = self:FindLoop("Offset/Panel/Scroll View/Viewport/Content")

    self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.OnUpdateItem)
end

function M:Show()
    base.Show(self)

    ActivityData.SendGetAresRobList()
  
    self:ResetData()
end

function M:ResetData()
    self.robList = ActivityData.GetAresRobList() or {}
    self.uiLoop.ItemsCount = #self.robList
    self.textNoTips.gameObject:SetActive(#self.robList == 0)
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityAres then
        self:ResetData()
    elseif cmd == LocalCmds.Activity then
        self:ResetData()
    end
end

function M:GetLoopItem(idx)
   return self.robList[idx]
end

function M:OnCreateItem(index, coms)
    local trans = coms.trans
	coms.textRank = self:FindText("Rank/Text", trans)
	coms.imageRank = self:FindImage("Rank/Image", trans)
	coms.textName = self:FindText("TextName", trans)
	coms.textScore = self:FindText("TextScore", trans)
    coms.textIsFriend = self:FindText("TextIsFriend", trans)
    coms.transItem = self:FindTransform("Item", trans)
	
    coms.textRobNot = self:FindText("ButtonRob/ImgNot/Text", trans)
    coms.imgNot = self:FindTransform("ButtonRob/ImgNot", trans)
    coms.transRob = self:FindTransform("ButtonRob/ButtonGreen", trans)
    UguiLuaEvent.ButtonClick(coms.transRob.gameObject, nil, function(_go)
        self:OnClickRob(self.uiLoop:GetItemGlobalIndex(trans.gameObject) + 1, _go)
    end)
    UguiLuaEvent.ButtonClick(coms.imgNot.gameObject, nil, function(_go)
        self:OnClickRobNot(self.uiLoop:GetItemGlobalIndex(trans.gameObject) + 1, _go)
    end)
end

function M:OnUpdateItem(index, coms)
    local data = self:GetLoopItem(index)

    local ginfo = dataMgr.GuildData.GetGuildMemberByGUID(data.guid)

    coms.textName.text = data.name
    coms.textScore.text = data.score
    coms.textIsFriend.text = ginfo and "军团" or ""

    self:UpdateRank(coms.textRank, coms.imageRank, index)

    local canRob, robError, protectTime = ActivityData.GetAresCanRob(data)
    coms.transRob.gameObject:SetActive(canRob)
    coms.imgNot.gameObject:SetActive(not canRob)
    if robError then
        if robError == "robing" then
            coms.textRobNot.text = "战斗中"
        elseif robError == "protect" then
            coms.textRobNot.text = Utility.GetVaryTimeFormat(protectTime)
        else
            coms.textRobNot.text = "抢夺"
        end
    end

    UITools.SetFriendInfo(coms.transItem, data)
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

function M:OnClickRob(index, go)
    local data = self:GetLoopItem(index)
    ActivityData.SendAresRob(data)
end

function M:OnClickRobNot(index, go)
    local data = self:GetLoopItem(index)
    ActivityData.GetAresCanRob(data, true)
end

function M:OnClick(go)
    local goName = go.name

    if goName == "ButtonClose" then
        self:Hide()
    end
end

function M:Update()
    if Time.realtimeSinceStartup - preUpdateTime < 1 then
        return
    end
    preUpdateTime = Time.realtimeSinceStartup

    if self.robList then
        self.uiLoop.ItemsCount = #self.robList
    end
end

return M