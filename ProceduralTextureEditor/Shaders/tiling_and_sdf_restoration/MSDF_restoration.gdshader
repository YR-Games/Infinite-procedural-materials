shader_type spatial;
uniform float mult;
uniform float normal_power;
uniform sampler2D sed:filter_linear,source_color;
uniform sampler2D noise:filter_linear,source_color;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/library.gdshaderinc"


// Функция медианы для декодирования MSDF
float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

vec4 mat(vec2 uv){
    // Сэмплирование MSDF (RGB каналы)
    vec3 sdf = texture(sed, uv).xyz;

    // Декодирование signed distance: медиана - 0.5 (0.5 ≈ край в нормализованном MSDF)
    float d = median(sdf.r, sdf.g, sdf.b) - 0.5;

    // Альфа/цвет: smoothstep для плавного перехода (пороги подстроены под MSDF)
    float f_out = smoothstep(0.1, 0.5, d); // Контраст вокруг края

    // Высота для нормалей: используем d (signed distance) для точного рельефа
    return vec4(f_out, 0., 0., f_out);
}

void vertex(){
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

    // Высота теперь основана на d (из mat.w)
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


//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/