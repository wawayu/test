--[[
 活动 - 护送、押镖
]]

local ActivityData = require "Data.ActivityData"
local TimeSync = require "TimeSync"
local base = require "UI.UILuaBase"
local M = base:Extend()
local ConvoyData = dataMgr.ActivityConvoyData

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true

local maxCarLength = 4
local carType = {"绿色镖车", "蓝色镖车", "紫色镖车", "橙色镖车"}

--M.test_data = 

function M.Open(params)
	if not activityMgr.IsActivityOpen(Const.ACTIVITY_ID_CONVOY) then
		Tips("活动未开放")
		return
	end

	CloseUI("UIActivity")
    uiMgr.ShowAsync("UIConvoy")
end

function M:Awake()
	base.Awake(self)

	self.offsetGameObject = self:FindGameObject("Offset")
    self.panel = self:FindTransform("Offset/Panel")

    self.prefabParent = self:FindTransform("Top/Content", self.panel)
    self.prefabs = {}
    self.rtTb = {}
    for i=1,maxCarLength do
        self.prefabs[i] = self:FindTransform(string.format("Item (%s)", i), self.prefabParent)
        self:OnCreateItem(i, self.prefabs[i].gameObject)
        self.rtTb[i] = self:LoadRenderTexture("CharRoot/CameraModel", "CharRoot/RawImage", "RT256_"..i, self.prefabs[i])
    end

	UITools.AddBtnsListenrList(self.offsetGameObject.transform, self, M.OnClick)

	local textBottomDesc = self:FindText("Offset/Panel/Bottom/Text")
	textBottomDesc.text = Lan("activity_convoy_desc")

	self.textCurCar = self:FindText("Offset/Panel/Top/TextCurCar")
	self.transOk = self:FindTransform("Offset/Panel/Bottom/ButtonOk")

	self.transCostOneKey = self:FindTransform("Offset/Panel/Bottom/OneKeyCost")

	--押镖次数
	self.escort = self:FindText("Offset/Panel/Bottom/EscortNum")
	--求助按钮
	self.btnSeek = self:FindGameObject("Offset/Panel/Bottom/ButtonSeek")

end

function M:Show()
	base.Show(self)
	self:TweenOpen(self.offsetGameObject)

	self.selectIndex = 1
	self:ResetInfo()
end

function M:ResetInfo()
	self.convoyInfo = ConvoyData.GetConvoyInfo()
	if self.convoyInfo == nil then
		self.panel.gameObject:SetActive(false)
		return
	end
	self.panel.gameObject:SetActive(true)

	if self.convoyInfo.id == 0 then self.convoyInfo.id = 1 end

	self.listCar = ConvoyData.GetCarList()
	self.selectIndex = self.convoyInfo.id

	--判断状态
	if self.convoyInfo.id == 4 then
		self.btnSeek:SetActive(true)
	else
		self.btnSeek:SetActive(false)
	end

	--剩余押镖次数
	local count = 2-self.convoyInfo.time
	if count <= 0 then
		count = 0
	end
	self.escort.text = string.format("今日剩余次数:<color=#18A338FF>%d次</color>",count) 
	for i,v in ipairs(self.listCar) do
		self:UpdateItem(i, self.prefabs[i].gameObject)
	end

	--置灰
	if self.convoyInfo.time >= 2 then
		UITools.SetImageGrey(self:FindImage("Offset/Panel/Bottom/ButtonOk"),true)
		UITools.SetImageGrey(self:FindImage("Offset/Panel/Bottom/ButtonRefresh"),true)
		UITools.SetImageGrey(self:FindImage("Offset/Panel/Bottom/ButtonOneKey"),true)
	else
		UITools.SetImageGrey(self:FindImage("Offset/Panel/Bottom/ButtonOk"),false)
		UITools.SetImageGrey(self:FindImage("Offset/Panel/Bottom/ButtonRefresh"),false)
		UITools.SetImageGrey(self:FindImage("Offset/Panel/Bottom/ButtonOneKey"),false)
	end

	--{itemid=170206,num=1}
	local costItem = excelLoader.SettingTable.convoy_refresh_expend
	self.comTable = self.comTable or {}
	self.comTable.transRoot = self.comTable.transRoot or self:FindTransform("Bottom/RefreshCost", self.panel)
	UITools.SetCommonItemCost(self.comTable, costItem, nil)
	
	local transRefresh =  self:FindTransform("Bottom/ButtonRefresh", self.panel)
	local textRefresh = self:FindText("Text", transRefresh)
	local remain = ConvoyData.GetRemainFreeNum()
	if remain > 0 then
		textRefresh.text = "免费"..remain.."次"
	else
		textRefresh.text = "刷新"
	end

	local curSelectItem = self:GetLoopItem(self.selectIndex)
	self.textCurCar.text = UITools.FormatStarName(curSelectItem.name, curSelectItem.quality)

	--local costItemStart = excelLoader.SettingTable.convoy_expend
	--self.comTableStart = self.comTableStart or {}
	--self.comTableStart.transRoot = self.comTableStart.transRoot or self:FindTransform("Bottom/StartCost", self.panel)
	--UITools.SetCommonItemCost(self.comTableStart, costItemStart, nil)

	self.costOneKey = excelLoader.SettingTable.convoy_refresh_oneclick.cost[1] or {}
	UITools.SetMoneyInfo(self.transCostOneKey.gameObject, self.costOneKey.itemid, self.costOneKey.num, "")
end

function M:OnCreateItem(index, go)
    
end

function M:GetLoopItem(index)
    return self.listCar[index]
end

function M:OnChooseItem(index, go)
	self.selectIndex = index
    if go == nil then go = self.prefabs[index].gameObject end
	self:ResetInfo()
end

local imageNames = {"yunbiao_bg1", "yunbiao_bg2","yunbiao_bg3","yunbiao_bg4",}

function M:UpdateItem(index, go)
    local etbData = self:GetLoopItem(index)

    local trans = go.transform

    local transModelParent = self:FindTransform("CharRoot/CameraModel/Model", trans)
    UITools.LoadModel(etbData.horseID, "UIConvoy"..etbData.horseID, transModelParent)
    
	local transSelect = self:FindTransform("ImgBg/ImageSelect", trans)
	transSelect.gameObject:SetActive(self.selectIndex == index)

	local textName = self:FindText("Name/Text", trans)
	textName.text = UITools.FormatStarName(etbData.name, etbData.quality)

	local textGet = self:FindText("TextGet", trans)
	textGet.text = "铜钱收益+"..etbData.money_percent.."%"
	local imageGet = self:FindImage("ImageGet", trans)
	UITools.SetImageIcon(imageGet, Const.atlasName.Yabiao, imageNames[index], false)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Convoy then
		if msg and msg.cmd then
			if msg.cmd == Cmds.ConvoyRefresh.index then
				Tips("刷新成功")
			end
		end
		self:ResetInfo()
	elseif cmd == LocalCmds.Bag then
		self:ResetInfo()
	end
end

--点击按钮
function M:OnClick(go)
	local name = go.name
	if name == "ButtonClose" then
		self:Hide()
	elseif name == "ButtonRefresh" then

		if self.convoyInfo.time >= 2 then
			Tips("今日押镖次数已用完！")
			return
		end
		
		local remain = ConvoyData.GetRemainFreeNum()
		if remain > 0 then
			self:SendRefresh()
		else
			local costItem = excelLoader.SettingTable.convoy_refresh_expend
			dataMgr.PlayerData.AutoExpendWithMoney({costItem}, "UIConvoy", function(moneyInstead)
            	self:SendRefresh()
        	end)
		end
	elseif name == "ButtonOk" then
		if self.convoyInfo.time >= 2 then
			Tips("今日押镖次数已用完！")
			return
		end
		--判断归队
		if dataMgr.TeamData.GetFollowMemberCount() < dataMgr.TeamData.GetTeamMemberCount()  then
			Tips("所有队伍成员必须归队！")
			return
		end

		--首先判断是否需要提示双倍
		self:IsInDoubleTime()
	elseif name == "ButtonTips" then
		Hint({rectTransform = go.transform, content = Lan("activity_convoy_tips"), alignment = 0})
	elseif name == "ButtonOneKey" then
		if self.convoyInfo.time >= 2 then
			Tips("今日押镖次数已用完！")
			return
		end
		
		if self.costOneKey and not dataMgr.PlayerData.CheckItemsNum({self.costOneKey}, true, true) then
			return
		end

		local car = ConvoyData.GetConvoyInfo()
		if car and car.id == 4 then
			Tips("鏢车已达最高等级")
			return
		end
		ConvoyData.SendOneKey()
	elseif name == "ButtonSeek" then
	--求助
		self:SendSeekInfo(Const.CHAT_CHANNEL_GUILD)
	end
end

function M:SendRefresh()
	local car = ConvoyData.GetConvoyInfo()
	if car and car.id == 4 then
		Tips("鏢车已达最高等级")
		return
	else
		ConvoyData.SendRefresh()
	end
end


--双倍时间
function M:IsInDoubleTime()
	local curTime = netMgr.mainClient:GetServerTime()
	local d = curTime - TimeSync.day_start(curTime)
	local st = excelLoader.SettingTable.convoy_doubletime
	local isInDouble = false
	if d>=st[1] and d<=st[2] then
		isInDouble = true
	end

	if not isInDouble then
		UIMsgbox.ShowChoose(Lan("convoy_not_double_time"), function(ok, param)
			if ok == true then              
				self:StartConvoy()
			end
		end, nil, "提示")
	else
		self:StartConvoy()
	end
end

--判断类型，开始押镖
function M:StartConvoy()
	-- if self.convoyInfo.id == 4 then
	-- 	--提示组队
	-- 	self:SendTeamHint()
	-- else
	-- 	--直接开始押镖
	-- 	ConvoyData.SendConvoyStart()
	-- 	if dataMgr.TeamData.IsMatching() then
	-- 		dataMgr.TeamData.RequestCancelMatchTeam()
	-- 	end

	-- end
	--8-14号改为不需要判断镖车等级组队
	self:SendTeamHint()
end

--提示
function M:SendTeamHint()
	UIMsgbox.ShowChoose("组队护送<color=#18A338>最多可获得20%奖励</color>加成哦！", function(ok, param)
		if ok == true then 
			--组队信息 
			self:SendSeekInfo()            
			ConvoyData.SendConvoyStart()
		end
	end, nil, "提示")
end

--判断队伍
function M:SendSeekInfo(chattype)
	--没有队伍创建队伍
	if not dataMgr.TeamData.GetCurrentTeamInfo() then
		dataMgr.TeamData.RequestCreateTeam(607,nil,function ()
			--自动征集
			dataMgr.TeamData.RequestMatchTeam(607)
			if chattype then
				--发送工会求助
				self:RecruitMember(chattype)
				require ("UI.Team.UITeam").Open({panelIndex = 1})
			end
			
		end)
	else		
		dataMgr.TeamData.RequestMatchTeam(607)
		if chattype then
			--发送工会求助
			self:RecruitMember(chattype)
			require ("UI.Team.UITeam").Open({panelIndex = 1})
		end

	end	
end

function M:RecruitMember(channel)

	--聊天频道
	local channel = channel or Const.CHAT_CHANNEL_GUILD
	local minLv = excelLoader.UITable.UIConvoy.needlv
	local leadName = dataMgr.TeamData.GetLeaderMemberInfo().name
	local leadGuid = dataMgr.TeamData.GetLeaderMemberInfo().guid
	local paramText = string.format("\"tp\":%d,\"guid\":\"%s\",\"minLevel\":%d,\"maxLevel\":%d", hyperlinkMgr.types.TeamRecruit,leadGuid,minLv,999)
		
	local hyperText = hyperlinkMgr.FormatHyperLink(paramText, "<color=#18A338>我要加入</color>")	
	local descText = string.format(Lan("convoy_groupseek"), leadName, minLv)
	local chatText = string.format("%s%s", descText, hyperText)
	dataMgr.ChatData.SendChat(channel, chatText, nil, false)

end



return M