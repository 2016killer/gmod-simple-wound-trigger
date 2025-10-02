AddCSLuaFile();

local HITGROUP_WOUND_SIZE = {
	[HITGROUP_HEAD] = {
		[DMG_BULLET] = Vector(5, 3, 3),        -- 子弹伤
		[DMG_SLASH] = Vector(5, 5, 1.5),       -- 刀伤
		[DMG_BLAST] = Vector(5, 3, 3),         -- 爆炸伤
		[DMG_CLUB] = Vector(5, 3, 3),          -- 钝器伤
		[DMG_PLASMA] = Vector(5, 3, 3),        -- 等离子伤
		[DMG_BLAST_SURFACE] = Vector(5, 3, 3), -- 表面爆炸伤

		[DMG_AIRBOAT] = Vector(5, 3, 3),       -- 气垫船枪伤
		[bit.bor(DMG_AIRBOAT, DMG_BULLET)] = Vector(5, 3, 3),

		[DMG_BUCKSHOT] = Vector(5, 3, 3),      -- 霰弹伤
		[bit.bor(DMG_BUCKSHOT, DMG_BULLET)] = Vector(5, 3, 3),
		    
		[DMG_SNIPER] = Vector(5, 3, 3),        -- 狙击伤
		[bit.bor(DMG_SNIPER, DMG_BULLET)] = Vector(5, 3, 3),


		[DMG_MISSILEDEFENSE] = Vector(5, 3, 3) -- 导弹类伤害
	},
	[HITGROUP_CHEST] = {
		[DMG_BULLET] = Vector(5, 3, 3),
		[DMG_SLASH] = Vector(5, 8, 1.5),
		[DMG_BLAST] = Vector(5, 7, 7), 
		[DMG_CLUB] = Vector(5, 3, 3),  
		[DMG_PLASMA] = Vector(5, 5, 5),  
		[DMG_BLAST_SURFACE] = Vector(5, 7, 7),

		[DMG_AIRBOAT] = Vector(5, 6, 6),
		[bit.bor(DMG_AIRBOAT, DMG_BULLET)] = Vector(5, 6, 6),

		[DMG_BUCKSHOT] = Vector(5, 6, 6),
		[bit.bor(DMG_BUCKSHOT, DMG_BULLET)] = Vector(5, 6, 6),

		[DMG_SNIPER] = Vector(8, 3, 3),
		[bit.bor(DMG_SNIPER, DMG_BULLET)] = Vector(8, 3, 3),

		[DMG_MISSILEDEFENSE] = Vector(5, 7, 7)
	},
	[HITGROUP_STOMACH] = nil,
	[HITGROUP_LEFTARM] = nil,
	[HITGROUP_RIGHTARM] = nil,
	[HITGROUP_LEFTLEG] = nil,
	[HITGROUP_RIGHTLEG] = nil
}

HITGROUP_WOUND_SIZE[HITGROUP_STOMACH] = HITGROUP_WOUND_SIZE[HITGROUP_CHEST]
HITGROUP_WOUND_SIZE[HITGROUP_LEFTARM] = HITGROUP_WOUND_SIZE[HITGROUP_HEAD]
HITGROUP_WOUND_SIZE[HITGROUP_RIGHTARM] = HITGROUP_WOUND_SIZE[HITGROUP_HEAD]
HITGROUP_WOUND_SIZE[HITGROUP_LEFTLEG] = HITGROUP_WOUND_SIZE[HITGROUP_HEAD]
HITGROUP_WOUND_SIZE[HITGROUP_RIGHTLEG] = HITGROUP_WOUND_SIZE[HITGROUP_HEAD]


local HITGROUP_BONE_MAP = {
	[HITGROUP_HEAD] = 'ValveBiped.Bip01_Head1',
	[HITGROUP_CHEST] = 'ValveBiped.Bip01_Spine2',
	[HITGROUP_STOMACH] = 'ValveBiped.Bip01_Pelvis',
	[HITGROUP_LEFTARM] = 'ValveBiped.Bip01_L_UpperArm',
	[HITGROUP_RIGHTARM] = 'ValveBiped.Bip01_R_UpperArm',
	[HITGROUP_LEFTLEG] = 'ValveBiped.Bip01_L_Thigh',
	[HITGROUP_RIGHTLEG] = 'ValveBiped.Bip01_R_Thigh',
}

local IsSinglePlayer = game.SinglePlayer()


local function GetBoneIdByHitgroup(ent, hitgroup)
	local bonename = HITGROUP_BONE_MAP[hitgroup] or 'ValveBiped.Bip01_Pelvis'
	return ent:LookupBone(bonename) or 0
end

local function GetWoundSize(ent, hitgroup, dmgtype)
	return (HITGROUP_WOUND_SIZE[hitgroup] or HITGROUP_WOUND_SIZE[HITGROUP_HEAD])[dmgtype]
end



if SERVER then
	util.AddNetworkString('swt_apply_easy')

	local function ApplySimpWoundEasy(ent, pos, dir, hitgroup, dmgtype)
		local woundsize = GetWoundSize(ent, hitgroup, dmgtype)
		if not woundsize then
			return
		end
		local boneid = GetBoneIdByHitgroup(ent, hitgroup)
		local boneMatrix = ent:GetBoneMatrix(boneid) or Matrix()
		local woundtransform = Matrix()
		woundtransform:Translate(pos)
		woundtransform:SetAngles(dir:Angle())
		woundtransform:SetScale(woundsize)
		woundtransform = boneMatrix:GetInverse() * woundtransform

		net.Start('swt_apply_easy')
			if IsSinglePlayer then
				net.WriteEntity(ent)
			else
				net.WriteInt(ent:EntIndex(), 32)
			end

			net.WriteMatrix(woundtransform)
			net.WriteInt(boneid, 32)
		net.SendPVS(pos)
	end

	local swt_enable_sv = CreateConVar('swt_enable_sv', '1', {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_CLIENTCMD_CAN_EXECUTE}, '')

	hook.Add('ScaleNPCDamage', 'simpwoundtrigger' , function(npc, hitgroup, dmginfo)
		-- 伤口参数初始化
		if not IsValid(npc) or not swt_enable_sv:GetBool() then 
			return 
		end
		
		local dmg = dmginfo:GetDamage()
		if dmg > npc:Health() then
			local params = {
				pos = dmginfo:GetDamagePosition(),
				dir = -dmginfo:GetDamageForce(),
				dmg = dmg,
				dmgtype = dmginfo:GetDamageType(),
				hitgroup = hitgroup
			}

			npc.swt_params = params
		end
	end)

	hook.Add('CreateEntityRagdoll', 'simpwoundtrigger', function(ent, rag)
		if not ent.swt_params then
			return
		end

		local succ, err = pcall(ApplySimpWoundEasy, 
			rag,
			ent.swt_params.pos,
			ent.swt_params.dir,
			ent.swt_params.hitgroup,
			ent.swt_params.dmgtype
		)

		if not succ then
			print(err)
		end
	end)
end


if CLIENT then
	SWTData = SWTData or {}

	function SWTLoadDataFile(path)
		if file.Exists(path, 'GAME') then
			local content = file.Read(path, 'GAME')
			if content then
				local data = util.JSONToTable(content)
				if data then
					return data
				end
			end
		end
	end

	function SWTAppendDataFile(path)
		if file.Exists(path, 'GAME') then
			local content = file.Read(path, 'GAME')
			if content then
				local data = util.JSONToTable(content)
				if data then
					for model, wounddata in pairs(data) do
						SWTData[model] = wounddata
					end
				end
			end
		end
	end

	SWTAppendDataFile('data/swt/default.json')

	local datafiles = file.Find('data/swt/*.json', 'GAME', 'nameasc')
	print('[simpwoundtrigger]: loading---------------')
	for _, filename in pairs(datafiles) do
		print(filename)
		if filename == 'default.json' then
			continue
		end
		
		SWTAppendDataFile('data/swt/' .. filename)
	end
	print('[simpwoundtrigger]: loading done---------------')
	
	local swt_enable = CreateClientConVar('swt_enable', '1', true, false)
	local swt_litegorec = CreateClientConVar('swt_litegorec', '0', true, false)
	local swt_ws = CreateClientConVar('swt_ws', '1', true, false)
	local swt_bs = CreateClientConVar('swt_bs', '0.7', true, false)
	local swt_bm = CreateClientConVar('swt_bm', '0', true, false)
	local swt_deformtex = CreateClientConVar('swt_deformtex', 'models/flesh', true, false)
	local swt_projtex = CreateClientConVar('swt_projtex', 'models/flesh', true, false)
	local swt_offset = CreateClientConVar('swt_offset', 'z90', true, false)
	local swt_client_delay = CreateClientConVar('swt_client_delay', '0.3', true, false)

	local swtdata = SWTData

	local function ApplySimpWoundEasy(ent, woundLocalTransform, boneid)
		if IsValid(ent) then
			local modelname = ent:GetModel()
			local wounddata = swtdata[modelname]

			if istable(wounddata) and wounddata.skip then
				return
			end
			
			-- 默认伤口参数
			local shader = 'SimpWoundVertexLit'
			local woundsize_blendmode = Vector(swt_ws:GetFloat(), swt_bs:GetFloat(), swt_bm:GetInt())
			local deformedtexture = swt_deformtex:GetString()
			local projectedtexture = swt_projtex:GetString()
			local litegorec = swt_litegorec:GetInt()
			local offset = swt_offset:GetString()

			-- 自定义伤口参数
			if istable(wounddata) then
				shader = wounddata.shader or shader
				woundsize_blendmode = wounddata.woundsize_blendmode or woundsize_blendmode
				deformedtexture = wounddata.deformedtexture or deformedtexture
				projectedtexture = wounddata.projectedtexture or projectedtexture
				litegorec = wounddata.litegorec or litegorec
				offset = wounddata.offset or offset
			end

			local modelent = SimpWound.GetClientModel(modelname)
			SimpWound.ApplySimpWound(ent, {
				shader = shader,
				woundtransform = SimpWound.GetOffsetInvert(modelent, offset) * SimpWound.GetBoneMatrixSafe(modelent, boneid) * woundLocalTransform,
				woundsize_blendmode = woundsize_blendmode,
				deformedtexture = deformedtexture,
				projectedtexture = projectedtexture,
				litegorec = litegorec,
			})
		end
	end


	net.Receive('swt_apply_easy', function()
		local SimpWound = SimpWound
		if not SimpWound or not swt_enable:GetBool() then
			return
		end
		
		local ent = IsSinglePlayer and net.ReadEntity() or net.ReadInt(32)
		local woundLocalTransform = net.ReadMatrix()
		local boneid = net.ReadInt(32)
	
		if IsSinglePlayer then
			local succ, err = pcall(ApplySimpWoundEasy, ent, woundLocalTransform, boneid)
			if not succ then
				print(err)
			end
		else
			timer.Simple(swt_client_delay:GetFloat(), function()
				local succ, err = pcall(ApplySimpWoundEasy, Entity(ent), woundLocalTransform, boneid)
				if not succ then
					print(err)
				end
			end)
		end
    end)

	concommand.Add('swt_checkdata', function()
		PrintTable(SWTData)
	end)
end