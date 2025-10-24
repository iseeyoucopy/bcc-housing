InTpHouse, CurrentTpHouse, BreakHandleLoop = false, nil, false
local PlayerAccessibleHouses = {}

BccUtils.RPC:Register('bcc-housing:ReceiveAccessibleHouses', function(params)
    devPrint("Received accessible houses list via RPC")
    PlayerAccessibleHouses = params and params.houses or {}
end)

local function notifyNoAccess(message)
    Notify(message or _U('noAccessToHouse'), 'error', 4000)
end

local function afterGivingAccess(houseId, playerId, playerServerId, completion)
    if houseId and playerId and playerServerId then
        local success = BccUtils.RPC:CallAsync('bcc-housing:NewPlayerGivenAccess', {
            charIdentifier = playerId,
            houseId = houseId,
            recSource = playerServerId
        })
        if success then
            Notify(_U("givenAccess"), "success", 4000)
        else
            Notify(_U("giveAccesFailed"), "error", 4000)
        end
        completion(success, success and _U('accessGranted') or _U('giveAccesFailed'))
    else
        completion(false, _U('missingInfos'))
    end
end

local function afterRemoveAccess(houseId, playerId)
    devPrint("Attempting to remove access with House ID: " .. tostring(houseId) .. ", Player ID: " .. tostring(playerId))
    if houseId and playerId then
        local success = BccUtils.RPC:CallAsync('bcc-housing:RemovePlayerAccess', {
            houseId = houseId,
            playerId = playerId
        })
        if not success then
            Notify(_U("updateFailed"), "error", 4000)
        end
    end
end

local function showAccessMenu(houseId)
    devPrint("Showing access menu for House ID: " .. tostring(houseId))
    PlayerListMenuForGiveAccess(houseId, afterGivingAccess, "giveAccess")
end

-- Function to show the remove access menu
local function showRemoveAccessMenu(houseId)
    devPrint("Showing access menu for House ID: " .. tostring(houseId))
    PlayerListMenuForRemoveAccess(houseId, afterRemoveAccess, "removeAccess")
end

-- Function to show the player list menu for giving access
function PlayerListMenuForGiveAccess(houseId, callback, context)
    devPrint("Opening player list menu for giving access to House ID: " .. tostring(houseId))
    BCCHousingMenu:Close()
    local players = GetPlayers()
    table.sort(players, function(a, b)
        return a.serverId < b.serverId
    end)

    local playerListGiveMenuPage = BCCHousingMenu:RegisterPage("bcc-housing:playerListGiveMenuPage")
    playerListGiveMenuPage:RegisterElement("header", {
        value = _U("StaticId_desc"),
        slot = "header",
        style = {}
    })

    playerListGiveMenuPage:RegisterElement('line', {
        slot = "header",
        style = {}
    })

    for k, v in pairs(players) do
        playerListGiveMenuPage:RegisterElement("button", {
            label = Config.dontShowNames and ("ID - " .. v.serverId) or v.PlayerName,
            style = {}
        }, function()
            callback(houseId, v.staticid, v.serverId, function(success, message)
                Notify(message, 4000)
                housingAccessMenu:RouteTo()
            end)
        end)
    end

    playerListGiveMenuPage:RegisterElement('line', {
        slot = "footer",
        style = {}
    })

    playerListGiveMenuPage:RegisterElement("button", {
        label = _U("backButton"),
        slot = "footer",
        style = {['position'] = 'relative', ['z-index'] = 9,}
    }, function()
        housingAccessMenu:RouteTo()
    end)

    playerListGiveMenuPage:RegisterElement('bottomline', {
        slot = "footer",
        style = {}
    })

    TextDisplay = playerListGiveMenuPage:RegisterElement('textdisplay', {
        slot = "footer",
        value = _U('selectPlayerFromList'),
        style = {}
    })

    BCCHousingMenu:Open({ startupPage = playerListGiveMenuPage })
end

function PlayerListMenuForRemoveAccess(houseId, callback, context)
    devPrint("Opening player list menu for removing access to House ID: " .. tostring(houseId))
    BCCHousingMenu:Close()
    if HandlePlayerDeathAndCloseMenu() then
        return -- Skip opening the menu if the player is dead
    end
    -- Asynchronous call to get players with access
    GetPlayersWithAccess(houseId, function(rplayers)
        devPrint("Number of players with access: " .. #rplayers) -- This will print the count of players fetched

        local playerListRemoveMenuPage = BCCHousingMenu:RegisterPage("bcc-housing:playerListRemoveMenuPage")
        playerListRemoveMenuPage:RegisterElement("header", {
            value = _U('removeAccess'),
            slot = "header",
            style = {}
        })

        playerListRemoveMenuPage:RegisterElement('line', {
            slot = "header",
            style = {}
        })

        if #rplayers == 0 then
            devPrint("No players to display in menu")
            TextDisplay = playerListRemoveMenuPage:RegisterElement('textdisplay', {
                value = _U("noAccessNotify"),
                style = {}
            })
        end

        for k, v in pairs(rplayers) do
            devPrint("Adding button for player ID: " .. tostring(v.charidentifier)) -- Ensure charidentifier is correct
            playerListRemoveMenuPage:RegisterElement("button", {
                label = v.firstname .. " " .. v.lastname,                           -- Displaying player's name
                style = {}
            }, function()
                AfterRemoveAccess(houseId, v.charidentifier)
                housingAccessMenu:RouteTo()
            end)
        end

        playerListRemoveMenuPage:RegisterElement('line', {
            slot = "footer",
            style = {}
        })

        playerListRemoveMenuPage:RegisterElement("button", {
            label = _U("backButton"),
            slot = "footer",
            style = {['position'] = 'relative', ['z-index'] = 9,}
        }, function()
            housingAccessMenu:RouteTo()
        end)

        playerListRemoveMenuPage:RegisterElement('bottomline', {
            slot = "footer",
            style = {}
        })

        TextDisplay = playerListRemoveMenuPage:RegisterElement('textdisplay', {
            slot = "footer",
            value = _U('selectPlayerToRemove'),
            style = {}
        })

        BCCHousingMenu:Open({ startupPage = playerListRemoveMenuPage })
    end)
end

function OpenHousingMainMenu(houseId, isOwner, ownershipStatus)
    devPrint("Opening housing main menu for House ID: " .. tostring(houseId) .. ", Is Owner: " .. tostring(isOwner))

    if HandlePlayerDeathAndCloseMenu() then
        return -- Skip opening the menu if the player is dead
    end

    local housingMainMenu = BCCHousingMenu:RegisterPage("bcc-housing:MainPage")

    housingMainMenu:RegisterElement('header', {
        value = _U("creationMenuName"),
        slot = 'header',
        style = {}
    })

    housingMainMenu:RegisterElement('line', { style = {} })

    -- House Inventory
    housingMainMenu:RegisterElement('button', {
        label = _U("houseInv"),
        style = {}
    }, function()
        devPrint("Attempting to open inventory for House ID: " .. tostring(houseId))

        if not houseId then
            notifyNoAccess()
            return
        end

        local success, response = BccUtils.RPC:CallAsync('bcc-house:OpenHouseInv', { houseId = houseId })
        if not success then
            notifyNoAccess(response and response.error)
        end
    end)

    -- Enter/Exit TP House if available
    if TpHouse ~= nil then
        if not InTpHouse then
            housingMainMenu:RegisterElement('button', {
                label = _U("enterTpHouse"),
                style = {}
            }, function()
                enterOrExitHouse(true, TpHouse)
            end)
        else
            housingMainMenu:RegisterElement('button', {
                label = _U("exitTpHouse"),
                style = {}
            }, function()
                enterOrExitHouse(false)
            end)
        end
    end

    -- Owner-only actions
    if isOwner then
        -- Access management entry
        housingMainMenu:RegisterElement('button', {
            label = _U('giveAccesstoHouse'),
            style = {}
        }, function()
            local housingAccessMenu = BCCHousingMenu:RegisterPage("bcc-housing:AccessPage")

            housingAccessMenu:RegisterElement('header', {
                value = _U('giveAccesstoHouse'),
                slot = 'header',
                style = {}
            })
            housingAccessMenu:RegisterElement('line', { style = {} })

            -- Give Access
            housingAccessMenu:RegisterElement('button', {
                label = _U("giveAccess"),
                style = {}
            }, function()
                devPrint("Validating access for House ID: " .. tostring(houseId))
                if not houseId then
                    Notify(_U('noAccessToHouse'), 'error', 4000)
                    return
                end

                local success, data = BccUtils.RPC:CallAsync('bcc-housing:getHouseId', {
                    context = 'access',
                    houseId = houseId
                })

                if success and data then
                    showAccessMenu(houseId)
                    return
                end
                Notify(_U('noAccessToHouse'), 'error', 4000)
            end)

            -- Remove Access
            housingAccessMenu:RegisterElement('button', {
                label = _U("removeAccess"),
                style = {}
            }, function()
                devPrint("Validating remove access for House ID: " .. tostring(houseId))
                if not houseId then
                    Notify(_U('noAccessToHouse'), 'error', 4000)
                    return
                end

                local success, data = BccUtils.RPC:CallAsync('bcc-housing:getHouseId', {
                    context = 'removeAccess',
                    houseId = houseId
                })

                if success and data then
                    showRemoveAccessMenu(houseId)
                    return
                end
                Notify(_U('noAccessToHouse'), 'error', 4000)
            end)

            housingAccessMenu:RegisterElement('line', { slot = "footer", style = {} })
            housingAccessMenu:RegisterElement('button', {
                label = _U("backButton"),
                slot = "footer",
                style = { ['position'] = 'relative', ['z-index'] = 9 }
            }, function()
                housingMainMenu:RouteTo()
            end)
            housingAccessMenu:RegisterElement('bottomline', { style = {}, slot = "footer" })

            BCCHousingMenu:Open({ startupPage = housingAccessMenu })
        end)

        -- Door management
        housingMainMenu:RegisterElement('button', {
            label = _U("doors"),
            style = {}
        }, function()
            local doorManagementPage = BCCHousingMenu:RegisterPage('owner_door_management_page')

            doorManagementPage:RegisterElement('header', {
                value = _U("doorManagementTitle"),
                slot = "header",
                style = {}
            })
            doorManagementPage:RegisterElement('line', { slot = "header", style = {} })

            if Config.doors.createNewDoors then
                doorManagementPage:RegisterElement('button', {
                    label = _U("createNewDoor"),
                    style = {}
                }, function()
                    BCCHousingMenu:Close()
                    local playerId = GetPlayerServerId(PlayerId())
                    local newDoorId = exports['bcc-doorlocks']:addPlayerToDoor(playerId)

                    if newDoorId then
                        devPrint("Door created and player added successfully: " .. tostring(newDoorId))
                        BccUtils.RPC:Call("bcc-housing:AddDoorToHouse",
                            { houseId = houseId, newDoor = newDoorId },
                            function(success)
                                if success then
                                    Notify(_U("doorCreated"), "success", 4000)
                                else
                                    Notify(_U("doorSaveFailed"), "error", 4000)
                                end
                            end)
                    else
                        Notify(_U("doorCreationFailed"), "error", 4000)
                    end
                end)
            end

            -- List doors
            doorManagementPage:RegisterElement('button', {
                label = _U("listDoors"),
                style = {}
            }, function()
                local doorListPage = BCCHousingMenu:RegisterPage('door_list_management_page')

                doorListPage:RegisterElement('header', {
                    value = _U("doorManagementTitle"),
                    slot = "header",
                    style = {}
                })
                doorListPage:RegisterElement('line', { slot = "header", style = {} })

                local currentHouseId = houseId
                if not currentHouseId then
                    Notify(_U("invalidHouseId"), "error", 4000)
                    return
                end

                BccUtils.RPC:Call("bcc-housing:GetDoorsByHouseId", { houseId = currentHouseId }, function(doors)
                    if not doors or #doors == 0 then
                        doorListPage:RegisterElement('textdisplay', {
                            value = _U("noDoorsFound"),
                            slot = "content",
                            style = {}
                        })
                    else
                        for k, door in ipairs(doors) do
                            doorListPage:RegisterElement('button', {
                                label = _U("doorId") .. (door.doorid or k),
                                style = {}
                            }, function()
                                local doorOptionsPage = BCCHousingMenu:RegisterPage('door_options_page')

                                doorOptionsPage:RegisterElement('header', {
                                    value = _U("doorOptions") .. (door.doorid or ""),
                                    slot = "header",
                                    style = {}
                                })
                                doorOptionsPage:RegisterElement('line', { slot = "header", style = {} })

                                -- Remove door
                                if Config.doors.removeDoors then
                                    doorOptionsPage:RegisterElement('button', {
                                        label = _U("removeDoor"),
                                        style = {}
                                    }, function()
                                        local doorRemoveDoorPage = BCCHousingMenu:RegisterPage('door_options_page')

                                        doorRemoveDoorPage:RegisterElement('header', {
                                            value = _U("confirmDoorDelete") .. (door.doorid or ""),
                                            slot = "header",
                                            style = {}
                                        })
                                        doorRemoveDoorPage:RegisterElement('line', { slot = "header", style = {} })

                                        doorRemoveDoorPage:RegisterElement('button', {
                                            label = _U("confirmYes"),
                                            style = {}
                                        }, function()
                                            BccUtils.RPC:Call("bcc-housing:DeleteDoor", { doorId = door.doorid }, function(success)
                                                if success then
                                                    Notify(_U("doorRemoved"), "success", 4000)
                                                else
                                                    Notify(_U("doorRemoveFailed"), "error", 4000)
                                                end
                                                doorListPage:RouteTo()
                                            end)
                                        end)

                                        doorRemoveDoorPage:RegisterElement('button', {
                                            label = _U("confirmNo"),
                                            style = {}
                                        }, function()
                                            doorListPage:RouteTo()
                                        end)

                                        doorRemoveDoorPage:RegisterElement('line', { slot = "footer", style = {} })
                                        doorRemoveDoorPage:RegisterElement('button', {
                                            label = _U("backButton"),
                                            slot = "footer",
                                            style = { ['position'] = 'relative', ['z-index'] = 9 }
                                        }, function()
                                            doorOptionsPage:RouteTo()
                                        end)
                                        doorRemoveDoorPage:RegisterElement('bottomline', { slot = "footer", style = {} })

                                        BCCHousingMenu:Open({ startupPage = doorRemoveDoorPage })
                                    end)
                                end

                                -- Give access to door
                                doorOptionsPage:RegisterElement('button', {
                                    label = _U('giveAccesstoDoor'),
                                    style = {}
                                }, function()
                                    BccUtils.RPC:Call("bcc-housing:GetPlayersWithAccess", { houseId = houseId }, function(players)
                                        if not players or #players == 0 then
                                            Notify(_U('doorNoUsersWithAccess'), "error", 4000)
                                            return
                                        end

                                        local giveAccessPage = BCCHousingMenu:RegisterPage('give_access_page')

                                        giveAccessPage:RegisterElement('header', {
                                            value = _U('doorSelectUser'),
                                            slot = "header",
                                            style = {}
                                        })
                                        giveAccessPage:RegisterElement('line', { slot = "header", style = {} })

                                        for _, player in ipairs(players) do
                                            giveAccessPage:RegisterElement('button', {
                                                label = "ID: " .. tostring(player.charidentifier) ..
                                                        " Name: " .. player.firstname .. " " .. player.lastname,
                                                style = {}
                                            }, function()
                                                if not door.doorid then
                                                    devPrint("Invalid door ID.")
                                                    return
                                                end

                                                BccUtils.RPC:Call("bcc-housing:GiveAccessToDoor",
                                                    { doorId = door.doorid, userId = player.charidentifier },
                                                    function(success)
                                                        if success then
                                                            BCCHousingMenu:Close()
                                                            Notify(_U('doorAccessGranted') ..
                                                                player.firstname .. " " .. player.lastname, "success", 4000)
                                                        else
                                                            BCCHousingMenu:Close()
                                                            Notify(player.firstname .. " " .. player.lastname ..
                                                                _U('doorHasAccess'), "error", 4000)
                                                        end
                                                    end)
                                            end)
                                        end

                                        giveAccessPage:RegisterElement('line', { slot = "footer", style = {} })
                                        giveAccessPage:RegisterElement('button', {
                                            label = _U("backButton"),
                                            slot = "footer",
                                            style = { ['position'] = 'relative', ['z-index'] = 9 }
                                        }, function()
                                            doorOptionsPage:RouteTo()
                                        end)
                                        giveAccessPage:RegisterElement('bottomline', { slot = "footer", style = {} })

                                        BCCHousingMenu:Open({ startupPage = giveAccessPage })
                                    end)
                                end)

                                -- Remove door access
                                doorOptionsPage:RegisterElement('button', {
                                    label = _U('removeAccessFromDoor'),
                                    style = {}
                                }, function()
                                    BccUtils.RPC:Call("bcc-housing:GetPlayersWithAccess", { houseId = houseId }, function(players)
                                        if not players or #players == 0 then
                                            Notify(_U('doorNoUsersWithAccess'), "error", 4000)
                                            return
                                        end

                                        local removeAccessPage = BCCHousingMenu:RegisterPage('remove_access_page')

                                        removeAccessPage:RegisterElement('header', {
                                            value = _U('doorSelectUserToRemove'),
                                            slot = "header",
                                            style = {}
                                        })
                                        removeAccessPage:RegisterElement('line', { slot = "header", style = {} })

                                        for _, player in ipairs(players) do
                                            removeAccessPage:RegisterElement('button', {
                                                label = "ID: " .. tostring(player.charidentifier) ..
                                                        " Name: " .. player.firstname .. " " .. player.lastname,
                                                style = {}
                                            }, function()
                                                if not door.doorid then
                                                    devPrint("Invalid door ID.")
                                                    return
                                                end

                                                BccUtils.RPC:Call("bcc-housing:RemoveAccessFromDoor",
                                                    { doorId = door.doorid, userId = player.charidentifier },
                                                    function(success)
                                                        if success then
                                                            doorOptionsPage:RouteTo()
                                                            Notify(player.firstname .. " " .. player.lastname ..
                                                                _U('doorAccessRevoked'), "success", 4000)
                                                        else
                                                            doorOptionsPage:RouteTo()
                                                            Notify(_U('doorRemoveAccessFailed') ..
                                                                player.firstname .. " " .. player.lastname, "error", 4000)
                                                        end
                                                    end)
                                            end)
                                        end

                                        removeAccessPage:RegisterElement('line', { slot = "footer", style = {} })
                                        removeAccessPage:RegisterElement('button', {
                                            label = _U("backButton"),
                                            slot = "footer",
                                            style = { ['position'] = 'relative', ['z-index'] = 9 }
                                        }, function()
                                            doorOptionsPage:RouteTo()
                                        end)
                                        removeAccessPage:RegisterElement('bottomline', { slot = "footer", style = {} })

                                        BCCHousingMenu:Open({ startupPage = removeAccessPage })
                                    end)
                                end)

                                -- Footer
                                doorOptionsPage:RegisterElement('line', { slot = "footer", style = {} })
                                doorOptionsPage:RegisterElement('button', {
                                    label = _U("backButton"),
                                    slot = "footer",
                                    style = { ['position'] = 'relative', ['z-index'] = 9 }
                                }, function()
                                    doorListPage:RouteTo()
                                end)
                                doorOptionsPage:RegisterElement('bottomline', { slot = "footer", style = {} })

                                BCCHousingMenu:Open({ startupPage = doorOptionsPage })
                            end)
                        end
                    end

                    doorListPage:RegisterElement('line', { slot = "footer", style = {} })
                    doorListPage:RegisterElement('button', {
                        label = _U("backButton"),
                        slot = "footer",
                        style = {}
                    }, function()
                        doorManagementPage:RouteTo()
                    end)

                    BCCHousingMenu:Open({ startupPage = doorListPage })
                end)
            end)

            -- Footer
            doorManagementPage:RegisterElement('line', { slot = "footer", style = {} })
            doorManagementPage:RegisterElement('button', {
                label = _U("backButton"),
                slot = "footer",
                style = { ['position'] = 'relative', ['z-index'] = 9 }
            }, function()
                housingMainMenu:RouteTo()
            end)
            doorManagementPage:RegisterElement('bottomline', { slot = "footer", style = {} })

            BCCHousingMenu:Open({ startupPage = doorManagementPage })
        end)

        -- Sell / Sell to player
        if ownershipStatus == 'purchased' then
            housingMainMenu:RegisterElement('button', {
                label = _U("sellHouse"),
                style = {}
            }, function()
                sellHouseConfirmation(houseId, ownershipStatus)
            end)

            if Config.SellToPlayer then
                housingMainMenu:RegisterElement('button', {
                    label = _U('sellHouseToPlayer'),
                    style = {}
                }, function()
                    sellHouseToPlayer(houseId, ownershipStatus)
                end)
            end
        end
    end

    -- Ledger (both purchased / rented)
    housingMainMenu:RegisterElement('button', {
        label = (ownershipStatus == "purchased") and _U("ledger") or _U("ledgerGold"),
        style = {}
    }, function()
        local ledgerPage = BCCHousingMenu:RegisterPage('bcc-housing:ledger:page')

        ledgerPage:RegisterElement('header', {
            value = (ownershipStatus == "purchased") and _U("ledger") or _U("ledgerGold"),
            slot = "header",
            style = {}
        })

        ledgerPage:RegisterElement('button', {
            label = _U("checkledger"),
            style = {}
        }, function()
            local success, err = BccUtils.RPC:CallAsync('bcc-housing:CheckLedger', { houseid = houseId })
            if not success then
                devPrint("CheckLedger RPC failed: " .. tostring(err and err.error))
            end
        end)

        ledgerPage:RegisterElement('button', {
            label = (ownershipStatus == "purchased") and _U("ledgerInsert") or _U("ledgerInsertGold"),
            style = {}
        }, function()
            if houseId then
                TriggerEvent('bcc-housing:addLedger', houseId, isOwner)
            else
                devPrint("Error: HouseId is undefined or invalid.")
            end
        end)

        if ownershipStatus == "purchased" then
            ledgerPage:RegisterElement('button', {
                label = _U('removeFromLedger'),
                style = {}
            }, function()
                if houseId then
                    TriggerEvent('bcc-housing:removeLedger', houseId, isOwner)
                else
                    devPrint("Error: HouseId is undefined or invalid.")
                end
            end)
        end

        ledgerPage:RegisterElement('line', { slot = "footer", style = {} })
        ledgerPage:RegisterElement('button', {
            label = _U("backButton"),
            slot = "footer",
            style = { ['position'] = 'relative', ['z-index'] = 9 }
        }, function()
            OpenHousingMainMenu(houseId, isOwner, ownershipStatus)
        end)
        ledgerPage:RegisterElement('bottomline', { style = { ['position'] = 'relative', ['z-index'] = 9 }, slot = "footer" })

        BCCHousingMenu:Open({ startupPage = ledgerPage })
    end)

    housingMainMenu:RegisterElement('bottomline', { style = {}, slot = "footer" })

    if Config.UseImageAtBottomMenu then
        housingMainMenu:RegisterElement("html", {
            value = { Config.HouseImageURL },
            slot = "footer"
        })
    end

    BCCHousingMenu:Open({ startupPage = housingMainMenu })
end

-- Helper function to manage entering or exiting houses
function enterOrExitHouse(enter, tpHouseIndex)
    BCCHousingMenu.Close()
    if enter then
        devPrint("Entering house with tpHouseIndex: " .. tostring(tpHouseIndex))
        local houseTable = Config.TpInteriors["Interior" .. tostring(tpHouseIndex)]
        CurrentTpHouse = tpHouseIndex
        enterTpHouse(houseTable)
    else
        local playerPed = PlayerPedId()
        devPrint("Exiting house")
        SetEntityCoords(playerPed, HouseCoords.x, HouseCoords.y, HouseCoords.z, false, false, false, false)
        FreezeEntityPosition(playerPed, true)
        Wait(500)
        FreezeEntityPosition(playerPed, false)
        InTpHouse = false
        showManageOpt(HouseCoords.x, HouseCoords.y, HouseCoords.z, HouseId)
    end
end

-- Event to open the add ledger page
RegisterNetEvent('bcc-housing:addLedger')
AddEventHandler('bcc-housing:addLedger', function(houseId, isOwner)
    devPrint("Adding ledger for House ID: " .. tostring(houseId))
    local AddLedgerPage = BCCHousingMenu:RegisterPage('add_ledger_page')
    local amountToInsert = nil

    AddLedgerPage:RegisterElement('header', {
        value = _U('ledger'),
        slot = 'header',
        style = {}
    })

    AddLedgerPage:RegisterElement('input', {
        label = _U('taxAmount'),
        placeholder = _U("ledgerAmountToInsert"),
        inputType = 'number',
        slot = 'content',
        style = {}
    }, function(data)
        if data.value and tonumber(data.value) and tonumber(data.value) > 0 then
            amountToInsert = tonumber(data.value)
        else
            amountToInsert = nil
            devPrint("Invalid input for amount.")
        end
    end)

    AddLedgerPage:RegisterElement('line', {
        slot = "footer",
        style = {}
    })

    AddLedgerPage:RegisterElement('button', {
        label = _U("Confirm"),
        slot = "footer",
        style = {}
    }, function()
        if amountToInsert then
            devPrint("Submitting ledger update for amount: " .. tostring(amountToInsert) .. " (Adding)")
            local success, err = BccUtils.RPC:CallAsync('bcc-housing:LedgerHandling', {
                amount = amountToInsert,
                houseid = houseId,
                isAdding = true
            }) -- true for adding
            if not success then
                devPrint("Ledger add RPC failed: " .. tostring(err and err.error))
            end
            BCCHousingMenu:Close()
        else
            devPrint("Error: Amount not set or invalid.")
        end
    end)

    AddLedgerPage:RegisterElement('button', {
        label = _U("backButton"),
        slot = "footer",
        style = {['position'] = 'relative', ['z-index'] = 9,}
    }, function()
        OpenHousingMainMenu(houseId, isOwner, ownershipStatus)
    end)

    AddLedgerPage:RegisterElement('bottomline', {
        slot = "footer",
        style = {}
    })

    BCCHousingMenu:Open({ startupPage = AddLedgerPage })
end)

-- Event to open the remove ledger page
RegisterNetEvent('bcc-housing:removeLedger')
AddEventHandler('bcc-housing:removeLedger', function(houseId, isOwner)
    devPrint("Remove ledger for House ID: " .. tostring(houseId))
    local RemoveLedgerPage = BCCHousingMenu:RegisterPage('remove_ledger_page')
    local amountToInsert = nil

    RemoveLedgerPage:RegisterElement('header', {
        value = _U('ledger'),
        slot = 'header',
        style = {}
    })

    RemoveLedgerPage:RegisterElement('input', {
        label = _U('taxAmount'),
        placeholder = _U("ledgerAmountToInsert"),
        inputType = 'number',
        slot = 'content',
        style = {}
    }, function(data)
        if data.value and tonumber(data.value) and tonumber(data.value) > 0 then
            amountToInsert = tonumber(data.value)
        else
            amountToInsert = nil
            devPrint("Invalid input for amount.")
        end
    end)

    RemoveLedgerPage:RegisterElement('line', {
        slot = "footer",
        style = {}
    })

    RemoveLedgerPage:RegisterElement('button', {
        label = _U("Confirm"),
        slot = "footer",
        style = {}
    }, function()
        if amountToInsert then
            devPrint("Submitting ledger update for amount: " .. tostring(amountToInsert) .. " (Removing)")
            local success, err = BccUtils.RPC:CallAsync('bcc-housing:LedgerHandling', {
                amount = amountToInsert,
                houseid = houseId,
                isAdding = false
            }) -- false for removing
            if not success then
                devPrint("Ledger remove RPC failed: " .. tostring(err and err.error))
            end
            BCCHousingMenu:Close()
        else
            devPrint("Error: Amount not set or invalid.")
        end
    end)

    RemoveLedgerPage:RegisterElement('button', {
        label = _U("backButton"),
        slot = "footer",
        style = {['position'] = 'relative', ['z-index'] = 9,}
    }, function()
        OpenHousingMainMenu(houseId, isOwner, ownershipStatus)
    end)

    RemoveLedgerPage:RegisterElement('bottomline', {
        slot = "footer",
        style = {}
    })

    BCCHousingMenu:Open({ startupPage = RemoveLedgerPage })
end)

function enterTpHouse(houseTable)
    devPrint("Entering TP house")
    InTpHouse = true
    local playerPed = PlayerPedId()
    HousingInstance.Set(HousingInstance.Compute(TpHouseInstance))
    SetEntityCoords(playerPed, houseTable.exitCoords.x, houseTable.exitCoords.y, houseTable.exitCoords.z, false, false, false, false)

    FreezeEntityPosition(playerPed, true)
    Wait(1000)
    FreezeEntityPosition(playerPed, false)
    showManageOpt(houseTable.exitCoords.x, houseTable.exitCoords.y, houseTable.exitCoords.z, HouseId)
end
