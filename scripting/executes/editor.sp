int g_iBeamSprite = 0;
int g_iHaloSprite = 0;

public void StartEditMode() {
  g_EditMode = true;
  StartPausedWarmup();

  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && !IsFakeClient(i)) {
      MovePlayerToEditMode(i);
    }
  }

  Executes_MessageToAll("Edit mode launched, type !edit to open the edit menu");

  if (LibraryExists("practicemode")) {
    PM_StartPracticeMode();
  }

  ServerCommand("sv_infinite_ammo 1");
}

public void ExitEditMode() {
  g_EditMode = false;

  if (LibraryExists("practicemode")) {
    PM_ExitPracticeMode();
  }

  ServerCommand("sv_infinite_ammo 0");

  if (InWarmup()) {
    ServerCommand("mp_warmup_end");
  } else {
    ServerCommand("mp_restartgame 1");
  }
}

public void CSU_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3],
                        const float velocity[3]) {
  LogDebug("CSU_OnThrowGrenade %L %d", client, grenadeType);
  if (g_EditMode && CheckCommandAccess(client, "sm_edit", ADMFLAG_CHANGEMAP)) {
    g_EditingSpawnGrenadeType[client] = grenadeType;
    g_EditingSpawnNadePoint[client] = origin;
    g_EditingSpawnNadeVelocity[client] = velocity;

    // TODO: add a way to disable this
    if (!g_EditingExecutes[client]) {
      GiveNewSpawnMenu(client);
    }
  }
}

public void MovePlayerToEditMode(int client) {
  SwitchPlayerTeam(client, CS_TEAM_T);
  CS_RespawnPlayer(client);
}

// public void ShowSpawns(Bombsite site) {
//     g_EditingSite = site;
//     Executes_MessageToAll("Showing spawns for bombsite \x04%s.", SITESTRING(site));

//     int ct_count = 0;
//     int t_count = 0;
//     for (int i = 0; i < g_NumSpawns; i++) {
//         if (!g_SpawnDeleted[i]) {
//             if (g_SpawnTeams[i] == CS_TEAM_CT) {
//                 ct_count++;
//             } else {
//                 t_count++;
//             }
//         }
//     }
//     Executes_MessageToAll("Found %d CT spawns.", ct_count);
//     Executes_MessageToAll("Found %d T spawns.", t_count);
// }

public Action Timer_ShowSpawns(Handle timer) {
  if (!g_EditMode || g_hEditorEnabled.IntValue == 0 || !g_ShowingEditorInformation)
    return Plugin_Continue;

  g_iBeamSprite = PrecacheModel("sprites/laserbeam.vmt", true);
  g_iHaloSprite = PrecacheModel("sprites/halo.vmt", true);
  float origin[3];
  float angle[3];

  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i) || IsFakeClient(i)) {
      continue;
    }

    for (int j = 0; j < g_NumSpawns; j++) {
      origin = g_SpawnPoints[j];
      angle = g_SpawnPoints[j];
      if (!g_SpawnDeleted[j]) {
        DisplaySpawnPoint(i, origin, angle, 40.0, g_SpawnTeams[j] == CS_TEAM_CT);
      }
    }
  }

  return Plugin_Continue;
}

public Action Timer_ShowClosestSpawn(Handle timer) {
  if (!g_EditMode || g_hEditorEnabled.IntValue == 0 || !g_ShowingEditorInformation)
    return Plugin_Continue;

  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i) || IsFakeClient(i)) {
      continue;
    }

    int closest = FindClosestSpawn(i);
    if (closest > 0) {
      bool ct = g_SpawnTeams[closest] == CS_TEAM_CT;
      // TODO: color this text red/blue whether ct or T
      PrintHintText(i, "%s Spawn %s: \"%s\"", ct ? "CT" : "T", g_SpawnIDs[closest],
                    g_SpawnNames[closest]);
    }
  }

  return Plugin_Continue;
}

stock bool SpawnFilter(int spawn) {
  if (!IsValidSpawn(spawn) || g_SpawnDeleted[spawn]) {
    return false;
  }

  return true;
}

stock void AddSpawn(int client) {
  g_DirtySpawns = true;
  if (g_NumSpawns + 1 >= MAX_SPAWNS) {
    Executes_MessageToAll(
        "{DARK_RED}WARNING: {NORMAL}the maximum number of spawns has been reached. New spawns cannot be added.");
    LogError("Maximum number of spawns reached");
    return;
  }

  int spawnIndex = g_NumSpawns;
  if (g_EditingASpawn[client]) {
    spawnIndex = g_EditingSpawnIndex[client];
  }

  strcopy(g_SpawnNames[spawnIndex], SPAWN_NAME_LENGTH, g_EditingNameBuffer[client]);

  if (!g_EditingASpawn[client]) {
    IntToString(g_NextSpawnId, g_SpawnIDs[spawnIndex], ID_LENGTH);
    g_NextSpawnId++;
  }

  GetClientAbsOrigin(client, g_SpawnPoints[spawnIndex]);
  GetClientEyeAngles(client, g_SpawnAngles[spawnIndex]);
  g_SpawnTeams[spawnIndex] = g_EditingSpawnTeam[client];
  g_SpawnGrenadeTypes[spawnIndex] = g_EditingSpawnGrenadeType[client];

  g_SpawnNadePoints[spawnIndex] = g_EditingSpawnNadePoint[client];
  g_SpawnNadeVelocities[spawnIndex] = g_EditingSpawnNadeVelocity[client];
  g_SpawnSiteFriendly[spawnIndex] = g_EditingSpawnSiteFriendly[client];
  g_SpawnAwpFriendly[spawnIndex] = g_EditingSpawnAwpFriendly[client];
  g_SpawnBombFriendly[spawnIndex] = g_EditingSpawnBombFriendly[client];
  g_SpawnLikelihood[spawnIndex] = g_EditingSpawnLikelihood[client];
  g_SpawnGrenadeThrowTimes[spawnIndex] = g_EditingSpawnThrowTime[client];
  g_SpawnFlags[spawnIndex] = g_EditingSpawnFlags[client];

  g_SpawnDeleted[spawnIndex] = false;
  ClearSpawnBuffers(client);

  if (!g_EditingASpawn[client]) {
    Executes_MessageToAll("Added %s spawn (id:%s).", TEAMSTRING(g_EditingSpawnTeam[client]),
                          g_SpawnIDs[spawnIndex]);

    g_NumSpawns++;
  } else {
    Executes_MessageToAll("Edited %s spawn (id:%s).", TEAMSTRING(g_EditingSpawnTeam[client]),
                          g_SpawnIDs[spawnIndex]);
  }

  g_EditingASpawn[client] = false;
  g_EditingSpawnThrowTime[client] = DEFAULT_THROWTIME;
  g_EditingSpawnFlags[client] = 0;
  g_EditingSpawnGrenadeType[client] = GrenadeType_None;
}

public void ClearSpawnBuffers(int client) {
  Format(g_EditingNameBuffer[client], TEMP_NAME_LENGTH, "");
  g_EditingASpawn[client] = false;
  g_EditingSpawnIndex[client] = -1;
  g_EditingSpawnTeam[client] = CS_TEAM_T;
  g_EditingSpawnGrenadeType[client] = GrenadeType_None;
  g_EditingSpawnSiteFriendly[client] = {MIN_FRIENDLINESS, MIN_FRIENDLINESS};
  g_EditingSpawnAwpFriendly[client] = AVG_FRIENDLINESS;
  g_EditingSpawnBombFriendly[client] = AVG_FRIENDLINESS;
  g_EditingSpawnLikelihood[client] = AVG_FRIENDLINESS;
}

public void ClearExecuteBuffers(int client) {
  Format(g_EditingExecuteForceBombId[client], 16, "");
  Format(g_EditingNameBuffer[client], TEMP_NAME_LENGTH, "");
  g_EditingExecuteTRequired[client] = new ArrayList(ID_LENGTH);
  g_EditingExecuteTOptional[client] = new ArrayList(ID_LENGTH);
  g_EditingExecuteStratTypes[client][StratType_Normal] = true;
  g_EditingExecuteStratTypes[client][StratType_Pistol] = false;
  g_EditingExecuteStratTypes[client][StratType_ForceBuy] = false;
  g_EditingExecuteFake[client] = false;
}

public void ClearAllEditBuffers() {
  for (int i = 1; i <= MaxClients; i++) {
    ClearExecuteBuffers(i);
    ClearEditBuffers(i);
  }
}

public void AddExecute(int client) {
  g_DirtySpawns = true;
  if (g_NumExecutes + 1 >= MAX_EXECUTES) {
    Executes_MessageToAll(
        "{DARK_RED}WARNING: {NORMAL}the maximum number of spawns has been reached. New spawns cannot be added.");
    LogError("Maximum number of spawns reached");
    return;
  }

  int execIndex = g_NumExecutes;
  if (g_EditingAnExecute[client]) {
    execIndex = g_EditingExecuteIndex[client];
  }

  strcopy(g_ExecuteNames[execIndex], EXECUTE_NAME_LENGTH, g_EditingNameBuffer[client]);

  if (!g_EditingAnExecute[client]) {
    IntToString(g_NextExecuteId, g_ExecuteIDs[execIndex], ID_LENGTH);
    g_NextExecuteId++;
  }

  g_ExecuteLikelihood[execIndex] = AVG_FRIENDLINESS;
  g_ExecuteSites[execIndex] = g_EditingExecuteSite[client];
  g_ExecuteDeleted[execIndex] = false;
  g_ExecuteLikelihood[execIndex] = g_EditingExecuteLikelihood[client];
  strcopy(g_ExecuteForceBombId[execIndex], ID_LENGTH, g_EditingExecuteForceBombId[client]);

  g_ExecuteTSpawnsRequired[execIndex].Clear();
  g_ExecuteTSpawnsOptional[execIndex].Clear();
  CopyList(g_EditingExecuteTRequired[client], g_ExecuteTSpawnsRequired[execIndex]);
  CopyList(g_EditingExecuteTOptional[client], g_ExecuteTSpawnsOptional[execIndex]);
  g_ExecuteStratTypes[execIndex] = g_EditingExecuteStratTypes[client];
  g_ExecuteFake[execIndex] = g_EditingExecuteFake[client];

  ClearExecuteBuffers(client);

  if (!g_EditingAnExecute[client]) {
    Executes_MessageToAll("Added %s execute (id:%s).", SITESTRING(g_EditingExecuteSite[client]),
                          g_ExecuteIDs[execIndex]);
    g_NumExecutes++;
  } else {
    Executes_MessageToAll("Edited %s execute (id:%s).", SITESTRING(g_EditingExecuteSite[client]),
                          g_ExecuteIDs[execIndex]);
  }

  g_EditingAnExecute[client] = false;
  g_EditingExecuteLikelihood[client] = AVG_FRIENDLINESS;
}

public void DisplaySpawnPoint(int client, const float position[3], const float angles[3], float size,
                       bool ct) {
  float direction[3];
  GetAngleVectors(angles, direction, NULL_VECTOR, NULL_VECTOR);
  ScaleVector(direction, size / 2);
  AddVectors(position, direction, direction);

  int r, g, b;
  if (ct) {
    // blue
    r = 0;
    g = 0;
    b = 255;
  } else {
    // red
    r = 255;
    g = 0;
    b = 0;
  }

  TE_Start("BeamRingPoint");
  TE_WriteVector("m_vecCenter", position);
  TE_WriteFloat("m_flStartRadius", 10.0);
  TE_WriteFloat("m_flEndRadius", size);
  TE_WriteNum("m_nModelIndex", g_iBeamSprite);
  TE_WriteNum("m_nHaloIndex", g_iHaloSprite);
  TE_WriteNum("m_nStartFrame", 0);
  TE_WriteNum("m_nFrameRate", 0);
  TE_WriteFloat("m_fLife", 1.0);
  TE_WriteFloat("m_fWidth", 1.0);
  TE_WriteFloat("m_fEndWidth", 1.0);
  TE_WriteFloat("m_fAmplitude", 0.0);
  TE_WriteNum("r", r);
  TE_WriteNum("g", g);
  TE_WriteNum("b", b);
  TE_WriteNum("a", 255);
  TE_WriteNum("m_nSpeed", 50);
  TE_WriteNum("m_nFlags", 0);
  TE_WriteNum("m_nFadeLength", 0);
  TE_SendToClient(client);

  TE_Start("BeamPoints");
  TE_WriteVector("m_vecStartPoint", position);
  TE_WriteVector("m_vecEndPoint", direction);
  TE_WriteNum("m_nModelIndex", g_iBeamSprite);
  TE_WriteNum("m_nHaloIndex", g_iHaloSprite);
  TE_WriteNum("m_nStartFrame", 0);
  TE_WriteNum("m_nFrameRate", 0);
  TE_WriteFloat("m_fLife", 1.0);
  TE_WriteFloat("m_fWidth", 1.0);
  TE_WriteFloat("m_fEndWidth", 1.0);
  TE_WriteFloat("m_fAmplitude", 0.0);
  TE_WriteNum("r", r);
  TE_WriteNum("g", g);
  TE_WriteNum("b", b);
  TE_WriteNum("a", 255);
  TE_WriteNum("m_nSpeed", 50);
  TE_WriteNum("m_nFlags", 0);
  TE_WriteNum("m_nFadeLength", 0);
  TE_SendToClient(client);
}

stock int FindClosestSpawn(int client) {
  int closest = -1;
  float minDist = 0.0;
  for (int i = 0; i < g_NumSpawns; i++) {
    if (!SpawnFilter(i)) {
      continue;
    }

    float origin[3];
    origin = g_SpawnPoints[i];

    float playerOrigin[3];
    GetClientAbsOrigin(client, playerOrigin);

    float dist = GetVectorDistance(origin, playerOrigin);
    if (closest < 0 || dist < minDist) {
      minDist = dist;
      closest = i;
    }
  }
  return closest;
}

public int CountSpawnUse(int spawn) {
  int count = 0;
  for (int i = 0; i < g_NumExecutes; i++) {
    if (!g_ExecuteDeleted[i]) {
      bool required = g_ExecuteTSpawnsRequired[i].FindString(g_SpawnIDs[spawn]) >= 0;
      bool opt = g_ExecuteTSpawnsOptional[i].FindString(g_SpawnIDs[spawn]) >= 0;
      if (required || opt) {
        count++;
      }
    }
  }
  return count;
}

public void DeleteClosestSpawn(int client) {
  g_DirtySpawns = true;
  int closestSpawnIndex = FindClosestSpawn(client);
  if (IsValidSpawn(closestSpawnIndex)) {
    int useCount = CountSpawnUse(closestSpawnIndex);
    if (useCount >= 1) {
      Executes_MessageToAll("Cannot delete spawn since it is used in %d executes.", useCount);
    } else {
      Executes_MessageToAll("Deleted spawn id %s.", g_SpawnIDs[closestSpawnIndex]);
      g_SpawnDeleted[closestSpawnIndex] = true;
    }
  }
}

public void SaveMapData() {
  WriteMapConfig();
  Executes_MessageToAll("Saved map data, %d spawns, %d executes.", g_NumSpawns, g_NumExecutes);
}

public void ReloadMapData() {
  ReadMapConfig();
  Executes_MessageToAll("Reloaded map data, got %d spawns, %d executes.", g_NumSpawns,
                        g_NumExecutes);
}

public void MoveToSpawnInEditor(int client, int spawnIndex) {
  TeleportEntity(client, g_SpawnPoints[spawnIndex], g_SpawnAngles[spawnIndex], NULL_VECTOR);
  Executes_Message(client, "Teleporting to spawn id: {GREEN}%s", g_SpawnIDs[spawnIndex]);
  Executes_Message(client, "   Name: {MOSS_GREEN}%s", g_SpawnNames[spawnIndex]);
  Executes_Message(client, "   Team: {MOSS_GREEN}%s", TEAMSTRING(g_SpawnTeams[spawnIndex]));
}

public void GrenadeTypeName(GrenadeType grenadeType, char[] buf, int len) {
  switch (grenadeType) {
    case GrenadeType_Smoke:
      Format(buf, len, "smoke");
    case GrenadeType_Flash:
      Format(buf, len, "flash");
    case GrenadeType_Molotov:
      Format(buf, len, "molotov");
    default:
      Format(buf, len, "none");
  }
}

public Action Command_ClearBuffers(int client, int args) {
  ClearEditBuffers(client);
  char clientName[MAX_NAME_LENGTH];
  char finalMsg[1024];
  GetClientName(client, clientName, sizeof(clientName));
  Format(finalMsg, sizeof(finalMsg), "%s %s", "Cleared edit buffers for", clientName);
  Executes_MessageToAll(finalMsg);
  return Plugin_Handled;
}

public void ClearEditBuffers(int client) {
  g_EditingSpawnGrenadeType[client] = GrenadeType_None;
  ClearExecuteBuffers(client);
  ClearSpawnBuffers(client);
}

public Action Command_ExecuteDistribution(int client, int args) {
  if (g_NumExecutes == 0) {
    ReplyToCommand(client, "No executes found");
  } else {
    char arg[32];
    if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
      int numt = StringToInt(arg);

      ArrayList potentialExecutes = new ArrayList();
      for (int i = 0; i < g_NumExecutes; i++) {
        int weight = ExecuteValid(numt, 5, i);
        AddRepeatedElement(potentialExecutes, i, weight);
      }

      for (int i = 0; i < g_NumExecutes; i++) {
        if (!g_ExecuteDeleted[i]) {
          float p = float(CountArrayListOccurances(potentialExecutes, i)) /
                    float(potentialExecutes.Length);
          ReplyToCommand(client, "Execute \"%s\": %s, has likelihood %.1f%%", g_ExecuteIDs[i],
                         g_ExecuteNames[i], 100.0 * p);
        }
      }

      delete potentialExecutes;

    } else {
      ReplyToCommand(client, "Usage: sm_execute_distrubtion <number of ts>");
    }
  }
  return Plugin_Handled;
}

public Action Command_EditorInfo(int client, int args) {
  g_ShowingEditorInformation = !g_ShowingEditorInformation;
}
