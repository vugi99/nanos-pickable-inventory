
Package.Export("CharactersInventories", {})


function GetCharacterInventoryID(char)
    for i, v in ipairs(CharactersInventories) do
        if v.char == char then
            return i
        end
    end
    return false
end
Package.Export("GetCharacterInventoryID", GetCharacterInventoryID)

function GetCharacterInventory(char)
    for i, v in ipairs(CharactersInventories) do
        if v.char == char then
            return v
        end
    end
    return false
end
Package.Export("GetCharacterInventory", GetCharacterInventory)


local function FakeWeaponDestroy(v)
    if (v.weapon:IsValid() and not v.in_void) then
        v.in_void = true

        local char = v.weapon:GetHandler()
        if char then
            v.destroying = true
            char:Drop()
        end

        v.weapon:SetVisibility(false)
        v.weapon:SetGravityEnabled(false)
        v.weapon:SetCollision(CollisionType.NoCollision)
        v.weapon:SetPickable(false)

        --print("FakeWeaponDestroy", v.weapon)
    end
end

local function UnvoidWeapon(v)
    if (v.weapon:IsValid() and v.in_void) then
        v.in_void = false

        v.weapon:SetVisibility(true)
        v.weapon:SetGravityEnabled(true)
        v.weapon:SetCollision(CollisionType.Normal)
        v.weapon:SetPickable(true)
    end
end


function GenerateWeaponToInsert(char, pickable, slot)
    local tbl = {
        slot = slot,
        weapon = pickable,
    }
    --Events.CallRemote("UpdateInventoryWeapon", ply, tbl)
    return tbl
end

function GetInsertSlot(Inv)
    if Inv then
        local empty_slots = {}
        for i = 1, Inv.slots_nb do
            empty_slots[i] = true
        end
        for k, v in pairs(Inv.weapons) do
            empty_slots[v.slot] = false
        end
        for k, v in pairs(empty_slots) do
            if v then
                return tonumber(k)
            end
        end
        return Inv.selected_slot
    else
        return 1
    end
end

local function GiveInventoryPlayerWeapon(char, v)
    if (v.weapon and v.weapon:IsValid()) then
        if v.in_void then
            UnvoidWeapon(v)
        end

        v.weapon:SetValue("pinvInternalPickup", true, false)

        char:PickUp(v.weapon)
    else
        Console.Warn("[PInv] : The inventory is not being used correctly")
    end
end

function EquipSlot(char, slot)
    --print("EquipSlot", char:GetID(), slot)
    local charInvID = GetCharacterInventoryID(char)
    if charInvID then
        local Inv = CharactersInventories[charInvID]
        if slot <= Inv.slots_nb then
            if slot ~= Inv.selected_slot then
                for i, v in ipairs(Inv.weapons) do
                    if (v.slot == Inv.selected_slot and v.weapon) then
                        FakeWeaponDestroy(v)
                        break
                    end
                end
                for i, v in ipairs(Inv.weapons) do
                    if v.slot == slot then
                        GiveInventoryPlayerWeapon(char, v)
                        break
                    end
                end
                Inv.selected_slot = slot
                Events.Call("UpdateSelectedSlot", char, Inv.selected_slot)
            else
                for i, v in ipairs(Inv.weapons) do
                    if (v.slot == Inv.selected_slot) then
                        GiveInventoryPlayerWeapon(char, v)
                    end
                end
            end
            return true
        else
            return false
        end
    end
end
Package.Export("EquipSlot", EquipSlot)

function DestroyCharacterWeapon(char, slot)
    local charInvID = GetCharacterInventoryID(char)
    if charInvID then
        local Inv = CharactersInventories[charInvID]
        for i, v in ipairs(Inv.weapons) do
            if v.slot == slot then
                v.destroying = true
                Events.Call("RemoveWeaponFromSlot", char, slot)
                v.weapon:Destroy()
                table.remove(Inv.weapons, i)
                return true
            end
        end
    end
    return false
end
Package.Export("DestroyCharacterWeapon", DestroyCharacterWeapon)

function AddCharacterWeapon(char, pickable, equip)
    local charInvID = GetCharacterInventoryID(char)
    if charInvID then
        local insert_sl = GetInsertSlot(CharactersInventories[charInvID])

        --[[if pickable:IsA(Grenade) then
            if not ammo_bag then
                error("Missing grenades count at AddCharacterWeapon")
                return false
            else
                pickable:SetValue("RemainingGrenades", ammo_bag, false)
            end
        end]]--

        local SlotDrop = false
        for i, v in ipairs(CharactersInventories[charInvID].weapons) do
            if v.slot == insert_sl then
                if v.weapon then
                    if not v.just_dropped then
                        v.Dropping = true
                        char:Drop()
                        v.Dropping = nil
                    else
                        Events.Call("RemoveWeaponFromSlot", char, CharactersInventories[charInvID].weapons[i].slot)
                        table.remove(CharactersInventories[charInvID].weapons, i)
                    end
                end
                SlotDrop = true
                break
            end
        end

        if not SlotDrop then
            for i, v in ipairs(CharactersInventories[charInvID].weapons) do
                if v.slot == CharactersInventories[charInvID].selected_slot then
                    if v.weapon then
                        v.just_dropped = nil
                    end
                    break
                end
            end
        end

        table.insert(CharactersInventories[charInvID].weapons, GenerateWeaponToInsert(char, pickable, insert_sl))
        if equip then
            EquipSlot(char, insert_sl)
        else
            if (insert_sl == CharactersInventories[charInvID].selected_slot) then
                EquipSlot(char, insert_sl)
            else
                for i, v in ipairs(CharactersInventories[charInvID].weapons) do
                    if v.weapon == pickable then
                        FakeWeaponDestroy(v)
                        break
                    end
                end
            end
        end
    else
        return false
    end
end
Package.Export("AddCharacterWeapon", AddCharacterWeapon)

function CreateCharacterInventory(char, slots_nb, keep_inventory_on_death, drop_on_destroy)
    local charInvID = GetCharacterInventoryID(char)
    if slots_nb <= 0 then
        error("Slots Number passed is <= 0")
    end
    if charInvID then
        return false
    else
        local insert_sl = GetInsertSlot()
        table.insert(CharactersInventories, {
            char = char,
            selected_slot = insert_sl,
            slots_nb = slots_nb,
            drop_on_destroy = drop_on_destroy,
            keep_inventory_on_death = keep_inventory_on_death,
            weapons = {},
        })
        EquipSlot(char, insert_sl)
        Events.Call("CreatedCharacterInventory", char)
        return charInvID
    end
end
Package.Export("CreateCharacterInventory", CreateCharacterInventory)

Character.Subscribe("Destroy", function(char)
    local charInvID = GetCharacterInventoryID(char)
    if charInvID then
        for i, v in ipairs(CharactersInventories[charInvID].weapons) do
            if (v.weapon and v.weapon:IsValid()) then
                Events.Call("RemoveWeaponFromSlot", char, v.slot)
                if not CharactersInventories[charInvID].drop_on_destroy then
                    v.destroying = true
                    v.weapon:Destroy()
                elseif v.in_void then
                    UnvoidWeapon(v)
                    v.weapon:SetLocation(char:GetLocation())
                end
            end
        end
        table.remove(CharactersInventories, charInvID)
    end
end)

Character.Subscribe("Death", function(char)
    local charInvID = GetCharacterInventoryID(char)
    if charInvID then
        if CharactersInventories[charInvID].keep_inventory_on_death then
            for i, v in ipairs(CharactersInventories[charInvID].weapons) do
                if (v.weapon and v.weapon:IsValid()) then
                    if not v.in_void then
                        FakeWeaponDestroy(v)
                    end
                end
            end
        else
            for i, v in ipairs(CharactersInventories[charInvID].weapons) do
                if (v.weapon and v.weapon:IsValid()) then
                    if v.in_void then
                        UnvoidWeapon(v)
                        v.weapon:SetLocation(char:GetLocation())
                    end
                    Events.Call("RemoveWeaponFromSlot", char, v.slot)
                end
            end
            CharactersInventories[charInvID].weapons = {}
        end
    end
end)

Character.Subscribe("Respawn", function(char)
    local charInvID = GetCharacterInventoryID(char)
    if charInvID then
        if CharactersInventories[charInvID].keep_inventory_on_death then
            EquipSlot(char, CharactersInventories[charInvID].selected_slot)
        end
    end
end)

local function DropInvItem(weapon, char, was_triggered_by_player)
    --print("Drop", weapon, char, was_triggered_by_player, weapon:GetAssetName())
    local charInvID = GetCharacterInventoryID(char)
    if charInvID then
        for i, v in ipairs(CharactersInventories[charInvID].weapons) do
            if (v.weapon and v.weapon == weapon) then
                if not v.destroying then
                    if (was_triggered_by_player or v.Dropping) then
                        Events.Call("RemoveWeaponFromSlot", char, CharactersInventories[charInvID].weapons[i].slot)
                        table.remove(CharactersInventories[charInvID].weapons, i)
                    end
                    v.weapon:SetPickable(true)
                    v.just_dropped = true
                else
                    v.destroying = nil
                end
                break
            end
        end
    end
end
Weapon.Subscribe("Drop", DropInvItem)
Melee.Subscribe("Drop", DropInvItem)
Grenade.Subscribe("Drop", DropInvItem)

function PickupInvItem(weapon, char)
    if not weapon:GetValue("pinvInternalPickup") then
        --AddCharacterWeapon(char, weapon, true, weapon:GetValue("RemainingGrenades"))
        AddCharacterWeapon(char, weapon, true)
    else
        weapon:SetValue("pinvInternalPickup", nil, false)
    end
end
Weapon.Subscribe("PickUp", PickupInvItem)
Melee.Subscribe("PickUp", PickupInvItem)
Grenade.Subscribe("PickUp", PickupInvItem)


Grenade.Subscribe("Throw", function(grenade, char)
    --[[local remaining_count = grenade:GetValue("RemainingGrenades")
    if remaining_count then
        local charInvID = GetCharacterInventoryID(char)
        if charInvID then

            grenade:SetPickable(false)

            for i, v in ipairs(CharactersInventories[charInvID].weapons) do
                if v.weapon == grenade then
                    CharactersInventories[charInvID].weapons[i].weapon = nil

                    CharactersInventories[charInvID].weapons[i].ammo_bag = remaining_count - 1

                    if CharactersInventories[charInvID].weapons[i].ammo_bag > 0 then
                        GiveInventoryPlayerWeapon(char, v)
                    else
                        Events.Call("RemoveWeaponFromSlot", char, CharactersInventories[charInvID].weapons[i].slot)
                        table.remove(CharactersInventories[charInvID].weapons, i)
                    end

                    break
                end
            end
        end
    end]]--

    local charInvID = GetCharacterInventoryID(char)
    if charInvID then
        grenade:SetPickable(false)
        for i, v in ipairs(CharactersInventories[charInvID].weapons) do
            if v.weapon == grenade then
                Events.Call("RemoveWeaponFromSlot", char, CharactersInventories[charInvID].weapons[i].slot)
                table.remove(CharactersInventories[charInvID].weapons, i)
                break
            end
        end
    end
end)

local function WeaponDestroyHandler(weap)
    for i, v in ipairs(CharactersInventories) do
        for i2, v2 in ipairs(v.weapons) do
            if v2.weapon == weap then
                if not v2.destroying then
                    table.remove(CharactersInventories[i].weapons, i2)
                end
                break
            end
        end
    end
end
Weapon.Subscribe("Destroy", WeaponDestroyHandler)
Melee.Subscribe("Destroy", WeaponDestroyHandler)
Grenade.Subscribe("Destroy", WeaponDestroyHandler)