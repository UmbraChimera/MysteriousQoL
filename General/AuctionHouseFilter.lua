local _, addon = ...

-- Auto-enables "Current Expansion Only" filter when opening the Auction House.

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent", function()
    if not addon.db.general_ahCurrentExpansion then return end

    -- Defer one frame to let the AH UI finish initializing
    C_Timer.After(0, function()
        if not AuctionHouseFrame then return end
        local searchBar = AuctionHouseFrame.SearchBar
        if not searchBar or not searchBar.FilterButton then return end
        local filters = searchBar.FilterButton.filters
        if filters then
            filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            if searchBar.FilterButton.UpdateClearFiltersButton then
                searchBar.FilterButton:UpdateClearFiltersButton()
            end
        end
    end)
end)
