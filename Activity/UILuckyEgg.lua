---幸运砸蛋

local PlayerData = dataMgr.PlayerData
local LuckyEggData = dataMgr.LuckyEggData

local SettingTable = excelLoader.SettingTable

local base = require "UI.UILuaBase"
local M = base:Extend()

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}

local EggCountMax = 8
local ShowEffectTime = 0.5

local eggImage = {
    "hdzd_zs03",--普通
    "hdzd_zs09",--彩蛋
}

local eggOpenImage = {
    "hdzd_zs04",--普通
    "hdzd_zs010",--彩蛋
}

function M.Open(param)
    if moduleMgr.IsModuleEntryShow(moduleMgr.moduleID.LuckyEgg) then
        M.closeTween = param and param.closeTween
        uiMgr.ShowAsync("UILuckyEgg")
    else
        Tips("活动暂未开始")
    end
end

function M:Awake()
    base.Awake(self)
    self.offset = self:FindGameObject("Offset")

    self.textLucky = self:FindText("Offset/PanelLucky/Text")
    self.imageLucky = self:FindImage("Offset/PanelLucky/Slider/Image")

    self.textTime = self:FindText("Offset/TextTime/Text")
    self.textLog = self:FindText("Offset/PanelLog/Viewport/Content")
    self.refreshCost = self:FindTransform("Offset/PanelRefresh/Cost")
    self.openAllCost = self:FindTransform("Offset/PanelAll/Cost")
    self.openOneCost = self:FindTransform("Offset/PanelEgg/Cost")

    self.imageItem1 = self:FindImage("Offset/Item1/ImageIcon")
    self.textNumItem1 = self:FindText("Offset/Item1/TextNum")

    self.imageItem2 = self:FindImage("Offset/Item2/ImageIcon")
    self.textNumItem2 = self:FindText("Offset/Item2/TextNum")
   
    self.rewareItem = self:FindTransform("Offset/PanelReward/Viewport/Grid/Item")

    self.eggComs = {}
    for i=1, EggCountMax do
        local trans = self:FindTransform(string.format("Offset/PanelEgg/Grid/ItemEgg (%d)", i))
        UguiLuaEvent.ButtonClick(trans.gameObject, self, function(go)
            self:OnClickEgg(i)
        end)
        self.eggComs[i] = self:GetEggComs(trans)
    end

    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonClose"), self, M.Hide)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/PanelRefresh/ButtonRefresh"), self, M.OnClickRefresh)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/PanelAll/ButtonAll"), self, M.OnClickAll)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/Item1/ButtonAdd"), self, M.OnClickRecharge)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonHelp"), self, M.OnClickHelp)
    UguiLuaEvent.ButtonClick(self.imageItem2.gameObject, nil, function(go)
        dataMgr.ItemData.ShowItemDetail(nil, excelLoader.ItemTable[Const.ITEM_ID_LUCKY_EGG_HAMMER], go.transform)
    end)
    self.rawImage = self:LoadRenderTexture("Offset/CameraModel", "Offset/RawImage", "RenderTexture1", nil, Color.New(0.125, 0.125, 0.125, 0))
    self.modelParent = self:FindTransform("Offset/CameraModel/Model")
    UITools.LoadModel(603, "model_lucky_egg", self.modelParent, function(unitBase)
    end)
end

function M:Show()
    base.Show(self)
    self.clickIndex = {}
    self.showResultEgg = {}
    LuckyEggData.RequestLuckyEggRecord()

    self.clickOpenTime = -1

    self:Refresh()
    self:TweenOpen(self.offset)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
        self:Refresh()
    end
end

function M:Update()
    if self.clickOpenTime > 0 then
        if (Time.realtimeSinceStartup - self.clickOpenTime) > ShowEffectTime then
            self.clickOpenTime = -1
            if self.openIndex then
                LuckyEggData.RequestOpenEgg(self.openIndex, 1)
            else
                LuckyEggData.RequestOpenEgg(nil, EggCountMax)
            end
        end
    end
end

function M:Refresh()
    self.requestOpenAll=false
    --奖励展示
    if self.rewardGoList == nil then self.rewardGoList = {} end
    UITools.CopyRewardList({LuckyEggData.GetShowRewardID()}, self.rewardGoList, self.rewareItem, {isnative=false, showQualityEffect=true})

    --幸运值
    local c, m = LuckyEggData.GetLuckyEggLuckyNum()
    self.textLucky.text = string.format("%d/%d", c, m)
    self.imageLucky.transform.localScale = Vector3.New(1, c/m, 1)

    local endtime = LuckyEggData.GetLuckyEggEndTime()
    local lefttime = math.max(0, endtime - netMgr.mainClient:GetServerTime())
    --剩余时间
    local tween = TweenText.Begin(self.textTime, lefttime, 0, lefttime, 0)
    tween.isTime = true
    --全服记录
    self.textLog.text = LuckyEggData.FormatLuckyEggLog()

    --刷新消耗
    local refreshExpend = LuckyEggData.GetLuckyEggRefreshExpend()
    if refreshExpend then
        UITools.SetActive(self.refreshCost, true)
        UITools.SetMoneyInfo(self.refreshCost, refreshExpend[1].itemid, refreshExpend[1].num, "", true)
    else
        UITools.SetActive(self.refreshCost, false)        
    end

    --全部砸开消耗
    local openAllExpend = LuckyEggData.GetLuckyEggOpenAllExpend()
    UITools.SetMoneyInfo(self.openAllCost, openAllExpend.itemid, openAllExpend.num, "", false)

    --单个消耗
    local openOneExpend = SettingTable.xyzd_expend[2]
    UITools.SetMoneyInfo(self.openOneCost, openOneExpend.itemid, openOneExpend.num, "", true)--单个消耗

    UITools.SetItemIcon(self.imageItem1, Const.ITEM_ID_VCOIN, false)--元宝
    UITools.SetItemIcon(self.imageItem2, Const.ITEM_ID_LUCKY_EGG_HAMMER, false)--锤子
    self.textNumItem1.text = PlayerData.GetItemCount(Const.ITEM_ID_VCOIN, Const.ITEM_FLAG_CURRENCY)
    self.textNumItem2.text = PlayerData.GetItemCount(Const.ITEM_ID_LUCKY_EGG_HAMMER)
    local items = {}
    for i=1, EggCountMax do
        if self.clickIndex[i] then
            local itemInfo = LuckyEggData.GetLuckyEggItemInfo(i)
            if itemInfo then
                table.insert(items, itemInfo)
            end
        end
        self:SetEggInfo(i)        
    end
    if #items > 0 then
        OpenUI("UIRewardPreview", {items=items})    
    end
    self.clickIndex = {}

    if LuckyEggData.GetLeftEggCount() == 0 then
        LuckyEggData.RequestRefreshLuckyEgg(false)
    end
end


---全部砸开
function M:OnClickAll(go)
    if not dataMgr.PlayerData.NeedBagSize(1, true) then
        return
    end
    local expend = LuckyEggData.GetLuckyEggOpenAllExpend()
    UIMsgbox.ShowChooseWithNotShow(string.format("是否消耗%s%d全部砸开?", UITools.FormatItemIconText(expend.itemid), expend.num), function(ok, param)
        if ok == true then			   
            if dataMgr.PlayerData.CheckItemsNum({expend}, true, true) then
                self.openIndex = nil
                for i=1, EggCountMax do
                    self:ShowOpenEggAnimation(i, true)
                end        
            end
        end
    end, nil, "提示", "uiluckyegg_openall")
end

function M.ManualRefreshEgg()
    local expend = LuckyEggData.GetLuckyEggRefreshExpend()
    if expend then
        UIMsgbox.ShowChooseWithNotShow(string.format("是否消耗%s%d刷新?", UITools.FormatItemIconText(expend[1].itemid), expend[1].num), function(ok, param)
			if ok == true then			
				LuckyEggData.RequestRefreshLuckyEgg(true)
			end
		end, nil, "提示", "uiluckyegg_refresh")
    else
        LuckyEggData.RequestRefreshLuckyEgg(true)
    end
end

---刷新
function M:OnClickRefresh(go)
    if LuckyEggData.IsHaveSpecialEggNotOpen() then
        UIMsgbox.ShowChoose("还有彩蛋未砸开,是否继续刷新?", function(ok, param)
			if ok == true then			
				self:ManualRefreshEgg()
			end
        end, nil, "提示")
    else
        self:ManualRefreshEgg()
    end
end

---充值
function M:OnClickRecharge(go)
    OpenUI("UIRecharge")
end

---说明
function M:OnClickHelp(go)
    Hint({rectTransform = go.transform, content = Lan("rule_lucky_egg"), alignment = 0, preferredWidth=460})
end

function M:GetEggComs(trans) 
    local coms = {}
    coms.trans = trans
    coms.imageEgg = self:FindImage("ImageEgg", trans)
    coms.imageEggOpen = self:FindImage("ImageEggOpen", trans)
    coms.itemTrans = self:FindTransform("Item", trans)
    return coms
end

function M:OnClickEgg(index)
    if not dataMgr.PlayerData.NeedBagSize(1, true) then
        return
    end
    local expend, tp = LuckyEggData.GetLuckyEggOpenOneExpend()
    UIMsgbox.ShowChooseWithNotShow(string.format("是否消耗%s%d砸蛋?", UITools.FormatItemIconText(expend.itemid), expend.num), function(ok, param)
        if ok == true then		
            if dataMgr.PlayerData.CheckItemsNum({expend}, true, true) then
                self:ShowOpenEggAnimation(index, false)
            end
        end
    end, nil, "提示", "uiluckyegg_clickone")
end

function M:ShowOpenEggAnimation(index, isAll)
    if LuckyEggData.GetLuckyEggItemInfo(index) or self.clickIndex[index] then
        return
    end
    effectMgr:SpawnToUI("2d_lucky_egg", Vector3.zero, self.eggComs[index].trans, 0)
    TweenAlpha.Begin(self.eggComs[index].imageEgg.gameObject, 1, 0, 0.2, 0.3)
    TweenAlpha.Begin(self.eggComs[index].imageEggOpen.gameObject, 0, 1, 0, 0.3)
    if not isAll then
        self.openIndex = index
    end
    self.clickIndex[index]=true
    self.clickOpenTime = Time.realtimeSinceStartup
end

function M:SetEggInfo(index)
    local itemInfo = LuckyEggData.GetLuckEggRecord(index)   
    if itemInfo and itemInfo.num > 0 then
        UITools.SetActive(self.eggComs[index].imageEgg, false)       
        UITools.SetActive(self.eggComs[index].imageEggOpen, true)   
        UITools.SetActive(self.eggComs[index].itemTrans, true)             
        local itemTrans = self.eggComs[index].itemTrans
        UITools.SetItemInfo(itemTrans, itemInfo, false, true)
        UguiLuaEvent.ButtonClick(itemTrans.gameObject, nil, function(go)
            dataMgr.ItemData.ShowItemDetail(itemInfo, nil, go.transform)
        end)
        UITools.SetImageIcon(self.eggComs[index].imageEggOpen, Const.atlasName.LuckyEgg, eggOpenImage[itemInfo.flag])  
      
    else
        UITools.SetActive(self.eggComs[index].imageEgg, true)       
        UITools.SetActive(self.eggComs[index].imageEggOpen, false)   
        UITools.SetActive(self.eggComs[index].itemTrans, false) 
        UITools.SetImageIcon(self.eggComs[index].imageEgg, Const.atlasName.LuckyEgg, eggImage[itemInfo.flag])  
        TweenAlpha.Begin(self.eggComs[index].imageEgg.gameObject, 0, 1, 0.1, 0)
        self.clickIndex[index]=false 
    end
end

return M