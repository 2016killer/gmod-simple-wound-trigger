AddCSLuaFile();

CreateConVar('swt_enable_sv', '1', {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_CLIENTCMD_CAN_EXECUTE}, '')
if CLIENT then
	CreateClientConVar('swt_enable', '1', true, false)
	CreateClientConVar('swt_litegorec', '0', true, false)
	CreateClientConVar('swt_ws', '1', true, false)
	CreateClientConVar('swt_bs', '0.7', true, false)
	CreateClientConVar('swt_bm', '0', true, false)
	CreateClientConVar('swt_deformtex', 'models/flesh', true, false)
	CreateClientConVar('swt_projtex', 'models/flesh', true, false)
	CreateClientConVar('swt_offset', 'z90', true, false)
	CreateClientConVar('swt_client_delay', '0.3', true, false)

	hook.Add('PopulateToolMenu', 'simpwoundtrigger', function()
		spawnmenu.AddToolMenuOption('Utilities', language.GetPhrase('#swt.menu.category'), 'simpwoundtrigger', '#swt.menu.name', '', '', function(panel) 
			panel:Clear()
			
			local items = {
				'models/flesh',
				'models/props_c17/paper01',
				'models/props_foliage/tree_deciduous_01a_trunk',
				'models/props_wasteland/wood_fence01a'
			}
			panel:CheckBox(
				'#swt.var.enable_sv', 
				'swt_enable_sv'
			)

			panel:CheckBox(
				'#swt.var.enable', 
				'swt_enable'
			)
			
			panel:CheckBox(
				'#swt.var.litegorec', 
				'swt_litegorec'
			)
			
			panel:NumSlider('#swt.var.bs', 'swt_bs', 0, 1, 2)

			panel:Help('#swt.var.deformtex')
			local MatSelect = vgui.Create('MatSelect', panel)
			MatSelect:Dock(TOP)
			Derma_Hook(MatSelect.List, 'Paint', 'Paint', 'Panel')

			panel:AddItem(MatSelect)
			MatSelect:SetConVar('swt_deformtex')

			MatSelect:SetAutoHeight(true)
			MatSelect:SetItemWidth(64)
			MatSelect:SetItemHeight(64)

			for k, material in pairs(items) do
				MatSelect:AddMaterial(material, material)
			end

			panel:Help('#swt.var.projtex')
			local MatSelect2 = vgui.Create('MatSelect', panel)
			MatSelect2:Dock(TOP)
			Derma_Hook(MatSelect2.List, 'Paint', 'Paint', 'Panel')

			panel:AddItem(MatSelect2)
			MatSelect2:SetConVar('swt_projtex')

			MatSelect2:SetAutoHeight(true)
			MatSelect2:SetItemWidth(64)
			MatSelect2:SetItemHeight(64)

			for k, material in pairs(items) do
				MatSelect2:AddMaterial(material, material)
			end
		end)
	end )
	


end


























