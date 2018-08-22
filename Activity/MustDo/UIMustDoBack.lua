local ActivityTable = require "Excel.ActivityTable"
local RecordTable = require "Excel.RecordTable"
local SettingTable = require "Excel.SettingTable"
local RewardTable = require "Excel.RewardTable"
local ActivityCalendarTable = require "Excel.ActivityCalendarTable"
local ConfRule = require "ConfRule"
local TimeSync = require "TimeSync"

local PlayerData = require "Data.PlayerData"
local ActivityData = require "Data.ActivityData"
local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"

local UIWidgetBase = require("UI.Widgets.UIWidgetBase")

local base          = require "UI.UILuaBase"
local M             = base:Extend()

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}

function M:Awake()
    base.Awake(self)

        --按钮。ButtonScale
    UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)
    
    self.uiEmptyRoot = self:FindGameObject("Offset/Empty")
    self.uiSrollView = self:FindGameObject("Offset/Scroll View")
    
    --UIloop
	self.uiRewardLoop = self:FindLoop("Offset/Scroll View/Viewport/Content")
    self:BindLoopEventAdvance(self.uiRewardLoop, M.OnCreateItem, M.UpdateItem)

end

function M:Show()
	base.Show(self)  
    dataMgr.ActMustDoData.isEnter = true
	self:RefreshPanel()
end


function M:RefreshPanel()
    local getBackInfo =  dataMgr.ActMustDoData.GetAllGetBackInfo()
	if not getBackInfo or #getBackInfo == 0 then
		--没有可收回的（所有活动都做完了）
		self.uiEmptyRoot:SetActive(true)
		self.uiSrollView:SetActive(false)
	else
		--有可回收
		self.uiEmptyRoot:SetActive(false)
		self.uiSrollView:SetActive(true)

        --刷新UILoop
        if not getBackInfo then
            self.uiRewardLoop.ItemsCount = 0
        else
            self.uiRewardLoop.ItemsCount = #getBackInfo
        end
		
	end
end

function M:OnClick(go)
    local btnName = go.name
    if btnName == "BtnAllBack" then
        --一键找回
        self:OnClickOnekey()
    elseif btnName == "ButtonClose" then
        self:Hide()
    elseif btnName == "BtnDesc" then
        Hint({rectTransform = go.transform, content = Lan("mustdoback_desc"), alignment = 0})
    end
end


function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
        if msg.cmd == Cmds.GetMustdoBack.index or msg.cmd == Cmds.GetMustDoInfo.index then
            self:RefreshPanel()
		end  		
    end
end




--找回
function M:OnClickOnekey()

	local num = self:CalOnekeyCostNum()
	if num == 0 then
		Tips(Lan("activity_res_getback_empty"))
		return
	end
	local itemid
	itemid = Const.ITEM_ID_VCOIN
	local str = string.format("是否愿意花费%s<color=#09ADFF>%d</color>一键找回所有资源？", UITools.FormatItemIconText(itemid), num) 
	require ("Data.TeamData").ShowMsgBox(str, 
		function()
			if dataMgr.PlayerData.CheckItemsNum({{itemid=itemid, num=num}}, true, true) then
                dataMgr.ActMustDoData.RequestGetBackReward(0)
			end
		end,
	function() end)
end



function M:CalOnekeyCostNum()

    	--计算一键找回消耗
	local num = 0
    local getBackInfo = dataMgr.ActMustDoData.GetAllGetBackInfo()
	if getBackInfo then
		for i,v in ipairs(getBackInfo) do
			if not v.isget then
				--未找回
				local expendId = self:GetRewardIdAndExpendId(v.id)
				local expendTab = ExpendTable[expendId]
				if expendTab ~= nil then
					local expendData = expendTab.expend[1]
					-- print(expendData.num, getBackInfo.num)
					num = num + expendData.num * v.times
				end
			end
		end
	end
	return num
end

function M:OnCreateItem(coms)
    coms.actIcon = self:FindImage("ActTypeImg", coms.trans)--活动图片
    coms.actName = self:FindText("ActName", coms.trans)--活动名称
    coms.actNum = self:FindText("Num",coms.trans) --活动次数
    coms.CanGetBtn = self:FindGameObject("BtnBack",coms.trans) --找回按钮
    coms.getDone = self:FindGameObject("GetDone",coms.trans) --已经找回

    UguiLuaEvent.ButtonClick(coms.CanGetBtn, nil, function(go)
		self:OnChoose(self.uiRewardLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)

end

--点击可找回按钮
function M:OnChoose(index, go)
	
        --点击可找回按钮
        local itemid
        local num = 0
		local getBackInfo = dataMgr.ActMustDoData.GetGetBackInfoByIndex(index)
		if getBackInfo ~= nil then
			local activityId = getBackInfo.id
			local expendId = self:GetRewardIdAndExpendId(activityId)

			--判断消耗
            local expendTab = ExpendTable[expendId]
            if expendTab ~= nil then
                local expendData = expendTab.expend[1]
                -- print(expendData.num, getBackInfo.num)
                num = expendData.num * getBackInfo.times
            end

           
            itemid = Const.ITEM_ID_VCOIN
            local str = string.format("是否愿意花费%s<color=#09ADFF>%d</color>一键找回资源？", UITools.FormatItemIconText(itemid), num) 
	        require ("Data.TeamData").ShowMsgBox(str, 
            function()
                
                if dataMgr.PlayerData.CheckItemsNum({{itemid=itemid, num=num}}, true, true) then
                --消耗充足，发包
				    dataMgr.ActMustDoData.RequestGetBackReward(activityId)
                end
		    end,
		    function() end)
		end
	
end


function M:GetRewardIdAndExpendId (activityId)
	local activityTab = ActivityTable[activityId]
	local rewardId = nil
	local expendId = nil

	expendId = activityTab.dexpend
	return expendId
end

function M:UpdateItem(coms)
    local index = coms.globalIndex
    local getBackInfo = dataMgr.ActMustDoData.GetGetBackInfoByIndex(index)
    local day = getBackInfo.day
    if getBackInfo ~= nil then
        local activityTab = ActivityTable[getBackInfo.id]
        --活动名称
        coms.actName.text = activityTab.name
        --图片
        uiMgr.SetSpriteAsync(coms.actIcon, Const.atlasName.ItemIcon, activityTab.icon)
        --次数
        coms.actNum.text = string.format("%d/%d",getBackInfo.times,activityTab.dnum * day)
        --是否找回
        if not getBackInfo.isget then
            coms.CanGetBtn:SetActive(true)
            coms.getDone:SetActive(false)
        else
            coms.CanGetBtn:SetActive(false)
            coms.getDone:SetActive(true)
        end
    end
    
end
return M