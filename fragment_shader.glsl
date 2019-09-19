#version 120
uniform float albedo_r;
uniform float albedo_g;
uniform float albedo_b;
uniform float ks;
uniform float light_r[9];
uniform float light_g[9];
uniform float light_b[9];

uniform sampler2D noise_texture;

varying vec3 view_position;
varying vec3 pixel_position;
varying vec3 world_position;
varying vec3 camera_position;
varying vec3 normal;

float nine_dot_product(float[9] v1, float[9] v2)
{
    float sum = 0.0;
    for(int i = 0; i < 9; i++)
    {
        sum += v1[i] * v2[i];
    }
    return sum;
}

float factorial(int n)
{
    float product = 1.0;
    for(int i = 1; i <= n; i++)
    {
        product *= float(i);
    }

    return product;
}

float K(int l, int m)
{
    float temp = ((2.0 * l + 1.0) * factorial(l - abs(m))) / (4.0 * 3.141 * factorial(l + abs(m)));
    return sqrt(temp);
}

float P(int l, int m, float x)
{
    float pmm = 1.0;
    if(m>0) {
        float somx2 = sqrt((1.0-x)*(1.0+x));
        float fact = 1.0;
        for(int i=1; i<=m; i++) {
            pmm *= (-fact) * somx2;
            fact += 2.0;
        }
    }
    if(l==m) return pmm;
    float pmmp1 = x * (2.0*m+1.0) * pmm;
    if(l==m+1) return pmmp1;
    float pll = 0.0;
    for(int ll=m+2; ll<=l; ++ll) {
        pll = ( (2.0*ll-1.0)*x*pmmp1-(ll+m-1.0)*pmm ) / (ll-m);
        pmm = pmmp1;
        pmmp1 = pll;
    }
    return pll;
}

float spherical_harmonic(int l, int m, float theta, float phi)
{
    // return a point sample of a Spherical Harmonic basis function
    // l is the band, range [0..N]
    // m in the range [-l..l]
    // theta in the range [0..Pi]
    // phi in the range [0..2*Pi]
    const float sqrt2 = sqrt(2.0);
    if(m==0) return K(l,0)*P(l,m,cos(theta));
    else if(m>0) return sqrt2*K(l,m)*cos(m*phi)*P(l,m,cos(theta));
    else return sqrt2*K(l,-m)*sin(-m*phi)*P(l,-m,cos(theta));
}

float[9] sh_1d(float theta, float phi)
{
    float[9] ret;
    for(int l = 0; l < 3; l++)
    {
        for(int m = -l; m <= l; m++)
        {
            int i = l * (l + 1) + m;
            ret[i] = spherical_harmonic(l, m, theta, phi);
        }
    }

    return ret;
}

vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float snoise(vec3 v){ 
    const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
    const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
    vec3 i  = floor(v + dot(v, C.yyy) );
    vec3 x0 =   v - i + dot(i, C.xxx) ;

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min( g.xyz, l.zxy );
    vec3 i2 = max( g.xyz, l.zxy );

    //  x0 = x0 - 0. + 0.0 * C 
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1. + 3.0 * C.xxx;

    // Permutations
    i = mod(i, 289.0 ); 
    vec4 p = permute( permute( permute( 
                i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
            + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
            + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

    // Gradients
    // ( N*N points uniformly over a square, mapped onto an octahedron.)
    float n_ = 1.0/7.0; // N=7
    vec3  ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  //  mod(p,N*N)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4( x.xy, y.xy );
    vec4 b1 = vec4( x.zw, y.zw );

    vec4 s0 = floor(b0)*2.0 + 1.0;
    vec4 s1 = floor(b1)*2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
    vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

    vec3 p0 = vec3(a0.xy,h.x);
    vec3 p1 = vec3(a0.zw,h.y);
    vec3 p2 = vec3(a1.xy,h.z);
    vec3 p3 = vec3(a1.zw,h.w);

    //Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
}

float random_ray(vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

void main()
{
    vec3 interpolated_normal = normalize(normal);

    // sample rays
    float red_sum = 0.0;
    float green_sum = 0.0;
    float blue_sum = 0.0;

    float num_samples = 10000;
    for(int i = 0; i < num_samples; i++)
    {
        float a = texture2D(noise_texture, interpolated_normal.xy * i).r;
        float b = texture2D(noise_texture, interpolated_normal.yz * i).r;
        float theta = 2.0 * acos(sqrt(1.0-a));
        float phi = 2.0 * 3.141 * b;
        float x = sin(theta) * cos(phi);
        float y = sin(theta) * sin(phi);
        float z = cos(theta);
        vec3 sample_ray = vec3(x, y, z);

        // to do: oclusao
        float dot_light = max(dot(interpolated_normal, sample_ray), 0);
        float sh[9] = sh_1d(theta, phi);
        for(int j = 0; j < 9; j++)
        {
            float red_value = dot_light * sh[j] * light_r[j];
            float green_value = dot_light * sh[j] * light_g[j];
            float blue_value = dot_light * sh[j] * light_b[j];
            red_sum += albedo_r * red_value;
            green_sum += albedo_g * green_value;
            blue_sum += albedo_b * blue_value;
        }
    }

    float red_diffuse = red_sum * (4.0 * 3.141) / num_samples;
    float green_diffuse = green_sum * (4.0 * 3.141) / num_samples;
    float blue_diffuse = blue_sum * (4.0 * 3.141) / num_samples;

    gl_FragColor = vec4(red_diffuse, green_diffuse, blue_diffuse, 1.0);
}