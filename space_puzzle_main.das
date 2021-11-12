require daslib/media
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

// Create a 2D array to represent your map, setting all cells in the map as walls.
var map: array<array<bool>>
let mapWidth: int = 24
let mapHeight: int = 14
let mapCellSize: int = 52
let mapPos: int2 = int2(screenBorder + 30.0, screenBorder)
var mapSeed: int4 = int4(5, 3, 6, 2)
var curTime: float
var timeBest: float = 0.0

def get_map_cell(x: int; y: int): BBox2
    var box: BBox2
    box.lim0 = float2(mapPos.x + x * mapCellSize, mapPos.y + y * mapCellSize)
    box.lim1 = box.lim0 + float2(mapCellSize, mapCellSize)
    return box

def genMap()
    // Create a 2D array to represent your map, setting all cells in the map as walls.
    let width: int = mapWidth
    let height: int = mapHeight
    resize(map, width)
    for w in range(0, width - 1)
        resize(map[w], height)
        for h in range(0, height - 1)
            map[w][h] = true

    // Choose a random cell with odd x and y coordinates and clear it.
    var seed: int4 = mapSeed
    var x: int = int(random_float(seed) * float(width - 1));
    var y: int = int(random_float(seed) * float(height - 1));
    map[x][y] = false;

    // Create an array and add valid cells that are two orthogonal spaces away from the cell you just cleared.
    var to_check: array<int2>
    if (y - 2 >= 0)
        push(to_check, int2(x, y - 2));
    if (y + 2 < height)
        push(to_check, int2(x, y + 2));
    if (x - 2 >= 0)
        push(to_check, int2(x - 2, y));
    if (x + 2 < width)
        push(to_check, int2(x + 2, y));

    // While there are cells in your growable array, choose choose one at random, clear it, and remove it from the growable array.
    while (length(to_check) > 0)
        var index: int = int(random_float(seed) * float(length(to_check) - 1));
        var cell: int2 = to_check[index];
        x = cell.x;
        y = cell.y;
        map[x][y] = false
        erase(to_check, index);

        // The cell you just cleared needs to be connected with another clear cell.
        // Look two orthogonal spaces away from the cell you just cleared until you find one that is not a wall.
        // Clear the cell between them.
        let NORTH: int = 0
        let SOUTH: int = 1
        let EAST: int = 2
        let WEST: int = 3
        var d: array<int>
        push(d, NORTH)
        push(d, SOUTH)
        push(d, EAST)
        push(d, WEST)
        while (length(d) > 0)
            var dir_index: int = int(random_float(seed) * float(length(d) - 1));
            if d[dir_index] == NORTH
                if (y - 2 >= 0 && map[x][y - 2] == false)
                    map[x][y - 1] = false
                    clear(d)
            elif d[dir_index] == SOUTH
                if (y + 2 < height && map[x][y + 2] == false)
                    map[x][y + 1] = false
                    clear(d)
            elif d[dir_index] == EAST
                if (x - 2 >= 0 && map[x - 2][y] == false)
                    map[x - 1][y] = false
                    clear(d)
            elif d[dir_index] == WEST
                if (x + 2 < width && map[x + 2][y] == false)
                    map[x + 1][y] = false
                    clear(d)
            if length(d) > 0
                erase(d, dir_index);

        // Add valid cells that are two orthogonal spaces away from the cell you cleared.
        if (y - 2 >= 0 && map[x][y - 2] == true)
            push(to_check, int2(x, y - 2));
        if (y + 2 < height && map[x][y + 2] == true) {
            push(to_check, int2(x, y + 2));
        }
        if (x - 2 >= 0 && map[x - 2][y] == true) {
            push(to_check, int2(x - 2, y));
        }
        if (x + 2 < width && map[x + 2][y] == true) {
            push(to_check, int2(x + 2, y));
        }

struct Mat23
    forward: float2 = float2(1, 0)
    up: float2 = float2(0, 1)
    pos: float2 = float2(0, 0)

struct BBox2
    lim0: float2
    lim1: float2

struct CollisionPoint
    normal: float2

struct Car
    tm: Mat23
    speed: float2
    angle: float
    size: float

struct Obstacle
    box: BBox2

def set_box2(var box: BBox2; lim0: float2; lim1: float2)
    box.lim0 = lim0
    box.lim1 = lim1

def set_box2_pos_size(var box: BBox2; pos: float2; size: float2)
    box.lim0 = pos - size * 0.5
    box.lim1 = pos + size * 0.5

def test_box2_inner(borders: BBox2; box: BBox2; var normals: array<float2>)
    if (box.lim0.x < borders.lim0.x)
        push(normals, float2(1, 0))
    if (box.lim0.y < borders.lim0.y)
        push(normals, float2(0, 1))
    if (box.lim1.x > borders.lim1.x)
        push(normals, float2(-1, 0))
    if (box.lim1.y > borders.lim1.y)
        push(normals, float2(0, -1))

def test_box2_convex(convex: BBox2; box: BBox2; var normals: array<float2>): bool
    if (box.lim0.x < convex.lim1.x && box.lim0.y < convex.lim1.y && box.lim1.x > convex.lim0.x && box.lim1.y > convex.lim0.y)
        var center = (box.lim0 + box.lim1) * 0.5
        if (center.x < convex.lim0.x && center.y < convex.lim0.y)
            push(normals, float2(-1.0, 0.0))
            push(normals, float2(0.0, -1.0))
        elif (center.x < convex.lim0.x && center.y > convex.lim0.y && center.y < convex.lim1.y)
            push(normals, float2(-1.0, 0.0))
        elif (center.x > convex.lim0.x && center.x < convex.lim1.x && center.y < convex.lim0.y)
            push(normals, float2(0.0, -1.0))
        elif (center.x > convex.lim1.x && center.y > convex.lim1.y)
            push(normals, float2(1.0, 0.0))
            push(normals, float2(0.0, 1.0))
        elif (center.x > convex.lim1.x && center.y > convex.lim0.y && center.y < convex.lim1.y)
            push(normals, float2(1.0, 0.0))
        elif (center.x > convex.lim0.x && center.x < convex.lim1.x && center.y > convex.lim1.y)
            push(normals, float2(0.0, 1.0))
        elif (center.x < convex.lim0.x && center.y > convex.lim1.y)
            push(normals, float2(-1.0, 0.0))
            push(normals, float2(0.0, 1.0))
        elif (center.x > convex.lim1.x && center.y < convex.lim0.y)
            push(normals, float2(1.0, 0.0))
            push(normals, float2(0.0, -1.0))
        return true;
    return false

def mul_point(mat: Mat23; vec: float2)
    return mat.forward * vec.x + mat.up * vec.y + mat.pos;

def mul_vector(mat: Mat23; vec: float2)
    return mat.forward * vec.x + mat.up * vec.y;

def mul(mat: Mat23; vec: float3)
    return mat.forward * vec.x + mat.up * vec.y + mat.pos * vec.z;

def mul(mat1: Mat23; mat2: Mat23): Mat23
    return [[Mat23
      forward = float2(mat1.forward.x * mat2.forward.x + mat1.up.x * mat2.forward.y, mat1.forward.y * mat2.forward.x + mat1.up.y * mat2.forward.y),
      up = float2(mat1.forward.x * mat2.up.x + mat1.up.x * mat2.up.y, mat1.forward.y * mat2.up.x + mat1.up.y * mat2.up.y),
      pos = float2(mat1.forward.x * mat2.pos.x + mat1.up.x * mat2.pos.y + mat1.pos.x, mat1.forward.y * mat2.pos.x + mat1.up.y * mat2.pos.y + mat1.pos.y)]]

def frac(value: float): float
    return value - floor(value)

def make_rot2d(angle: float): Mat23
    var rotSin: float
    var rotCos: float
    sincos(frac(angle / (2.0f * PI)) * 2.0f * PI, rotSin, rotCos);
    return [[Mat23 forward = float2(rotCos, rotSin), up = float2(-rotSin, rotCos)]]

def make_wtm(pos: float2; rot: float): Mat23
    var mat: Mat23 = make_rot2d(rot)
    mat.pos = pos
    return mat

let screenBorder: float = 20.0
var viewMat: Mat23 = [[Mat23 forward = float2(1, 0), up = float2(0, -1), pos = float2(0.0, float(get_screen_height()))]]
var camPos: float2 = float2(0.0, 0.0)

var car: Car = [[Car tm = [[Mat23 pos = float2(25.0 + screenBorder, float(get_screen_height()) / 2.0)]], size = 25.0]]
var obstacle1: Obstacle
var obstacles: Obstacle[] = [[Obstacle[]
    [[Obstacle box = [[BBox2 lim0 = float2(500, 200), lim1 = float2(510, 600)]]]];
    [[Obstacle box = [[BBox2 lim0 = float2(100, 30), lim1 = float2(200, 40)]]]]
]]

def draw_car(car: Car)
    let halfSize: float = car.size * 0.5
    let globTm = mul(viewMat, car.tm)

    let pos0: float2 = mul_point(globTm, float2(-halfSize, -halfSize));
    let pos1: float2 = mul_point(globTm, float2(halfSize, 0.0))
    let pos2: float2 = mul_point(globTm, float2(-halfSize, halfSize))
    polygon([[float2[3] pos0; pos1; pos2]], 0xFF00FFFF)

    //for (i = 0)
    let cr0 = mul_point(globTm, float2(-halfSize * 0.3, -halfSize * 0.3))
    let cr1 = mul_point(globTm, float2(halfSize * 0.3, halfSize * 0.3))
    let cr2 = mul_point(globTm, float2(-halfSize * 0.3, halfSize * 0.3))
    let cr3 = mul_point(globTm, float2(halfSize * 0.3, -halfSize * 0.3))
    line(cr0.x, cr0.y, cr1.x, cr1.y, 0xFF00FFFF)
    line(cr2.x, cr2.y, cr3.x, cr3.y, 0xFF00FFFF)

def draw_obstacle(obstacle: Obstacle)
    var pos0: float2 = mul_point(viewMat, obstacle.box.lim0)
    var pos1: float2 = mul_point(viewMat, obstacle.box.lim1)
    fill_rect(pos0.x, pos0.y, pos1.x - pos0.x, pos1.y - pos0.y, 0xFFFFFFFF)
    return

def draw_map_cell(cell: BBox2)
    var pos0: float2 = mul_point(viewMat, cell.lim0)
    var pos1: float2 = mul_point(viewMat, cell.lim1)
    fill_rect(pos0.x, pos0.y, pos1.x - pos0.x, pos1.y - pos0.y, 0xFFFFFF00)

def update_car(var car: Car; dt: float)
    let accel: float = (get_key(VK_UP) ? 1.0 : (get_key(VK_DOWN) ? -1.0 : 0.0)) * 500.0 * dt
    let carAngle = (get_key(VK_LEFT) ? 1.0 : (get_key(VK_RIGHT) ? -1.0 : 0.0)) * PI * dt

    //var speedProj: float2 = float2(dot(car.speed, car.tm.forward), dot(car.speed, car.tm.up))
    //speedProj.x = speedProj.x + max(accel, 0.0) + max(min(accel, 0.0), min(-speedProj.x, 0.0))
    //car.speed = car.tm.forward * speedProj.x + car.tm.up * speedProj.y
    var carSpeedLen: float = length(car.speed)
    var carSpeedDir = car.speed / max(carSpeedLen, 0.001);
    car.speed += car.tm.forward * max(accel, 0.0) + carSpeedDir * max(min(accel, 0.0), -carSpeedLen)
    car.angle += carAngle

    var borders: BBox2;
    set_box2(borders, float2(screenBorder, screenBorder), float2(float(get_screen_width()) - screenBorder,
        float(get_screen_height()) - screenBorder))
    var carBox: BBox2
    set_box2_pos_size(carBox, car.tm.pos, float2(car.size, car.size))    

    var collisions: array<CollisionPoint>

    var borderNormals: array<float2>
    test_box2_inner(borders, carBox, borderNormals);
    for borderNormal in borderNormals
        if borderNormal.x == -1.0
            car.tm.pos = float2(50.0 + screenBorder, 50.0 + screenBorder)
            car.speed = float2(0, 0)
            car.angle = 0.0
            mapSeed.x += 1
            timeBest = timeBest != 0.0 ? min(timeBest, curTime) : curTime
            curTime = 0.0
            genMap()
            return
        push(collisions, [[CollisionPoint normal = borderNormal]])
    
    /*for obstacle in obstacles
        var convexNormals: array<float2>
        if (test_box2_convex(obstacle.box, carBox, convexNormals))
            for convexNormal in convexNormals
                push(collisions, [[CollisionPoint normal = convexNormal]])*/

    for x in range(0, mapWidth - 1)
        for y in range(0, mapHeight - 1)
            if map[x][y]
                var convexNormals: array<float2>
                if (test_box2_convex(get_map_cell(x, y), carBox, convexNormals))
                    for convexNormal in convexNormals
                        push(collisions, [[CollisionPoint normal = convexNormal]])

    for collision in collisions
        car.speed += collision.normal * max(dot(-car.speed, collision.normal), 0.0)

    var carPos = car.tm.pos
    //carPos.x = min(max(carPos.x, 0.0), float(get_screen_width()) - screenBorder * 2.0);
    //carPos.y = min(max(carPos.y, -(float(get_screen_height()) * 0.5 - screenBorder)), 
    //  float(get_screen_height()) * 0.5 - screenBorder)
    carPos += car.speed * dt

    car.tm = make_wtm(carPos, car.angle)

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("Space Puzzle")
    genMap()
    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    curTime += dt

    if get_key(VK_ESCAPE)
        schedule_quit_game()
    viewMat.pos.x += dt * 0.0

    update_car(car, dt)
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    draw_car(car)
    //for obstacle in obstacles
    //    draw_obstacle(obstacle)
    for x in range(0, mapWidth - 1)
        for y in range(0, mapHeight - 1)
            if map[x][y]
                draw_map_cell(get_map_cell(x, y))

    text_out(0, 0, "time {string(float(int(curTime * 10.0)) / 10.0)}", 0xFFFFFFFF)
    text_out(0, 20, "best {string(float(int(timeBest * 10.0)) / 10.0)}", 0xFFFFFFFF)
    return
