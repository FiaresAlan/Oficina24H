--!strict
-- Notificações: histórico da sessão (mensagens do servidor e avaliações). Só exibe o que o servidor enviou.
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Kit)

local t = Kit.t
local Notifications = {}

export type Entry = { Text: string, Success: boolean, At: number, Read: boolean }

function Notifications.new(parent: Instance, getEntries: () -> { Entry }, onMarkRead: () -> ())
	local panel = Kit.panel(parent, t("notif_title"))

	local function render()
		panel.Clear()
		local entries = getEntries()
		Kit.button(panel.Body, t("notif_mark_read"), onMarkRead, "secondary").LayoutOrder = 0
		if #entries == 0 then
			Kit.label(panel.Body, t("notif_empty"), { TextColor3 = Theme.Muted }).LayoutOrder = 1
			return
		end
		for i = #entries, 1, -1 do
			local entry = entries[i]
			local card = Kit.card(panel.Body, #entries - i + 1)
			Kit.label(card, entry.Text, {
				TextSize = 14,
				TextColor3 = entry.Read and Theme.Muted or (entry.Success and Theme.Text or Theme.Red),
			})
		end
	end

	local open = panel.Open
	panel.Open = function()
		render()
		open()
	end
	local anyPanel: any = panel
	anyPanel.Render = render
	return panel
end

return Notifications
