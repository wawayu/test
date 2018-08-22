local BusinessData = require "Data.BusinessData"
local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local rewardExParams = {showtips = true, isnative = true, showQualityEffect = true, maxlen = 2}
local commonParamsTable = {showtips = true, showQualityEffect = true}
local TT = {}
local endCallback= nil
local ConstLen = 8
local evCurAngle
local businesspb

local openid
function M.Open(openParams)
    openid = BusinessData.HeroLot_GetOpenID()
    if not openid then
        Debugger.LogWarning("UIHeroLottery open id is nil")
        return
    end
    uiMgr.ShowAsync("UIHeroLottery")
end

function M:Awake()
    base.Awake(self);

    self.frame = self:FindGameObject("Frame")

    self.logoGuanYu = self:FindGameObject("Frame/LogoGuanYu")
    self.logoZhouYu = self:FindGameObject("Frame/LogoZhouYu")

    UITools.AddBtnsListenrList(self:FindTransform("Frame"), self, M.OnClick, ButtonScale)

    UguiLuaEvent.ButtonClick(self:FindGameObject("Frame/ButtonClose"), self, M.Hide)

    self.transItems = {}
    self.comsItems ={}
    for i=1,8 do
        self.transItems[i] = self:FindTransform(string.format("Frame/Wheel/Items/Item1 (%s)", i))
        self.comsItems[i] = {transRoot = self.transItems[i], index = i}
    end
    self.transPointer = self:FindTransform("Frame/Wheel/Pointer")
    self.textTime = self:FindText("Frame/Time")
    self.transTriangle = self:FindTransform("Frame/Wheel/Triangle")
    
    self.textNum = self:FindText("Frame/Remain/Num")
    self.textCount = self:FindText("Frame/Count")

    self.extraReward1 = self:FindTransform("Frame/ExtraReward1")
	self.extraReward2 = self:FindTransform("Frame/ExtraReward2")
    self.transRewardItem1 = self:FindTransform("Viewport/Grid/Item", self.extraReward1)
    self.transRewardItem2 = self:FindTransform("Viewport/Grid/Item", self.extraReward2)
    
    self.rewardComs1 = {}
    self.rewardComs2 = {}
    --[[
        commonParamsTable.clickCallback = function(_,_,com)
            self:OnChooseItem(com.index, com)
        end
    ]]

    TT.Init(self.transPointer, function()
		self:AnimationEnd()
    end)
    
    local halfangle = 180/ConstLen
    local fullangle = 360/ConstLen
    TT.AddAngleEvent(halfangle, function(angle)
        if angle < 0 then angle = angle + 360 end
        local index = math.floor((angle + halfangle) / fullangle)
        index = index % ConstLen
        if index == 0 then index = ConstLen end
        self.transTriangle.localEulerAngles = Vector3.New(0, 0, index * fullangle)
    end)
end

function M:Show()
    base.Show(self)  

    businesspb = nil
    local id = openid or BusinessData.HeroLot_GetOpenID()
    openid = nil
    if not id or id < 0 then
        self:Hide()
        return
    end
    self.script = BusinessData.GetScript(id)
	if not self.script then
		self:Hide()
		return
	end

    self.tab = BusinessActivityTable[id]
    self.heroType = self.tab.param2.herotype
    self.confExtraReward = self.tab.rewardconfig.extrareward
    self.costItem = self.tab.param1.cost

    self.logoZhouYu:SetActive(self.heroType == 1)
    self.logoGuanYu:SetActive(self.heroType == 2)

    local rewards = dataMgr.ItemData.GetRewardList({self.confExtraReward[1][2]})
    UITools.CopyRewardListWithItemsEx(rewards, self.rewardComs1, self.transRewardItem1, rewardExParams)

    local rewards2 = dataMgr.ItemData.GetRewardList({self.confExtraReward[2][2]})
    UITools.CopyRewardListWithItemsEx(rewards2, self.rewardComs2, self.transRewardItem2, rewardExParams)

    self.tableRewards = self.script:GetRewards()
    for i=1,8 do
        local r = self.tableRewards[i]
        UITools.SetCommonItem(self.comsItems[i], nil, excelLoader.ItemTable[r.itemid], commonParamsTable)
        self.comsItems[i].textNum.text = r.num > 1 and r.num or ""
    end

    self.endTime = 0

    self.startTime = -1
    self.transTriangle.localEulerAngles = Vector3.New(0,0,0)
    TT.Reset()

    self:ResetData()

    self:TweenOpen(self.frame)
end 

function M:ResetData()
    local remain = dataMgr.PlayerData.GetItemCount(self.costItem.itemid)
    self.textNum.text = string.format("%s/%s", remain, self.costItem.num)

    self.info = self.script:Info()
    if not self.info then
        return
    end

    self.endTime = self.info.endtime

    self.textCount.text = self.info.intparam.."次"
end

function M:OnChooseItem(index, com)
    local r = self.tableRewards[index]
    if not r or not r.rewardid then
        return
    end

    OpenUI("UIBoxReward", {rectTransform = com.transRoot, rewardID = r.rewardid, isShowBot = false})
end

function M:OnClick(go)
    local name = go.name

    if name == "BtnOnce" then
        self:OnClickOK(1)
    elseif name == "BtnTenTimes" then
        self:OnClickOK(10)
    elseif name == "ButtonWheel" then
        self:OnClickOK(1)
    elseif name == "BtnAdd" then
        local openid, index = BusinessData.GetLinkOpenID(self.tab.id)
        if openid > 0 then
            OpenUI("UIBusinessActivity", {bid= openid})
        end
    end
end

local preUpdateTime = -999
function M:Update()
    base.Update(self)

    TT.UpdateTable()

    if Time.time - preUpdateTime < 0.3 then
		return
	end
	preUpdateTime = Time.time

    if not self.endTime then
        return
    end
    local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
	self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
        if msg.cmd == Cmds.GetBusinessActivityInfo.index then
            self:ResetData()
        elseif msg.cmd == Cmds.GetBusinessReward.index then
            if msg.pb and #msg.pb.list > 0 then
                businesspb = msg.pb.list[1]
				self:StartRotate(businesspb.reward)
			end
		end
    elseif cmd == LocalCmds.Bag then
        self:ResetData()
    end
end

function M:End()
	if endCallback then
		local _endCallback = endCallback
		endCallback = nil
		_endCallback()
    end
    
    if businesspb then
        OpenUI("UIRewardPreview", {items = businesspb.itemlist})
        self:ResetData()
    end
    businesspb = nil
end

function M:AnimationEnd()
	self.startTime = -1
	self:End()
	self:ResetData()
end

function M:Hide()
	self:End()

	base.Hide(self)
end

function M:OnClickOK(num)
	if self.startTime and self.startTime > 0 then
		Tips("转盘运转中")
		return
	end

    local cost = {}
    cost.itemid = self.costItem.itemid
    cost.num = num * self.costItem.num
	if not dataMgr.PlayerData.CheckItemsNum({cost}, true, false) then
		return
	end
	
	self.script:SendLot(num)
end

function M:StartRotate(index)
    local index = index
	self.startTime = Time.time
	TT.Start(Time.time, index)
end

local CreateTable = function(len)
	
local ConstDuration = 4	-- 进入最终选时间
local ConstSlowTime = 3	-- 变慢时间
local ConstLen = len
local PerAngle = 360 / ConstLen			-- 每一个物品占的角度
local HalfPerAngle = PerAngle / 2		-- 半个角度
local AngleOffset = HalfPerAngle - 2	-- 最终点位置偏移值

local passTime = 0
local speed = 720
local offset = 0
local curAngles = 0
local curAngleZ = 0
local nextToIndex = 0

local transPointer = nil
local startTime = 0
local targetAngle = 0
local endCallback= nil
local angleEventCallback = nil
local angleEventAngle = nil
local angleEventPre = 0

local ct = {}
ct.Init = function(_transPointer, _endCallback)
    transPointer = _transPointer
    endCallback = _endCallback
end

ct.AddAngleEvent = function(angle, callback)
    angleEventAngle = angle
    angleEventCallback = callback
end

ct.Reset = function()
    startTime = -1
    targetAngle = -1
    angleEventPre = 0
end

ct.Start = function(tim, index)
    ct.Reset()
    startTime = tim
    targetAngle = -1 * PerAngle * (index-1)
    local lesshalf = HalfPerAngle-2
    targetAngle = targetAngle + math.random(-1 * lesshalf, lesshalf)
end

ct.UpdateTable = function()
    if startTime < 0  then
        return
    end

    passTime = Time.time - startTime
    if passTime < ConstDuration then
        if passTime < 1 then
            speed = passTime * 1000
        elseif passTime < ConstSlowTime then
            speed = 1000
        else
            speed = Mathf.Max(70, (ConstDuration - passTime) * 1000)
        end
    end

    curAngles = transPointer.localEulerAngles + Vector3.New(0,0, -1 * Time.deltaTime * speed)
    transPointer.localEulerAngles = curAngles
    if angleEventAngle and angleEventAngle > 0 and math.abs(curAngles.z - angleEventPre) > angleEventAngle then
        angleEventPre = curAngles.z
        if angleEventCallback then
            angleEventCallback(curAngles.z)
        end
    end
    
    if passTime > ConstDuration then
        offset = targetAngle - transPointer.localEulerAngles.z
        offset = offset % 360
        offset = (offset + 360) % 360
        if offset < 5 then
            startTime = -1
            if endCallback then
                endCallback()
            end
        end
    end
end

return ct
end

TT = CreateTable(ConstLen)

return M