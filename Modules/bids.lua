local addonName, bepgp = ...
local moduleName = addonName.."_bids"
local bepgp_bids = bepgp:NewModule(moduleName, "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local DF = LibStub("LibDeformat-3.0")
local T = LibStub("LibQTip-1.0")

bepgp_bids.bids_main,bepgp_bids.bids_off,bepgp_bids.bid_item = {},{},{}
local bids_blacklist = {}
local bidlink = {
  ["ms"]=L["|cffFF3333|Hbepgpbid:1:$ML|h[Mainspec/NEED]|h|r"],
  ["os"]=L["|cff009900|Hbepgpbid:2:$ML|h[Offspec/GREED]|h|r"]
}
local out = "|cff9664c8"..addonName..":|r %s"
local running_bid
local color_msgp, color_osgp = "32cd32", "20b2aa"

local pr_sorter_bids = function(a,b)
  local minep = bepgp.db.profile.minep
  if minep > 0 then
    local a_over = a[3]-minep >= 0
    local b_over = b[3]-minep >= 0
    if a_over and b_over or (not a_over and not b_over) then
      if a[5] ~= b[5] then
        return tonumber(a[5]) > tonumber(b[5])
      else
        return tonumber(a[3]) > tonumber(b[3])
      end
    elseif a_over and (not b_over) then
      return true
    elseif b_over and (not a_over) then
      return false
    end
  else
    if a[5] ~= b[5] then
      return tonumber(a[5]) > tonumber(b[5])
    else
      return tonumber(a[3]) > tonumber(b[3])
    end
  end
end

function bepgp_bids:OnEnable()
  self:RegisterEvent("CHAT_MSG_WHISPER", "captureBid")
  self:RegisterEvent("CHAT_MSG_RAID", "captureLootCall")
  self:RegisterEvent("CHAT_MSG_RAID_LEADER", "captureLootCall")
  self:RegisterEvent("CHAT_MSG_RAID_WARNING", "captureLootCall")
  self:SecureHook("SetItemRef")
  self:RawHook(ItemRefTooltip,"SetHyperlink",true)

  self.qtip = T:Acquire(addonName.."bidsTablet") -- Name, ep, gp, pr, Main
  self.qtip:SetColumnLayout(5, "LEFT", "CENTER", "CENTER", "CENTER", "RIGHT")
  self.qtip:ClearAllPoints()
  self.qtip:SetClampedToScreen(true)
  self.qtip:SetClampRectInsets(-100,100,50,-50)
  self.qtip:SetPoint("TOP",UIParent,"TOP",0,-50)
end

function bepgp_bids:announceWinner(data)
  local name, pr, msos = data[1], data[2], data[3]
  local out
  if msos == "ms" then
    out = L["Winning Mainspec Bid: %s (%.03f PR)"]
  elseif msos == "os" then
    out = L["Winning Offspec Bid: %s (%.03f PR)"]
  end
  if out then
    bepgp:widestAudience(out:format(name,pr))
  end
end

function bepgp_bids:updateBids()
  -- {name,class,ep,gp,ep/gp[,main]}
  table.sort(self.bids_main, pr_sorter_bids)
  table.sort(self.bids_off, pr_sorter_bids)
end

function bepgp_bids:Refresh()
  local frame = self.qtip
  if not frame then return end
  frame:Clear()
  local minep = bepgp.db.profile.minep
  local line
  line = frame:AddHeader()
  frame:SetCell(line,1,L["BastionEPGP bids"],nil,"CENTER",4)
  frame:SetCell(line,5,C:Red("[x]"),nil,"RIGHT")
  frame:SetCellScript(line,5,"OnMouseUp", function() bepgp_bids.qtip:Hide() end)
  
  if self.bid_item.itemlink then
    line = frame:AddHeader()
    --SetCell spec : lineNum, colNum, value, font, justification, colSpan, provider
    frame:SetCell(line,1,C:Orange(L["Item"]),nil,"LEFT",2)
    frame:SetCell(line,3,C:Orange(L["Mainspec GP"]),nil,"RIGHT")
    frame:SetCell(line,4,C:Orange(L["Offspec GP"]),nil,"RIGHT")
    line = frame:AddSeparator(2)
    line = frame:AddLine()
    frame:SetCell(line,1,self.bid_item.itemlink,nil,"LEFT",2)
    frame:SetCell(line,3,C:Colorize(color_msgp,self.bid_item.price),nil,"RIGHT")
    frame:SetCell(line,4,C:Colorize(color_osgp,self.bid_item.off_price),nil,"RIGHT")

    if #(self.bids_main) > 0 then
      line = frame:AddLine(" ")
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Gold(L["Mainspec Bids"]),nil,"LEFT",5)
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Orange(L["Name"]),nil,"LEFT")
      frame:SetCell(line,2,C:Orange(L["ep"]),nil,"CENTER")
      frame:SetCell(line,3,C:Orange(L["gp"]),nil,"CENTER")
      frame:SetCell(line,4,C:Orange(L["pr"]),nil,"RIGHT")
      frame:SetCell(line,5,C:Orange(L["Main"]),nil,"RIGHT")
      line = frame:AddSeparator(1)
      for i,data in ipairs(self.bids_main) do
        local name, class, ep, gp, pr, main = unpack(data)
        local eclass,_,hexclass = bepgp:getClassData(class)
        local r,g,b = RAID_CLASS_COLORS[eclass].r, RAID_CLASS_COLORS[eclass].g, RAID_CLASS_COLORS[eclass].b
        --local name_c = C:Colorize(hexclass,name)
        local text2, text4
        if minep > 0 and ep < minep then
          text2 = C:Red(string.format("%.4g", ep))
          text4 = C:Red(string.format("%.4g", pr))
        else
          text2 = string.format("%.4g", ep)
          text4 = string.format("%.4g", pr)
        end
        local text3, text5 = string.format("%.4g", gp), (main or "")
        line = frame:AddLine()
        frame:SetCell(line,1,name,nil,"LEFT")
        frame:SetCellTextColor(line,1,r,g,b)
        frame:SetCell(line,2,text2,nil,"CENTER")
        frame:SetCell(line,3,text3,nil,"CENTER")
        frame:SetCell(line,4,text4,nil,"RIGHT")
        frame:SetCell(line,5,text5,nil,"RIGHT")
        frame:SetLineScript(line, "OnMouseUp", bepgp_bids.announceWinner, {name, pr, "ms"})
      end
    end    
    if #(self.bids_off) > 0 then
      line = frame:AddLine(" ")
      line = frame:AddHeader()    
      frame:SetCell(line,1,C:Silver(L["Offspec Bids"]),nil,"LEFT",5)
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Orange(L["Name"]),nil,"LEFT")
      frame:SetCell(line,2,C:Orange(L["ep"]),nil,"CENTER")
      frame:SetCell(line,3,C:Orange(L["gp"]),nil,"CENTER")
      frame:SetCell(line,4,C:Orange(L["pr"]),nil,"RIGHT")
      frame:SetCell(line,5,C:Orange(L["Main"]),nil,"RIGHT")
      line = frame:AddSeparator(1)
      for i,data in ipairs(self.bids_off) do
        local name, class, ep, gp, pr, main = unpack(data)
        local eclass,_,hexclass = bepgp:getClassData(class)
        local r,g,b = RAID_CLASS_COLORS[eclass].r, RAID_CLASS_COLORS[eclass].g, RAID_CLASS_COLORS[eclass].b
        --local name_c = C:Colorize(hexclass,name)
        local text2, text4
        if minep > 0 and ep < minep then
          text2 = C:Red(string.format("%.4g", ep))
          text4 = C:Red(string.format("%.4g", pr))
        else
          text2 = string.format("%.4g", ep)
          text4 = string.format("%.4g", pr)
        end
        local text3, text5 = string.format("%.4g", gp), (main or "")
        line = frame:AddLine()
        frame:SetCell(line,1,name,nil,"LEFT")
        frame:SetCellTextColor(line,1,r,g,b)
        frame:SetCell(line,2,text2,nil,"CENTER")
        frame:SetCell(line,3,text3,nil,"CENTER")
        frame:SetCell(line,4,text4,nil,"RIGHT")
        frame:SetCell(line,5,text5,nil,"RIGHT")
        frame:SetLineScript(line,"OnMouseUp", bepgp_bids.announceWinner, {name, pr, "os"})
      end      
    end
  end
  frame:UpdateScrolling()
end

function bepgp_bids:Toggle(anchor)
  if not T:IsAcquired(addonName.."bidsTablet") then
    self.qtip = T:Acquire(addonName.."bidsTablet") -- Name, ep, gp, pr, Main
    self.qtip:SetColumnLayout(5, "LEFT", "CENTER", "CENTER", "CENTER", "RIGHT")
    return
  end
  if self.qtip:IsShown() then
    self.qtip:Hide()
  else
    if anchor then
      self.qtip:SmartAnchorTo(anchor)
    else
      self.qtip:ClearAllPoints()
      self.qtip:SetClampedToScreen(true)
      self.qtip:SetClampRectInsets(-100,100,50,-50)
      self.qtip:SetPoint("TOP",UIParent,"TOP",0,-50)      
    end
    self:Refresh()
    self.qtip:Show()
  end
end

function bepgp_bids:SetItemRef(link, text, button, chatFrame)
  if string.sub(link,1,8) == "bepgpbid" then
    local _,_,bid,masterlooter = string.find(link,"bepgpbid:(%d+):(%w+)")
    if bid == "1" then
      bid = "+"
    elseif bid == "2" then
      bid = "-"
    else
      bid = nil
    end
    if not bepgp:inRaid(masterlooter) then
      masterlooter = nil
    end
    if (bid and masterlooter) then
      SendChatMessage(bid,"WHISPER",nil,masterlooter)
    end
    return false
  end  
end

function bepgp_bids:SetHyperlink(frame, link, ...)
  if string.sub(link,1,8) == "bepgpbid" then
    return false
  end
  self.hooks[ItemRefTooltip].SetHyperlink(frame, link, ...)
end

local lootCall = {
  ["whisper"] = {
  "^(w)[%s%p%c]+.+",".+[%s%p%c]+(w)$",".+[%s%p%c]+(w)[%s%p%c]+.*",".*[%s%p%c]+(w)[%s%p%c]+.+",
  "^(whisper)[%s%p%c]+.+",".+[%s%p%c]+(whisper)$",".+[%s%p%c]+(whisper)[%s%p%c]+.*",".*[%s%p%c]+(whisper)[%s%p%c]+.+",
  ".+[%s%p%c]+(bid)[%s%p%c]*.*",".*[%s%p%c]*(bid)[%s%p%c]+.+"
  },
  ["ms"] = {
  ".+(%+).*",".*(%+).+", 
  "^(ms)[%s%p%c]+.+",".+[%s%p%c]+(ms)$",".+[%s%p%c]+(ms)[%s%p%c]+.*",".*[%s%p%c]+(ms)[%s%p%c]+.+", 
  ".+(mainspec).*",".*(mainspec).+"
  },
  ["os"] = {
  ".+(%-).*",".*(%-).+", 
  "^(os)[%s%p%c]+.+",".+[%s%p%c]+(os)$",".+[%s%p%c]+(os)[%s%p%c]+.*",".*[%s%p%c]+(os)[%s%p%c]+.+", 
  ".+(offspec).*",".*(offspec).+"
  },
  ["blacklist"] = {
  "^(roll)[%s%p%c]+.+",".+[%s%p%c]+(roll)$",".*[%s%p%c]+(roll)[%s%p%c]+.*"
  },
}
function bepgp_bids:captureLootCall(event, text, sender)
  if not (string.find(text, "|Hitem:", 1, true)) then return end
  local linkstriptext, count = string.gsub(text,"|c%x+|H[eimt:%d]+|h%[[%w%s',%-]+%]|h|r"," ; ")
  if count > 1 then return end
  local lowtext = string.lower(linkstriptext)
  local whisperkw_found, mskw_found, oskw_found, link_found, blacklist_found
  for _,f in ipairs(lootCall.blacklist) do
    blacklist_found = string.find(lowtext,f)
    if (blacklist_found) then return end
  end
  sender = Ambiguate(sender,"short") --:gsub("(\-.+)","")
  local _, itemLink, itemColor, itemString, itemName, itemID
  for _,f in ipairs(lootCall.whisper) do
    whisperkw_found = string.find(lowtext,f)
    if (whisperkw_found) then break end
  end
  for _,f in ipairs(lootCall.ms) do
    mskw_found = string.find(lowtext,f)
    if (mskw_found) then break end
  end
  for _,f in ipairs(lootCall.os) do
    oskw_found = string.find(lowtext,f)
    if (oskw_found) then break end
  end
  if (whisperkw_found) or (mskw_found) or (oskw_found) then
    _,_,itemLink = string.find(text,"(|c%x+|H[eimt:%d]+|h%[[%w%s',%-]+%]|h|r)")
    if (itemLink) and (itemLink ~= "") then
      itemColor, itemString, itemName, itemID = bepgp:getItemData(itemLink)
    end
    if (itemName) then
      local price = bepgp:GetPrice(itemString, bepgp.db.profile.progress)
      if (price and price > 0) then
        if (bepgp:raidLeader() or bepgp:lootMaster()) and (sender == bepgp._playerName) then
          self:clearBids(true)
          bepgp_bids.bid_item.itemstring = itemString
          bepgp_bids.bid_item.itemlink = itemLink
          bepgp_bids.bid_item.name = string.format("%s%s|r",itemColor,itemName)
          bepgp_bids.bid_item.price = price
          bepgp_bids.bid_item.off_price = math.floor(price*bepgp.db.profile.discount)
          self._bidTimer = self:ScheduleTimer("clearBids",300)
          running_bid = true
          bepgp:debugPrint("Capturing Bids for 5min.")
          self.qtip:Show()
        end
        self:bidPrint(itemLink,sender,mskw_found,oskw_found,whisperkw_found)
      end
    end
  end
end

local lootBid = {
  ["ms"] = {"(%+)",".+(%+).*",".*(%+).+",".*(%+).*",L["(ms)"],L["(need)"]},
  ["os"] = {"(%-)",".+(%-).*",".*(%-).+",".*(%-).*",L["(os)"],L["(greed)"]}
}
function bepgp_bids:captureBid(event, text, sender)
  if not (running_bid) then return end
  if not (bepgp:raidLeader() or bepgp:lootMaster()) then return end
  if not bepgp_bids.bid_item.itemstring then return end
  sender = Ambiguate(sender,"short") --:gsub("(\-.+)","")
  local mskw_found,oskw_found
  local lowtext = string.lower(text)
  for _,f in ipairs(lootBid.ms) do
    mskw_found = string.find(text,f)
    if (mskw_found) then break end
  end
  for _,f in ipairs(lootBid.os) do
    oskw_found = string.find(text,f)
    if (oskw_found) then break end
  end
  if (mskw_found) or (oskw_found) then
    if bepgp:inRaid(sender) then
      if bids_blacklist[sender] == nil then
        for i = 1, GetNumGuildMembers(true) do
          local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
          name = Ambiguate(name,"short") --:gsub("(\-.+)","")
          if name == sender then
            local ep = (bepgp:get_ep(name,officernote) or 0) 
            local gp = (bepgp:get_gp(name,officernote) or bepgp.VARS.basegp)
            local main_name
            if (bepgp.db.profile.altspool) then
              local main, main_class, main_rank, main_offnote = bepgp:parseAlt(name,officernote)
              if (main) then
                ep = (self:get_ep(main,main_offnote) or 0)
                gp = (self:get_gp(main,main_offnote) or bepgp.VARS.basegp)
                main_name = main
              end
            end
            if (mskw_found) then
              bids_blacklist[sender] = true
              if (bepgp.db.profile.altspool) and (main_name) then
                table.insert(bepgp_bids.bids_main,{name,class,ep,gp,ep/gp,main_name})
              else
                table.insert(bepgp_bids.bids_main,{name,class,ep,gp,ep/gp})
              end
            elseif (oskw_found) then
              bids_blacklist[sender] = true
              if (bepgp.db.profile.altspool) and (main_name) then
                table.insert(bepgp_bids.bids_off,{name,class,ep,gp,ep/gp,main_name})
              else
                table.insert(bepgp_bids.bids_off,{name,class,ep,gp,ep/gp})
              end
            end
            self:updateBids()
            self:Refresh()
            return
          end
        end
      end
    end
  end
end

function bepgp_bids:clearBids(reset)
  if reset~=nil then
    bepgp:debugPrint(L["Clearing old Bids"])
  else
    self.qtip:Hide()
  end
  table.wipe(bepgp_bids.bid_item) -- = {}
  table.wipe(bepgp_bids.bids_main) -- = {}
  table.wipe(bepgp_bids.bids_off) -- = {}
  table.wipe(bids_blacklist) -- = {}
  if self._bidTimer then
    self:CancelTimer(self._bidTimer)
    self._bidTimer = nil
  end
  running_bid = false
  self:updateBids()
  self:Refresh()
  --sepgp_bids._counterText = ""
  --sepgp_bids:Refresh()
end

function bepgp_bids:bidPrint(link,masterlooter,need,greed,bid)
  local mslink = string.gsub(bidlink["ms"],"$ML",masterlooter)
  local oslink = string.gsub(bidlink["os"],"$ML",masterlooter)
  local msg = string.format(L["Click $MS or $OS for %s"],link)
  if (need and greed) then
    msg = string.gsub(msg,"$MS",mslink)
    msg = string.gsub(msg,"$OS",oslink)
  elseif (need) then
    msg = string.gsub(msg,"$MS",mslink)
    msg = string.gsub(msg,L["or $OS "],"")
  elseif (greed) then
    msg = string.gsub(msg,"$OS",oslink)
    msg = string.gsub(msg,L["$MS or "],"")
  elseif (bid) then
    msg = string.gsub(msg,"$MS",mslink)
    msg = string.gsub(msg,"$OS",oslink)  
  end
  local _, count = string.gsub(msg,"%$","%$")
  if (count > 0) then return end
  local chatframe
  if (SELECTED_CHAT_FRAME) then
    chatframe = SELECTED_CHAT_FRAME
  else
    if not DEFAULT_CHAT_FRAME:IsVisible() then
      FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
    end
    chatframe = DEFAULT_CHAT_FRAME
  end
  if (chatframe) then
    chatframe:AddMessage(" ")
    chatframe:AddMessage(string.format(out,msg),NORMAL_FONT_COLOR.r,NORMAL_FONT_COLOR.g,NORMAL_FONT_COLOR.b)
  end
end

