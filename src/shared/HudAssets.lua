--!strict
-- Imagens do HUD recortadas da imagem de referência (tools/slice_hud_reference.py) e enviadas pela Open Cloud como Decal;
-- aqui ficam os ids das IMAGENS (obtidos com InsertService:LoadAsset a partir do id do Decal). Ver assets/hud_sprites/_decal_ids.json.
local HudAssets = {}

local ids: { [string]: number } = {
	logo = 97940944572430,
	star_level = 100263753897541,
	dollar = 123037501481690,
	trophy_top = 77360312137184,
	bell = 132522603890155,
	gear = 94120599044065,
	exit = 74939650554614,
	clipboard = 83997903453675, -- versão laranja (botão selecionado)
	b_clipboard = 104256773971648, -- versão branca
	cap = 86905137226731,
	store = 133938347222794,
	box = 112369036004414,
	person = 94642207694037,
	b_cap = 81117354950222,
	b_cart = 94246075554213,
	b_box = 110527898167186,
	b_trophy = 115972239670754,
	car_icon = 91117111364094,
	people = 99438629111929,
	check_ok = 85094357514451,
	star_gold = 118667046082561,
	chart = 94163781596565,
	photo_hood = 74736464794898,
	photo_shop = 87196516725023,
	photo_blue = 109007814491989,
	-- painéis (assets/hud_sprites/pn_*, recortados de assets/hud_ref/panels_reference.webp)
	pn_c_body = 82511998792731, pn_c_brake = 75716908792929, pn_c_cart = 136781737763738, pn_c_elec = 110088792232460,
	pn_c_misc = 81582855750523, pn_c_motor = 107908245084580, pn_c_susp = 80877032240904, pn_c_tire = 107580758426987,
	pn_car_empty = 105108043385744, pn_chat = 94300155807833, pn_chev = 135040901812079, pn_empty_box = 79063838703131,
	pn_h_box = 120597153237911, pn_h_cap = 109362522048156, pn_h_cart = 90633372210574, pn_h_clip = 115565667113551,
	pn_h_store = 136646741040310, pn_hourglass = 137969038252095, pn_o_check = 83731475886950, pn_o_clock = 87783303756216,
	pn_o_wrench = 132560609492506, pn_p_people = 114839133138010, pn_p_refresh = 88117808518925, pn_p_star = 119644392835321,
	pn_photo_engine = 74384098410435, pn_photo_shop = 81743349670653, pn_prod_battery = 129486931336699,
	pn_prod_plug = 89894053605324, pn_s_elec = 127395104216235, pn_s_motor = 82036655702252, pn_s_paint = 115638196098381,
	pn_s_susp = 112386215522939, pn_s_wheel = 105979820929773, pn_search = 108177984286005, pn_star_o = 129335229118034,
	pn_t_bottle = 128397974299727, pn_t_chest = 74539797729554, pn_t_clock = 112114704028640, pn_t_gear = 123397457186992,
	pn_t_home = 116539181786579, pn_t_star = 128821516988931, pn_t_tag = 89802214494515, pn_t_trophy = 120599797456004,
	pn_t_wrench = 114781304203767,
}

function HudAssets.get(name: string): string
	local id = ids[name]
	return id and ("rbxassetid://" .. id) or ""
end

return HudAssets
