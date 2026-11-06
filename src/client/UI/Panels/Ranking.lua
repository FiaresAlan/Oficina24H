--!strict
-- Ranking das oficinas ONLINE no servidor atual (não há ranking persistente entre servidores).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Kit)
local Store = require(script.Parent.Parent.Store)

local t = Kit.t
local Ranking = {}

function Ranking.new(parent: Instance)
	local panel = Kit.panel(parent, t("ranking_panel_title"))

	local function render()
		local snapshot = Store.Snapshot
		panel.Clear()
		if not snapshot then
			Kit.label(panel.Body, t("loading"), { TextColor3 = Theme.Muted })
			return
		end
		local card = Kit.card(panel.Body, 1)
		local list = snapshot.Ranking or {}
		if #list == 0 then
			Kit.label(card, t("ranking_empty"), { TextColor3 = Theme.Muted })
		end
		for position, entry in ipairs(list) do
			Kit.label(card, t("ranking_row", position, entry.Name, CustomerRules.StarsText(entry.Rating or 3.5), entry.Rating or 3.5, entry.Reputation, math.floor(entry.Price * 100 + 0.5)), {
				TextColor3 = entry.IsMe and Theme.Accent or Theme.Text, TextSize = 14,
			})
		end
	end

	Store.Changed.Event:Connect(function()
		if panel.IsOpen() then
			render()
		end
	end)
	local open = panel.Open
	panel.Open = function()
		render()
		open()
	end
	return panel
end

return Ranking
