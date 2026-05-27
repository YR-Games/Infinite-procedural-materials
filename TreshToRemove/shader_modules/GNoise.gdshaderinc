#include "Hash.gdshaderinc"



vec4 gnoised(in vec3 x) {
    vec3 p = floor(x);
    vec3 w = fract(x);

    // Quintic interpolant (оптимизировано)
    vec3 w2 = w * w;
    vec3 w3 = w2 * w;
    vec3 u = w3 * (w * (6.0 * w - 15.0) + 10.0);
    vec3 du = 30.0 * w2 * (w2 - 2.0 * w + 1.0);

    // Gradients (оптимизация через массив)
    vec3 g[8];
    g[0] = hash33(p);
    g[1] = hash33(p + vec3(1.0, 0.0, 0.0));
    g[2] = hash33(p + vec3(0.0, 1.0, 0.0));
    g[3] = hash33(p + vec3(1.0, 1.0, 0.0));
    g[4] = hash33(p + vec3(0.0, 0.0, 1.0));
    g[5] = hash33(p + vec3(1.0, 0.0, 1.0));
    g[6] = hash33(p + vec3(0.0, 1.0, 1.0));
    g[7] = hash33(p + vec3(1.0, 1.0, 1.0));

    // Projections (оптимизация через цикл)
    float v[8];
    for (int i = 0; i < 8; i++) {
        vec3 offset = vec3(float(i & 1), float((i >> 1) & 1),float( (i >> 2) & 1));
        v[i] = dot(g[i], w - offset);
    }

    // Интерполяция значения
    float va = v[0], vb = v[1], vc = v[2], vd = v[3];
    float ve = v[4], vf = v[5], vg = v[6], vh = v[7];

    float val = va + u.x*(vb-va) + u.y*(vc-va) + u.z*(ve-va)
              + u.x*u.y*(va-vb-vc+vd) + u.y*u.z*(va-vc-ve+vg)
              + u.z*u.x*(va-vb-ve+vf)
              + u.x*u.y*u.z*(-va+vb+vc-vd+ve-vf-vg+vh);

    // Интерполяция градиента (оптимизация через векторные операции)
    vec3 d = g[0]
           + u.x*(g[1]-g[0]) + u.y*(g[2]-g[0]) + u.z*(g[4]-g[0])
           + u.x*u.y*(g[0]-g[1]-g[2]+g[3])
           + u.y*u.z*(g[0]-g[2]-g[4]+g[6])
           + u.z*u.x*(g[0]-g[1]-g[4]+g[5])
           + u.x*u.y*u.z*(-g[0]+g[1]+g[2]-g[3]+g[4]-g[5]-g[6]+g[7])
           + du * (vec3(vb-va, vc-va, ve-va)
                   + u.yzx * vec3(va-vb-vc+vd, va-vc-ve+vg, va-vb-ve+vf)
                   + u.zxy * vec3(va-vb-ve+vf, va-vb-vc+vd, va-vc-ve+vg)
                   + u.yzx*u.zxy*(-va+vb+vc-vd+ve-vf-vg+vh));

    return vec4(val, d);
}
