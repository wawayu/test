local PlayerData   = dataMgr.PlayerData
local ActivityData   = dataMgr.ActivityData

local SilkRoadsTable = excelLoader.SilkRoadsTable
local SettingTable = excelLoader.SettingTable
local ItemTable = excelLoader.ItemTable

local base         = require "UI.UILuaBase"
local M            = base:Extend()

--M.needPlayShowSE = true

--[丝绸之路]

local chatItemInfo = nil
function M.Open(args)
    chatItemInfo = args
    uiMgr.ShowAsync("UISilkRoad")
end

function M:Awake()
	base.Awake(self)

    self.offsetGameObject = self:FindGameObject("Offset")

    --等待界面
    self.uiWaitPanel = self:FindGameObject("Offset/WaitPanel")
	self.txtDescTop = self:FindText("Offset/WaitPanel/Top/TxtDescTop")
    self.txtDescButtom = self:FindText("Offset/WaitPanel/Buttom/StateRoot/TxtDescButtom")
    self.txtWord = self:FindText("Offset/WaitPanel/Top/ImgBg/TxtDesc")
    self.txtCountDown = self:FindText("Offset/WaitPanel/Top/ImgBg/TxtCountDown")
    self.uiBtnUpload = self:FindGameObject("Offset/WaitPanel/Buttom/StateRoot/BtnUpload")
    self.tranNeedItem = self:FindTransform("Offset/WaitPanel/Buttom/ScrollView/Viewport/Grid/Item")

    --装货界面
    self.uiCollectPanel = self:FindGameObject("Offset/CollectPanel")
    --上
    self.txtCollectDesc = self:FindText("Offset/CollectPanel/Middle/TopInfo/LeftTime/TxtDesc")
    self.uiCountDown = self:FindGameObject("Offset/CollectPanel/Middle/TopInfo/LeftTime/ImgBg")
    self.txtCollectCountDown = self:FindText("Offset/CollectPanel/Middle/TopInfo/LeftTime/ImgBg/TxtLeft")
    self.txtCollectHelpNum = self:FindText("Offset/CollectPanel/Middle/TopInfo/LeftCount")
    --货物信息
    self.transItemRoot = self:FindTransform("Offset/CollectPanel/Right/InfoRoot/ItemData")
    self.txtCollectRewardNum = self:FindText("Offset/CollectPanel/Right/InfoRoot/RewardRoot/TxtItemName/ImgIcon/TxtNum")
    self.uiItemNum = self:FindGameObject("Offset/CollectPanel/Right/InfoRoot/ItemData/TextNum")
    
    --装货按钮
    self.btnReady = self:FindButton("Offset/CollectPanel/Right/InfoRoot/BtnReady")
    self.imgReady = self:FindImage("Offset/CollectPanel/Right/InfoRoot/BtnReady")
    self.uiAlreadyGoods = self:FindGameObject("Offset/CollectPanel/Right/InfoRoot/Already")
    --按钮
    self.uiBtnRoot = self:FindGameObject("Offset/CollectPanel/Right/InfoRoot/Buttons")
    self.btnGuild = self:FindButton("Offset/CollectPanel/Right/InfoRoot/Buttons/BtnGuild")
    self.imgGuild = self:FindImage("Offset/CollectPanel/Right/InfoRoot/Buttons/BtnGuild")
    self.btnFriend = self:FindButton("Offset/CollectPanel/Right/InfoRoot/Buttons/BtnFriend")
    self.imgFriend = self:FindImage("Offset/CollectPanel/Right/InfoRoot/Buttons/BtnFriend")
    --奖励
    self.uiRewardPanel = self:FindGameObject("Offset/CollectPanel/Right/RewardRoot/Reward")
    self.uiBtnGo = self:FindGameObject("Offset/CollectPanel/Right/RewardRoot/Reward/BtnGo")
    self.transRewardItem = self:FindTransform("Offset/CollectPanel/Right/RewardRoot/Reward/RewardList/Viewport/Grid/Item")

    self.tranItemSelect = self:FindTransform("Offset/CollectPanel/Middle/ScrollView/Viewport/ImgSelect")

	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
    --ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

    --需要道具
    self.uiItemLoop = self:FindLoop("Offset/CollectPanel/Middle/ScrollView/Viewport/Content")
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem, M.OnChooseItem)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
        if msg.cmd == Cmds.HelpOtherLoadGoods.index then
            --帮人装货
            self.btnReady.gameObject:SetActive(false)
            self.uiAlreadyGoods:SetActive(true)
        elseif msg == "SendSilkRoadHelp" then
            self:ShowPanel()
        else
            if msg.cmd == Cmds.LoadGoods.index then
                self:AutoSelectIndex()
            end

            self:ShowPanel()
        end
    elseif cmd == LocalCmds.Bag then
        self:ShowPanel()
    end
end

function M:Show()
    base.Show(self)
    self:TweenOpen(self.offsetGameObject)

    self.curSelectIndex = 1

    self:AutoSelectIndex()

    self:ShowPanel()
end

function M:AutoSelectIndex()
    --自动选中第一个可装货的物品
    local itemList = ActivityData.GetCurSilkRoadItemList()
    if itemList then
        for i, v in ipairs(itemList) do
            if not v.status and ActivityData.IsSilkItemEnough(v.id) then
                self.curSelectIndex = i
            end
        end
    end
end

function M:CheckItemEnough(silkID, func)
    local items = ActivityData.GetSilkActualItems(silkID)
    if items then
        local isEnough = dataMgr.PlayerData.CheckItemsNum(items, false, false)
        if isEnough then
            func()
        else
            local showItem, isCooking = ActivityData.GetSilkRoadShowItem(silkID)
            if not showItem then
                return
            end
            if isCooking then
                Tips(string.format("物品不足，缺少%s", UITools.FormatItemColorName(showItem.itemid)))
                quickGetMgr.Goto(showItem.itemid)
            else
                dataMgr.PlayerData.CheckItemsNum({showItem}, true, true)
            end
        end
    end
end

function M:OnClick(go)
    local goname = go.name
    if goname == "ButtonClose" then
        self:Hide()
    elseif goname == "BtnUpload" then
        --开始装货
        ActivityData.RequestStartSilkRoad()
    elseif goname == "BtnReady" then
        --装货
        if self:IsHelpOther() then
            --帮人装货
            local func = function()
                ActivityData.RequestHelpOtherLoadGoods(chatItemInfo.target, chatItemInfo.id, chatItemInfo.channel, chatItemInfo.name, chatItemInfo.info.timeout)
            end
            self:CheckItemEnough(chatItemInfo.id, func)
        else
            --自己装货
            local silkRoadGood = self.itemList[self.curSelectIndex]
            if silkRoadGood then
                local func = function()
                    ActivityData.RequestLoadGoods(silkRoadGood.id)
                end
                self:CheckItemEnough(silkRoadGood.id, func)
            end
        end
    elseif goname == "BtnFriend" then
        --好友求助，打开好友选择界面
        local count = ActivityData.GetLoadGoodCount()
        if count >= 5 then
            self:GetHelp(Const.CHAT_CHANNEL_PER)
        else
            Tips("需装满5个货物以上方可求助！")
        end
    elseif goname == "BtnGuild" then
        --帮会求助
        local count = ActivityData.GetLoadGoodCount()
        if count >= 5 then
            self:GetHelp(Const.CHAT_CHANNEL_GUILD)
        else
            Tips("需装满5个货物以上方可求助！")
        end
    elseif goname == "BtnGetWay" then
        --获取途径
        local silkRoadGood = self.itemList[self.curSelectIndex]
        if silkRoadGood then
            local showItem, isCooking = ActivityData.GetSilkRoadShowItem(silkRoadGood.id)
            if showItem then
                quickGetMgr.Goto(showItem.itemid)
            end
        end
    elseif goname == "BtnGo" then
        --出发
        if ActivityData.IfCanGo() then
            ActivityData.RequestFinishSilkRoad()
        end
    end
end

--求助
function M:GetHelp(_channel)
    if not self:IsHelpOther() then
        local silkRoadGood = self.itemList[self.curSelectIndex]
        if silkRoadGood then
             if ActivityData.GetSilkHelpCount() >= 2 then
                Tips("次数已满，没法求助")
                return
            end

            if _channel == Const.CHAT_CHANNEL_GUILD then
                --非帮派成员无法发送求助
                if not require("Data.GuildData").GetGuildInfo() then
                    Tips("你还没有加入军团")
                    return
                end
                if not UITools.CanPressButton(string.format("silkRoad_%d_%d", silkRoadGood.id, _channel), 60) then
                    return
                end
                ActivityData.SendSilkRoadHelp(silkRoadGood.id, _channel)
            elseif _channel == Const.CHAT_CHANNEL_PER then
                --好友  
                if #dataMgr.FriendData.GetFriendList(nil, true) > 0 then
                    if not UITools.CanPressButton(string.format("silkRoad_%d_%d", silkRoadGood.id, _channel), 60) then
                        return
                    end
                    OpenUI("UISilkRoadPreview")
                else
                    Tips("没有好友，或好友未上线")
                    return
                end
            end
        end
    end
end

function M:ShowPanel()
    local panelType = 1
    if self.IsHelpOther() or (ActivityData.IsSilkRoadOpen() and not ActivityData.IsSilkRoadFinished() and not ActivityData.IsSilkRoadTimeout())then
        --聊天入口打开，或者已经开始装货、还没结束、未超时
        panelType = 2
    else
        --未装货
        panelType = 1
    end
    
    if panelType == 1 then
        --等待界面
        self.uiWaitPanel:SetActive(true)
        self.uiCollectPanel:SetActive(false)

        self:RefreshWaitPanel()
    elseif panelType == 2 then
        --装货界面
        self.uiWaitPanel:SetActive(false)
        self.uiCollectPanel:SetActive(true)
        
        self:RefreshAllPanel()
    end
end

function M:Hide()
    base.Hide(self)

    chatItemInfo = nil
end

----------------------------------------------等待界面

function M:RefreshWaitPanel()
    -- print("RefreshWaitPanel")
    if not self.IsHelpOther() and not ActivityData.IsSilkRoadOpen() then
        --丝绸之路未接取
        if not ActivityData.IsSilkRoadFinished() then
            -- print("aaaaaaaaaaaaaaaaaaaaaa")
            --未完成
            self.txtDescTop.text = "商队已到达，可以开始装货"

            self.txtWord.gameObject:SetActive(true)
            self.txtWord.text = Lan("activity_silkroad_word")

            --隐藏倒计时
            self.txtCountDown.gameObject:SetActive(false)

            self.txtDescButtom.gameObject:SetActive(true)
            self.txtDescButtom.text = "请在十小时内完成"

            --开始装货按钮
            self.uiBtnUpload:SetActive(true)
        else
            -- print("bbbbbbbbbbbbbbbbbbbbbbb")
            --已完成
            self.txtDescTop.text = "下一班商队还需等待:"

            self.txtWord.gameObject:SetActive(false)

            --开启倒计时。倒计时时间都多5s
            self.txtCountDown.gameObject:SetActive(true)
            self:OnCountDown(self.txtCountDown, 
                function()
                    ActivityData.SilkRoadRestart()
					-- self:RefreshWaitPanel()
				end, 
                ActivityData.GetNextSilkRoadTime() + 5)

            self.txtDescButtom.gameObject:SetActive(false)
            self.uiBtnUpload:SetActive(false)
        end

        --货物
        local itemList = ActivityData.GetCurSilkRoadItemList()
        if itemList then
            if self.waitRewardGoList == nil then self.waitRewardGoList = {} end
            UITools.CopyRewardListWithItems(self:GetRewardList(itemList), self.waitRewardGoList, self.tranNeedItem)
        end
    end
end

function M:GetRewardList(itemInfoList)
    local rewardItems = {}
    if itemInfoList then
        for k,v in ipairs(itemInfoList) do
            local showItem = ActivityData.GetSilkRoadShowItem(v.id)
            if showItem then
                table.insert(rewardItems, showItem)
            end
        end
    end
    return rewardItems
end

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

---------------------------------装货界面
M.ItemPos = {{-62, 110}, {4, 80}}   --左上角，当中

function M:RefreshAllPanel()
    self.itemList = ActivityData.GetCurSilkRoadItemList()
    if self:IsHelpOther() then
        --帮助装货
        self.itemList = chatItemInfo.info.goods

        self.transItemRoot.anchoredPosition3D = Vector3.New(M.ItemPos[1][1], M.ItemPos[1][2])
    end
    
    self.transItemRoot.anchoredPosition3D = Vector3.New(M.ItemPos[2][1], M.ItemPos[2][2])

    self:RefreshItemPanel()
    self:RefreshInfoPanel()
    self:RefreshTopPanel()
end

function M:RefreshItemPanel()
    self.uiItemLoop.ItemsCount = #self.itemList
end

function M:RefreshTopPanel()
    if not self:IsHelpOther() then
        --还剩多久结束
        self.uiCountDown:SetActive(true)
        local timeout = ActivityData.GetSilkTimeOut() + 5
        -- print(netMgr.mainClient:GetServerTime(), timeout)
        local delta = timeout - netMgr.mainClient:GetServerTime()
        if delta > 0 then
            self:OnCountDown(self.txtCollectCountDown, function()
                -- self:RefreshWaitPanel()
                ActivityData.SilkRoadRestart()
            end, delta)
        end

        self.txtCollectHelpNum.gameObject:SetActive(true)
        self.txtCollectHelpNum.text = string.format("求助次数：   %d/2", ActivityData.GetSilkHelpCount())
    else
        self.uiCountDown:SetActive(false)
        self.txtCollectHelpNum.gameObject:SetActive(false)
    end
end

function M:RefreshInfoPanel()
    local silkRoadGood = nil
    if self:IsHelpOther() then
        silkRoadGood = ActivityData.GetSilkInfoById(chatItemInfo.id, chatItemInfo.info)
    else
        silkRoadGood = self.itemList[self.curSelectIndex]
    end
    if not silkRoadGood then
        return
    end
        
    local silkTab = SilkRoadsTable[silkRoadGood.id]
    if not silkTab then
        return
    end
       
    --货物
    self.comTable = self.comTable or {}
    if self.comTable.transRoot == nil then
        self.comTable.transRoot = self.transItemRoot
    end

    ActivityData.SetSilkItemInfo(self.comTable, silkRoadGood.id)
    
    --装货奖励，修炼经验。silk_roads_rewardparam
    self.txtCollectRewardNum.text = ActivityData.CalSilkRoadRewardNum(silkRoadGood.id)

    if not self:IsHelpOther() then
        --按钮相关信息
        local loadNum = ActivityData.GetLoadGoodCount()
        --装货按钮
        local itemPost = nil
        if silkRoadGood.status == true then
            --已装货
            self.btnReady.gameObject:SetActive(false)
            self.uiAlreadyGoods:SetActive(true)
            self.uiBtnRoot:SetActive(false)
            itemPost = M.ItemPos[2]

            self.uiItemNum:SetActive(false)
        else
            --未装货
            self.btnReady.gameObject:SetActive(true)
            self.uiAlreadyGoods:SetActive(false)
            self.uiBtnRoot:SetActive(true)
            itemPost = M.ItemPos[1]

            self.uiItemNum:SetActive(true)
        end
        self.transItemRoot.anchoredPosition3D = Vector3.New(itemPost[1], itemPost[2])

        --出货奖励
        if ActivityData.IfCanGo() then
            self.uiBtnGo:SetActive(true)
        else
            self.uiBtnGo:SetActive(false)
        end
        --奖励
        self.uiRewardPanel:SetActive(true)
        if self.rewardGoList == nil then self.rewardGoList = {} end
        self.rewardExParams = self.rewardExParams or {isnative = false}
        UITools.CopyRewardList({SettingTable["silk_roads_completereward"]}, self.rewardGoList, self.transRewardItem, self.rewardExParams)
    else
        --帮人装货
        --奖励
        self.uiBtnRoot:SetActive(false)
        self.uiRewardPanel:SetActive(false)

        --装货按钮
        self.btnReady.enabled = true
        self.btnReady.gameObject:SetActive(true)
        self.uiAlreadyGoods:SetActive(false)

        --物品数量
        self.uiItemNum:SetActive(false)
    end
end

--道具
function M:OnCreateItem(index, coms)
    coms.txtName = self:FindText("TxtName", coms.trans)
    coms.txtCount = self:FindText("Bg/ImgIcon/TxtCount", coms.trans)
    coms.imgIcon = self:FindImage("Bg/ImgIcon", coms.trans)
    coms.imgState = self:FindImage("Bg/ImgStatus", coms.trans)
    coms.uiMask = self:FindGameObject("Bg/ImgMask", coms.trans)
    coms.uiHelp = self:FindGameObject("Bg/ImgHelp", coms.trans)

    coms.transSelectParent = self:FindTransform("Bg", coms.trans)
end

function M:OnChooseItem(index, coms)
    -- print("OnChooseItem")
    if not self:IsHelpOther() then
        self:SetSelectActive(coms.transSelectParent, true)
        self.chooseItemGo = coms
        if self.curSelectIndex == index then
            return
        end

        self.curSelectIndex = index
        self:RefreshInfoPanel()
    end
end

function M:SetSelectActive(parent, active)
    self.tranItemSelect.gameObject:SetActive(active)
    if active == true then    
        UITools.AddChild(parent.gameObject, self.tranItemSelect.gameObject, false)
        self.tranItemSelect.anchoredPosition3D = Vector3.zero
    end
end

function M:UpdateItem(index, coms)
    local silkRoadGood = self.itemList[index]
        
    --聊天入口需要显示遮罩
    local silkTab = SilkRoadsTable[silkRoadGood.id]
    if not silkTab then
        print("----index no silktab", index, silkRoadGood.id)
        return
    end
        
    if self:IsHelpOther() then
        --帮助装货
        if chatItemInfo.id == silkRoadGood.id then
            --需要帮助的道具
            coms.uiMask:SetActive(false)
        else
            coms.uiMask:SetActive(true)
        end
        self:SetSelectActive(coms.transSelectParent, false)
        coms.uiHelp:SetActive(false)
        coms.imgState.gameObject:SetActive(false)
    else
        --自己装货
        coms.uiMask:SetActive(false)
        coms.imgState.gameObject:SetActive(false)

        --是否已经求助过好友、帮派
        if ActivityData.IsGoodsCallHelp(silkRoadGood.id) then
            coms.uiHelp:SetActive(true)
        else
            coms.uiHelp:SetActive(false)
        end

        --状态
        if silkRoadGood.status == true then
            --已完成
            coms.imgState.gameObject:SetActive(true)
            coms.uiHelp:SetActive(false)
            UITools.SetImageIcon(coms.imgState, Const.atlasName.Common, "bq_ywc", true)
        elseif ActivityData.IsSilkItemEnough(silkRoadGood.id) then
            --未完成，但是物体足够，显示红点
            coms.imgState.gameObject:SetActive(true)
            UITools.SetImageIcon(coms.imgState, Const.atlasName.Common, "dian_red", true)
        else
            coms.imgState.gameObject:SetActive(false)
        end
    end

    local itemTb = ActivityData.GetSilkRoadShowItem(silkRoadGood.id)
    if itemTb then
         --名称、数量、图片、状态
        local cfgItem = ItemTable[itemTb.itemid]
        coms.txtName.text = cfgItem.name
        coms.txtCount.text = tostring(itemTb.num)
        uiMgr.SetSpriteAsync(coms.imgIcon , Const.atlasName.ItemIcon, cfgItem.icon)
    end
   
    if self.curSelectIndex == index then
        self:SetSelectActive(coms.transSelectParent, true)
    elseif self.curSelectIndex == coms then
        self:SetSelectActive(coms.transSelectParent, false)
    end
end

----@return:true标识帮助其他人装货
function M:IsHelpOther()
    if chatItemInfo and chatItemInfo.target then
        return true
    end
    return false
end

return M