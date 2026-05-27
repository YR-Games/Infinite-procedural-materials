shader_type spatial;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_nearest;

#include "shader_modules/library.gdshaderinc"

/*
	for(int i=0;i<=8;i++){
	uv+=grand(float(i)*0.75);
	uv*=1.1;
	uv*=rotate2d(0.33);
	iuv = floor(uv);
   	fuv = fract(uv);
	smth = fuv-vec2(0.5,0.5);
	//float a = atan(smth.y,smth.x);
	//vec2 r = abs(smth)*2.;
	r=max(abs(smth.x),abs(smth.y))*2.;//length(smth)*2.;
 	//f =0.5+smth.y*bn(iuv);
   // f1=max(f1,smoothstep(f,f-0.2,r));
	}
			*/


float hsh(float seed) {
    return fract(sin(seed * 129.1) * 43758.5453);
}

// Аналитический расчет позиции
void getTiledInterval(
    float x,
    float minInterval,
    float maxInterval,
    float minSpace,
    float maxSpace,
    out float localX,
    out int intervalID,
    out bool isSpace
) {
    // Нормализация параметров
    float avgInterval = (minInterval + maxInterval)*0.5;
    float avgSpace = (minSpace + maxSpace)*0.5;
    float totalSegment = avgInterval + avgSpace;

    // Определение базового сегмента
    float segment = floor(x / totalSegment);
    float offset = x - segment * totalSegment;

    // Расчет характеристик сегмента
    float interval = minInterval + hash(segment*2.0) * (maxInterval - minInterval);
    float space = minSpace + hash(segment*2.0 + 1.0) * (maxSpace - minSpace);

    // Определение типа области
    if(offset < interval) {
        localX = offset;
        intervalID = int(hash(segment*2.0 + 0.5) * 1000000.0);
        isSpace = false;
    } else {
        localX = offset - interval;
        intervalID = -1;
        isSpace = true;
    }

    // Коррекция граничных условий
    float err = (interval + space) - totalSegment;
    localX -= err * (localX/(interval + space));
}



float customIntervalSize(int id, float minSize, float maxSize) {
    float test_arr[7] =float[7](3.,4.,5.,2.,3.,3.,2.);
    return minSize + test_arr[id%7] * (maxSize - minSize);
}

void dynamicTiling(
    float x,
    float minInterval,
    float maxInterval,
    float minSpace,
    float maxSpace,
    out float localX,
    out int intervalID,
    out bool isSpace
) {
    // Параметры системы
    const float baseCycle = 50.0;  // Базовый размер цикла
    const float speedFactor = 0.1; // Коэффициент скорости изменения

    // Расчет позиции в паттерне
    float patternPos = mod(x, baseCycle*2.0);
    int patternID = int(floor(x/(baseCycle*2.0)));

    // Генерация ID интервала
    intervalID = int(floor(patternPos*speedFactor)) + patternID*1000;

    // Получение размера интервала через пользовательскую функцию
    float interval = customIntervalSize(intervalID, minInterval, maxInterval);
    float space = minSpace + fract(sin(float(intervalID)*129.1))* (maxSpace - minSpace);

    // Расчет положения точки
    float segment = floor(patternPos/(interval + space));
    float offset = mod(patternPos, interval + space);

    isSpace = offset > interval;
    localX = isSpace ? offset - interval : offset;

    // Коррекция для границ цикла
    if(patternPos > baseCycle*1.5) {
        intervalID += int(fract(patternPos)*100.0);
        localX *= 0.8;
    }
}



float lines(vec2 uv){

	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);
	//float a = atan(smth.y,smth.x);
	//vec2 r = abs(smth)*2.;
	float r=length(smth)*2.;//max(abs(smth.x),abs(smth.y))*2.;//length(smth)*2.;
 		//	float f =0.5;
    		//float f1=smoothstep(f,f-0.2,r);//+smoothstep(f,f+0.2,r);;
			fuv.y=floor(fuv.y*8.)/8.;
	float f =step(fuv.y,grand(uv.x*0.5+0.5));
	//texture(seed,iuv/32.).x*r;

	float x=uv.x;
    float minInterval=0.1;
    float maxInterval=0.5;
    float minSpace=0.1;
    float maxSpace=0.2;
    float localX;
    int intervalID;
    bool isSpace;
	dynamicTiling(x,minInterval, maxInterval,minSpace,maxSpace,localX,intervalID,isSpace);


return float(isSpace);
}

vec4 mat(vec2 uv){
	float f_out = lines(uv);
    return vec4(f_out,0.,0.,f_out);
}

void vertex(){
	    w_norm = NORMAL;
		w_pos = VERTEX;
	}

void fragment() {

    vec3 anorm=abs(w_norm);
	vec3 v=w_pos;
	v.x*=floor(sign(w_norm.z));
	v.z*=-floor(sign(w_norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	mp=mix(mp,w_pos.xz*-sign(w_norm.y),round(anorm.y));

	mp*=mult;

    vec4 outp = mat(mp);

		float offset = 0.001;
		float mlp = 0.1;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,mat(nuv).w*mlp);;

	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,mat(nuv).w*mlp);

		 nuv = vec2(mp.x-offset,mp.y);
    vec3 fb = vec3(nuv.x, 0.0,mat(nuv).w*mlp);

	    nuv = vec2(mp.x,mp.y+offset);
    vec3 fd = vec3(0.0, nuv.y,mat(nuv).w*mlp);

	vec3 normal = 0.5+normalize(cross(fa-fb*vec3(1.,0.,1.), fc-fd*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);
	ALBEDO=vec3(mat(mp).x);
   // ROUGHNESS = 0.5;
	NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/