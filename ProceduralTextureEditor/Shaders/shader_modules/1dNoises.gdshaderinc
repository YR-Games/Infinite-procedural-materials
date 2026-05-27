
float hash( float p )
{
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// Basic noise
float brand( in float x )
{
    // setup
    float i = floor(x);
    float f = fract(x);
    float s = sign(fract(x/2.0)-0.5);

    // use some hash to create a random value k in [0..1] from i
  //float k = hash(uint(i));
  //float k = 0.5+0.5*sin(i);
    float k = fract(i*.1731);

    // quartic polynomial
        return 0.5 * s * f * (f - 1.0) * ((16.0 * k - 4.0) * f * (f - 1.0) - 1.0) + 0.5;
}

// Traditional gradient noise
float grand( in float p )
{
    float  i = floor(p);
    float f = fract(p);
	float u = f*f*(3.0-2.0*f);

    float g0 = hash(i)*2.0-1.0;
    float g1 = hash(i+1.)*2.0-1.0;
    return 0.5 + 1.2 * mix(g0 * (f - 0.0), g1 * (f - 1.0), u);
}

////////////////////////////////////

float frand( in float x )
{
    float n = 0.0;
    float s = 1.0;
    for( int i=0; i<9; i++ )
    {
        n += s*brand(x);
        s *= 0.5;
        x *= 2.0;
        x += 0.131;
    }
    return n;
}