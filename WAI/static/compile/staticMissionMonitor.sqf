local _mission = _this select 0;
local _position = _this select 1;
local _name = _this select 2;
local _triggerDist = _this select 3;
local _aiType = _this select 4;
local _aiCaching = _this select 5;
local _autoClaim = _this select 6;
local _killPercent = _this select 7;
local _lootWhenClear = _this select 8;
local _claimPlayer = _this select 9;
local _respawn = _this select 10;
local _enableRespawn = _respawn select 0;
local _respawnTimer = _respawn select 1;
local _markerOptions = _this select 11;
local _enableMarkers = _markerOptions select 0;
local _markerIndex = _markerOptions select 1;
local _showMarkerText = _markerOptions select 2;
local _showAiCount = _markerOptions select 3;
local _markWhenClear = _markerOptions select 4;
local _hero = (_aiType == "Hero");
local _respawnIndexes = [];
local _playerNear = false;
local _frozen = false;
local _cacheTime = diag_tickTime;
local _dotMarker = "WAI" + str(_mission) + "dot";
local _newCount = 0;
local _clear = false;
local _running = true;
local _time = diag_tickTime;
local _text = "";
local _markers = [];
if (_enableMarkers) then {
	_markers = DZE_ServerMarkerArray select _markerIndex;
} else {
	_markers = [];
};
local _aiCount = (WAI_MissionData select _mission) select 0;
local _crates = (WAI_MissionData select _mission) select 2;
local _aiVehicles = (WAI_MissionData select _mission) select 3;
//local _vehicles = (WAI_MissionData select _mission) select 4;
local _closestPlayer = objNull;
local _acArray = [];
local _claimed = false;
local _acTime = diag_tickTime;
local _claimTime = 0;
local _left = false;
local _leftTime = 0;
local _player = objNull;
local _warnArray = [];
local _autoMarkDot = "WAI" + str(_mission) + "autodot";
local _autoText = "";
_killPercent = _aiCount - (_aiCount * (_killPercent / 100));

if (!_lootWhenClear && !_markWhenClear) then { // Spawn loot in crates if loot when clear disabled.
	{
		[(_x select 0),(_x select 1)] call WAI_DynCrate;
	} count _crates;
};

// Add AI counter if enabled
if (_enableMarkers && _showMarkerText && _showAiCount) then {
	_text = if (_hero) then {
		["STR_CL_MISSION_HERO_COUNT",_name,_aiCount,"STR_CL_MISSION_HEROS"];
	} else {
		["STR_CL_MISSION_BANDIT_COUNT",_name,_aiCount,"STR_CL_MISSION_BANDITS"];
	};
	PVDZ_ServerMarkerSend = ["textSingle",[_dotMarker,_text]];
	publicVariable "PVDZ_ServerMarkerSend";
	(_markers select 1) set [7, _text];
	DZE_ServerMarkerArray set [_markerIndex, _markers];
};

while {_running} do {
	// Update marker text for AI counter if AI count changes
	if (_enableMarkers && _showMarkerText && _showAiCount && !_clear) then {
		// Check to see if the AI count has changed and update the marker.
		_newCount = (WAI_MissionData select _mission) select 0;
		if (_newCount != _aiCount) then {
			_aiCount = _newCount;
			_text = if (_hero) then {
				["STR_CL_MISSION_HERO_COUNT",_name,_aiCount,"STR_CL_MISSION_HEROS"];
			} else {
				["STR_CL_MISSION_BANDIT_COUNT",_name,_aiCount,"STR_CL_MISSION_BANDITS"];
			};
			PVDZ_ServerMarkerSend = ["textSingle",[_dotMarker,_text]];
			publicVariable "PVDZ_ServerMarkerSend";
			(_markers select 1) set [7, _text];
			DZE_ServerMarkerArray set [_markerIndex, _markers];
		};
	};
	
	// AI vehicles need to be refueled and filled with ammo 
	if (count _aiVehicles > 0) then {
		_aiVehicles call WAI_VehMonitor;
		// JIP invisible gunner fix
		if ((diag_tickTime - _time) > 180) then {
			{
				if (_x isKindOf "StaticWeapon") then {
					(gunner _x) action ["getout",_x];
				};
			} count _aiVehicles;
			_time = diag_tickTime;
		};
	};
	
	_playerNear = [_position,_triggerDist] call isNearPlayer;
	
	// Retrieve the AI groups in the loop to see which ones should be removed and respawned if enabled.
	local _unitGroups = (WAI_MissionData select _mission) select 1;
	
	// AI Caching
	if (_aiCaching) then {
		if (!_playerNear && !_frozen && {diag_tickTime - _cacheTime > 15}) then {
			_unitGroups call WAI_Freeze;
			_cacheTime = diag_tickTime;
			_frozen = true;
		};
		
		if (_playerNear && _frozen && {diag_tickTime - _cacheTime > 15}) then {
			_unitGroups call WAI_UnFreeze;
			_cacheTime = diag_tickTime;
			_frozen = false;
		};
	};
	
	if (_autoClaim && _enableMarkers) then {
		#include "\z\addons\dayz_server\WAI\static\compile\autoClaimStatic.sqf"	
	};
	
	// Mark When clear if enabled.
	if (!_clear && _enableMarkers && _showMarkerText && _markWhenClear) then {
		if (((WAI_MissionData select _mission) select 0) <= _killPercent) then {
			_clear = true;
			
			if (_lootWhenClear) then { // Spawn loot in crates if loot when clear enabled.
				{
					[(_x select 0),(_x select 1)] call WAI_DynCrate;
				} count _crates;
			};
			
			PVDZ_ServerMarkerSend = ["textSingle",[_dotMarker,[_name + ": Clear"]]];
			publicVariable "PVDZ_ServerMarkerSend";
			(_markers select 1) set [7, [_name + ": Clear"]];
			DZE_ServerMarkerArray set [_markerIndex, _markers];
		};
	};
	
	{
		// remove empty groups
		if (count units _x == 0) then {
			if (_enableRespawn) then {
				// Add the group array and a time stamp
				local _respawn = _x getVariable ["Respawn", nil];
				if (!isNil "_respawn") then {
					_respawnIndexes set [count _respawnIndexes, [_respawn, diag_tickTime]];
					//diag_log format ["WAI: Group %1 set to respawn.",_x];
				};
			};
			deleteGroup _x;
		};

		// remove null groups from the array
		if (isNull _x) then {
			_unitGroups = _unitGroups - [_x];
			//_unitGroups = [_unitGroups,_forEachIndex] call fnc_deleteAt;
		};
	} forEach _unitGroups;
	
	{
		if (diag_tickTime - (_x select 1) >= (_respawnTimer * 60)) then {
			// Respawn the group and remove it from the indexes array.
			(_x select 0) call WAI_SpawnGroup;
			_respawnIndexes = [_respawnIndexes, _forEachIndex] call fnc_deleteAt;
		};
	} forEach _respawnIndexes;
	
	//diag_log _unitGroups; // Used for testing
	
	// When all groups have been removed from the array, shut the loop down
	if (!_enableRespawn) then {
		if (count _unitGroups == 0) then {_running = false;};
	};
	uiSleep 1;
};

diag_log "WAI: All Static Spawns have been killed.";
WAI_MissionData set [_mission, -1];
