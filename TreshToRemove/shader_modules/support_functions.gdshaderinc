//////////////////__Support functions__/////////////////
float mod289(const in float x) { return x - floor(x * (1. / 289.)) * 289.; }
vec2 mod289_2d(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 mod289_3d(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289_4d(const in vec4 x) { return x - floor(x * (1. / 289.)) * 289.; }

float permute(const in float v) { return mod289(((v * 34.0) + 1.0) * v); }
vec2 permute_2d(const in vec2 v) { return mod289_2d(((v * 34.0) + 1.0) * v); }
vec3 permute_3d(const in vec3 v) { return mod289_3d(((v * 34.0) + 1.0) * v); }
vec4 permute_4d(const in vec4 v) { return mod289_4d(((v * 34.0) + 1.0) * v); }

float taylorInvSqrt(in float r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec2 taylorInvSqrt_2d(in vec2 r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec3 taylorInvSqrt_3d(in vec3 r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec4 taylorInvSqrt_4d(in vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float quintic(const in float v) { return v*v*v*(v*(v*6.0-15.0)+10.0); }
vec2  quintic_2d(const in vec2 v)  { return v*v*v*(v*(v*6.0-15.0)+10.0); }
vec3  quintic_3d(const in vec3 v)  { return v*v*v*(v*(v*6.0-15.0)+10.0); }
vec4  quintic_4d(const in vec4 v)  { return v*v*v*(v*(v*6.0-15.0)+10.0); }
