/*
	Project: Dynamic SQLite Housing System (SA-MP)
	Version: 1.0 (2021)
	Credits: Weponz (Developer), [N]1ghtM4r3_ (BETA Tester), H&Wplayz (BETA Tester)
*/

#define FILTERSCRIPT

// -----------------------------------------------------------------------------
// Dependencies
// -----------------------------------------------------------------------------

#include <a_samp>		//Credits: SA-MP Team
#include <samp_bcrypt>	//Credits: _SyS_
#include <streamer>		//Credits: Incognito
#include <sscanf2>		//Credits: Y_Less
#include <zcmd>			//Credits: ZeeX

// -----------------------------------------------------------------------------
// Configuration and definitions
// -----------------------------------------------------------------------------

#define ERROR_COLOUR 	0xFF0000FF	//Default: Red
#define NOTICE_COLOUR 	0xFFFF00FF	//Default: Yellow
#define LABEL_COLOUR 	0xFFFFFFFF	//Default: White

#define SERVER_DATABASE "houses.db"	//This is where the database will be saved (scriptfiles)

#define MAX_HOUSES 		(500)	//This will be the maximum amount of houses that can be created

#define LAND_VALUE_PERCENT (12)	//The percentage of interest added when a nearby house sells (Default: 12%)

#define HOUSE_ONE_PRICE 	(random(500000)  + 500000)	//Default: 1 Story House (Random 500K-1M)
#define HOUSE_TWO_PRICE 	(random(1000000) + 1000000)	//Default: 2 Story House (Random 1M-2M)
#define MANSION_ONE_PRICE 	(random(2000000) + 2000000)	//Default: Small Mansion (Random 2M-4M)
#define MANSION_TWO_PRICE 	(random(4000000) + 4000000)	//Default: Large Mansion (Random 4M-8M)
#define APARTMENT_PRICE 	(random(3000000) + 3000000)	//Default: Apartment (Random 3M-6M)

enum 
{
	BUY_DIALOG = 1234, //Change this number if it clashes with other scripts using the same dialogid
	VERIFY_DIALOG,
	ACCESS_DIALOG,
	MENU_DIALOG,
	NAME_DIALOG,
	PASS_DIALOG,
	SAFE_DIALOG,
	BALANCE_DIALOG,
	DEPOSIT_DIALOG,
	WITHDRAW_DIALOG,
	SELL_DIALOG,
	COMMANDS_DIALOG,
};

// -----------------------------------------------------------------------------
// Forward declarations
// -----------------------------------------------------------------------------

forward EncryptHousePassword(playerid, houseid);
forward VerifyHousePassword(playerid, bool:success);

new DB:gServerDatabase;
new DBResult:gDatabaseResult;

enum E_PLAYER_DATA
{
	E_PLAYER_HOUSE_ID,
	E_PLAYER_SALE_HOUSE,
	E_PLAYER_SALE_PRICE,
	E_PLAYER_SALE_OWNER,
	E_PLAYER_SALE_TO,
	E_PLAYER_SPAM,
	bool:E_PLAYER_SALE_ACTIVE
};
new PlayerData[MAX_PLAYERS][E_PLAYER_DATA];

enum E_HOUSE_DATA
{
	E_HOUSE_OWNER[MAX_PLAYER_NAME],
	E_HOUSE_NAME[64],
	E_HOUSE_VALUE,
	E_HOUSE_SAFE,
	Float:E_HOUSE_EXT_X,
	Float:E_HOUSE_EXT_Y,
	Float:E_HOUSE_EXT_Z,
	Float:E_HOUSE_INT_X,
	Float:E_HOUSE_INT_Y,
	Float:E_HOUSE_INT_Z,
	Float:E_HOUSE_ENTER_X,
	Float:E_HOUSE_ENTER_Y,
	Float:E_HOUSE_ENTER_Z,
	Float:E_HOUSE_ENTER_A,
	Float:E_HOUSE_EXIT_X,
	Float:E_HOUSE_EXIT_Y,
	Float:E_HOUSE_EXIT_Z,
	Float:E_HOUSE_EXIT_A,
	E_HOUSE_EXT_INTERIOR,
	E_HOUSE_EXT_WORLD,
	E_HOUSE_INT_INTERIOR,
	E_HOUSE_INT_WORLD,
	E_HOUSE_MAPICON,
	E_HOUSE_ENTER_CP,
	E_HOUSE_EXIT_CP,
	Text3D:E_HOUSE_LABEL,
	bool:E_HOUSE_IS_ACTIVE,
};
new HouseData[MAX_HOUSES][E_HOUSE_DATA];

// -----------------------------------------------------------------------------
// Generic Utilities
// -----------------------------------------------------------------------------

GetName(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	return name;
}

Float:GetPosBehindPlayer(playerid, &Float:x, &Float:y, Float:distance)
{
    new Float:a;
    GetPlayerPos(playerid, x, y, a);
    
    if(IsPlayerInAnyVehicle(playerid))
	{
	    GetVehicleZAngle(GetPlayerVehicleID(playerid), a);
	}
    else
    {
        GetPlayerFacingAngle(playerid, a);
        
        x -= (distance * floatsin(-a, degrees));
        y -= (distance * floatcos(-a, degrees));
	}
    return a;
}

PointInRangeOfPoint(Float:range, Float:x, Float:y, Float:z, Float:x2, Float:y2, Float:z2)
{
    x2 -= x;
    y2 -= y;
    z2 -= z;
    return ((x2 * x2) + (y2 * y2) + (z2 * z2)) < (range * range);
}

ReturnPercent(amount, percent)
{
	return (amount / 100 * percent);
}

// -----------------------------------------------------------------------------
// Non-Generic Utilities
// -----------------------------------------------------------------------------

GetFreeHouseSlot()
{
	new query[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
		format(query, sizeof(query), "SELECT `ID` FROM `HOUSES` WHERE `ID` = '%i'", i);
		gDatabaseResult = db_query(gServerDatabase, query);
		if(!db_num_rows(gDatabaseResult))
		{
		    return i;
		}
	}
	return -1;
}

IsPlayerNearHouse(playerid, Float:distance)
{
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
	    	if(IsPlayerInRangeOfPoint(playerid, distance, HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z])) return 1;
	    }
	}
	return 0;
}

GetOwnedHouseID(playerid)
{
	new query[128], field[MAX_PLAYER_NAME];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
		    format(query, sizeof(query), "SELECT `OWNER` FROM `HOUSES` WHERE `ID` = '%i'", i);
			gDatabaseResult = db_query(gServerDatabase, query);
			if(db_num_rows(gDatabaseResult))
		  	{
		    	db_get_field_assoc(gDatabaseResult, "OWNER", field, sizeof(field));

				db_free_result(gDatabaseResult);

			 	if(!strcmp(HouseData[i][E_HOUSE_OWNER], GetName(playerid), true) && IsPlayerInRangeOfPoint(playerid, 100.0, HouseData[i][E_HOUSE_INT_X], HouseData[i][E_HOUSE_INT_Y], HouseData[i][E_HOUSE_INT_Z])) return i;
			}
			db_free_result(gDatabaseResult);
		}
	}
	return -1;
}

UpdateNearbyLandValue(houseid)
{
	new label[128], query[128];
    for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true && i != houseid)
		{
			if(PointInRangeOfPoint(100.0, HouseData[houseid][E_HOUSE_EXT_X], HouseData[houseid][E_HOUSE_EXT_Y], HouseData[houseid][E_HOUSE_EXT_Z], HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z]))
			{
				HouseData[i][E_HOUSE_VALUE] = (HouseData[i][E_HOUSE_VALUE] + ReturnPercent(HouseData[i][E_HOUSE_VALUE], LAND_VALUE_PERCENT));

			 	if(!strcmp(HouseData[i][E_HOUSE_OWNER], "~", true))
				{
					format(label, sizeof(label), "4-Sale\nPrice: $%i", HouseData[i][E_HOUSE_VALUE]);
					UpdateDynamic3DTextLabelText(HouseData[i][E_HOUSE_LABEL], LABEL_COLOUR, label);
				}
				else
				{
					format(label, sizeof(label), "%s\nValue: $%i", HouseData[i][E_HOUSE_NAME], HouseData[i][E_HOUSE_VALUE]);
					UpdateDynamic3DTextLabelText(HouseData[i][E_HOUSE_LABEL], LABEL_COLOUR, label);
				}

				format(query, sizeof(query), "UPDATE `HOUSES` SET `VALUE` = '%i' WHERE `ID` = '%i'", HouseData[i][E_HOUSE_VALUE], i);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);
		    }
	    }
	}
	return 1;
}

// -----------------------------------------------------------------------------
// Event Handlers
// -----------------------------------------------------------------------------

public OnFilterScriptInit()
{
    gServerDatabase = db_open(SERVER_DATABASE);
    db_query(gServerDatabase, "CREATE TABLE IF NOT EXISTS `HOUSES` (`ID`, `OWNER`, `NAME`, `PASS`, `VALUE`, `SAFE`, `EXTX`, `EXTY`, `EXTZ`, `INTX`, `INTY`, `INTZ`, `ENTERX`, `ENTERY`, `ENTERZ`, `ENTERA`, `EXITX`, `EXITY`, `EXITZ`, `EXITA`, `EXTINTERIOR`, `EXTWORLD`, `INTINTERIOR`, `INTWORLD`)");

	new query[128], field[64], field2[MAX_PLAYER_NAME], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
		format(query, sizeof(query), "SELECT * FROM `HOUSES` WHERE `ID` = '%i'", i);
		gDatabaseResult = db_query(gServerDatabase, query);
		if(db_num_rows(gDatabaseResult))
		{
	 		db_get_field_assoc(gDatabaseResult, "OWNER", field2, sizeof(field2));
	     	HouseData[i][E_HOUSE_OWNER] = field2;

	     	db_get_field_assoc(gDatabaseResult, "NAME", field, sizeof(field));
	     	HouseData[i][E_HOUSE_NAME] = field;

	    	db_get_field_assoc(gDatabaseResult, "VALUE", field, sizeof(field));
	      	HouseData[i][E_HOUSE_VALUE] = strval(field);

	     	db_get_field_assoc(gDatabaseResult, "SAFE", field, sizeof(field));
	     	HouseData[i][E_HOUSE_SAFE] = strval(field);

	     	db_get_field_assoc(gDatabaseResult, "EXTX", field, sizeof(field));
	      	HouseData[i][E_HOUSE_EXT_X] = floatstr(field);

	    	db_get_field_assoc(gDatabaseResult, "EXTY", field, sizeof(field));
	    	HouseData[i][E_HOUSE_EXT_Y] = floatstr(field);

	      	db_get_field_assoc(gDatabaseResult, "EXTZ", field, sizeof(field));
	     	HouseData[i][E_HOUSE_EXT_Z] = floatstr(field);

	    	db_get_field_assoc(gDatabaseResult, "INTX", field, sizeof(field));
	     	HouseData[i][E_HOUSE_INT_X] = floatstr(field);

	      	db_get_field_assoc(gDatabaseResult, "INTY", field, sizeof(field));
	      	HouseData[i][E_HOUSE_INT_Y] = floatstr(field);

	     	db_get_field_assoc(gDatabaseResult, "INTZ", field, sizeof(field));
	      	HouseData[i][E_HOUSE_INT_Z] = floatstr(field);

	     	db_get_field_assoc(gDatabaseResult, "ENTERX", field, sizeof(field));
	      	HouseData[i][E_HOUSE_ENTER_X] = floatstr(field);

	      	db_get_field_assoc(gDatabaseResult, "ENTERY", field, sizeof(field));
	      	HouseData[i][E_HOUSE_ENTER_Y] = floatstr(field);

	      	db_get_field_assoc(gDatabaseResult, "ENTERZ", field, sizeof(field));
	      	HouseData[i][E_HOUSE_ENTER_Z] = floatstr(field);

	      	db_get_field_assoc(gDatabaseResult, "ENTERA", field, sizeof(field));
	      	HouseData[i][E_HOUSE_ENTER_A] = floatstr(field);

	      	db_get_field_assoc(gDatabaseResult, "EXITX", field, sizeof(field));
	     	HouseData[i][E_HOUSE_EXIT_X] = floatstr(field);

	    	db_get_field_assoc(gDatabaseResult, "EXITY", field, sizeof(field));
	      	HouseData[i][E_HOUSE_EXIT_Y] = floatstr(field);

	     	db_get_field_assoc(gDatabaseResult, "EXITZ", field, sizeof(field));
	     	HouseData[i][E_HOUSE_EXIT_Z] = floatstr(field);

	     	db_get_field_assoc(gDatabaseResult, "EXITA", field, sizeof(field));
	      	HouseData[i][E_HOUSE_EXIT_A] = floatstr(field);

	      	db_get_field_assoc(gDatabaseResult, "EXTINTERIOR", field, sizeof(field));
	      	HouseData[i][E_HOUSE_EXT_INTERIOR] = strval(field);

	      	db_get_field_assoc(gDatabaseResult, "EXTWORLD", field, sizeof(field));
	      	HouseData[i][E_HOUSE_EXT_WORLD] = strval(field);

	     	db_get_field_assoc(gDatabaseResult, "INTINTERIOR", field, sizeof(field));
	      	HouseData[i][E_HOUSE_INT_INTERIOR] = strval(field);

	     	db_get_field_assoc(gDatabaseResult, "INTWORLD", field, sizeof(field));
	      	HouseData[i][E_HOUSE_INT_WORLD] = strval(field);
	      	
	      	HouseData[i][E_HOUSE_IS_ACTIVE] = true;

			format(label, sizeof(label), "%s\nValue: $%i", HouseData[i][E_HOUSE_NAME], HouseData[i][E_HOUSE_VALUE]);
			HouseData[i][E_HOUSE_LABEL] = CreateDynamic3DTextLabel(label, LABEL_COLOUR, HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z] + 0.2, 4.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 1, HouseData[i][E_HOUSE_EXT_WORLD], HouseData[i][E_HOUSE_EXT_INTERIOR], -1, 4.0);

			if(!strcmp(HouseData[i][E_HOUSE_OWNER], "~", true))
			{
				HouseData[i][E_HOUSE_MAPICON] = CreateDynamicMapIcon(HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z], 31, -1, -1, -1, -1, 250.0);
			}
			else
			{
				HouseData[i][E_HOUSE_MAPICON] = CreateDynamicMapIcon(HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z], 32, -1, -1, -1, -1, 250.0);
			}

			HouseData[i][E_HOUSE_ENTER_CP] = CreateDynamicCP(HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z], 1.0, HouseData[i][E_HOUSE_EXT_WORLD], HouseData[i][E_HOUSE_EXT_INTERIOR], -1, 4.0);
			HouseData[i][E_HOUSE_EXIT_CP] = CreateDynamicCP(HouseData[i][E_HOUSE_INT_X], HouseData[i][E_HOUSE_INT_Y], HouseData[i][E_HOUSE_INT_Z], 1.0, HouseData[i][E_HOUSE_INT_WORLD], HouseData[i][E_HOUSE_INT_INTERIOR], -1, 4.0);

			db_free_result(gDatabaseResult);
		}
	}
	return 1;
}

public OnFilterScriptExit()
{
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
			DestroyDynamic3DTextLabel(HouseData[i][E_HOUSE_LABEL]);
			DestroyDynamicMapIcon(HouseData[i][E_HOUSE_MAPICON]);
			DestroyDynamicCP(HouseData[i][E_HOUSE_ENTER_CP]);
			DestroyDynamicCP(HouseData[i][E_HOUSE_EXIT_CP]);

			HouseData[i][E_HOUSE_IS_ACTIVE] = false;
		}
	}
	
    db_close(gServerDatabase);
	return 1;
}

public OnPlayerConnect(playerid)
{
    PlayerData[playerid][E_PLAYER_HOUSE_ID] = -1;
	PlayerData[playerid][E_PLAYER_SALE_HOUSE] = -1;
	PlayerData[playerid][E_PLAYER_SALE_PRICE] = 0;
	PlayerData[playerid][E_PLAYER_SALE_OWNER] = INVALID_PLAYER_ID;
	PlayerData[playerid][E_PLAYER_SALE_TO] = INVALID_PLAYER_ID;
	PlayerData[playerid][E_PLAYER_SPAM] = 0;
	PlayerData[playerid][E_PLAYER_SALE_ACTIVE] = false;
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
	    case BUY_DIALOG:
	    {
	        if(response)
	        {
	            new string[128];
		   		format(string, sizeof(string), "{FFFFFF}Are you sure you want to buy this house for $%i?", HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_VALUE]);
	            return ShowPlayerDialog(playerid, VERIFY_DIALOG, DIALOG_STYLE_MSGBOX, "{FFFFFF}Verify Purchase", string, "Yes", "No");
	        }
	        else
	        {
				SetPlayerInterior(playerid, HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_INT_INTERIOR]);
				SetPlayerVirtualWorld(playerid, HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_INT_WORLD]);
   	    	  	SetPlayerPos(playerid, HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_ENTER_X], HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_ENTER_Y], HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_ENTER_Z]);
   	    	  	SetPlayerFacingAngle(playerid, HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_ENTER_A]);
   	    	  	return SetCameraBehindPlayer(playerid);
	        }
	    }
	    case VERIFY_DIALOG:
	    {
	        if(response)
	        {
	            new houseid = PlayerData[playerid][E_PLAYER_HOUSE_ID];
	            if(GetPlayerMoney(playerid) < HouseData[houseid][E_HOUSE_VALUE]) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You don't have enough money to buy this house.");
	            
	            GivePlayerMoney(playerid, -HouseData[houseid][E_HOUSE_VALUE]);
	            
	            UpdateNearbyLandValue(houseid);
	            
				new owner[MAX_PLAYER_NAME], name[64], label[128], query[200];
				format(owner, sizeof(owner), "%s", GetName(playerid));
				format(name, sizeof(name), "%s's House", GetName(playerid));
				format(label, sizeof(label), "%s\nValue: $%i", name, HouseData[houseid][E_HOUSE_VALUE]);
				
				HouseData[houseid][E_HOUSE_OWNER] = owner;
				HouseData[houseid][E_HOUSE_NAME] = name;
				
				UpdateDynamic3DTextLabelText(HouseData[houseid][E_HOUSE_LABEL], LABEL_COLOUR, label);
				
				DestroyDynamicMapIcon(HouseData[houseid][E_HOUSE_MAPICON]);
				HouseData[houseid][E_HOUSE_MAPICON] = CreateDynamicMapIcon(HouseData[houseid][E_HOUSE_EXT_X], HouseData[houseid][E_HOUSE_EXT_Y], HouseData[houseid][E_HOUSE_EXT_Z], 32, -1, -1, -1, -1, 250.0);
				
				SetPlayerPos(playerid, HouseData[houseid][E_HOUSE_EXIT_X], HouseData[houseid][E_HOUSE_EXIT_Y], HouseData[houseid][E_HOUSE_EXIT_Z]);
				SetPlayerFacingAngle(playerid, HouseData[houseid][E_HOUSE_EXIT_A] + 180);
				SetCameraBehindPlayer(playerid);

				format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q' WHERE `ID` = '%i'", owner, name, houseid);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);
	        }
	        return 1;
		}
	    case ACCESS_DIALOG:
	    {
	        if(response)
	        {
	            if(strlen(inputtext) < 3 || strlen(inputtext) > 32) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: The password must be from 3-32 characters long.");

	            new houseid = PlayerData[playerid][E_PLAYER_HOUSE_ID], query[128], field[64];
	            format(query, sizeof(query), "SELECT `PASS` FROM `HOUSES` WHERE `ID` = '%i'", houseid);
				gDatabaseResult = db_query(gServerDatabase, query);
		     	if(db_num_rows(gDatabaseResult))
				{
					db_get_field_assoc(gDatabaseResult, "PASS", field, sizeof(field));
			    	bcrypt_verify(playerid, "VerifyHousePassword", inputtext, field);
				}
				db_free_result(gDatabaseResult);
	        }
	        return 1;
	    }
	    case MENU_DIALOG:
	    {
	        if(response)
	        {
	            switch(listitem)
	            {
	                case 0:
	                {
	                    return ShowPlayerDialog(playerid, SAFE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Safe", "{FFFFFF}Balance\nDeposit\nWithdraw", "Select", "Cancel");
	                }
	                case 1:
	                {
	                    return ShowPlayerDialog(playerid, NAME_DIALOG, DIALOG_STYLE_INPUT, "{FFFFFF}Change House Name", "{FFFFFF}Please enter a new name for your house below:", "Enter", "Cancel");
	                }
	                case 2:
	                {
	                    return ShowPlayerDialog(playerid, PASS_DIALOG, DIALOG_STYLE_PASSWORD, "{FFFFFF}Change House Password", "{FFFFFF}Please enter a new password to give access to other players:", "Enter", "Cancel");
	                }
	                case 3:
	                {
	                    new string[128];
	                    format(string, sizeof(string), "{FFFFFF}Do you want to sell your house for $%i?", HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_VALUE]);
	                    return ShowPlayerDialog(playerid, SELL_DIALOG, DIALOG_STYLE_MSGBOX, "{FFFFFF}Sell House", string, "Yes", "No");
	                }
				}
	        }
	        return 1;
		}
	    case NAME_DIALOG:
	    {
	        if(response)
	        {
	            if(strlen(inputtext) < 1 || strlen(inputtext) > 64) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Your house name must be from 1-64 characters long.");
	            
	            new houseid = PlayerData[playerid][E_PLAYER_HOUSE_ID], name[64], query[128], label[128];
	            format(name, sizeof(name), "%s", inputtext);
	            
	            HouseData[houseid][E_HOUSE_NAME] = name;
	            
	            format(label, sizeof(label), "%s\nValue: $%i", HouseData[houseid][E_HOUSE_NAME], HouseData[houseid][E_HOUSE_VALUE]);
				UpdateDynamic3DTextLabelText(HouseData[houseid][E_HOUSE_LABEL], LABEL_COLOUR, label);

				format(query, sizeof(query), "UPDATE `HOUSES` SET `NAME` = '%q' WHERE `ID` = '%i'", HouseData[houseid][E_HOUSE_NAME], houseid);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);
				
				GameTextForPlayer(playerid, "~g~Name Changed!", 3000, 5);
	        }
	        return 1;
		}
	    case PASS_DIALOG:
	    {
	        if(response)
	        {
	            if(strlen(inputtext) < 3 || strlen(inputtext) > 32) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Your house password must be from 3-32 characters long.");

				bcrypt_hash(playerid, "EncryptHousePassword", inputtext, 12, "i", PlayerData[playerid][E_PLAYER_HOUSE_ID]);
	        }
	        return 1;
		}
	    case SAFE_DIALOG:
	    {
	        if(response)
	        {
	            new string[64];
	            switch(listitem)
	            {
	                case 0:
	                {
	                    format(string, sizeof(string), "{FFFFFF}Funds: $%i", HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_SAFE]);
	                    return ShowPlayerDialog(playerid, BALANCE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}Balance", string, "Back", "Close");
	                }
	                case 1:
	                {
	                    format(string, sizeof(string), "{FFFFFF}Deposit (Holding: $%i)", GetPlayerMoney(playerid));
	                    return ShowPlayerDialog(playerid, DEPOSIT_DIALOG, DIALOG_STYLE_INPUT, string, "{FFFFFF}How much would you like to deposit?", "Enter", "Back");
	                }
	                case 2:
	                {
	                    format(string, sizeof(string), "{FFFFFF}Withdraw (Funds: $%i)", HouseData[PlayerData[playerid][E_PLAYER_HOUSE_ID]][E_HOUSE_SAFE]);
	                    return ShowPlayerDialog(playerid, WITHDRAW_DIALOG, DIALOG_STYLE_INPUT, string, "{FFFFFF}How much would you like to withdraw?", "Enter", "Back");
	                }
				}
	        }
	        return 1;
		}
	    case BALANCE_DIALOG:
	    {
	        if(response)
	        {
	            ShowPlayerDialog(playerid, SAFE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Safe", "{FFFFFF}Balance\nDeposit\nWithdraw", "Select", "Cancel");
	        }
	        return 1;
		}
	    case DEPOSIT_DIALOG:
	    {
	        if(response)
	        {
				new money;

				if(sscanf(inputtext, "d", money) || money < 1)
				{
					SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must input a number greater than 0.");
					return 1;
				}

	            if(GetPlayerMoney(playerid) < money) 
				{
					SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You are not holding that much money.");
					return 1;
				}
	            
	            GivePlayerMoney(playerid, -money);
	            
	            new houseid = PlayerData[playerid][E_PLAYER_HOUSE_ID], query[128];
	            HouseData[houseid][E_HOUSE_SAFE] += money;
	            
				format(query, sizeof(query), "UPDATE `HOUSES` SET `SAFE` = '%i' WHERE `ID` = '%i'", HouseData[houseid][E_HOUSE_SAFE], houseid);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);
	            
	            GameTextForPlayer(playerid, "~g~Money Deposited!", 3000, 5);
				return 1;
	        }
	        else
	        {
	            ShowPlayerDialog(playerid, SAFE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Safe", "{FFFFFF}Balance\nDeposit\nWithdraw", "Select", "Cancel");
	        }
	        return 1;
		}
	    case WITHDRAW_DIALOG:
	    {
	        if(response)
	        {
				new money;

				if(sscanf(inputtext, "d", money) || money < 1)
				{
					SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must input a number greater than 0.");
					return 1;
				}
	            
	            new houseid = PlayerData[playerid][E_PLAYER_HOUSE_ID];
	            if(money > HouseData[houseid][E_HOUSE_SAFE]) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You do not have that much money in your safe.");

	            GivePlayerMoney(playerid, money);

	            HouseData[houseid][E_HOUSE_SAFE] -= money;

	            new query[128];
				format(query, sizeof(query), "UPDATE `HOUSES` SET `SAFE` = '%i' WHERE `ID` = '%i'", HouseData[houseid][E_HOUSE_SAFE], houseid);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);

	            GameTextForPlayer(playerid, "~g~Money Withdrawn!", 3000, 5);
				return 1;
	        }
	        else
	        {
	            ShowPlayerDialog(playerid, SAFE_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Safe", "{FFFFFF}Balance\nDeposit\nWithdraw", "Select", "Cancel");
	        }
		}
		case SELL_DIALOG:
		{
	        if(response)
	        {
	            new houseid = PlayerData[playerid][E_PLAYER_HOUSE_ID];
	            GivePlayerMoney(playerid, (HouseData[houseid][E_HOUSE_VALUE] + HouseData[houseid][E_HOUSE_SAFE]));
	            
	            GameTextForPlayer(playerid, "~g~House Sold!", 3000, 5);
	            
				new name[64], owner[MAX_PLAYER_NAME], query[200], label[128];
				
				format(owner, sizeof(owner), "~");
				format(name, sizeof(name), "4-Sale");
				format(label, sizeof(label), "%s\nPrice: $%i", name, HouseData[houseid][E_HOUSE_VALUE]);
				
				HouseData[houseid][E_HOUSE_OWNER] = owner;
				HouseData[houseid][E_HOUSE_NAME] = name;

				format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q', `SAFE` = '0' WHERE `ID` = '%i'", owner, name, houseid);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);
				
				DestroyDynamicMapIcon(HouseData[houseid][E_HOUSE_MAPICON]);
				HouseData[houseid][E_HOUSE_MAPICON] = CreateDynamicMapIcon(HouseData[houseid][E_HOUSE_EXT_X], HouseData[houseid][E_HOUSE_EXT_Y], HouseData[houseid][E_HOUSE_EXT_Z], 31, -1, -1, -1, -1, 250.0);

				return UpdateDynamic3DTextLabelText(HouseData[houseid][E_HOUSE_LABEL], LABEL_COLOUR, label);
	        }
		}
	}
	return 1;
}

public OnPlayerEnterDynamicCP(playerid, checkpointid)
{
    if(GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
		for(new i = 0; i < MAX_HOUSES; i++)
		{
	    	if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    	{
	   	    	if(checkpointid == HouseData[i][E_HOUSE_ENTER_CP])
	   	    	{
	   	    	    new string[64];
	   	    	    if(!strcmp(HouseData[i][E_HOUSE_OWNER], "~", true))
			   		{
			   		    PlayerData[playerid][E_PLAYER_HOUSE_ID] = i;

			   		    format(string, sizeof(string), "{FFFFFF}4-Sale: $%i", HouseData[i][E_HOUSE_VALUE]);
					   	ShowPlayerDialog(playerid, BUY_DIALOG, DIALOG_STYLE_MSGBOX, string, "{FFFFFF}Would you like to buy or preview this house?", "Buy", "Preview");
					}
					else if(!strcmp(HouseData[i][E_HOUSE_OWNER], GetName(playerid), true))
					{
					    SetPlayerInterior(playerid, HouseData[i][E_HOUSE_INT_INTERIOR]);
					    SetPlayerVirtualWorld(playerid, HouseData[i][E_HOUSE_INT_WORLD]);
	   	    	    	SetPlayerPos(playerid, HouseData[i][E_HOUSE_ENTER_X], HouseData[i][E_HOUSE_ENTER_Y], HouseData[i][E_HOUSE_ENTER_Z]);
	   	    	    	SetPlayerFacingAngle(playerid, HouseData[i][E_HOUSE_ENTER_A]);
	   	    	    	SetCameraBehindPlayer(playerid);

	   	    	    	SendClientMessage(playerid, NOTICE_COLOUR, "SERVER: Type /menu to access the list of house features.");
					}
					else
					{
			   		    PlayerData[playerid][E_PLAYER_HOUSE_ID] = i;

					    format(string, sizeof(string), "{FFFFFF}Owner: %s", HouseData[i][E_HOUSE_OWNER]);
					    ShowPlayerDialog(playerid, ACCESS_DIALOG, DIALOG_STYLE_PASSWORD, string, "{FFFFFF}Please enter the password to gain access:", "Enter", "Cancel");
					}
					return 1;
	   	    	}
	   	    	else if(checkpointid == HouseData[i][E_HOUSE_EXIT_CP])
	   	    	{
					SetPlayerInterior(playerid, HouseData[i][E_HOUSE_EXT_INTERIOR]);
					SetPlayerVirtualWorld(playerid, HouseData[i][E_HOUSE_EXT_WORLD]);

	   	    	    SetPlayerPos(playerid, HouseData[i][E_HOUSE_EXIT_X], HouseData[i][E_HOUSE_EXIT_Y], HouseData[i][E_HOUSE_EXIT_Z]);
	   	    	    SetPlayerFacingAngle(playerid, HouseData[i][E_HOUSE_EXIT_A]);
	   	    	    return SetCameraBehindPlayer(playerid);
	   	    	}
   	    	}
		}
	}
	return 1;
}

public EncryptHousePassword(playerid, houseid)
{
	new password[64];
	bcrypt_get_hash(password);

	new query[128];
	format(query, sizeof(query), "UPDATE `HOUSES` SET `PASS` = '%s' WHERE `ID` = '%i'", password, houseid);
	gDatabaseResult = db_query(gServerDatabase, query);
	db_free_result(gDatabaseResult);
	
	return GameTextForPlayer(playerid, "~g~Password Changed!", 3000, 5);
}

public VerifyHousePassword(playerid, bool:success)
{
 	if(success)
	{
	    new houseid = PlayerData[playerid][E_PLAYER_HOUSE_ID];
		SetPlayerInterior(playerid, HouseData[houseid][E_HOUSE_INT_INTERIOR]);
		SetPlayerVirtualWorld(playerid, HouseData[houseid][E_HOUSE_INT_WORLD]);
   	  	SetPlayerPos(playerid, HouseData[houseid][E_HOUSE_ENTER_X], HouseData[houseid][E_HOUSE_ENTER_Y], HouseData[houseid][E_HOUSE_ENTER_Z]);
   	   	SetPlayerFacingAngle(playerid, HouseData[houseid][E_HOUSE_ENTER_A]);
   	 	return SetCameraBehindPlayer(playerid);
 	}
	else
 	{
 		SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Invalid password. Contact the owner for access.");
 	}
	return 1;
}

// -----------------------------------------------------------------------------
// Commands
// -----------------------------------------------------------------------------

CMD:hcmds(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	return ShowPlayerDialog(playerid, COMMANDS_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Commands", "{FFFFFF}/menu (Players)\n/sellhouse (Players)\n/accepthouse (Players)\n/declinehouse (Players)\n/createhouse (Admins)\n/deletehouse (Admins)\n/deleteallhouses (Admins)\n/resethouseprice (Admins)\n/resetallprices (Admins)\n/resethouseowner (Admins)\n/resetallowners (Admins)", "Close", "");
}

CMD:menu(playerid, params[])
{
	if(GetOwnedHouseID(playerid) == -1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be inside an owned house to use /menu.");
	PlayerData[playerid][E_PLAYER_HOUSE_ID] = GetOwnedHouseID(playerid);
	return ShowPlayerDialog(playerid, MENU_DIALOG, DIALOG_STYLE_LIST, "{FFFFFF}House Menu", "{FFFFFF}Access Safe\nChange Name\nChange Password\nSell House", "Select", "Cancel");
}

CMD:sellhouse(playerid, params[])
{
	new houseid = GetOwnedHouseID(playerid);
	if(houseid == -1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be inside an owned house to sell it.");
	if((gettime() - 5) < PlayerData[playerid][E_PLAYER_SPAM]) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Please wait 5 seconds before using this command again.");
    PlayerData[playerid][E_PLAYER_SPAM] = gettime();
    
	new targetid, price;
	if(sscanf(params, "ui", targetid, price)) return SendClientMessage(playerid, ERROR_COLOUR, "USAGE: /sellhouse [player] [price]");
	if(!IsPlayerConnected(targetid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player is not connected.");
	if(IsPlayerNPC(targetid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player is an NPC.");
	if(targetid == playerid) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You cannot sell your house to yourself.");
	if(price < 1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: The sale price must be greater than 0.");
	
	PlayerData[targetid][E_PLAYER_SALE_HOUSE] = houseid;
	PlayerData[targetid][E_PLAYER_SALE_PRICE] = price;
	PlayerData[targetid][E_PLAYER_SALE_OWNER] = playerid;

	PlayerData[targetid][E_PLAYER_SALE_ACTIVE] = true;
	
	PlayerData[playerid][E_PLAYER_SALE_TO] = targetid;
	
	new string[200];
	format(string, sizeof(string), "SERVER: You have offered %s (%i) your house for $%i. Please wait for their response.", GetName(targetid), targetid, price);
	SendClientMessage(playerid, NOTICE_COLOUR, string);
	
	format(string, sizeof(string), "SERVER: %s (%i) has offered you their house for $%i. Type /accepthouse or /declinehouse to respond.", GetName(playerid), playerid, price);
	return SendClientMessage(targetid, NOTICE_COLOUR, string);
}

CMD:accepthouse(playerid, params[])
{
	if(PlayerData[playerid][E_PLAYER_SALE_ACTIVE] == false) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You have not been offered any houses to purchase.");
	
	new houseid = PlayerData[playerid][E_PLAYER_SALE_HOUSE], price = PlayerData[playerid][E_PLAYER_SALE_PRICE], targetid = PlayerData[playerid][E_PLAYER_SALE_OWNER];
	if(targetid == INVALID_PLAYER_ID)
	{
		PlayerData[playerid][E_PLAYER_SALE_ACTIVE] = false;
		return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player has recently disconnected.");
	}
	if(PlayerData[targetid][E_PLAYER_SALE_TO] != playerid)
	{
		PlayerData[playerid][E_PLAYER_SALE_ACTIVE] = false;
		return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player has offered the house to someone else.");
	}
	if(GetPlayerMoney(playerid) < PlayerData[playerid][E_PLAYER_SALE_PRICE]) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You don't have enough money to accept that offer.");
	
	GivePlayerMoney(playerid, -price);
	GivePlayerMoney(targetid, price);
	
	UpdateNearbyLandValue(houseid);
	
	PlayerData[playerid][E_PLAYER_SALE_ACTIVE] = false;
	PlayerData[targetid][E_PLAYER_SALE_TO] = INVALID_PLAYER_ID;

	new query[128], label[128], name[64];
	GameTextForPlayer(playerid, "~g~Offer Accepted!", 3000, 5);
	GameTextForPlayer(targetid, "~g~Offer Accepted!", 3000, 5);

	format(name, sizeof(name), "%s's House", GetName(playerid));
	
	HouseData[houseid][E_HOUSE_OWNER] = GetName(playerid);
	HouseData[houseid][E_HOUSE_NAME] = name;
	
	GivePlayerMoney(targetid, HouseData[houseid][E_HOUSE_SAFE]);
	
	HouseData[houseid][E_HOUSE_SAFE] = 0;

	format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q', `SAFE` = '%i' WHERE `ID` = '%i'", GetName(playerid), name, HouseData[houseid][E_HOUSE_SAFE], houseid);
	gDatabaseResult = db_query(gServerDatabase, query);
	db_free_result(gDatabaseResult);

	format(label, sizeof(label), "%s\nValue: $%i", name, HouseData[houseid][E_HOUSE_VALUE]);
	return UpdateDynamic3DTextLabelText(HouseData[houseid][E_HOUSE_LABEL], LABEL_COLOUR, label);
}

CMD:declinehouse(playerid, params[])
{
	if(PlayerData[playerid][E_PLAYER_SALE_ACTIVE] == false) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You have not been offered any houses to decline.");
	
	new targetid = PlayerData[playerid][E_PLAYER_SALE_OWNER];
	if(targetid == INVALID_PLAYER_ID)
	{
		PlayerData[playerid][E_PLAYER_SALE_ACTIVE] = false;
		return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player has recently disconnected.");
	}
	if(PlayerData[targetid][E_PLAYER_SALE_TO] != playerid)
	{
		PlayerData[playerid][E_PLAYER_SALE_ACTIVE] = false;
		return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: That player has offered the house to someone else.");
	}

	PlayerData[playerid][E_PLAYER_SALE_ACTIVE] = false;
	PlayerData[targetid][E_PLAYER_SALE_TO] = INVALID_PLAYER_ID;

	GameTextForPlayer(playerid, "~r~Offer Declined!", 3000, 5);
	return GameTextForPlayer(targetid, "~r~Offer Declined!", 3000, 5);
}

CMD:createhouse(playerid, params[])
{
	new type[16];
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	if(sscanf(params, "s[16]", type)) return SendClientMessage(playerid, ERROR_COLOUR, "USAGE: /createhouse [house1/house2/mansion1/mansion2/apartment]");
	if(IsPlayerNearHouse(playerid, 5.0)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You cannot create a house within 5 metres of another one.");

	new houseid = GetFreeHouseSlot(), owner[MAX_PLAYER_NAME], password[64], Float:pos[4], query[700], name[64], label[128];
	if(houseid == -1) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You have reached the max amount of houses the server can have, increase MAX_HOUSES in the script.");

	if(!strcmp(type, "house1", true))//1 Story House
	{
		HouseData[houseid][E_HOUSE_VALUE] = HOUSE_ONE_PRICE;

		HouseData[houseid][E_HOUSE_INT_X] = 2196.84;
		HouseData[houseid][E_HOUSE_INT_Y] = -1204.36;
		HouseData[houseid][E_HOUSE_INT_Z] = 1049.02;
		
		HouseData[houseid][E_HOUSE_ENTER_X] = 2193.9001;
		HouseData[houseid][E_HOUSE_ENTER_Y] = -1202.4185;
		HouseData[houseid][E_HOUSE_ENTER_Z] = 1049.0234;
		HouseData[houseid][E_HOUSE_ENTER_A] = 91.9386;
		
		HouseData[houseid][E_HOUSE_INT_INTERIOR] = 6;
		HouseData[houseid][E_HOUSE_INT_WORLD] = houseid;
	}
	else if(!strcmp(type, "house2", true))//2 Story House
	{
  		HouseData[houseid][E_HOUSE_VALUE] = HOUSE_TWO_PRICE;

		HouseData[houseid][E_HOUSE_INT_X] = 2317.77;
		HouseData[houseid][E_HOUSE_INT_Y] = -1026.76;
		HouseData[houseid][E_HOUSE_INT_Z] = 1050.21;

		HouseData[houseid][E_HOUSE_ENTER_X] = 2320.0730;
		HouseData[houseid][E_HOUSE_ENTER_Y] = -1023.9533;
		HouseData[houseid][E_HOUSE_ENTER_Z] = 1050.2109;
		HouseData[houseid][E_HOUSE_ENTER_A] = 358.4915;

		HouseData[houseid][E_HOUSE_INT_INTERIOR] = 9;
		HouseData[houseid][E_HOUSE_INT_WORLD] = houseid;
	}
	else if(!strcmp(type, "mansion1", true))//Small Mansion
	{
		HouseData[houseid][E_HOUSE_VALUE] = MANSION_ONE_PRICE;

		HouseData[houseid][E_HOUSE_INT_X] = 2324.41;
		HouseData[houseid][E_HOUSE_INT_Y] = -1149.54;
		HouseData[houseid][E_HOUSE_INT_Z] = 1050.71;

		HouseData[houseid][E_HOUSE_ENTER_X] = 2324.4490;
		HouseData[houseid][E_HOUSE_ENTER_Y] = -1145.2841;
		HouseData[houseid][E_HOUSE_ENTER_Z] = 1050.7101;
		HouseData[houseid][E_HOUSE_ENTER_A] = 357.5873;

		HouseData[houseid][E_HOUSE_INT_INTERIOR] = 12;
		HouseData[houseid][E_HOUSE_INT_WORLD] = houseid;
	}
	else if(!strcmp(type, "mansion2", true))//Large Mansion
	{
		HouseData[houseid][E_HOUSE_VALUE] = MANSION_TWO_PRICE;

		HouseData[houseid][E_HOUSE_INT_X] = 140.28;
		HouseData[houseid][E_HOUSE_INT_Y] = 1365.92;
		HouseData[houseid][E_HOUSE_INT_Z] = 1083.85;

		HouseData[houseid][E_HOUSE_ENTER_X] = 140.1788;
		HouseData[houseid][E_HOUSE_ENTER_Y] = 1369.1936;
		HouseData[houseid][E_HOUSE_ENTER_Z] = 1083.8641;
		HouseData[houseid][E_HOUSE_ENTER_A] = 359.2263;

		HouseData[houseid][E_HOUSE_INT_INTERIOR] = 5;
		HouseData[houseid][E_HOUSE_INT_WORLD] = houseid;
	}
	else if(!strcmp(type, "apartment", true))//Apartment
	{
		HouseData[houseid][E_HOUSE_VALUE] = APARTMENT_PRICE;

		HouseData[houseid][E_HOUSE_INT_X] = 225.7121;
		HouseData[houseid][E_HOUSE_INT_Y] = 1021.4438;
		HouseData[houseid][E_HOUSE_INT_Z] = 1084.0177;

		HouseData[houseid][E_HOUSE_ENTER_X] = 225.8993;
		HouseData[houseid][E_HOUSE_ENTER_Y] = 1023.9148;
		HouseData[houseid][E_HOUSE_ENTER_Z] = 1084.0078;
		HouseData[houseid][E_HOUSE_ENTER_A] = 358.4921;

		HouseData[houseid][E_HOUSE_INT_INTERIOR] = 7;
		HouseData[houseid][E_HOUSE_INT_WORLD] = houseid;
	}
	else return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: Invalid house type. Must be: house1/house2/mansion1/mansion2/apartment");
	
	format(owner, sizeof(owner), "~");
	format(password, sizeof(password), "$2y$12$1h2ra6euo5IoIGlVWgvnN.kIOiImlQRnML7Zw/GDZ6Ogb89kA9Lpe");//Randomized Bcrypt Password
	format(name, sizeof(name), "4-Sale", HouseData[houseid][E_HOUSE_VALUE]);
	format(label, sizeof(label), "%s\nPrice: $%i", name, HouseData[houseid][E_HOUSE_VALUE]);
	
	GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
	GetPlayerFacingAngle(playerid, pos[3]);
	
	HouseData[houseid][E_HOUSE_OWNER] = owner;
	HouseData[houseid][E_HOUSE_NAME] = name;
	HouseData[houseid][E_HOUSE_SAFE] = 0;
	HouseData[houseid][E_HOUSE_EXT_X] = pos[0];
	HouseData[houseid][E_HOUSE_EXT_Y] = pos[1];
	HouseData[houseid][E_HOUSE_EXT_Z] = pos[2];
	
	GetPosBehindPlayer(playerid, pos[0], pos[1], 2.0);
	
	HouseData[houseid][E_HOUSE_EXIT_X] = pos[0];
	HouseData[houseid][E_HOUSE_EXIT_Y] = pos[1];
	HouseData[houseid][E_HOUSE_EXIT_Z] = pos[2];
	HouseData[houseid][E_HOUSE_EXIT_A] = (pos[3] + 180);
	
	SetPlayerPos(playerid, pos[0], pos[1], pos[2]);
	
	HouseData[houseid][E_HOUSE_IS_ACTIVE] = true;
	
	HouseData[houseid][E_HOUSE_EXT_INTERIOR] = GetPlayerInterior(playerid);
	HouseData[houseid][E_HOUSE_EXT_WORLD] = GetPlayerVirtualWorld(playerid);
	
	HouseData[houseid][E_HOUSE_LABEL] = CreateDynamic3DTextLabel(label, LABEL_COLOUR, HouseData[houseid][E_HOUSE_EXT_X], HouseData[houseid][E_HOUSE_EXT_Y], HouseData[houseid][E_HOUSE_EXT_Z] + 0.2, 4.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 1, HouseData[houseid][E_HOUSE_EXT_WORLD], HouseData[houseid][E_HOUSE_EXT_INTERIOR], -1, 4.0);
	HouseData[houseid][E_HOUSE_MAPICON] = CreateDynamicMapIcon(HouseData[houseid][E_HOUSE_EXT_X], HouseData[houseid][E_HOUSE_EXT_Y], HouseData[houseid][E_HOUSE_EXT_Z], 31, -1, -1, -1, -1, 250.0);
	
	HouseData[houseid][E_HOUSE_ENTER_CP] = CreateDynamicCP(HouseData[houseid][E_HOUSE_EXT_X], HouseData[houseid][E_HOUSE_EXT_Y], HouseData[houseid][E_HOUSE_EXT_Z], 1.0, HouseData[houseid][E_HOUSE_EXT_WORLD], HouseData[houseid][E_HOUSE_EXT_INTERIOR], -1, 4.0);
	HouseData[houseid][E_HOUSE_EXIT_CP] = CreateDynamicCP(HouseData[houseid][E_HOUSE_INT_X], HouseData[houseid][E_HOUSE_INT_Y], HouseData[houseid][E_HOUSE_INT_Z], 1.0, HouseData[houseid][E_HOUSE_INT_WORLD], HouseData[houseid][E_HOUSE_INT_INTERIOR], -1, 4.0);
	
	format(query, sizeof(query),
"INSERT INTO `HOUSES` (`ID`, `OWNER`, `NAME`, `PASS`, `VALUE`, `SAFE`, `EXTX`, `EXTY`, `EXTZ`, `INTX`, `INTY`, `INTZ`, `ENTERX`, `ENTERY`, `ENTERZ`, `ENTERA`, `EXITX`, `EXITY`, `EXITZ`, `EXITA`, `EXTINTERIOR`, `EXTWORLD`, `INTINTERIOR`, `INTWORLD`) VALUES ('%i', '%q', '%q', '%s', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i', '%i', '%i')",
houseid, owner, name, password, HouseData[houseid][E_HOUSE_VALUE], HouseData[houseid][E_HOUSE_SAFE], HouseData[houseid][E_HOUSE_EXT_X], HouseData[houseid][E_HOUSE_EXT_Y], HouseData[houseid][E_HOUSE_EXT_Z], HouseData[houseid][E_HOUSE_INT_X], HouseData[houseid][E_HOUSE_INT_Y], HouseData[houseid][E_HOUSE_INT_Z], HouseData[houseid][E_HOUSE_ENTER_X], HouseData[houseid][E_HOUSE_ENTER_Y], HouseData[houseid][E_HOUSE_ENTER_Z], HouseData[houseid][E_HOUSE_ENTER_A],
HouseData[houseid][E_HOUSE_EXIT_X], HouseData[houseid][E_HOUSE_EXIT_Y], HouseData[houseid][E_HOUSE_EXIT_Z], HouseData[houseid][E_HOUSE_EXIT_A], HouseData[houseid][E_HOUSE_EXT_INTERIOR], HouseData[houseid][E_HOUSE_EXT_WORLD], HouseData[houseid][E_HOUSE_INT_INTERIOR], HouseData[houseid][E_HOUSE_INT_WORLD]);
	gDatabaseResult = db_query(gServerDatabase, query);
	db_free_result(gDatabaseResult);
	
	return GameTextForPlayer(playerid, "~g~House Created!", 3000, 5);
}

CMD:deletehouse(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	
	new query[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
		    if(IsPlayerInRangeOfPoint(playerid, 5.0, HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z]))
		  	{
				DestroyDynamic3DTextLabel(HouseData[i][E_HOUSE_LABEL]);
				DestroyDynamicMapIcon(HouseData[i][E_HOUSE_MAPICON]);
				DestroyDynamicCP(HouseData[i][E_HOUSE_ENTER_CP]);
				DestroyDynamicCP(HouseData[i][E_HOUSE_EXIT_CP]);

				HouseData[i][E_HOUSE_IS_ACTIVE] = false;

				format(query, sizeof(query), "DELETE FROM `HOUSES` WHERE `ID` = '%i'", i);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);
				return GameTextForPlayer(playerid, "~r~House Deleted!", 3000, 5);
		    }
	    }
	}
	return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be within 5 metres of a house to delete it.");
}

CMD:deleteallhouses(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");

	new query[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
		    DestroyDynamic3DTextLabel(HouseData[i][E_HOUSE_LABEL]);
			DestroyDynamicMapIcon(HouseData[i][E_HOUSE_MAPICON]);
			DestroyDynamicCP(HouseData[i][E_HOUSE_ENTER_CP]);
			DestroyDynamicCP(HouseData[i][E_HOUSE_EXIT_CP]);

			HouseData[i][E_HOUSE_IS_ACTIVE] = false;

			format(query, sizeof(query), "DELETE FROM `HOUSES` WHERE `ID` = '%i'", i);
			gDatabaseResult = db_query(gServerDatabase, query);
			db_free_result(gDatabaseResult);
		}
	}
	return GameTextForPlayer(playerid, "~r~All Houses Deleted!", 3000, 5);
}

CMD:resethouseowner(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	
	new owner[MAX_PLAYER_NAME], query[128], name[64], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
		    if(IsPlayerInRangeOfPoint(playerid, 5.0, HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z]))
		  	{
		    	GameTextForPlayer(playerid, "~r~House Owner Reset!", 3000, 5);

		     	format(owner, sizeof(owner), "~");
		     	format(name, sizeof(name), "4-Sale");
		      	format(label, sizeof(label), "%s\nPrice: $%i", name, HouseData[i][E_HOUSE_VALUE]);

		      	HouseData[i][E_HOUSE_OWNER] = owner;
		     	HouseData[i][E_HOUSE_NAME] = name;
		     	HouseData[i][E_HOUSE_SAFE] = 0;

		      	DestroyDynamicMapIcon(HouseData[i][E_HOUSE_MAPICON]);
				HouseData[i][E_HOUSE_MAPICON] = CreateDynamicMapIcon(HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z], 31, -1, -1, -1, -1, 250.0);

				format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q', `SAFE` = '%i' WHERE `ID` = '%i'", owner, name, HouseData[i][E_HOUSE_SAFE], i);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);

				return UpdateDynamic3DTextLabelText(HouseData[i][E_HOUSE_LABEL], LABEL_COLOUR, label);
			}
		}
	}
	return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be within 5 metres of a house to reset the owner.");
}

CMD:resetallowners(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");

	new owner[MAX_PLAYER_NAME], query[128], name[64], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
		    format(owner, sizeof(owner), "~");
		 	format(name, sizeof(name), "4-Sale");
		 	format(label, sizeof(label), "%s\nPrice: $%i", name, HouseData[i][E_HOUSE_VALUE]);

		  	HouseData[i][E_HOUSE_OWNER] = owner;
		  	HouseData[i][E_HOUSE_NAME] = name;
		  	HouseData[i][E_HOUSE_SAFE] = 0;

			DestroyDynamicMapIcon(HouseData[i][E_HOUSE_MAPICON]);
			HouseData[i][E_HOUSE_MAPICON] = CreateDynamicMapIcon(HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z], 31, -1, -1, -1, -1, 250.0);

			format(query, sizeof(query), "UPDATE `HOUSES` SET `OWNER` = '%q', `NAME` = '%q', `SAFE` = '%i' WHERE `ID` = '%i'", owner, name, HouseData[i][E_HOUSE_SAFE], i);
			gDatabaseResult = db_query(gServerDatabase, query);
			db_free_result(gDatabaseResult);

			UpdateDynamic3DTextLabelText(HouseData[i][E_HOUSE_LABEL], LABEL_COLOUR, label);
		}
	}
	return GameTextForPlayer(playerid, "~r~All Owners Reset!", 3000, 5);
}

CMD:resethouseprice(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");

	new query[128], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
		    if(IsPlayerInRangeOfPoint(playerid, 5.0, HouseData[i][E_HOUSE_EXT_X], HouseData[i][E_HOUSE_EXT_Y], HouseData[i][E_HOUSE_EXT_Z]))
		  	{
				if(HouseData[i][E_HOUSE_INT_INTERIOR] == 6)//1 Story House
				{
		        	HouseData[i][E_HOUSE_VALUE] = HOUSE_ONE_PRICE;
				}
				else if(HouseData[i][E_HOUSE_INT_INTERIOR] == 9)//2 Story House
				{
		        	HouseData[i][E_HOUSE_VALUE] = HOUSE_TWO_PRICE;
				}
				else if(HouseData[i][E_HOUSE_INT_INTERIOR] == 12)//Small Mansion
				{
		         	HouseData[i][E_HOUSE_VALUE] = MANSION_ONE_PRICE;
				}
				else if(HouseData[i][E_HOUSE_INT_INTERIOR] == 5)//Large Mansion
				{
		         	HouseData[i][E_HOUSE_VALUE] = MANSION_TWO_PRICE;
				}
				else if(HouseData[i][E_HOUSE_INT_INTERIOR] == 7)//Apartment
				{
		       		HouseData[i][E_HOUSE_VALUE] = APARTMENT_PRICE;
				}

				if(!strcmp(HouseData[i][E_HOUSE_OWNER], "~", true))
				{
					format(label, sizeof(label), "4-Sale\nPrice: $%i", HouseData[i][E_HOUSE_VALUE]);
					UpdateDynamic3DTextLabelText(HouseData[i][E_HOUSE_LABEL], LABEL_COLOUR, label);
				}
				else
				{
					format(label, sizeof(label), "%s\nValue: $%i", HouseData[i][E_HOUSE_NAME], HouseData[i][E_HOUSE_VALUE]);
					UpdateDynamic3DTextLabelText(HouseData[i][E_HOUSE_LABEL], LABEL_COLOUR, label);
				}

				format(query, sizeof(query), "UPDATE `HOUSES` SET `VALUE` = '%i' WHERE `ID` = '%i'", HouseData[i][E_HOUSE_VALUE], i);
				gDatabaseResult = db_query(gServerDatabase, query);
				db_free_result(gDatabaseResult);

				return GameTextForPlayer(playerid, "~r~House Price Reset!", 3000, 5);
		    }
	    }
	}
	return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be within 5 metres of a house to delete it.");
}

CMD:resetallprices(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, ERROR_COLOUR, "SERVER: You must be logged in as admin to use this command.");
	
	new query[128], label[128];
	for(new i = 0; i < MAX_HOUSES; i++)
	{
	    if(HouseData[i][E_HOUSE_IS_ACTIVE] == true)
	    {
		    if(HouseData[i][E_HOUSE_INT_INTERIOR] == 6)//1 Story House
			{
	       		HouseData[i][E_HOUSE_VALUE] = HOUSE_ONE_PRICE;
			}
			else if(HouseData[i][E_HOUSE_INT_INTERIOR] == 9)//2 Story House
			{
	        	HouseData[i][E_HOUSE_VALUE] = HOUSE_TWO_PRICE;
			}
			else if(HouseData[i][E_HOUSE_INT_INTERIOR] == 12)//Small Mansion
			{
	        	HouseData[i][E_HOUSE_VALUE] = MANSION_ONE_PRICE;
			}
			else if(HouseData[i][E_HOUSE_INT_INTERIOR] == 5)//Large Mansion
			{
	        	HouseData[i][E_HOUSE_VALUE] = MANSION_TWO_PRICE;
			}
			else if(HouseData[i][E_HOUSE_INT_INTERIOR] == 7)//Apartment
			{
	       		HouseData[i][E_HOUSE_VALUE] = APARTMENT_PRICE;
			}

			if(!strcmp(HouseData[i][E_HOUSE_OWNER], "~", true))
			{
				format(label, sizeof(label), "4-Sale\nPrice: $%i", HouseData[i][E_HOUSE_VALUE]);
				UpdateDynamic3DTextLabelText(HouseData[i][E_HOUSE_LABEL], LABEL_COLOUR, label);
			}
			else
			{
				format(label, sizeof(label), "%s\nValue: $%i", HouseData[i][E_HOUSE_NAME], HouseData[i][E_HOUSE_VALUE]);
				UpdateDynamic3DTextLabelText(HouseData[i][E_HOUSE_LABEL], LABEL_COLOUR, label);
			}

			format(query, sizeof(query), "UPDATE `HOUSES` SET `VALUE` = '%i' WHERE `ID` = '%i'", HouseData[i][E_HOUSE_VALUE], i);
			gDatabaseResult = db_query(gServerDatabase, query);
			db_free_result(gDatabaseResult);
		}
	}
	return GameTextForPlayer(playerid, "~r~All Prices Reset!", 3000, 5);
}


// -----------------------------------------------------------------------------
// EOF
