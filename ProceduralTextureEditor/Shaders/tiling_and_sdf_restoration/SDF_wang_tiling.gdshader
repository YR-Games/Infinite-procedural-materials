shader_type spatial;
uniform float mult;
uniform float normal_power;
uniform sampler2D sed:filter_linear,source_color;
uniform int num_tiles = 16;
uniform float tile_size = 64.0;
uniform int grid_size = 4; // sqrt(num_tiles), adjust if needed
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/library.gdshaderinc"

// Simple integer hash for tile selection
int hash(int x, int y) {
    return (x * 73856093 ^ y * 19349663) % num_tiles;
}

vec4 mat(vec2 uv) {
    // Compute tile grid position
    vec2 tile_grid = floor(uv / tile_size);
    int tile_index = hash(int(tile_grid.x), int(tile_grid.y));

    // Compute UV within the atlas
    vec2 tile_uv = fract(uv / tile_size);
    int tile_row = tile_index / grid_size;
    int tile_col = tile_index % grid_size;
    vec2 atlas_uv = (vec2(float(tile_col), float(tile_row)) + tile_uv) / float(grid_size);

    vec3 sdf = texture(sed, atlas_uv).xyz;
    float f_out = smoothstep(0., 0.84, sdf.x); // contrast
    return vec4(f_out, 0., 0., f_out);
}

void vertex() {
    w_norm = NORMAL;
    w_pos = VERTEX;
}

void fragment() {
    vec3 anorm = abs(w_norm);
    vec3 v = w_pos;
    v.x *= floor(sign(w_norm.z));
    v.z *= -floor(sign(w_norm.x));
    v.y = -v.y;
    vec2 mp = mix(v.xy, v.zy, round(anorm.x));
    mp = mix(mp, w_pos.xz * -sign(w_norm.y), round(anorm.y));

    mp *= mult;

    vec4 outp = mat(mp);

    float offset = 0.018;
    float mlp = 0.5;

    float h = mat(mp).w * mlp;
    float h_right = mat(vec2(mp.x + offset, mp.y)).w * mlp;
    float h_left = mat(vec2(mp.x - offset, mp.y)).w * mlp;
    float h_up = mat(vec2(mp.x, mp.y + offset)).w * mlp;
    float h_down = mat(vec2(mp.x, mp.y - offset)).w * mlp;

    float dh_dx = (h_right - h_left) / (2.0 * offset);
    float dh_dy = (h_up - h_down) / (2.0 * offset);

    vec3 normal = normalize(vec3(dh_dx, -dh_dy, 1.0));

    ALBEDO = vec3(outp.x);
    ROUGHNESS = 0.5;
    METALLIC = 1.;
    NORMAL_MAP = normal * 0.5 + 0.5;
}
