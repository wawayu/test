local ActivityTable = require "Excel.ActivityTable"
local SettingTable = require "Excel.SettingTable"
local RewardTable = require "Excel.RewardTable"

local PlayerData = require "Data.PlayerData"
local ActivityData = require "Data.ActivityData"

local ScoreBuilder = require "ScoreBuilder"
local transPosition = Vector3.New(-50, -60, 0)

local UIWidgetBase = require("UI.Widgets.UIWidgetBase")

local base          = require "UI.UILuaBase"
local M             = base:Extend()



function M.Open(param)

    uiMgr.ShowAsync("UIMustDoUP")
end

function M:Awake()
    base.Awake(self)
    UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)
    self.hp = self:FindText("Offset/Right/HPText")
    self.atk = self:FindText("Offset/Right/ATKText")
    self.def = self:FindText("Offset/Right/DEFText")

    self.hpAdd = self:FindText("Offset/Right/HPText/NextText")
    self.atkAdd = self:FindText("Offset/Right/ATKText/NextText")
    self.defAdd = self:FindText("Offset/Right/DEFText/NextText")
    self.allFight = self:FindText("Offset/Right/FightText")

    self.transRewardItem = self:FindTransform("Offset/Right/#105RewardList/Viewport/Grid/Item")
    self.effect = self:FindTransform("Offset/PanelModel")

end

--本地监听
function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
        self:ResetData()
    end
end

function M:Show()
    base.Show(self)

    self.mustdoInfo = dataMgr.ActMustDoData.MustDoInfo()
    if self.mustdoInfo then
        self:ResetData()
    end

end

function M:ResetData()
    self.lv =  self.mustdoInfo.lv
    if self.lv <=0 or not self.lv then
        self.lv =1
    end
    local attrID = excelLoader.SettingTable["mrbz_attrgroupid1"]  
    local attrTable = excelLoader.AttrGrowthTable[attrID * 1000 + self.lv]
    local addLv = self.lv -1
    if addLv <=0 then
        -- body
    end
    local attAddTable = excelLoader.AttrGrowthTable[attrID * 1000 + addLv]
    self.hp.text = string.format("生命 %d",attrTable.maxhp) 
    self.atk.text = string.format("攻击 %d",attrTable.matk)
    self.def.text = string.format("防御 %d",attrTable.mdef)

    self.hpAdd.text = string.format("+%d",attrTable.maxhp - attAddTable.maxhp ) 
    self.atkAdd.text = string.format("+%d",attrTable.matk - attAddTable.matk)
    self.defAdd.text = string.format("+%d",attrTable.mdef - attAddTable.mdef)


    --奖励列表
    self.rewardTable =  dataMgr.ActMustDoData.RewardTable()
    self.rewardID = self.rewardTable[self.lv]

     --奖励
     if self.rewardGoList == nil then
        self.rewardGoList = {} 
    end

    self.allFight.text = ScoreBuilder.GetMustDoScore(self.lv)
    -- 刷新奖励
    UITools.CopyRewardList({self.rewardID.rewardid}, self.rewardGoList, self.transRewardItem, rewardExParams)

    --特效
    self.moduleTable = excelLoader.SettingTable["mrbz_effect"] 
    for i,v in ipairs(self.moduleTable) do
        if self.lv >= v.lv then
            self.effextInfo = self.moduleTable[i]
        elseif self.lv <5 then
            self.effextInfo = self.moduleTable[1]
        end
    end

    if not self.effectTrans then self.effectTrans = {} end
    local effextName = self.effextInfo.effectid
    if not self.effectTrans[effextName] then
        self.effectTrans[effextName] = effectMgr:SpawnToUI(effextName, transPosition, self.effect, 0)
    end

    for k, v in pairs(self.effectTrans) do
        UITools.SetActive(v, k==effextName)
    end
end

function M:OnClick(go)
    local btnName = go.name
	--print(btnName)
    if btnName == "Exit" then
        self:Hide()
    end
end

return M