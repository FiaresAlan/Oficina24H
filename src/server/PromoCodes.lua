--!strict
-- Códigos promocionais (SÓ no servidor: o cliente não consegue ler a lista antes do anúncio).
-- StartsAt/Expires em os.time() (UTC); nil = sem limite. Para lançar um código novo: adicione aqui e publique.
return {
	OFICINA24H = { Coins = 300, Text = "Bem-vindo à Oficina 24H!" },
	MECANICO = { Coins = 150, Parts = { TirePatch = 3, Battery = 1 }, Text = "Kit do mecânico" },
	TURBO = { Coins = 500, Text = "Turbinado!", Expires = 1830297600 }, -- até 2028-01-01
} :: { [string]: { Coins: number, Parts: { [string]: number }?, Text: string, StartsAt: number?, Expires: number? } }
