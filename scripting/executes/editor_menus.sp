// TODO: add CT spawn "exclusions" to the editor

enum SpawnStatus {
  Spawn_Required = 0,
  Spawn_Optional = 1,
  Spawn_NotUsed = 2,
}

stock void
GiveEditorMenu(int client, int menuPosition = -1) {
  Menu menu = new Menu(EditorMenuHandler);
  menu.ExitButton = true;
  menu.SetTitle("Executes editor");
  AddMenuOption(menu, "end_edit", "Exit edit mode");
  AddMenuOption(menu, "add_spawn", "Add a spawn");
  AddMenuOption(menu, "edit_spawn", "Edit a spawn");
  AddMenuOption(menu, "add_execute", "Add an execute");
  AddMenuOption(menu, "edit_execute", "Edit an execute");
  AddMenuOption(menu, "edit_nearest_spawn", "Edit nearest spawn");
  AddMenuOption(menu, "delete_nearest_spawn", "Delete nearest spawn");
  AddMenuOption(menu, "save_map_data", "Save map data");
  AddMenuOption(menu, "reload_map_data", "Reload map data (discard current changes)");
  AddMenuOption(menu, "clear_edit_buffers", "Clear edit buffers");

  if (menuPosition == -1) {
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
  } else {
    DisplayMenuAtItem(menu, client, menuPosition, MENU_TIME_FOREVER);
  }
}

public int EditorMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char choice[64];
    GetMenuItem(menu, param2, choice, sizeof(choice));
    int menuPosition = GetMenuSelectionPosition();

    if (StrEqual(choice, "end_edit")) {
      Executes_MessageToAll("Exiting edit mode.");
      ExitEditMode();

    } else if (StrEqual(choice, "add_spawn")) {
      g_EditingASpawn[client] = false;
      GiveNewSpawnMenu(client);

    } else if (StrEqual(choice, "add_execute")) {
      g_EditingAnExecute[client] = false;
      GiveNewExecuteMenu(client);

    } else if (StrEqual(choice, "edit_spawn")) {
      GiveEditSpawnChoiceMenu(client);

    } else if (StrEqual(choice, "edit_nearest_spawn")) {
      int spawn = FindClosestSpawn(client);
      EditSpawn(client, spawn);

    } else if (StrEqual(choice, "delete_nearest_spawn")) {
      DeleteClosestSpawn(client);
      GiveEditorMenu(client, menuPosition);

    } else if (StrEqual(choice, "edit_execute")) {
      ClearExecuteBuffers(client);
      GiveExecuteEditMenu(client);

    } else if (StrEqual(choice, "save_map_data")) {
      SaveMapData();
      GiveEditorMenu(client, menuPosition);

    } else if (StrEqual(choice, "reload_map_data")) {
      ReloadMapData();
      GiveEditorMenu(client, menuPosition);

    } else if (StrEqual(choice, "clear_edit_buffers")) {
      ClearEditBuffers(client);
      char clientName[MAX_NAME_LENGTH];
      char finalMsg[1024];
      GetClientName(client, clientName, sizeof(clientName));
      Format(finalMsg, sizeof(finalMsg), "%s %s", "Cleared edit buffers for", clientName);
      Executes_MessageToAll(finalMsg);
      GiveEditorMenu(client, menuPosition);
    } else {
      LogError("unknown menu info string = %s", choice);
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

stock void GiveNewSpawnMenu(int client, int pos = -1) {
  g_EditingExecutes[client] = false;
  Menu menu = new Menu(GiveNewSpawnMenuHandler);
  menu.SetTitle("Add a spawn");

  if (StrEqual(g_EditingNameBuffer[client], ""))
    AddMenuOptionDisabled(menu, "finish", "Finish spawn (use !setname to name first)");
  else
    AddMenuOption(menu, "finish", "Finish spawn (%s)", g_EditingNameBuffer[client]);

  AddMenuOption(menu, "team", "Team: %s", TEAMSTRING(g_EditingSpawnTeam[client]));
  if (g_EditingSpawnTeam[client] == CS_TEAM_CT) {
    AddMenuOption(menu, "a_friendly", "A site friendliness: %d",
                  g_EditingSpawnSiteFriendly[client][BombsiteA]);
    AddMenuOption(menu, "b_friendly", "B site friendliness: %d",
                  g_EditingSpawnSiteFriendly[client][BombsiteB]);
    AddMenuOption(menu, "awp_friendly", "AWP friendliness: %d", g_EditingSpawnAwpFriendly[client]);
    AddMenuOption(menu, "likelihood", "Likelihood value: %d", g_EditingSpawnLikelihood[client]);
  } else {
    AddMenuOption(menu, "bomb_friendly", "Bomb carrier friendliness: %d",
                  g_EditingSpawnBombFriendly[client]);
    AddMenuOption(menu, "awp_friendly", "AWP friendliness: %d", g_EditingSpawnAwpFriendly[client]);

    char type[32];
    GrenadeTypeName(g_EditingSpawnGrenadeType[client], type, sizeof(type));
    AddMenuOptionDisabled(menu, "x", "Grenade: %s", type);

    char throwTime[32];
    ThrowTimeString(g_EditingSpawnThrowTime[client], throwTime, sizeof(throwTime));
    if (IsGrenade(g_EditingSpawnGrenadeType[client])) {
      AddMenuOption(menu, "grenade_throw_time", "Throw Grenade: %s", throwTime);
    } else {
      AddMenuOptionDisabled(menu, "grenade_throw_time", "Throw Grenade: %s", throwTime);
    }
  }

  AddMenuOption(menu, "flags", "Edit flags");

  menu.ExitButton = true;
  menu.ExitBackButton = true;

  if (pos == -1) {
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
  } else {
    DisplayMenuAtItem(menu, client, pos, MENU_TIME_FOREVER);
  }
}

public int GiveNewSpawnMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int pos = GetMenuSelectionPosition();
    int client = param1;
    char choice[64];
    GetMenuItem(menu, param2, choice, sizeof(choice));
    if (StrEqual(choice, "finish")) {
      AddSpawn(client);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "team")) {
      g_EditingSpawnTeam[client] = GetOtherTeam(g_EditingSpawnTeam[client]);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "name")) {
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "a_friendly")) {
      IncSiteFriendly(client, BombsiteA);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "b_friendly")) {
      IncSiteFriendly(client, BombsiteB);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "awp_friendly")) {
      IncAwpFriendly(client);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "bomb_friendly")) {
      IncBombFriendly(client);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "likelihood")) {
      IncSpawnLikelihood(client);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "grenade_throw_time")) {
      IncThrowTime(client);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "flags")) {
      GiveEditFlagsMenu(client);

    } else {
      LogError("unknown menu info string = %s", choice);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveEditorMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void IncSiteFriendly(int client, Bombsite site) {
  g_EditingSpawnSiteFriendly[client][site]++;
  if (g_EditingSpawnSiteFriendly[client][site] > MAX_FRIENDLINESS) {
    g_EditingSpawnSiteFriendly[client][site] = MIN_FRIENDLINESS;
  }
}

public void IncAwpFriendly(int client) {
  g_EditingSpawnAwpFriendly[client]++;
  if (g_EditingSpawnAwpFriendly[client] > MAX_FRIENDLINESS) {
    g_EditingSpawnAwpFriendly[client] = MIN_FRIENDLINESS;
  }
}

public void IncBombFriendly(int client) {
  g_EditingSpawnBombFriendly[client]++;
  if (g_EditingSpawnBombFriendly[client] > MAX_FRIENDLINESS) {
    g_EditingSpawnBombFriendly[client] = MIN_FRIENDLINESS;
  }
}

public void IncSpawnLikelihood(int client) {
  g_EditingSpawnLikelihood[client]++;
  if (g_EditingSpawnLikelihood[client] > MAX_FRIENDLINESS) {
    g_EditingSpawnLikelihood[client] = MIN_FRIENDLINESS;
  }
}

public void IncExecuteLikelihood(int client) {
  g_EditingExecuteLikelihood[client]++;
  if (g_EditingExecuteLikelihood[client] > MAX_FRIENDLINESS) {
    g_EditingExecuteLikelihood[client] = MIN_FRIENDLINESS;
  }
}

public void ThrowTimeString(int time, char[] buf, int len) {
  if (time == 0) {
    Format(buf, len, "at freezetime end");
  } else if (time > 0) {
    Format(buf, len, "%d AFTER freezetime end", time);
  } else {
    Format(buf, len, "%d BEFORE freezetime end", -time);
  }
}

public void IncThrowTime(int client) {
  g_EditingSpawnThrowTime[client]++;
  if (g_EditingSpawnThrowTime[client] > 5) {
    g_EditingSpawnThrowTime[client] = 0;
  }
}

stock void GiveNewExecuteMenu(int client, int pos = -1) {
  g_EditingExecutes[client] = true;
  Menu menu = new Menu(GiveNewExecuteMenuHandler);
  if (g_EditingAnExecute[client])
    menu.SetTitle("Edit an execute");
  else
    menu.SetTitle("Add an execute");

  if (StrEqual(g_EditingNameBuffer[client], ""))
    AddMenuOptionDisabled(menu, "finish", "Finish execute (use !setname to name it first)");
  else
    AddMenuOption(menu, "finish", "finish execute (%s)", g_EditingNameBuffer[client]);

  AddMenuOption(menu, "site", "Site: %s", SITESTRING(g_EditingExecuteSite[client]));
  AddMenuOption(menu, "t_spawns", "Edit T spawns");

  AddMenuOption(menu, "play_required_nades", "Play required nades");
  AddMenuOption(menu, "play_all_nades", "Play all nades");
  AddMenuOption(menu, "likelihood", "Likelihood value: %d", g_EditingExecuteLikelihood[client]);

  AddMenuOption(menu, "strat_normal", "Gun round strat: %d",
                g_EditingExecuteStratTypes[client][StratType_Normal]);
  AddMenuOption(menu, "strat_pistol", "Pistol round strat: %d",
                g_EditingExecuteStratTypes[client][StratType_Pistol]);
  AddMenuOption(menu, "strat_force", "Force round strat: %d",
                g_EditingExecuteStratTypes[client][StratType_ForceBuy]);
  AddMenuOption(menu, "fake", "Is a fake: %s", g_EditingExecuteFake[client] ? "yes" : "no");

  if (IsValidSpawn(SpawnIdToIndex(g_EditingExecuteForceBombId[client]))) {
    AddMenuOption(menu, "forcebomb_id", "Forced bomb spawn: %s",
                  g_SpawnNames[SpawnIdToIndex(g_EditingExecuteForceBombId[client])]);
  } else {
    AddMenuOption(menu, "forcebomb_id", "Forced bomb spawn: none");
  }

  if (g_EditingAnExecute[client])
    AddMenuOption(menu, "delete", "Delete this execute");

  menu.ExitButton = true;
  menu.ExitBackButton = true;

  if (pos == -1) {
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
  } else {
    DisplayMenuAtItem(menu, client, pos, MENU_TIME_FOREVER);
  }
}

public int GiveNewExecuteMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int pos = GetMenuSelectionPosition();

    int client = param1;
    int freezetime = GetEditMinFreezetime(client);
    char choice[64];
    GetMenuItem(menu, param2, choice, sizeof(choice));
    if (StrEqual(choice, "finish")) {
      AddExecute(client);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "delete")) {
      g_ExecuteDeleted[g_EditingExecuteIndex[client]] = true;
      GiveEditorMenu(client);

    } else if (StrEqual(choice, "site")) {
      g_EditingExecuteSite[client] = GetOtherSite(g_EditingExecuteSite[client]);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "name")) {
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "t_spawns")) {
      GiveExecuteSpawnsMenu(client);

    } else if (StrEqual(choice, "play_required_nades")) {
      ThrowEditingNades(float(freezetime), client, false);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "play_all_nades")) {
      ThrowEditingNades(float(freezetime), client, true);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "likelihood")) {
      IncExecuteLikelihood(client);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "strat_normal")) {
      FlipStratType(client, StratType_Normal);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "strat_pistol")) {
      FlipStratType(client, StratType_Pistol);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "strat_force")) {
      FlipStratType(client, StratType_ForceBuy);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "fake")) {
      g_EditingExecuteFake[client] = !g_EditingExecuteFake[client];
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "forcebomb_id")) {
      GiveForceBombSpawneMenu(client);

    } else {
      LogError("unknown menu info string = %s", choice);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveEditorMenu(client);
    g_EditingAnExecute[client] = false;
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

static void FlipStratType(int client, StratType type) {
  g_EditingExecuteStratTypes[client][type] = !g_EditingExecuteStratTypes[client][type];
}

public void GiveForceBombSpawneMenu(int client) {
  Menu menu = new Menu(GiveForceBombSpawneMenuHandler);
  menu.SetTitle("Select spawn to force bomb to");

  for (int i = 0; i < g_EditingExecuteTRequired[client].Length; i++) {
    char id[ID_LENGTH];
    g_EditingExecuteTRequired[client].GetString(i, id, sizeof(id));
    int idx = SpawnIdToIndex(id);
    if (IsValidSpawn(idx))
      AddMenuOption(menu, id, g_SpawnNames[idx]);
  }

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int GiveForceBombSpawneMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    GetMenuItem(menu, param2, g_EditingExecuteForceBombId[client], ID_LENGTH);
    GiveNewExecuteMenu(client);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveNewExecuteMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }
}

static ArrayList GetSpawnList(int client, bool required, int execute = -1) {
  // Use temp buffers lists
  if (execute == -1) {
    return required ? g_EditingExecuteTRequired[client] : g_EditingExecuteTOptional[client];
  }

  return required ? g_ExecuteTSpawnsRequired[execute] : g_ExecuteTSpawnsOptional[execute];
}

stock void GiveExecuteSpawnsMenu(int client, int menuPosition = -1) {
  Menu menu = new Menu(GiveExecuteSpawnsMenuHandler);
  menu.SetTitle("Select spawns");
  int count = 0;

  for (int i = 0; i < g_NumSpawns; i++) {
    if (g_SpawnDeleted[i] || g_SpawnTeams[i] != CS_TEAM_T) {
      continue;
    }

    count++;

    char grenadeType[32];
    GrenadeTypeName(g_SpawnGrenadeTypes[i], grenadeType, sizeof(grenadeType));

    int useId = 0;
    char usedStr[32] = "not used";
    if (GetSpawnList(client, true).FindString(g_SpawnIDs[i]) >= 0) {
      useId = 1;
      usedStr = "required";
    } else if (GetSpawnList(client, false).FindString(g_SpawnIDs[i]) >= 0) {
      useId = 2;
      usedStr = "optional";
    }

    char infoStr[ID_LENGTH + 16];
    Format(infoStr, sizeof(infoStr), "%d %s", useId, g_SpawnIDs[i]);

    AddMenuOption(menu, infoStr, "%s: %s (id:%s, grenade:%s)", usedStr, g_SpawnNames[i],
                  g_SpawnIDs[i], grenadeType);
  }

  menu.ExitButton = true;
  menu.ExitBackButton = true;

  if (count == 0) {
    delete menu;
    Executes_Message(client, "No spawns avaliable, add more.");
    GiveNewSpawnMenu(client);
  } else {
    if (menuPosition == -1) {
      DisplayMenu(menu, client, MENU_TIME_FOREVER);
    } else {
      DisplayMenuAtItem(menu, client, menuPosition, MENU_TIME_FOREVER);
    }
  }
}

public int GiveExecuteSpawnsMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));

    char useString[2];
    strcopy(useString, sizeof(useString), info);
    int useId = StringToInt(useString);

    char id[ID_LENGTH];
    strcopy(id, sizeof(id), info[2]);
    int index = SpawnIdToIndex(id);

    if (useId == 0) {
      // not in use, make required
      SetSpawnStatus(id, Spawn_Required, GetSpawnList(client, true), GetSpawnList(client, false));
      Executes_MessageToAll("Added spawn \"%s\" to execute.", g_SpawnNames[index]);

    } else if (useId == 1) {
      // required, make optional
      SetSpawnStatus(id, Spawn_Optional, GetSpawnList(client, true), GetSpawnList(client, false));
      Executes_MessageToAll("Made spawn \"%s\" optional in execute.", g_SpawnNames[index]);

    } else {
      // optional, make not in use
      SetSpawnStatus(id, Spawn_NotUsed, GetSpawnList(client, true), GetSpawnList(client,false));
      Executes_MessageToAll("Removed spawn \"%s\" from execute.", g_SpawnNames[index]);
    }

    int menuPosition = GetMenuSelectionPosition();
    GiveExecuteSpawnsMenu(client, menuPosition);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveNewExecuteMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

stock void GiveExecuteEditMenu(int client, int menuPosition = -1) {
  Menu menu = new Menu(GiveExecuteMenuHandler);
  menu.SetTitle("Select an execute to edit");
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  int count = 0;

  for (int i = 0; i < g_NumExecutes; i++) {
    if (g_ExecuteDeleted[i]) {
      continue;
    }

    AddMenuOption(menu, g_ExecuteIDs[i], "%s (id:%s)", g_ExecuteNames[i], g_ExecuteIDs[i]);
    count++;
  }

  if (count == 0) {
    delete menu;
  } else {
    if (menuPosition == -1) {
      DisplayMenu(menu, client, MENU_TIME_FOREVER);
    } else {
      DisplayMenuAtItem(menu, client, menuPosition, MENU_TIME_FOREVER);
    }
  }
}

public int GiveExecuteMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char id[ID_LENGTH];
    GetMenuItem(menu, param2, id, sizeof(id));
    int execute = ExecuteIdToIndex(id);

    //g_TempNameBuffer = g_ExecuteNames[execute];
    g_EditingNameBuffer[client] = g_ExecuteNames[execute];
    g_EditingAnExecute[client] = true;
    g_EditingExecuteIndex[client] = execute;
    g_EditingExecuteSite[client] = g_ExecuteSites[execute];
    g_EditingExecuteLikelihood[client] = g_ExecuteLikelihood[execute];

    g_EditingExecuteTRequired[client].Clear();
    g_EditingExecuteTOptional[client].Clear();
    CopyList(g_ExecuteTSpawnsRequired[execute], g_EditingExecuteTRequired[client]);
    CopyList(g_ExecuteTSpawnsOptional[execute], g_EditingExecuteTOptional[client]);
    strcopy(g_EditingExecuteForceBombId[client], ID_LENGTH, g_ExecuteForceBombId[execute]);
    g_EditingExecuteStratTypes[client] = g_ExecuteStratTypes[execute];

    GiveNewExecuteMenu(client);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    g_EditingAnExecute[client] = false;
    GiveNewExecuteMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

stock void GiveEditSpawnChoiceMenu(int client, int menuPosition = -1) {
  Menu menu = new Menu(GiveEditSpawnChoiceMenuHandler);
  menu.SetTitle("Select a spawn to edit");
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  int count = 0;

  for (int i = 0; i < g_NumSpawns; i++) {
    if (g_SpawnDeleted[i]) {
      continue;
    }

    if (g_SpawnTeams[i] == CS_TEAM_CT) {
      AddMenuOption(menu, g_SpawnIDs[i], "%s (CT, id:%s)", g_SpawnNames[i], g_SpawnIDs[i]);
    } else {
      AddMenuOption(menu, g_SpawnIDs[i], "%s (T, id:%s)", g_SpawnNames[i], g_SpawnIDs[i]);
    }

    count++;
  }

  if (count == 0) {
    delete menu;
  } else {
    if (menuPosition == -1) {
      DisplayMenu(menu, client, MENU_TIME_FOREVER);
    } else {
      DisplayMenuAtItem(menu, client, menuPosition, MENU_TIME_FOREVER);
    }
  }
}

public int GiveEditSpawnChoiceMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char id[ID_LENGTH];
    GetMenuItem(menu, param2, id, sizeof(id));
    int spawn = SpawnIdToIndex(id);
    EditSpawn(client, spawn);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveEditorMenu(client);
    g_EditingASpawn[client] = false;

  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void EditSpawn(int client, int spawn) {
  MoveToSpawnInEditor(client, spawn);
  //g_TempNameBuffer = g_SpawnNames[spawn];
  g_EditingNameBuffer[client] = g_SpawnNames[spawn];
  g_EditingSpawnTeam[client] = g_SpawnTeams[spawn];
  g_EditingSpawnGrenadeType[client] = g_SpawnGrenadeTypes[spawn];
  g_EditingSpawnNadePoint[client] = g_SpawnNadePoints[spawn];
  g_EditingSpawnNadeVelocity[client] = g_SpawnNadeVelocities[spawn];
  g_EditingSpawnSiteFriendly[client] = g_SpawnSiteFriendly[spawn];
  g_EditingSpawnAwpFriendly[client] = g_SpawnAwpFriendly[spawn];
  g_EditingSpawnBombFriendly[client] = g_SpawnBombFriendly[spawn];
  g_EditingSpawnLikelihood[client] = g_SpawnLikelihood[spawn];
  g_EditingSpawnThrowTime[client] = g_SpawnGrenadeThrowTimes[spawn];
  g_EditingSpawnFlags[client] = g_SpawnFlags[spawn];

  g_EditingASpawn[client] = true;
  g_EditingSpawnIndex[client] = spawn;
  GiveNewSpawnMenu(client);
}

public void GiveEditFlagsMenu(int client) {
  Menu menu = new Menu(EditFlagsHandler);
  menu.SetTitle("Select a flag to toggle");
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  AddFlag(menu, client, SPAWNFLAG_MOLOTOV, "molotov");
  AddFlag(menu, client, SPAWNFLAG_FLASH, "flash");
  AddFlag(menu, client, SPAWNFLAG_SMOKE, "smoke");

  AddFlag(menu, client, SPAWNFLAG_MAG7, "mag7", CS_TEAM_CT);
  AddFlag(menu, client, SPAWNFLAG_ALURKER, "A lurker", CS_TEAM_T);
  AddFlag(menu, client, SPAWNFLAG_BLURKER, "B lurker", CS_TEAM_T);

  menu.Display(client, MENU_TIME_FOREVER);
}

static void AddFlag(Menu menu, int client, int flag, const char[] title, int team = -1) {
  char tmp[16] = "enabled";
  if (g_EditingSpawnFlags[client] & flag == 0) {
    tmp = "disabled";
  }
  char display[64];
  Format(display, sizeof(display), "%s: %s", title, tmp);

  if (team == -1 || g_EditingSpawnTeam[client] == team) {
    AddMenuInt(menu, flag, display);
  }
}

public int EditFlagsHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    int flagMask = GetMenuInt(menu, param2);

    if (g_EditingSpawnFlags[client] & flagMask == 0) {
      // Enabled the flag
      g_EditingSpawnFlags[client] |= flagMask;
    } else {
      // Disable the flag
      g_EditingSpawnFlags[client] &= ~flagMask;
    }

    GiveEditFlagsMenu(client);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveNewSpawnMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }
}

void SetSpawnStatus(const char[] id, SpawnStatus status, ArrayList req, ArrayList opt) {
  if (status == Spawn_NotUsed) {
    WipeFromList(req, id);
    WipeFromList(opt, id);
  } else if (status == Spawn_Required) {
    WipeFromList(opt, id);
    if (req.FindString(id) < 0) {
      req.PushString(id);
    }
  } else {
    // optional
    WipeFromList(req, id);
    if (opt.FindString(id) < 0) {
      opt.PushString(id);
    }
  }
}
