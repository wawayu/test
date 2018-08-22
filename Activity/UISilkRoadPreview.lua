local PlayerData   = dataMgr.PlayerData
local ActivityData   = dataMgr.ActivityData
local FriendData   = dataMgr.FriendData

local SilkRoadsTable = excelLoader.SilkRoadsTable
local SettingTable = excelLoader.SettingTable
local ItemTable = excelLoader.ItemTable

local base         = require "UI.UILuaBase"
local M            = base:Extend()

--M.needPlayShowSE = true

--[丝绸之路——提交道具、求助]

local panelType = 2
function M.Open(args)
    uiMgr.ShowAsync("UISilkRoadPreview")
end

function M:Awake()
	base.Awake(self)
    self.offsetGameObject = self:FindGameObject("Offset")
    --道具界面
    self.uiItemPanel = self:FindGameObject("Offset/ItemPanel")
    
    --求助界面
    self.itemSelect = self:FindTransform("Offset/HelpPanel/NeedItem/Scroll View/Viewport/ImgSelect")
    self.uiHelpPanel = self:FindGameObject("Offset/HelpPanel")

	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)

    -- --提交道具
    -- self.uiLoop = self:FindGameObject("Offset/Scroll View/Viewport/Content"):GetComponent(typeof(UILoop))
    -- self:BindLoopEventEx(self.uiLoop, M.OnCreateEquip, M.UpdateEquip, M.OnChooseEquip)
    -- self.itemSelect = self:FindTransform("Offset/Scroll View/Viewport/Content/ItemSelect")
    -- self.itemSelect.gameObject:SetActive(false)

    --求助好友
    self.uiFriendLoop = self:FindGameObject("Offset/HelpPanel/FriendInfo/Scroll View/Viewport/Content"):GetComponent(typeof(UILoop))
    self:BindLoopEventEx(self.uiFriendLoop, M.OnCreateHelpFriend, M.UpdateHelpFriend, M.OnChooseHelpFriend)
    --求助道具
    self.uiItemLoop = self:FindGameObject("Offset/HelpPanel/NeedItem/Scroll View/Viewport/Content"):GetComponent(typeof(UILoop))
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateHelpItem, M.UpdateHelpItem, M.OnChooseHelpItem)

    panelType = 2
end

function M:Show()
    base.Show(self)

    self:TweenOpen(self.offsetGameObject)

    self.chooseItemIndex = 1
    self:ShowPanel()
end

function M:OnClick(go)
    local goname = go.name
    if goname == "ButtonClose" then
        self:Hide()
    elseif goname == "BtnHelp" then
        --求助
        if self.selectFriends and #self.selectFriends > 0 and self.helpFriendList then
            local silkRoadGood = self.onlineSilkGoodsList[self.chooseItemIndex]
            if silkRoadGood then
                local selectFriendGuidList = {}
                for k,v in pairs(self.selectFriends) do
                    local friendInfo = self.helpFriendList[v]
                    if friendInfo then
                        ActivityData.SendSilkRoadHelp(silkRoadGood.id, Const.CHAT_CHANNEL_PER, friendInfo)

                        table.insert(selectFriendGuidList, friendInfo.guid)
                    end
                end

                ActivityData.WriteFriendHelpLocalConfig(silkRoadGood.id, selectFriendGuidList)
            end
        else
            Tips("请选择好友")
        end
    end
end

function M:ShowPanel()
    if panelType == 1 then
        --提交道具
        self.uiItemPanel:SetActive(true)
        --这种类型的所有装备
        self.uiLoop.ItemsCount = PlayerData.Get()
        self.uiLoop:ScrollToGlobalIndex(0)
    elseif panelType == 2 then
        --求助好友
        self.uiHelpPanel:SetActive(true)
        self.uiItemPanel:SetActive(false)
        --道具
        self.onlineSilkGoodsList = ActivityData.GetNeedHelpItemList()
        self.uiItemLoop.ItemsCount = #self.onlineSilkGoodsList
        --好友
        self:RefreshFriendPanel(self.chooseItemIndex)
    end
end

------------------求助界面

--求道具
function M:OnCreateHelpItem(index, coms)
    coms.txtName = self:FindText("TxtName", coms.trans)
    coms.txtCount = self:FindText("TxtCount", coms.trans)

    coms.transItemRoot = self:FindTransform("ItemData", coms.trans)
end

function M:OnChooseHelpItem(index, coms)
    self:SetSelectActive(coms.trans, true)
    self.chooseItemGo = coms
    if self.chooseItemIndex == index then
        return
    end
    self.chooseItemIndex = index

    self:RefreshFriendPanel(index)
end

function M:RefreshFriendPanel(index)
    --刷新好友列表
    local silkRoadGood = self.onlineSilkGoodsList[index]
    if silkRoadGood then
        self.selectFriends = nil
        --求助过的好友
        self.localSilkItemList = ActivityData.ReadFriendHelpLocalConfig(silkRoadGood.id)
        -- PrintTable(self.localSilkItemList)
        self.helpFriendList = FriendData.GetFriendList(nil, true)
        if self.helpFriendList then
            self.uiFriendLoop.ItemsCount = #self.helpFriendList
        end
    end
end

function M:UpdateHelpItem(index, coms)
    local silkRoadGood = self.onlineSilkGoodsList[index]
    if silkRoadGood then
        local id = silkRoadGood.id
        local showItem = ActivityData.GetSilkRoadShowItem(id)
        local cfgShowItem = ItemTable[showItem.itemid]

        coms.comTable = coms.comTable or {}
        if coms.comTable.transRoot == nil then
            coms.comTable.transRoot = coms.transItemRoot
        end
        ActivityData.SetSilkItemInfo(coms.comTable, id)
        
        --名称，修炼经验
        coms.txtName.text = cfgShowItem.name
        coms.txtCount.text = ActivityData.CalSilkRoadRewardNum(id)
    end

    if self.chooseItemIndex == index then
        self:SetSelectActive(coms.trans, true)
    elseif self.chooseItemGo == coms then
        self:SetSelectActive(coms.trans, false)
    end
end

function M:SetSelectActive(parent, active)
    self.itemSelect.gameObject:SetActive(active)
    if active == true then    
        UITools.AddChild(parent.gameObject, self.itemSelect.gameObject, false)
        self.itemSelect.anchoredPosition3D = Vector3.zero
         self.itemSelect:SetSiblingIndex(0)
    end
end

--------------好友

function M:OnCreateHelpFriend(index, coms)
    coms.txtName = self:FindText("TxtName", coms.trans)
    coms.txtValue = self:FindText("TxtCount", coms.trans)
    coms.txtStatus = self:FindText("TxtCount/TxtStatus", coms.trans)
    coms.imgHead = self:FindImage("ImgBg/ImgIcon", coms.trans)
    coms.uiSelect = self:FindGameObject("ImgSelect ", coms.trans)
    coms.uiHelp = self:FindGameObject("ImgHelp", coms.trans)

    coms.txtLv = self:FindText("LvBg/TxtLv", coms.trans)
end

function M:OnChooseHelpFriend(index, coms)
    self.chooseFriendIndex = index
    
    if not self:IsFriendSelectedByIndex(index) then
        table.insert(self.selectFriends, index)
        coms.uiSelect:SetActive(true)
    end
end

function M:UpdateHelpFriend(index, coms)
    --好友
    local friendInfo = self.helpFriendList[index]
    if friendInfo then
        --名字，等级
        coms.txtName.text = friendInfo.name
        coms.txtLv.text = friendInfo.lv
        --好感度
        coms.txtValue.text = friendInfo.intimacy
        --友好值
        coms.txtStatus.text = "友好"
        --头像
        -- local tableID, unitTab, idType = unitMgr.UnpackUnitGuid(friendInfo.guid)
		-- if idType == Const.ID_TYPE_CHARACTER then
		-- 	uiMgr.SetSpriteAsync(coms.imgHead, Const.atlasName.PhotoIcon, unitTab.icon)
        -- end
        
        UITools.SetPlayerIcon(coms.imgHead, friendInfo)

        --是否已经选中
        if self:IsFriendSelectedByIndex(index) then
            coms.uiSelect:SetActive(true)
        else
            coms.uiSelect:SetActive(false)
        end
        --是否已经请求过帮助
        if self:IfFriendHelpThisItem(friendInfo.guid) then
            coms.uiHelp:SetActive(true)
        else
            coms.uiHelp:SetActive(false)
        end
    end
end

--该好友是否已经求助过
function M:IfFriendHelpThisItem(guid)
    --{ itemid = itemid, friendList = friendList }
    if self.localSilkItemList then
        for k,v in pairs(self.localSilkItemList.friendList) do
            if v == guid then
                return true
            end
        end
    end
    return false
end

--该好友是否已经选中
function M:IsFriendSelectedByIndex(index)
    if not self.selectFriends then
        self.selectFriends = {}
    end
    for k,v in ipairs(self.selectFriends) do
        if v == index then
            return true
        end
    end
    return false
end

return M