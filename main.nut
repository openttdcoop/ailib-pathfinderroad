/* $Id$ */

/**
 * A Road Pathfinder.
 *  This road pathfinder tries to find a buildable / existing route for
 *  road vehicles. You can changes the costs below using for example
 *  roadpf.cost.turn = 30. Note that it's not allowed to change the cost
 *  between consecutive calls to FindPath. You can change the cost before
 *  the first call to FindPath and after FindPath has returned an actual
 *  route. To use only existing roads, set cost.no_existing_road to
 *  cost.max_cost.
 */
class Road
{
	_aystar_class = import("graph.aystar", "", 3);
	_max_cost = null;              ///< The maximum cost for a route.
	_cost_tile = null;             ///< The cost for a single tile.
	_cost_no_existing_road = null; ///< The cost that is added to _cost_tile if no road exists yet.
	_cost_turn = null;             ///< The cost that is added to _cost_tile if the direction changes.
	_cost_slope = null;            ///< The extra cost if a road tile is sloped.
	_cost_bridge_per_tile = null;  ///< The cost per tile of a bridge.
	_cost_tunnel_per_tile = null;  ///< The cost per tile of a tunnel.
	_cost_coast = null;            ///< The extra cost for a coast tile.
	_pathfinder = null;            ///< A reference to the used AyStar object.
	_lowest_cost = null;           ///< min(_cost_tile, _cost_bridge_per_tile, _cost_tunnel_per_tile)

	cost = null;                   ///< Used to change the costs.
	_running = null;

	constructor()
	{
		this._max_cost = 2000000000;
		this._cost_tile = 100;
		this._cost_no_existing_road = 40;
		this._cost_turn = 100;
		this._cost_slope = 200;
		this._cost_bridge_per_tile = 105;
		this._cost_tunnel_per_tile = 105;
		this._cost_coast = 20;
		this._pathfinder = this._aystar_class(this._Cost, this._Estimate, this._Neighbours, this, this, this);

		this.cost = this.Cost(this);
		this._running = false;
		this._lowest_cost = 0;
	}

	/**
	 * Initialize a path search between sources and goals.
	 * @param sources The source nodes.
	 * @param goals The target nodes.
	 * @see AyStar::InitializePath()
	 */
	function InitializePath(sources, goals) { this._pathfinder.InitializePath(sources, goals); }

	/**
	 * Try to find the path as indicated with InitializePath with the lowest cost.
	 * @param iterations After how many iterations it should abort for a moment.
	 *  This value should either be -1 for infinite, or > 0. Any other value
	 *  aborts immediatly and will never find a path.
	 * @return A route if one was found, or false if the amount of iterations was
	 *  reached, or null if no path was found.
	 *  You can call this function over and over as long as it returns false,
	 *  which is an indication it is not yet done looking for a route.
	 * @see AyStar::FindPath()
	 */
	function FindPath(iterations);
}

class Road.Cost
{
	_main = null;

	function _set(idx, val)
	{
		if (this._main._running) throw("You are not allowed to change parameters of a running pathfinder.");

		switch (idx) {
			case "max_cost":         this._main._max_cost = val; break;
			case "tile":             this._main._cost_tile = val; break;
			case "no_existing_road": this._main._cost_no_existing_road = val; break;
			case "turn":             this._main._cost_turn = val; break;
			case "slope":            this._main._cost_slope = val; break;
			case "bridge_per_tile":  this._main._cost_bridge_per_tile = val; break;
			case "tunnel_per_tile":  this._main._cost_tunnel_per_tile = val; break;
			case "coast":            this._main._cost_coast = val; break;
			default: throw("the index '" + idx + "' does not exist");
		}

		return val;
	}

	function _get(idx)
	{
		switch (idx) {
			case "max_cost":         return this._main._max_cost;
			case "tile":             return this._main._cost_tile;
			case "no_existing_road": return this._main._cost_no_existing_road;
			case "turn":             return this._main._cost_turn;
			case "slope":            return this._main._cost_slope;
			case "bridge_per_tile":  return this._main._cost_bridge_per_tile;
			case "tunnel_per_tile":  return this._main._cost_tunnel_per_tile;
			case "coast":            return this._main._cost_coast;
			default: throw("the index '" + idx + "' does not exist");
		}
	}

	function constructor(main)
	{
		this._main = main;
	}
}

function Road::FindPath(iterations)
{
	this._lowest_cost = min(min(this._cost_tile, this._cost_bridge_per_tile), this._cost_tunnel_per_tile);
	local ret = this._pathfinder.FindPath(iterations);
	this._running = (ret == false) ? true : false;
	return ret;
}

function Road::_Cost(path, new_node, self)
{
	/* path == null means this is the first node of a path, so the cost is 0. */
	if (path == null) return 0;

	local prev_node = path.GetNode();

	/* If the new tile is a bridge / tunnel tile, check wether we came from the other
	 * end of the bridge / tunnel or if we just entered the bridge / tunnel. */
	if (AIBridge.IsBridgeTile(new_node)) {
		if (AIBridge.GetOtherBridgeEnd(new_node) != prev_node) return path.GetCost() + self._cost_tile;
		return path.GetCost() + AIMap.DistanceManhattan(new_node, prev_node) * self._cost_bridge_per_tile;
	}
	if (AITunnel.IsTunnelTile(new_node)) {
		if (AITunnel.GetOtherTunnelEnd(new_node) != prev_node) return path.GetCost() + self._cost_tile;
		return path.GetCost() + AIMap.DistanceManhattan(new_node, prev_node) * self._cost_tunnel_per_tile;
	}

	/* Check for a turn. We do this by substracting the TileID of the current node from
	 * the TileID of the previous node and comparing that to the difference between the
	 * previous node and the node before that. */

	local cost = self._cost_tile;
	if (path.GetParent() != null && (prev_node - path.GetParent().GetNode()) != (new_node - prev_node)) {
		cost += self._cost_turn;
	}
	/* Check if the new tile is a coast tile. */
	if (AITile.IsCoastTile(new_node)) {
		cost += self._cost_coast;
	}
	/* Check if the last tile was sloped. */
	if (path.GetParent() != null && !AIBridge.IsBridgeTile(path.GetNode()) && !AITunnel.IsTunnelTile(path.GetNode()) &&
	    self._IsSlopedRoad(path.GetParent().GetNode(), path.GetNode(), new_node)) {
		cost += self._cost_slope;
	}
	if (!AIRoad.AreRoadTilesConnected(prev_node, new_node)) {
		cost += self._cost_no_existing_road;
	}
	return path.GetCost() + cost;
}

function Road::_Estimate(cur_tile, goal_tiles, self)
{
	local min_cost = self._max_cost;
	/* As estimate we multiply the lowest possible cost for a single tile with
	 * with the minimum number of tiles we need to traverse. */
	foreach (tile in goal_tiles) {
		min_cost = min(AIMap.DistanceManhattan(cur_tile, tile) * self._lowest_cost, min_cost);
	}
	return min_cost;
}

function Road::_Neighbours(path, cur_node, self)
{
	/* self._max_cost is the maximum path cost, if we go over it, the path isn't valid. */
	if (path.GetCost() >= self._max_cost) return [];
	local tiles = [];

	/* Check if the current tile is part of a bridge or tunnel */
	if ((AIBridge.IsBridgeTile(cur_node) || AITunnel.IsTunnelTile(cur_node)) &&
	     AITile.HasTransportType(cur_node, AITile.TRANSPORT_ROAD)) {
		local other_end = AIBridge.IsBridgeTile(cur_node) ? AIBridge.GetOtherBridgeEnd(cur_node) : AITunnel.GetOtherTunnelEnd(cur_node);
		/* The other end of the bridge / tunnel is a neighbour. */
		tiles.push(other_end);
		local next_tile = null;
		if (other_end < cur_node) {
			if (other_end <= cur_node - AIMap.GetMapSizeX()) {
				next_tile = cur_node + AIMap.GetMapSizeX();
			} else {
				next_tile = cur_node + 1;
			}
		} else {
			if (other_end >= cur_node + AIMap.GetMapSizeX()) {
				next_tile = cur_node - AIMap.GetMapSizeX();
			} else {
				next_tile = cur_node - 1;
			}
		}
		if (AIRoad.AreRoadTilesConnected(cur_node, next_tile) || AITile.IsBuildable(next_tile) ||
				AIRoad.IsRoadTile(next_tile)) {
			tiles.push(next_tile);
		}
	} else {
		local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
		                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
		/* Check all tiles adjacent to the current tile. */
		foreach (offset in offsets) {
			local next_tile = cur_node + offset;
			/* We add them to the to the neighbours-list if one of the following applies:
			 * 1) There already is a connections between the current tile and the next tile.
			 * 2) We can build a road to the next tile.
			 * 3) The next tile is the entrance of a tunnel / bridge in the correct direction. */
			if (AIRoad.AreRoadTilesConnected(cur_node, next_tile)) {
				tiles.push(next_tile);
			} else if ((AITile.IsBuildable(next_tile) || AIRoad.IsRoadTile(next_tile)) &&
					(path.GetParent() == null || self._CheckSlopes(path.GetParent().GetNode(), cur_node, next_tile))) {
				tiles.push(next_tile);
			} else if (self._CheckTunnelBridge(cur_node, next_tile)) {
				tiles.push(next_tile);
			}
		}
	}
	return tiles;
}

function Road::_IsSlopedRoad(start, middle, end)
{
	local NW = 0; //Set to true if we want to build a road to / from the north-west
	local NE = 0; //Set to true if we want to build a road to / from the north-east
	local SW = 0; //Set to true if we want to build a road to / from the south-west
	local SE = 0; //Set to true if we want to build a road to / from the south-east

	if (middle - AIMap.GetMapSizeX() == start || middle - AIMap.GetMapSizeX() == end) NW = 1;
	if (middle - 1 == start || middle - 1 == end) NE = 1;
	if (middle + AIMap.GetMapSizeX() == start || middle + AIMap.GetMapSizeX() == end) SE = 1;
	if (middle + 1 == start || middle + 1 == end) SW = 1;

	/* If there is a turn in the current tile, it can't be sloped. */
	if ((NW || SE) && (NE || SW)) return false;

	local slope = AITile.GetSlope(middle);
	/* A road on a steep slope is always sloped. */
	if (AITile.IsSteepSlope(slope)) return true;

	/* If only one corner is raised, the road is sloped. */
	if (slope == AITile.SLOPE_N || slope == AITile.SLOPE_W) return true;
	if (slope == AITile.SLOPE_S || slope == AITile.SLOPE_E) return true;

	if (NW && (slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SE)) return true;
	if (NE && (slope == AITile.SLOPE_NE || slope == AITile.SLOPE_SW)) return true;

	return false;
}

function Road::_CheckSlopes(start, middle, end)
{
	local NW = 0; //Set to true if we want to build a road to / from the north-west
	local NE = 0; //Set to true if we want to build a road to / from the north-east
	local SW = 0; //Set to true if we want to build a road to / from the south-west
	local SE = 0; //Set to true if we want to build a road to / from the south-east

	if (middle - AIMap.GetMapSizeX() == start || middle - AIMap.GetMapSizeX() == end) NW = 1;
	if (middle - 1 == start || middle - 1 == end) NE = 1;
	if (middle + AIMap.GetMapSizeX() == start || middle + AIMap.GetMapSizeX() == end) SE = 1;
	if (middle + 1 == start || middle + 1 == end) SW = 1;

	{
		local test_mode = AITestMode();
		if (!AIRoad.AreRoadTilesConnected(start, middle) && !AIRoad.BuildRoad(start, middle)) return false;
		if (!AIRoad.AreRoadTilesConnected(middle, end) && !AIRoad.BuildRoad(middle, end)) return false;
	}

	if ((NW && SE) || (NE && SW)) return true;

	local slope = AITile.GetSlope(middle);
	if (AITile.IsSteepSlope(slope)) return false;

	if (slope == AITile.SLOPE_NS || slope == AITile.SLOPE_EW) return true;

	if (NW && SW && (slope == AITile.SLOPE_E || slope == AITile.SLOPE_NE || slope == AITile.SLOPE_SE)) return false;
	if (NE && SE && (slope == AITile.SLOPE_W || slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SW)) return false;
	if (NW && NE && (slope == AITile.SLOPE_S || slope == AITile.SLOPE_SE || slope == AITile.SLOPE_SW)) return false;
	if (SW && SE && (slope == AITile.SLOPE_N || slope == AITile.SLOPE_NE || slope == AITile.SLOPE_NW)) return false;

	return true;
}

function Road::_CheckTunnelBridge(current_node, new_node)
{
	if (!AIBridge.IsBridgeTile(new_node) && !AITunnel.IsTunnelTile(new_node)) return false;
	local dir = new_node - current_node;
	local other_end = AIBridge.IsBridgeTile(new_node) ? AIBridge.GetOtherBridgeEnd(new_node) : AITunnel.GetOtherTunnelEnd(new_node);
	local dir2 = other_end - new_node;
	if ((dir < 0 && dir2 > 0) || (dir > 0 && dir2 < 0)) return false;
	dir = abs(dir);
	dir2 = abs(dir2);
	if ((dir >= AIMap.GetMapSizeX() && dir2 < AIMap.GetMapSizeX()) ||
	    (dir < AIMap.GetMapSizeX() && dir2 >= AIMap.GetMapSizeX())) return false;

	return true;
}
