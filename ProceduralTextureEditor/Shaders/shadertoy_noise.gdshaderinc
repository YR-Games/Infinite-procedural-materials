// SPDX-License-Identifier: MIT
// Copyright (c) 2026 @Peace @lumiey
//[LICENSE] https://opensource.org/licenses/MIT
//
// Godot 4 shading language port of the noise library. The fbm variants and the
// Shadertoy label/visualization code are left out.
//
//   #include "res://noise.gdshaderinc"
//
// Naming: trailing digits are <input dims><output dims>, e.g. perlin12 = 2D in, 1D out.
// A trailing "d" means the function also returns derivatives (value in .x, slope in the rest).
// scratches12() uses fwidth(), so call it from fragment() / light() only.

/////////// HASHES ///////////
const float NOISE_UINT_SCALE = 1.0 / 4294967296.0; // 2^-32, maps uint -> [0, 1)

// Fi Hash
float hash11(float p) {
	uint u = floatBitsToUint(p * 3141592653.0);
	return float(u * u * 3141592653u) * NOISE_UINT_SCALE;
}

float hash12(vec2 p) {
	uvec2 u = floatBitsToUint(p * vec2(141421356.0, 2718281828.0));
	return float((u.x ^ u.y) * 3141592653u) * NOISE_UINT_SCALE;
}

vec2 hash22(vec2 p) {
	uvec2 u = floatBitsToUint(p * vec2(141421356.0, 2718281828.0));
	return vec2(uvec2(u.x ^ u.y) * uvec2(3141592653u, 1618033988u)) * NOISE_UINT_SCALE;
}

vec3 hash32(vec2 p) {
	uvec2 u = floatBitsToUint(p * vec2(141421356.0, 2718281828.0));
	return vec3(uvec3(u.x ^ u.y) * uvec3(1732050807u, 2645751311u, 3316624790u)) * NOISE_UINT_SCALE;
}

float hash13(vec3 p) {
	uvec3 u = floatBitsToUint(p * vec3(141421356.0, 2718281828.0, 1618033988.0));
	return float((u.x ^ u.y ^ u.z) * 3141592653u) * NOISE_UINT_SCALE;
}

vec3 hash33(vec3 p) {
	uvec3 u = floatBitsToUint(p * vec3(141421356.0, 2718281828.0, 1618033988.0));
	return vec3(uvec3(u.x ^ u.y ^ u.z) * uvec3(1732050807u, 2645751311u, 3316624790u)) * NOISE_UINT_SCALE;
}

/////////// 1D NOISE ///////////
float value11(float p) {
	float i = floor(p);
	return mix(hash11(i), hash11(i + 1.0), p - i);
}

/////////// 2D NOISE ///////////
float value12(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f *= f * (3.0 - 2.0 * f);
	float res = mix(
			mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0)), f.x), f.y);
	return res;
}

float perlin12(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * f * (10.0 + f * (6.0 * f - 15.0));
	float a = dot(normalize(hash22(i + vec2(0.0, 0.0)) - 0.5), f - vec2(0.0, 0.0));
	float b = dot(normalize(hash22(i + vec2(1.0, 0.0)) - 0.5), f - vec2(1.0, 0.0));
	float c = dot(normalize(hash22(i + vec2(0.0, 1.0)) - 0.5), f - vec2(0.0, 1.0));
	float d = dot(normalize(hash22(i + vec2(1.0, 1.0)) - 0.5), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.7 + 0.5;
}

// From: https://iquilezles.org/articles/gradientnoise/
// returns (value, d/dx, d/dy)
vec3 perlin12d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	vec2 ga = hash22(i + vec2(0.0, 0.0)) * 2.0 - 1.0;
	vec2 gb = hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
	vec2 gc = hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
	vec2 gd = hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0;
	float va = dot(ga, f - vec2(0.0, 0.0));
	float vb = dot(gb, f - vec2(1.0, 0.0));
	float vc = dot(gc, f - vec2(0.0, 1.0));
	float vd = dot(gd, f - vec2(1.0, 1.0));
	return vec3(
			va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * (va - vb - vc + vd),
			ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd)
					+ du * (u.yx * (va - vb - vc + vd) + vec2(vb, vc) - va));
}

float simplex12(vec2 p) {
	vec2 i = floor(p + (p.x + p.y) * 0.366025);
	vec2 a = p - i + (i.x + i.y) * 0.211324;
	float m = step(a.y, a.x);
	vec2 o = vec2(m, 1.0 - m);
	vec2 b = a - o + 0.211324;
	vec2 c = a - 0.577351;
	vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
	vec3 n = h * h * h * h *
			vec3(dot(a, hash22(i) - 0.5),
					dot(b, hash22(i + o) - 0.5),
					dot(c, hash22(i + 1.0) - 0.5));
	return dot(n, vec3(70.0)) + 0.5;
}

float worley12(vec2 p) {
	vec2 i = floor(p);
	p -= i;
	float w = 1e6;
	for (float x = -1.0; x <= 1.0; ++x) {
		for (float y = -1.0; y <= 1.0; ++y) {
			vec2 c = p - vec2(x, y) - hash12(i + vec2(x, y));
			w = min(w, dot(c, c));
		}
	}
	return 1.0 - sqrt(w);
}

// returns (1 - distance to nearest node, unit direction away from that node)
vec3 worley12d(vec2 p) {
	vec2 i = floor(p);
	p -= i;
	float w = 1e6;
	vec2 cmin = vec2(0.0);
	for (float x = -1.0; x <= 1.0; ++x) {
		for (float y = -1.0; y <= 1.0; ++y) {
			vec2 c = p - vec2(x, y) - hash12(i + vec2(x, y));
			float l2 = dot(c, c);
			if (l2 < w) {
				w = l2;
				cmin = c;
			}
		}
	}
	w = sqrt(w);
	return vec3(1.0 - w, -cmin / w);
}

// s: edge smoothness
float voronoi12(vec2 x, float s) {
	s = 1.0 / s;
	vec2 p = floor(x);
	vec2 f = x - p;
	float va = 0.0;
	float wt = 0.0;
	for (float gx = -1.0; gx <= 1.0; ++gx) {
		for (float gy = -1.0; gy <= 1.0; ++gy) {
			vec3 o = hash32(p + vec2(gx, gy));
			float d = length(vec2(gx, gy) - f + o.xy);
			float ww = pow(1.0 - smoothstep(0.0, 1.414, d), s);
			va += o.z * ww;
			wt += ww;
		}
	}
	return va / wt;
}

// From: https://www.shadertoy.com/view/tllcR2
float blue12(vec2 p) {
	float v = 0.0;
	for (int k = 0; k < 9; k++) {
		v += hash12(p + vec2(float(k % 3 - 1), float(k / 3 - 1)));
	}
	return 0.9 * (1.125 * hash12(p) - v / 8.0) + 0.5;
}

int hilbert_encode(int n, ivec2 p) {
	int i = 0;
	for (int s = n >> 1; s > 0; s >>= 1) {
		int rx = (p.x & s) != 0 ? 1 : 0;
		int ry = (p.y & s) != 0 ? 1 : 0;
		i += s * s * ((rx << 1) | (rx ^ ry));
		int flip = ((p.x ^ p.y) * (1 - ry)) ^ ((s - 1) * (rx & (1 - ry)));
		p.x ^= flip;
		p.y ^= flip;
	}
	return i;
}

// Modified From: https://www.shadertoy.com/view/3tB3z3
// p is a pixel coordinate, e.g. floor(FRAGCOORD.xy)
float hilbert_blue12(vec2 p) {
	return fract(0.6180339887498948482 * float(hilbert_encode(512, ivec2(p)) % 262144));
}

// Modified from: https://www.shadertoy.com/view/XsGBDt
float crater12(vec2 p) {
	vec2 f = fract(p);
	p = floor(p);
	float va = 0.0;
	float wt = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(p + g);
			float d = distance(f - g, o);
			float w = exp(-4.0 * d);
			va += w * sin(6.28 * sqrt(max(d, 0.06)));
			wt += w;
		}
	}
	return abs(va / wt);
}

// output is in [-1, 1]
float gabor12(vec2 p) {
	const float kF = 8.0;
	vec2 i = floor(p);
	vec2 f = p - i;
	f *= f * (3.0 - 2.0 * f);
	return mix(mix(sin(kF * dot(p, hash22(i + vec2(0.0, 0.0)))),
					sin(kF * dot(p, hash22(i + vec2(1.0, 0.0)))), f.x),
			mix(sin(kF * dot(p, hash22(i + vec2(0.0, 1.0)))),
					sin(kF * dot(p, hash22(i + vec2(1.0, 1.0)))), f.x), f.y);
}

// Same as perlin12d(p).yz, but can be applied to other noises to get their derivative,
// useful when you don't have analytic noise derivative
vec2 curl22(vec2 p) {
	vec2 e = vec2(0.01, 0.0);
	vec2 a = vec2(perlin12(p + e.xy), perlin12(p + e.yx));
	vec2 b = vec2(perlin12(p - e.xy), perlin12(p - e.yx));
	return (a - b) / e.x * 0.5;
}

// Inspired from: https://www.shadertoy.com/view/4syXRD
float scratch(vec2 p, float f, float thickness, float wavyness) {
	//const float THICKNESS = 0.0;
	//const float WAVYNESS = 0.5;

	vec2 i = floor(p);
	vec2 h = hash22(i) * vec2(3104.0, 554.0);

	p = (p - i) * 2.0 - 1.0;
	p = p * cos(h.x + h.y) + vec2(-p.y, p.x) * sin(h.x + h.y);
	p += sin(h.x - h.y);

	float x = abs(p.x - cos(h.x + p.y * 1.57) * wavyness);
	x = 1.0 - smoothstep(thickness - f, thickness + f, x);
	x *= p.y * 0.5 + 0.5;

	return x;
}

/* uses fwidth(): fragment() / light() only
float scratches12(vec2 p) {
	const float SOFTNESS = 3.0;
	const int OCTAVES = 8;

	float scratches = 0.0;
	float w = length(fwidth(p)) * SOFTNESS;
	for (int i = 0; i < OCTAVES; ++i) {
		float x = scratch(p, w);
		scratches = max(scratches, x);
		p = p * mat2(vec2(1.0, 0.7), vec2(-0.7, 1.0)) - 12.31;
		w *= 1.22;
	}
	return scratches;
}
*/

// https://www.shadertoy.com/view/wsBfzK
// use scale = 1.24 for best results
// output is in [-1, 1]
float wavelet12(vec2 p, float phase, float scale) {
	float d = 0.0;
	float s = 1.0;
	float m = 0.0;
	for (float i = 0.0; i < 4.0; ++i) {
		vec2 q = p * s;
		vec2 g = fract(floor(q) * vec2(123.34, 233.53));
		g += dot(g, g + 23.234);
		float a = fract(g.x * g.y) * 1000.0; // + z * (mod(g.x + g.y, 2.0) - 1.0); // add vorticity
		q = (fract(q) - 0.5) * mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
		d += sin(q.x * 10.0 + phase) * (1.0 - smoothstep(0.0, 0.25, dot(q, q))) / s;
		p = p * mat2(vec2(0.54, -0.84), vec2(0.84, 0.54)) + i;
		m += 1.0 / s;
		s *= scale;
	}
	return d / m;
}

vec3 gullies(vec2 p, vec2 slope) {
	vec2 side_dir = vec2(-slope.y, slope.x) * 3.14159265;
	vec2 id = floor(p);
	p -= id;
	vec2 height_slope = vec2(0.0);
	float w_sum = 0.0;
	for (int x = -1; x <= 2; x++) {
		for (int y = -1; y <= 2; y++) {
			vec2 off = vec2(float(x), float(y));
			vec2 c = p - off - hash22(id + off) + 0.5;
			float dist2 = dot(c, c);
			float w = max(0.0, exp(-dist2 * 2.0) - 0.01111);
			w_sum += w;
			float t = dot(c, side_dir);
			height_slope += vec2(cos(t), -sin(t)) * w;
		}
	}
	return vec3(height_slope.x, height_slope.y * side_dir) / w_sum;
}

// modified & simplified from: https://www.shadertoy.com/view/sf23W1
// returns (height, d/dx, d/dy)
vec3 erosion12(vec2 p) {
	vec3 nd = perlin12d(p);
	float strength = 0.25;
	float freq = 8.0;
	float total = 1.0;
	for (int i = 0; i < 4; i++) {
		float len2 = dot(nd.yz, nd.yz);
		nd += gullies(p * freq, nd.yz * pow(len2, 0.5 * (0.5 - 1.0))) * strength * vec3(1.0, freq, freq);
		total += strength;
		strength *= 0.5;
		freq *= 2.0;
	}
	return nd / total;
}

// Interleaved Gradient Noise
// Cool Property: per pixel values when scrolling IGN linearly each frame is also low-discrepency, so it's low-discrepancy over space and time
float ign12(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float golden_ign12(vec2 p) {
	return float(uint(p.x) * 3242174889u + uint(p.y) * 2447445413u) * exp2(-32.0);
}

/////////// paper / stone / wool ///////////
// These three are separate noises in the original grid, but they are built on small
// fbm helpers (kept private-ish below). Delete this whole section if you don't want them.

float fbm_perlin12(vec2 p, int octaves) {
	float s = 0.0;
	float m = 0.0;
	float a = 1.0;
	for (int i = 0; i < octaves; i++) {
		float n = perlin12(p);
		s += a * n;
		m += a;
		a *= 0.5;
		p *= 2.0;
	}
	return s / m;
}

vec2 fbm_paper(vec2 p, int octaves) {
	vec2 s = vec2(0.0);
	float m = 0.0;
	float a = 1.0;
	for (int i = 0; i < octaves; i++) {
		s += a * clamp(perlin12d(p).yz * 0.5 + 0.5, vec2(0.0), vec2(1.0));
		m += a;
		a *= 0.8;
		p *= 2.0;
	}
	return s / m;
}

float paper12(vec2 p) {
	return length(fbm_paper(p, 10)) / 1.414 * 0.6 + 0.4;
}

vec3 fbm_stone(vec2 p, int octaves) {
	vec3 s = vec3(0.0);
	float a = 1.0;
	for (int i = 0; i < octaves; ++i) {
		s += a * perlin12d(p);
		a *= 0.5;
		p *= 2.0;
	}
	return s;
}

float stone12(vec2 p) {
	return fbm_perlin12(p + fbm_stone(p, 6).yz * 0.4, 6);
}

vec2 fbm_wool(vec2 p, int octaves) {
	vec2 s = vec2(0.0);
	float m = 0.0;
	float a = 1.0;
	for (int i = 0; i < octaves; i++) {
		vec2 n = perlin12d(p).yz;
		s += a * n;
		m += a;
		a *= 0.5;
		p *= 2.0;
	}
	return s / m;
}

float wool12(vec2 p) {
	vec2 n = fbm_wool(p, 6);
	return max(abs(n.x), abs(n.y));
}

/////////// 3D NOISE ///////////
vec4 perm(vec4 x) {
	x *= x * 34.0 + 1.0;
	return x - floor(x / 289.0) * 289.0;
}

float value13(vec3 p) {
	vec3 a = floor(p);
	vec3 d = p - a;
	d *= d * (3.0 - 2.0 * d);
	vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
	vec4 k1 = perm(b.xyxy);
	vec4 k2 = perm(k1.xyxy + b.zzww) + a.zzzz;
	vec4 k3 = perm(k2);
	vec4 k4 = perm(k2 + 1.0);
	vec4 o1 = fract(k3 * 0.02439024);
	vec4 o2 = fract(k4 * 0.02439024);
	vec4 o3 = mix(o1, o2, d.z);
	vec2 o4 = mix(o3.xz, o3.yw, d.x);
	return mix(o4.x, o4.y, d.y);
}

float perlin13(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	vec3 u = f * f * f * (10.0 + f * (6.0 * f - 15.0));
	float a0 = dot(f - vec3(0.0, 0.0, 0.0), normalize(hash33(i + vec3(0.0, 0.0, 0.0)) - 0.5));
	float b0 = dot(f - vec3(1.0, 0.0, 0.0), normalize(hash33(i + vec3(1.0, 0.0, 0.0)) - 0.5));
	float c0 = dot(f - vec3(0.0, 1.0, 0.0), normalize(hash33(i + vec3(0.0, 1.0, 0.0)) - 0.5));
	float d0 = dot(f - vec3(1.0, 1.0, 0.0), normalize(hash33(i + vec3(1.0, 1.0, 0.0)) - 0.5));
	float a1 = dot(f - vec3(0.0, 0.0, 1.0), normalize(hash33(i + vec3(0.0, 0.0, 1.0)) - 0.5));
	float b1 = dot(f - vec3(1.0, 0.0, 1.0), normalize(hash33(i + vec3(1.0, 0.0, 1.0)) - 0.5));
	float c1 = dot(f - vec3(0.0, 1.0, 1.0), normalize(hash33(i + vec3(0.0, 1.0, 1.0)) - 0.5));
	float d1 = dot(f - vec3(1.0, 1.0, 1.0), normalize(hash33(i + vec3(1.0, 1.0, 1.0)) - 0.5));
	float z0 = mix(mix(a0, b0, u.x), mix(c0, d0, u.x), u.y);
	float z1 = mix(mix(a1, b1, u.x), mix(c1, d1, u.x), u.y);
	return mix(z0, z1, u.z) * 0.7 + 0.5;
}

// From: https://iquilezles.org/articles/gradientnoise/
// returns (value, d/dx, d/dy, d/dz)
// NOTE: the original hashed the continuous position p instead of the cell id i (and skipped the
// [-1, 1] remap), which gives incoherent noise. Fixed here to match perlin12d.
vec4 perlin13d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec3 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	vec3 ga = hash33(i + vec3(0.0, 0.0, 0.0)) * 2.0 - 1.0;
	vec3 gb = hash33(i + vec3(1.0, 0.0, 0.0)) * 2.0 - 1.0;
	vec3 gc = hash33(i + vec3(0.0, 1.0, 0.0)) * 2.0 - 1.0;
	vec3 gd = hash33(i + vec3(1.0, 1.0, 0.0)) * 2.0 - 1.0;
	vec3 ge = hash33(i + vec3(0.0, 0.0, 1.0)) * 2.0 - 1.0;
	vec3 gf = hash33(i + vec3(1.0, 0.0, 1.0)) * 2.0 - 1.0;
	vec3 gg = hash33(i + vec3(0.0, 1.0, 1.0)) * 2.0 - 1.0;
	vec3 gh = hash33(i + vec3(1.0, 1.0, 1.0)) * 2.0 - 1.0;
	float va = dot(ga, f - vec3(0.0, 0.0, 0.0));
	float vb = dot(gb, f - vec3(1.0, 0.0, 0.0));
	float vc = dot(gc, f - vec3(0.0, 1.0, 0.0));
	float vd = dot(gd, f - vec3(1.0, 1.0, 0.0));
	float ve = dot(ge, f - vec3(0.0, 0.0, 1.0));
	float vf = dot(gf, f - vec3(1.0, 0.0, 1.0));
	float vg = dot(gg, f - vec3(0.0, 1.0, 1.0));
	float vh = dot(gh, f - vec3(1.0, 1.0, 1.0));
	return vec4(
			va + u.x * (vb - va) + u.y * (vc - va) + u.z * (ve - va) + u.x * u.y * (va - vb - vc + vd) + u.y * u.z * (va - vc - ve + vg) + u.z * u.x * (va - vb - ve + vf) + (-va + vb + vc - vd + ve - vf - vg + vh) * u.x * u.y * u.z,
			ga + u.x * (gb - ga) + u.y * (gc - ga) + u.z * (ge - ga) + u.x * u.y * (ga - gb - gc + gd) + u.y * u.z * (ga - gc - ge + gg) + u.z * u.x * (ga - gb - ge + gf) + (-ga + gb + gc - gd + ge - gf - gg + gh) * u.x * u.y * u.z
					+ du * (vec3(vb, vc, ve) - va + u.yzx * vec3(va - vb - vc + vd, va - vc - ve + vg, va - vb - ve + vf) + u.zxy * vec3(va - vb - ve + vf, va - vb - vc + vd, va - vc - ve + vg) + u.yzx * u.zxy * (-va + vb + vc - vd + ve - vf - vg + vh)));
}

float simplex13(vec3 p) {
	vec3 s = floor(p + dot(p, vec3(1.0 / 3.0)));
	vec3 x = p - s + dot(s, vec3(1.0 / 6.0));
	vec3 e = step(vec3(0.0), x - x.yzx);
	vec3 i1 = e * (1.0 - e.zxy);
	vec3 i2 = 1.0 - e.zxy * (1.0 - e);
	vec3 x1 = x - i1 + 1.0 / 6.0;
	vec3 x2 = x - i2 + 1.0 / 3.0;
	vec3 x3 = x - 0.5;
	vec4 w = vec4(dot(x, x), dot(x1, x1), dot(x2, x2), dot(x3, x3));
	w = max(0.6 - w, 0.0);
	vec4 d = vec4(dot(hash33(s) - 0.5, x),
			dot(hash33(s + i1) - 0.5, x1),
			dot(hash33(s + i2) - 0.5, x2),
			dot(hash33(s + 1.0) - 0.5, x3));
	w *= w;
	w *= w;
	d *= w;
	return dot(d, vec4(26.0)) + 0.5;
}

float worley13(vec3 p) {
	vec3 i = floor(p);
	p -= i;
	float w = 1e6;
	for (float x = -1.0; x <= 1.0; ++x) {
		for (float y = -1.0; y <= 1.0; ++y) {
			for (float z = -1.0; z <= 1.0; ++z) {
				vec3 c = p - vec3(x, y, z) - hash13(i + vec3(x, y, z));
				w = min(w, dot(c, c));
			}
		}
	}
	return 1.0 - sqrt(w);
}

// returns (1 - distance to nearest node, unit direction away from that node)
vec4 worley13d(vec3 p) {
	vec3 i = floor(p);
	p -= i;
	float w = 1e6;
	vec3 cmin = vec3(0.0);
	for (float x = -1.0; x <= 1.0; ++x) {
		for (float y = -1.0; y <= 1.0; ++y) {
			for (float z = -1.0; z <= 1.0; ++z) {
				vec3 c = p - vec3(x, y, z) - hash13(i + vec3(x, y, z));
				float l2 = dot(c, c);
				if (l2 < w) {
					w = l2;
					cmin = c;
				}
			}
		}
	}
	w = sqrt(w);
	return vec4(1.0 - w, -cmin / w);
}
