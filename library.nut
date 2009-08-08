/* $Id$ */

class Road extends AILibrary {
	function GetAuthor()      { return "OpenTTD NoAI Developers Team"; }
	function GetName()        { return "Road"; }
	function GetDescription() { return "An implementation of a road pathfinder"; }
	function GetVersion()     { return 2; }
	function GetDate()        { return "2008-06-18"; }
	function CreateInstance() { return "Road"; }
}

RegisterLibrary(Road());
