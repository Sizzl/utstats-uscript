# UTStats #
Logs game events in sql format for stat collection
Copyright (C) 2004/2005 azazel, )°DoE°(-AnthraX and pjmodos

This program is free software; you can redistribute and/or modify it under the terms of the Open Unreal Mod License.
See license for more information.

- - - -

## Version 4.2 beta ##
_Original release notes adapted for GitHub, with ChangeLog observations added_
All release history can be found at https://unrealadmin.org/forums/forumdisplay.php?f=174

## ChangeLog ##

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