# UTStats #
Logs game events in sql format for stat collection
Copyright (C) 2004/2005 azazel, )°DoE°(-AnthraX and toa

UTAssault.net modifications by Cratos, brajan and Sizzl (Timo/Weirdo) (2005-2008, 2020-2022)

This program is free software; you can redistribute and/or modify it under the terms of the Open Unreal Mod License.
See [LICENSE](LICENSE.md) for more information.

- - - -

## Version 5 ##
Fork of original UA code for UTAssault.net League Games and PUGs

_Original release notes adapted for GitHub, with ChangeLog observations added_

Original release history for v4.2 and below can be found at https://unrealadmin.org/forums/forumdisplay.php?f=174

## ChangeLog ##

### v5 ###
SmartAS 1.01m (2022):
 - Added area triggers for zones deemed as high-value or low-value for hammer launches

UT Stats:
 - Introduced Inventory damage tracking (handled before MutatorTakeDamage), requires package to be client download
 - Moved SpawnNotify projectile and combo tracking out to Client Simulated
 - Significant debug logging support added
 - "Kill detail" per-player damage attribution tracking added
 - Added private IP checking and lookup via AWS CheckIP API to handle Cloud VM Public IP lookup

### v4.2a beta  ###
SmartAS 1.01k (2008) - enhanced support for UTA Pug games:
 - Added a trigger by way of a config variable which would be set during match setup to generate a new match code

SmartAS 1.01a-j (2005):
 - Moved some of the Assault-specific stats processing into a separate mod
 - Introduced LeagueAssault match-mode support
 - Pulled in additional Assault objective statistics
 - Recorded additional events for Hammer and Rocket Launches, Hammer Jumps
 - Recorded Objective assists
 - Added better handling for spawn protection

UT Stats:
 - Merging of UTS Accuracy and main UT Stats packages
 - Replication requirements largely removed, all processing done server-side
 - Removal of beam spawnnotify
 - Projectile spawnnotify reduced to Rocket Launcher and Bio Rifle
 - UTGL removed
 - Better Assault objective handling

### v4.2 beta (update) ###
UTStats package:
 - Domination logs only log when players are in
 - Fix Teamkills identified as kills in non-team games (gg Epic :/)
 - Last line not logging of buffer fixed
 - Additional startup info logged
 - Function descriptions added
 - Ignore translocator from weapon stats
 - Team score logged
 - Mutators logged
 - Better ping logging (credit to Cratos)
 - Server IP lookup improved (credit to Cratos)
 - Assault FortStandard name logging added

UTS Accuracy package (UPDATED): 
 - Released under matching Open Unreal Mod License
 - Split Effect SpawnNotify to separately cover Projectiles, Shock beams, Combos and Instagib
 - Removed duplicate UTGL/caps/suicide handling from UTS Accu mutator
 - Fix mutator chain
 - Added Replication Info handling
 - Improved effect handling
 - Reduced SpawnNotify load
 - Replication info re-work, better split of items replicated vs. non-replicated
 - Replication info refactoring of functions

### v3.0a beta ###
 - Updates to Special Event handling via LogSpecialEvent()
 - Fix Spree handling
 - Fix Combo handling

### v3.0 beta ###
 - Reverted to standard logs generated by NGStats with some custom information added by the server actor.
 - "UTSAccu" package created to track weapon statistics including damage and accuracy
 - UTGL support

### v2.0 beta ###
Custom server actor to generate logs.

### v1.0 ###
Coding by azazel and PJMODOS

Stats output for:

 - Player Joins/Leaves
 - Match Start/End
 - Frags and Item Pickups
 - Sprees (Doubles/Multis and Domination/Monster etc)
 - Events

## To Do (In order) ##

 - Add all round Accuracy Code
 - Centralised stats id for consistent player tracking
 - Centralised stats
 - Add SmartCTF Events
 - Add autodemorec option

## Thanks ##
El_Muerte, TNSe, )°DoE°(-AnthraX, Cruicky and Truff