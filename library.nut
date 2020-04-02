/* $Id$ */

// 2012-08-19:
//   Version 3 -> 4: Updated to use AyStar 6 (instead of 4) by Zuu

class Road extends AILibrary {
	function GetAuthor()      { return "OpenTTD NoAI Developers Team"; }
	function GetName()        { return "Road"; }
	function GetShortName()   { return "PFRO"; }
	function GetDescription() { return "An implementation of a road pathfinder"; }
	function GetVersion()     { return 5; }
	function GetDate()        { return "2020-04-03"; }
	function CreateInstance() { return "Road"; }
	function GetCategory()    { return "Pathfinder"; }
}

RegisterLibrary(Road());
