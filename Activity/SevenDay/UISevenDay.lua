local UguiLuaEvent = require "UguiLuaEvent"

local SkillTable = require "Excel.SkillTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local toggleNotifyPos = Vector3.New(90,20,0)
local topTabNotifyPos = Vector3.New(35,24,0)
local rewardExParams = {isnative = true, showQualityEffect = true}

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true

local PanelType = {Bonus = 1, Target = 2, Target2=3, Half = 4}

local LeftTab = 
{
    {name = "每日福利", type = PanelType.Bonus},
    {name = "每日目标", type = PanelType.Target},
    {name = "每日目标2", type = PanelType.Target2},
    {name = "半价抢购", type = PanelType.Half},
}

local SubPanelPath = {
    "Offset/DailyBonus",
    "Offset/DailyTarget",
    "Offset/DailyTarget2",
    "Offset/HalfPrice",
}

--这里修改的多
M.childPanelConfig = {
    [SubPanelPath[1]] = "UI.Activity.SevenDay.UIDailyBonus",
    [SubPanelPath[2]] = "UI.Activity.SevenDay.UIDailyTarget",
    [SubPanelPath[3]] = "UI.Activity.SevenDay.UIDailyTarget",
    [SubPanelPath[4]] = "UI.Activity.SevenDay.UIHalfPrice",
}

function M.Open(openParams)
    M.closeTween = openParams and openParams.closeTween
    uiMgr.ShowAsync("UISevenDay")
end

function M:Awake()
	base.Awake(self)

    self.offset = self:FindGameObject("Offset")
    --print(#self.childs)

    -- print("aaaaaa")
    --默认关闭所有子界面
    for k,v in pairs(SubPanelPath) do
        self.childs[v].gameObject:SetActive(false)
    end

    --左边UILoop
	self.uiLeftLoop = self:FindGameObject("Offset/Left/ScrollView/Viewport/Content"):GetComponent(typeof(UILoop))
    self:BindLoopEventEx(self.uiLeftLoop, M.OnCreateItem, M.UpdateTabItem, M.OnChooseTab)

    self.tranSelect = self:FindTransform("Offset/Left/ScrollView/Viewport/ImgSelect")

    --顶部
    self.uiTopLoop = self:FindGameObject("Offset/Top/ScrollView/Viewport/Content"):GetComponent(typeof(UILoop))
    self:BindLoopEventEx(self.uiTopLoop, M.OnCreateDayItem, M.UpdateDayItem, M.OnChooseDay)

    --倒计时
    self.txtCountDown = self:FindText("Offset/Top/ImgTime/TxtLeft")

    --关闭按钮
    self.tranClose = self:FindTransform("Offset/ButtonClose")
    UguiLuaEvent.ButtonClick(self.tranClose.gameObject, self, M.Hide)

    self.transBox = self:FindTransform("Offset/Boxes")
    self.sliderBox = self:FindSlider("Offset/Boxes/Slider")
    self.transBoxTips = self:FindImage("Offset/Boxes/Tips")
    self.textBoxdesc = self:FindText("Offset/Boxes/Tips/DescText")
	self.transBoxItem = self:FindTransform("Offset/Boxes/Tips/RewardList/Viewport/Grid/Item")
	
    self.imageBoxs = {}
    self.imageBoxGot = {}
    self.redGotPoint = {}
    for i=1,3 do
        self.imageBoxs[i] = self:FindImage("Offset/Boxes/Buttons/Button"..i)
        self.imageBoxGot[i] = self:FindImage("Got", self.imageBoxs[i].transform)
        self.redGotPoint[i] = self:FindGameObject("RedPoint",self.imageBoxs[i].transform)
        UguiLuaEvent.ButtonClick(self.imageBoxs[i].gameObject, self, M.OnClickBox)
    end
    UguiLuaEvent.ExternalOnDown(self.transBoxTips.gameObject, self, function()
		self.transBoxTips.gameObject:SetActive(false)
    end)
    self.boxContainer = {}
    
    -- 设置target2 特殊配置
    local ui = self:GetChildUI(3)
    ui.uigroup = 2
end

function M:Show()
    base.Show(self)
    self:TweenOpen(self.offset)

    self.transBoxTips.gameObject:SetActive(false)

    --第几天
    local day = dataMgr.PlayerData.GetPlayerCreateDeltaDay()
    -- 实际天数
    self.curDay = day
    -- 循环的第几天
    self.loopCurDay = self.curDay % 7
    if self.loopCurDay == 0 then self.loopCurDay = 7 end
    -- 选择的绝对天数
    self.selectDayIndex = self.curDay
    -- 之前循环过了多少天
    self.preDayLen = self.curDay - self.loopCurDay

    --默认第一个子面板（每日福利）
    self:ShowChildPanelByIndex(1)

    self:ResetBase()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.SevenDay or cmd == LocalCmds.Achievement then
        self:ResetBase()
    end
end

function M:ResetBase()
    --刷新左侧界面
    self.uiLeftLoop.ItemsCount = #LeftTab

    self.uiTopLoop.ItemsCount = 7

    self:ResetBox()
end

--倒计时
function M:Update()
    local deltaTime = dataMgr.SevenDayData.GetEndSevenDayTime() - netMgr.mainClient:GetServerTime()
	if deltaTime <= 0 then
       self:Hide()
        return
    end

    if not self.lastDeltaTime or deltaTime ~= self.lastDeltaTime then
        self.lastDeltaTime = deltaTime
        self.txtCountDown.text = Utility.GetVaryTimeFormat(deltaTime)     
    end
end

---------------------------------左边

--道具
function M:OnCreateItem(index, coms)
	coms.txtLv = self:FindText("Name", coms.trans)--等级
end

--选中左边的Tab
function M:OnChooseTab(index, coms)
    if self.selectIndex == index then
		return
	end

    self:ShowChildPanelByIndex(index)
    self:SetSelectedBound(coms.go, self.tranSelect)

    if index == PanelType.Half then
        --每日半价
        dataMgr.LoginData.WriteConfig(dataMgr.PlayerData.GetRoleInfo().guid.."HalfPrice"..self.selectDayIndex, true)
        --刷新主界面红点
        LocalEvent(LocalCmds.SevenDay)
    end
    
    --刷新红点
    self:ResetBase()

	-- local tp = LeftTab[index].type
    -- if tp == PanelType.Daily then
	-- 	--每日签到。打开界面

	-- else
	-- 	--敬请期待
    --     Tips("敬请期待")
	-- end
end

--显示子面板
function M:ShowChildPanelByIndex(index)
    -- print("ccccccccccc   "..index)
    self.selectIndex = index
    local panelPath = SubPanelPath[index]
    if panelPath ~= nil then
        self.curChildPanel = self.childs[panelPath]
        self.curPanelIndex = index

        -- print(panelPath)
        -- print(self.curPanelIndex)

        --当前面板show，其他面板hide
        self:ShowSingleChild(self.curChildPanel)
    end
end

function M:IndexToDay(index)
    return self.preDayLen + index
end

function M:GetChooseDayIndex(realday)
    realday = realday or self.selectDayIndex
    return realday - self.preDayLen
end

function M:SetChooseDayIndex(relativeDay)
    self.selectDayIndex = self.preDayLen + relativeDay
end

function M:UpdateTabItem(index, coms)
	local tabInfo = LeftTab[index]
	if tabInfo ~= nil then
		coms.txtLv.text = tabInfo.name
	end

    --设置选中框
	if self.selectIndex == index then
		self:SetSelectedBound(coms.go, self.tranSelect)
	elseif self.tranSelect.parent == coms.trans then
  		self.tranSelect.anchoredPosition = Vector2.New(99999, 99999)
    end
    
    if tabInfo.type == PanelType.Target or tabInfo.type == PanelType.Target2 then
        local uigroup = tabInfo.type == PanelType.Target and 1 or 2
        local targetData =  dataMgr.DailyTargetData.GetDailyTargetData(self.selectDayIndex, uigroup)
        if targetData and #targetData > 0 then
            coms.txtLv.text = targetData[1].firstGroup
        end
    end

    self:AddTabNotify(coms.go, tabInfo, self.selectDayIndex)        
end

-- 设置选中框
function M:SetSelectedBound(parentGo, boundTrans)
    UITools.AddChild(parentGo, boundTrans.gameObject, false)
	boundTrans.anchoredPosition3D = Vector3.zero
	boundTrans.gameObject:SetActive(true)
    boundTrans:SetSiblingIndex(0)
end

------------------------------顶部，天
--道具
function M:OnCreateDayItem(index, coms)
	coms.txtName = self:FindText("Name", coms.trans)--等级

    --背景    
    coms.imgBg = coms.go:GetComponent(typeof(UnityEngine.UI.Image))
    coms.imgSelect = self:FindGameObject("ImgSelect", coms.trans)
end

--选中顶部的天Tab
function M:OnChooseDay(index, coms)
    local selectIndex = self:GetChooseDayIndex()
    if selectIndex == index then
		return
	end
    if index > self.loopCurDay then
        --tips
        Tips("时间没到")
    else
        self:SetChooseDayIndex(index)
        --刷新界面
        self:ShowChildPanelByIndex(1)
        --刷新红点
        self:ResetBase()
    end
end

function M:UpdateDayItem(index, coms)
    local thisDay = self:IndexToDay(index)
    if thisDay > self.curDay then
        --未来的
        UITools.SetImageGrey(coms.imgBg, true)
    else
        --现在或之前的
        UITools.SetImageGrey(coms.imgBg, false)
    end

    coms.imgSelect.gameObject:SetActive(self.selectDayIndex == thisDay)
    
    --字体颜色
    if self.selectDayIndex == index then
        --选中的
        coms.txtName.text = string.format("<color=#7A2903>第%d天</color>", thisDay)
    else
        --未选中的
        coms.txtName.text = string.format("<color=#FFFFFF>第%d天</color>", thisDay)
    end

    --红点
    self:AddTopTabNotify(coms.go, thisDay)        
end

--倒计时
function M:OnCountDown(uiText, _callBack, _second)
	if _second > 0 then
		TweenText.Begin(uiText, _second, 0, _second, 0)
		self.tweenTextContent = uiText.gameObject:GetComponent(typeof(TweenText))
		-- self.tweenTextContent.format = format
		self.tweenTextContent.isTime = true
		self.tweenTextContent:SetOnFinished(function()
			if _callBack then
				_callBack()
			end
		end)
	else
		print("OnCountDown wrong time")
	end
end

function M:GetAchievementID(index)
    local loop = dataMgr.SevenDayData.GetCurLoopIndex()
    local ori = 8400000
    local ten = (loop-1)*10
    return ori + ten + index
end

--[[
    local progress, gotReward, reachTime = AchievementData.CheckStatus(achieveTab.id)

		--名称、描述
		-- coms.name.text = UITools.FormatQualityText(achieveTab.quality, achieveTab.name)
		-- print(achieveTab.desc)
		coms.txtDesc.text = string.format("%s(<color=#45CF75>%d/%d</color>)", achieveTab.desc, progress, achieveTab.needNum)
]]

function M:ResetBox()
    local id = self:GetAchievementID(3)
    local tab = excelLoader.AchievementTable[id]
    if not tab then
        return
    end
    local progress, gotReward, reachTime = dataMgr.AchievementData.CheckStatus(id)
    self.sliderBox.value = progress/tab.needNum
    for i=1,3 do
        local id = self:GetAchievementID(i)
        local tab = excelLoader.AchievementTable[id]
        local progress, gotReward, reachTime = dataMgr.AchievementData.CheckStatus(id)
        UITools.SetImageGrey(self.imageBoxs[i], gotReward or progress < tab.needNum)
        self.imageBoxGot[i].gameObject:SetActive(gotReward)
        self.redGotPoint[i].gameObject:SetActive(not gotReward and progress >= tab.needNum)
    end
end

function M:ShowBox(index)
    local id = self:GetAchievementID(index)
    local tab = excelLoader.AchievementTable[id]
    if tab then
        self.transBoxTips.gameObject:SetActive(true)
        local progress, gotReward, reachTime = dataMgr.AchievementData.CheckStatus(id)
        local needNum = tab.needNum
        local curNum = progress or 0
        local str = "<color=#00aa00>%s到%s天</color>完成数量<color=#00aa00>%s</color>个可领取<color=#00aa00>(%s/%s)</color>"
        self.textBoxdesc.text = string.format(str, tab.param.day1, tab.param.day2, needNum, curNum, needNum)

        if tab.reward then
			UITools.CopyRewardList({tab.reward}, self.boxContainer, self.transBoxItem, rewardExParams)
		end

        if not gotReward and progress >= needNum then
            dataMgr.AchievementData.RequestGetReward(id)
        end
    end
end

function M:OnClickBox(go)
    local name = go.name
    if name == "Button1" then
        self:ShowBox(1)
    elseif name == "Button2" then
        self:ShowBox(2)
    elseif name == "Button3" then
        self:ShowBox(3)
    end
end
---------------红点，todo，待优化

--左边
function M:AddTabNotify(go, tabInfo, day)
    if not tabInfo then return end

    local func = notifyMgr.SevenDayLeftTabNotifyFunction[tabInfo.type]
    -- print("=>", tabInfo.name, tabInfo.type, tostring(func))
    if func then
        notifyMgr.AddNotify(go, func(day), toggleNotifyPos, notifyMgr.NotifyType.Common)
    else
        notifyMgr.AddNotify(go, false, toggleNotifyPos, notifyMgr.NotifyType.Common)
    end
end

--顶部
function M:AddTopTabNotify(go, day)
    -- print("天 ",  day)
   notifyMgr.AddNotify(go, notifyMgr.IsSevenDayTopTabNotifyByDay(day), topTabNotifyPos, notifyMgr.NotifyType.Common)
end

function M:GetChildUI(panelindex)
    local panelPath = SubPanelPath[panelindex]
    if panelPath ~= nil then
        return self.childs[panelPath]
    end

    return nil
end

return M