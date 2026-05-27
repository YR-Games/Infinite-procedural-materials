shader_type spatial;

uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;

// файл для подключения функций
#include "shader_modules/library.gdshaderinc"


//стракт с точками
struct ThreePoints {
    vec2 p1;
    vec2 p2;
    vec2 p3;
};

//функция, управляющая распределением точек.
vec2 p_distr(vec2 uv){
	return hash22(uv);
}

//функция, выбирающая 3 ближайшие к пикселю характеристические точки, распределенные по ячейкам в области 3х3.

ThreePoints tri_voronoi(vec2 uv) {
    vec2 cell = floor(uv);
    vec2 f_uv = fract(uv);
    vec2 p1 = vec2(0.0);
    vec2 p2 = vec2(0.0);
    vec2 p3 = vec2(0.0);
    float d1 = 1e10;
    float d2 = 1e10;
    float d3 = 1e10;

    // обход 3x3
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 offset = vec2(float(i), float(j));
            vec2 point = p_distr(cell + offset);
            vec2 global_point = cell + offset + point;  //вычисление глобальной позиции точки
            vec2 diff = global_point-uv;
			
            float dist = length(diff);  // функция длины. Можно менять для разных результатов.

            if (dist < d1) {
                d3 = d2; p3 = p2;
                d2 = d1; p2 = p1;
                d1 = dist; p1 = global_point;

            } else if (dist < d2) {
                d3 = d2; p3 = p2;
                d2 = dist; p2 = global_point;

            } else if (dist < d3) {
                d3 = dist; p3 = global_point;

            }
        }
    }


	
    return ThreePoints(p1, p2, p3);
}

// функция расстояния до отрезка между двумя точками. Нужна для отладочного отображения.
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}


// функция, генерирующая фигуру вокруг точки
vec3 tile_gen(vec2 uv,vec2 p){
    vec2 fuv = fract(uv-p);
    vec2 smth = fuv-vec2(0.5,0.5);
	
    //параметрические координаты
    float r = length(smth)*2.; //расстояние от точки
    float a = atan(smth.y,smth.x); // угол альфа

	float f = 0.3;// заменить на функцию от a или любую другую функцию
	
    f=smoothstep(f,f-0.1,r); // сглаживание краёв. для адекватной работы вычитать значение из второго аргумента
	
    return vec3(hash32(p))*f;

}

void vertex(){
w_norm = NORMAL;
w_pos = VERTEX;
}

void fragment() {
	
	// этот кусок нужен для авторазвёртки. Игнорируйте.
	vec3 anorm=abs(w_norm);
	vec3 v=w_pos;
	v.x*=floor(sign(w_norm.z));
	v.z*=-floor(sign(w_norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	mp=mix(mp,w_pos.xz*-sign(w_norm.y),round(anorm.y));

	mp*=scale;
	



vec2 iuv = floor(mp);
vec2 fuv =mp-iuv;

// сетка для отладки
vec3 grid = vec3((step(.98, fuv.x) + step(.98, fuv.y)));


ThreePoints res = tri_voronoi(mp);

// отрисовка отрезков между тремя точками.
float dist = sdSegment(mp,res.p1,res.p2);
dist = min(dist, sdSegment(mp,res.p2,res.p3));
dist = min(dist, sdSegment(mp,res.p1,res.p3));
//dist = sdTriangle(mp,res.p1,res.p2,res.p3);


   // ALBEDO = vec3(dist); //отрезки
	ALBEDO = (tile_gen(mp,res.p1)+tile_gen(mp,res.p2)+tile_gen(mp,res.p3))+grid; //
	
//hash32(res.p1+res.p2+res.p3);
}

