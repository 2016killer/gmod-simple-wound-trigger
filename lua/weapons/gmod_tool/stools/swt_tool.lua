AddCSLuaFile()
-------------------------------UI-------------------------------
if CLIENT then
	TOOL.Category = language.GetPhrase('#tool.sw_tool.category')
	TOOL.Name = '#tool.swt_tool.name'

	TOOL.ClientConVar['skip'] = '0'
	TOOL.ClientConVar['shader'] = 'SimpWoundVertexLit'
	TOOL.ClientConVar['projtex'] = 'models/flesh'
	TOOL.ClientConVar['deformtex'] = 'models/flesh'

	list.Add('OverrideMaterials', 'swt/alienflesh')

	function TOOL.BuildCPanel(panel)
		panel:CheckBox(
			'#tool.swt_tool.skip', 
			'swt_tool_skip'
		)

		local shaderComboBox = panel:ComboBox('#tool.sw_tool.shader', 'swt_tool_shader')
		shaderComboBox:AddChoice('#sw.simpwound', 'SimpWound')
		shaderComboBox:AddChoice('#sw.simpwoundvertexlit', 'SimpWoundVertexLit')

		local materiallist = list.GetForEdit('OverrideMaterials')
		local filter = {}
		for k, matpath in pairs(materiallist) do
			filter[matpath] = matpath
		end
	
		panel:Help('#tool.sw_tool.deformtex')
		panel:MatSelect('swt_tool_deformtex', filter, nil, 64, 64)

		panel:Help('#tool.sw_tool.projtex')
		panel:MatSelect('swt_tool_projtex', filter, nil, 64, 64)
	end

	TOOL.Information = {
		{name = 'apply', icon = 'gui/lmb.png'},
		{name = 'clear', icon = 'gui/r.png'},
	}

end
--------------------------------------------------------------
if SERVER then
	util.AddNetworkString('swt_tool_apply')
	util.AddNetworkString('swt_tool_reset')
end


function TOOL:LeftClick(tr)
	local ent = tr.Entity
	if not IsValid(ent) then
		return
	end

	if CLIENT then
		return true
	end

	local ply = self:GetOwner()
	local modelname = ent:GetModel()
	local params = {
		skip = self:GetClientNumber('skip') == 1,
		shader = self:GetClientInfo('shader'),
		deformedtexture = self:GetClientInfo('deformtex'),
		projectedtexture = self:GetClientInfo('projtex'),
	}

	net.Start('swt_tool_apply')
		net.WriteString(modelname)
		net.WriteTable(params)
	net.Send(ply)

	return true
end

function TOOL:Reload(tr)
	local ent = tr.Entity
	if not IsValid(ent) then
		return
	end

	if CLIENT then
		return true
	end

	local ply = self:GetOwner()
	local modelname = ent:GetModel()

	net.Start('swt_tool_reset')
		net.WriteString(modelname)
	net.Send(ply)

	return true
end


if CLIENT then
	SWTData = SWTData or {}
	local swtdata = SWTData

	local matcache = {}
	local GetMaterial = function(matpath)
		if matcache[matpath] == nil then
			matcache[matpath] = CreateMaterial(matpath, 'UnlitGeneric', {
				['$basetexture'] = matpath
			})
		end
		return matcache[matpath]
	end

	local swt_enable = CreateClientConVar('swt_enable', '1', true, false)
	local swt_litegorec = CreateClientConVar('swt_litegorec', '0', true, false)
	local swt_ws = CreateClientConVar('swt_ws', '1', true, false)
	local swt_bs = CreateClientConVar('swt_bs', '0.7', true, false)
	local swt_bm = CreateClientConVar('swt_bm', '0', true, false)
	local swt_deformtex = CreateClientConVar('swt_deformtex', 'models/flesh', true, false)
	local swt_projtex = CreateClientConVar('swt_projtex', 'models/flesh', true, false)
	local swt_offset = CreateClientConVar('swt_offset', 'z90', true, false)


	local function DataValid(fun, key, data, errmsg)
		if not fun(data[key]) then
			return string.format('%s: %s\n', key, errmsg)
		end
		return ''
	end

	local loadpath = 'data/swt/~bytool.json'
	local savepath = 'swt/~bytool.json'
	local swtdatalocal = SWTLoadDataFile(loadpath) or {}

	net.Receive('swt_tool_apply', function()
		local modelname = net.ReadString()
		local params = net.ReadTable()

		swtdata[modelname] = params
		swtdatalocal[modelname] = params
		file.Write(savepath, util.TableToJSON(swtdatalocal, true))
		print('save', modelname)
	end)


	net.Receive('swt_tool_reset', function()
		local modelname = net.ReadString()

		swtdata[modelname] = nil
		swtdatalocal[modelname] = nil
		file.Write(savepath, util.TableToJSON(swtdatalocal, true))
		print('reset', modelname)
	end)

	function TOOL:Think()
		local tr = LocalPlayer():GetEyeTrace()
		local ent = tr.Entity
		self.params = self.params or {}
		
		if IsValid(ent) and ent ~= self.params.ent then
			self.params.ent = ent
			self.params.modelname = ent:GetModel()

			self.params.skip = false
			self.params.shader = 'SimpWoundVertexLit'
			self.params.woundsize_blendmode = Vector(swt_ws:GetFloat(), swt_bs:GetFloat(), swt_bm:GetInt())
			self.params.deformedtexture = swt_deformtex:GetString()
			self.params.projectedtexture = swt_projtex:GetString()
			self.params.litegorec = swt_litegorec:GetInt()
			self.params.offset = swt_offset:GetString()


			local customdata = swtdata[self.params.modelname]
			if istable(customdata) then
				self.params.iscustom = true

				self.params.skip = customdata.skip or self.params.skip
				self.params.shader = customdata.shader or self.params.shader
				self.params.woundsize_blendmode = customdata.woundsize_blendmode or self.params.woundsize_blendmode
				self.params.deformedtexture = customdata.deformedtexture or self.params.deformedtexture
				self.params.projectedtexture = customdata.projectedtexture or self.params.projectedtexture
				self.params.litegorec = customdata.litegorec or self.params.litegorec
				self.params.offset = customdata.offset or self.params.offset
			else
				self.params.iscustom = false
			end

			local errmsg = ''
			errmsg = errmsg .. DataValid(isstring, 'shader', self.params, language.GetPhrase('#swt.err.notstr'))
			errmsg = errmsg .. DataValid(isvector, 'woundsize_blendmode', self.params, language.GetPhrase('#swt.err.notvec'))
			errmsg = errmsg .. DataValid(isstring, 'deformedtexture', self.params, language.GetPhrase('#swt.err.notstr'))
			errmsg = errmsg .. DataValid(isstring, 'projectedtexture', self.params, language.GetPhrase('#swt.err.notstr'))
			errmsg = errmsg .. DataValid(isnumber, 'litegorec', self.params, language.GetPhrase('#swt.err.notnum'))
			errmsg = errmsg .. DataValid(isstring, 'offset', self.params, language.GetPhrase('#swt.err.notstr'))

			if errmsg ~= '' then
				self.params.errmsg = string.format('%s:\n%s', language.GetPhrase('#swt.err'), errmsg)
			else
				self.params.errmsg = ''
			end

			self.params.deformMaterials = GetMaterial(isstring(self.params.deformedtexture) and self.params.deformedtexture or 'error')
			self.params.projMaterials = GetMaterial(isstring(self.params.projectedtexture) and self.params.projectedtexture or 'error')
		end

		self.leftclick = input.IsMouseDown(MOUSE_LEFT) and not self.leftdown and not gui.IsGameUIVisible()
		if self.leftclick then
			self.params.ent = nil
		end

		self.reset = input.IsKeyDown(KEY_R) and not self.resetdown and not gui.IsGameUIVisible()
		if self.reset then
			self.params.ent = nil
		end

		self.leftdown = input.IsMouseDown(MOUSE_LEFT)
		self.resetdown = input.IsKeyDown(KEY_R)

		self.DrawInfoFlag = IsValid(ent)
	end

	local colorwhite = Color(255, 255, 255)
	local colorred = Color(255, 0, 0)
	local coloryellow = Color(255, 255, 0)
	local colorgreen = Color(0, 255, 0)
	

	local label_skip = language.GetPhrase('#swt.label.skip')
	local label_custom = language.GetPhrase('#swt.label.custom')
	local label_default = language.GetPhrase('#default')
	local label_modelname = language.GetPhrase('#swt.label.modelname')
	local label_woundtex = language.GetPhrase('#swt.label.woundtex')
	function TOOL:DrawHUD()
		if not self.DrawInfoFlag then
			return
		end

		local params = self.params

		if not istable(params) or not IsValid(params.ent) then
			return
		end

		local eyepos = EyePos()
		local pos = params.ent:GetPos() + Vector(0, 0, 50)
		local yaw = (pos - eyepos)
			yaw = math.atan2(yaw.y, yaw.x) * 57 - 90
	
		local angles = Angle(0, yaw, 90)

		cam.Start3D(eyepos, EyeAngles())
			cam.Start3D2D(pos, angles, 0.5)
				if params.iscustom then
					draw.DrawText(label_custom, 'TargetID', 
						0, 0, coloryellow, TEXT_ALIGN_LEFT)
				else
					draw.DrawText(label_default, 'TargetID', 
						0, 0, colorgreen, TEXT_ALIGN_LEFT)
				end

				if params.skip then
					draw.DrawText(label_skip, 'TargetID', 
						50, 0, coloryellow, TEXT_ALIGN_LEFT)
				end

				draw.DrawText(label_modelname .. ':' .. params.modelname, 'TargetID', 
					0, 20, colorwhite, TEXT_ALIGN_LEFT)

				draw.DrawText(label_woundtex, 'TargetID', 
					0, 40, colorwhite, TEXT_ALIGN_LEFT)

				surface.SetMaterial(params.projMaterials)
				surface.DrawTexturedRect(0, 60, 48, 48)

				surface.SetMaterial(params.deformMaterials)
				surface.DrawTexturedRect(8, 68, 32, 32)

		    	surface.SetDrawColor(255, 255, 255, 255)
				local x1, y1 = 8, 68  
				local x2, y2 = 40, 100
				
				surface.DrawLine(x1, y1, x2, y1)
				surface.DrawLine(x2, y1, x2, y2)
				surface.DrawLine(x2, y2, x1, y2)
				surface.DrawLine(x1, y2, x1, y1)

				if params.errmsg ~= '' then
					draw.DrawText(params.errmsg, 'TargetID', 
						0, 120, colorred, TEXT_ALIGN_LEFT)
				end
			cam.End3D2D() 
		cam.End3D()
	end

	local errmsg = language.GetPhrase('#sw.missmodule')
	function TOOL:DrawToolScreen(width, height)
		-- 错误提示
		if not SimpWound then
			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(0, 0, width, height)

			draw.SimpleText(
				errmsg, 
				'DermaLarge', 
				0, 
				0, 
				Color(255, 0, 0, 255), 
				TEXT_ALIGN_LEFT, 
				TEXT_ALIGN_TOP 
			)
		end
	end
end 


