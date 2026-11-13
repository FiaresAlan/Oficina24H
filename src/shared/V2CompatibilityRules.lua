--!strict
-- V2-00: somente leitura. Nao altera perfil, nao faz migracao e nao substitui QA.
local Rules = { MinSchema = 12 }
local function finiteNonnegative(value: any): boolean
    return type(value) == "number" and value == value and value ~= math.huge
        and value ~= -math.huge and value >= 0
end
function Rules.Profile(profile: any): {string}
    if type(profile) ~= "table" then return {"perfil ausente"} end
    local errors: {string} = {}
    if not finiteNonnegative(profile.SchemaVersion) or profile.SchemaVersion < Rules.MinSchema
        or profile.SchemaVersion % 1 ~= 0 then
        table.insert(errors, "schema incompatível com V1 C31")
    end
    for _, key in ipairs({"Coins", "TotalEarned", "Reputation", "Employees"}) do
        if not finiteNonnegative(profile[key]) then table.insert(errors, key .. " invalido") end
    end
    if not finiteNonnegative(profile.WorkshopLevel) or profile.WorkshopLevel > 3
        or profile.WorkshopLevel % 1 ~= 0 then
        table.insert(errors, "WorkshopLevel invalido")
    end
    for _, key in ipairs({"Parts", "SupplyRequests", "Equipment", "EquipmentLevels", "OrderHistory",
        "RepairLedger", "PendingClaims", "PendingClaimAudits", "OwnerSettlementProofs",
        "WorkerSettlementProofs", "WorkerPaidTombstones"}) do
        if type(profile[key]) ~= "table" then table.insert(errors, key .. " ausente") end
    end
    return errors
end
Rules.PrivateKeys = {"RepairLedger", "PendingClaims", "PendingClaimAudits",
    "OwnerSettlementProofs", "WorkerSettlementProofs", "WorkerPaidTombstones"}
function Rules.Snapshot(snapshot: any): {string}
    if type(snapshot) ~= "table" or type(snapshot.Profile) ~= "table" then
        return {"snapshot sem perfil"}
    end
    local errors: {string} = {}
    for _, key in ipairs(Rules.PrivateKeys) do
        if snapshot.Profile[key] ~= nil then
            table.insert(errors, "informacao privada replicada: " .. key)
        end
    end
    if type(snapshot.Jobs) ~= "table" then table.insert(errors, "Jobs ausente") end
    return errors
end
return Rules
