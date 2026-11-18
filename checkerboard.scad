// Parametric camera-calibration checkerboard, v1.0
// Units: mm. Both colours have the SAME top plane.
// Export white and black separately, then import as ONE multi-part object.

/* [01 Grid - 行列数] */
// squares = actual squares; inner_corners = internal intersections
count_mode = "squares"; // [squares:格子数, inner_corners:内角点数]
// Horizontal count - 横向数量
columns = 10; // [2:1:60]
// Vertical count - 纵向数量
rows = 7; // [2:1:60]

/* [02 Size - 尺寸 mm] */
// square = fixed square size; outer = fit into exact outer dimensions
size_mode = "square"; // [square:按单格边长, outer:按整板宽高]
// Used in square mode - 单格边长
square_size = 20; // [2:0.1:100]
// Minimum white border on each side - 四周最小白边
border = 20; // [0.1:0.1:100]
// Used in outer mode; squares stay square, extra space becomes white border
outer_width = 240; // [10:0.1:1000]
outer_height = 180; // [10:0.1:1000]

/* [03 Thickness - 厚度 mm] */
// Continuous white backing - 连续底板厚度
base_thickness = 2; // [0.4:0.1:20]
// Black inlay depth; white squares remain flush - 黑格嵌入深度
pattern_thickness = 0.6; // [0.2:0.1:5]
// Internal taper below the top face; does NOT change the visible square size
inlay_taper = 0.05; // [0.01:0.01:0.5]
// Tiny corner chamfer avoids touching STL shells. 0 = ideal sharp corners, may cause mesh warnings.
corner_relief = 0.02; // [0:0.01:0.2]

/* [04 Export - 导出选择] */
// preview = colour preview; white/black = printable material parts
export_part = "preview"; // [preview:黑白预览, white:白色底板与白格, black:黑色格子, solid:整板实体]
// Black square at lower-left in XY coordinates
black_at_origin = true;

/* [Hidden] */
nx = columns + (count_mode == "inner_corners" ? 1 : 0);
ny = rows + (count_mode == "inner_corners" ? 1 : 0);
s = size_mode == "square" ? square_size : min((outer_width-2*border)/nx, (outer_height-2*border)/ny);
w = size_mode == "square" ? nx*s+2*border : outer_width;
h = size_mode == "square" ? ny*s+2*border : outer_height;
mx = (w-nx*s)/2;
my = (h-ny*s)/2;
z_top = base_thickness + pattern_thickness;
eps = 0.01;

assert(count_mode == "squares" || count_mode == "inner_corners", "Invalid count_mode");
assert(size_mode == "square" || size_mode == "outer", "Invalid size_mode");
assert(columns >= 2 && rows >= 2 && floor(columns)==columns && floor(rows)==rows, "Counts must be integers >= 2");
assert(nx <= 61 && ny <= 61, "Maximum actual grid: 61 x 61");
assert(border > 0 && s > 0, "Board is too small for its white border");
assert(base_thickness > 0 && pattern_thickness > 0, "Thickness must be positive");
assert(inlay_taper > 0 && 2*inlay_taper < s, "Inlay taper must be smaller than half a square");
assert(corner_relief >= 0 && corner_relief < s/4, "Corner relief must be smaller than a quarter square");
assert(export_part == "preview" || export_part == "white" || export_part == "black" || export_part == "solid", "Invalid export_part");

echo(str("Squares: ",nx," x ",ny,"; inner corners: ",nx-1," x ",ny-1));
echo(str("Square = ",s," mm; board = ",w," x ",h," x ",z_top," mm"));
echo(str("White margins X/Y = ",mx," / ",my," mm"));

function is_black(c,r) = ((c+r)%2 == (black_at_origin ? 0 : 1));

module tile_profile() {
    q = corner_relief;
    if(q == 0) square([s,s],center=true);
    else translate([-s/2,-s/2])
        polygon([[q,0],[s-q,0],[s,q],[s,s-q],[s-q,s],[q,s],[0,s-q],[0,q]]);
}

// Straight top edges lie on exact grid lines. Only the tiny corner chamfers
// depart from an ideal mathematical checkerboard; see the Chinese guide.
module tile(c,r,cut=false) {
    translate([mx+(c+0.5)*s,my+(r+0.5)*s,base_thickness])
        union() {
            linear_extrude(height=pattern_thickness,scale=s/(s-2*inlay_taper),convexity=4)
                scale((s-2*inlay_taper)/s) tile_profile();
            if(cut)
                translate([0,0,pattern_thickness])
                    linear_extrude(height=eps) tile_profile();
        }
}

module black_part() {
    for(r=[0:ny-1]) for(c=[0:nx-1])
        if(is_black(c,r)) tile(c,r);
}

module white_part() {
    difference() {
        cube([w,h,z_top]);
        for(r=[0:ny-1]) for(c=[0:nx-1])
            if(is_black(c,r)) tile(c,r,true);
    }
}

if(export_part == "white") white_part();
else if(export_part == "black") black_part();
else if(export_part == "solid") cube([w,h,z_top]);
else {
    color([0.93,0.93,0.90]) white_part();
    color([0.04,0.04,0.04]) black_part();
}
