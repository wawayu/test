--[[
  谁与争锋--战斗
]]
local base = require "UI.UILuaBase"
local M = base:Extend()
local UguiLuaEvent = require "UguiLuaEvent"

local CompeteTop = dataMgr.CompeteTopData
local intLen = 3
local preUpdateTime = -999
local buffIcon = {"skillicon_gongjizengqiang", "skillicon_fangyuzengqiang", "skillicon_qixuezengqiang"}

function M.Open(params)
    uiMgr.ShowAsync("UICompeteTopFight")
end

function M:Awake()
    base.Awake(self)

    -- 加成数据
    self.comsAddTable = {}
    for i=1,3 do
        self.comsAddTable[i] = {}
        local coms = self.comsAddTable[i]
        coms.trans = self:FindTransform(string.format("Offset/Add/Add (%s)", i))
        coms.image = self:FindImage("Image", coms.trans)
        coms.text = self:FindText("Text", coms.trans)
    end

    -- 奖励数据
    self.comsRewardTable = {}
    for i=1,4 do
        self.comsRewardTable[i] = {}
        local coms = self.comsRewardTable[i]
        coms.trans = self:FindTransform(string.format("Offset/Reward/Add (%s)", i))
        coms.image = self:FindImage("Image", coms.trans)
        coms.text = self:FindText("Text", coms.trans)
    end

    self.textCount = self:FindText("Offset/TextCount")
	self:OnFitter()
end

function M:OnFitter()
    FitterTool.Fitter(self:FindTransform("Offset"))
end

function M:Show()
    base.Show(self)
    
    self:ResetData()
end

function M:ResetData()
    local curInfo = CompeteTop.GetCurInfo()
    if curInfo == nil or curInfo.id == 0 then
        return
    end

    self.buffAdded = CompeteTop.GetBuffAdded()
    self:SetCurAdd(self.buffAdded)

    self.rewardAdded = CompeteTop.GetRewardAdded()
    self:SetCurReward(self.rewardAdded)

    local data = CompeteTop.GetCurCompeteConfig()
    self.textCount.text = string.format("%s/%s", curInfo.round, data.maxRound)
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityCompeteTop then
        self:ResetData()
    elseif cmd == LocalCmds.Activity then
        self:ResetData()
    end
end

function M:SetCurAdd(tb)
    local len = #tb
    for i,v in ipairs(self.comsAddTable) do
        UITools.SetImageIcon(v.image, Const.atlasName.SkillIcon, buffIcon[i])
        if i <= len then
            v.text.text = tb[i].."%"
        else
            v.text.text = "0%"
        end
    end
end

function M:SetCurReward(tb)
    local len = #tb
    for i,v in ipairs(self.comsRewardTable) do
        if i <= len then
            v.text.text = tb[i].num
            UITools.SetItemIcon(v.image, tb[i].itemid)
        end
    end
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityCompeteTop then
        self:ResetData()
    elseif cmd == LocalCmds.Activity then
        self:ResetData()
    end
end
return M