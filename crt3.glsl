#define CURVATURE 1.
#define SCANLINES 1.
#define CURVED_SCANLINES 1.
#define BLURED 1.
#define LIGHT 1.
#define COLOR_CORRECTION 1.
//#define ASPECT_RATIO 1.

const float gamma = 1.;
const float contrast = 1.;
const float saturation = 1.;
const float brightness = 1.;

const float light = 9.;
const float blur = 1.5;

vec3 postEffects(in vec3 rgb, in vec2 xy) {
    rgb = pow(rgb, vec3(gamma));
    rgb = mix(vec3(.5), mix(vec3(dot(vec3(.2125, .7154, .0721), rgb*brightness)), rgb*brightness, saturation), contrast);

    return rgb;
}

// Sigma 1. Size 3
vec3 gaussian(in vec2 uv) {
    float b = blur / (iResolution.x / iResolution.y);

    uv+= .5;

    vec3 col = texture(iChannel0, vec2(uv.x - b/iResolution.x, uv.y - b/iResolution.y) ).rgb * 0.077847;
    col += texture(iChannel0, vec2(uv.x - b/iResolution.x, uv.y) ).rgb * 0.123317;
    col += texture(iChannel0, vec2(uv.x - b/iResolution.x, uv.y + b/iResolution.y) ).rgb * 0.077847;

    col += texture(iChannel0, vec2(uv.x, uv.y - b/iResolution.y) ).rgb * 0.123317;
    col += texture(iChannel0, vec2(uv.x, uv.y) ).rgb * 0.195346;
    col += texture(iChannel0, vec2(uv.x, uv.y + b/iResolution.y) ).rgb * 0.123317;

    col += texture(iChannel0, vec2(uv.x + b/iResolution.x, uv.y - b/iResolution.y) ).rgb * 0.077847;
    col += texture(iChannel0, vec2(uv.x + b/iResolution.x, uv.y) ).rgb * 0.123317;
    col += texture(iChannel0, vec2(uv.x + b/iResolution.x, uv.y + b/iResolution.y) ).rgb * 0.077847;

    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 st = (fragCoord.xy / iResolution.xy) - vec2(.5);
    
    // Curvature/light
    float d = length(st*.5 * st*.5);
#ifdef CURVATURE
    vec2 uv = st*d + st*.935;
#else
    vec2 uv = st;
#endif

    // Fudge aspect ratio
#ifdef ASPECT_RATIO
    uv.x *= iResolution.x/iResolution.y*.75;
#endif
    
    // CRT color blur
#ifdef BLURED
    vec3 color = gaussian(uv);
#else
    vec3 color = texture(iChannel0, uv+.5).rgb;
#endif

    // Light
#ifdef LIGHT
    float l = 1. - min(1., d*light);
    color *= l;
#endif

    // Scanlines
#ifdef CURVED_SCANLINES
    float y = uv.y;
#else
    float y = st.y;
#endif

    float showScanlines = 1.;
    if (iResolution.y<360.) showScanlines = 0.;
    
#ifdef SCANLINES
    float s = 1. - smoothstep(320., 1440., iResolution.y) + 1.;
    float j = cos(y*iResolution.y*s)*.1; // values between .01 to .25 are ok.
    color = abs(showScanlines-1.)*color + showScanlines*(color - color*j);
    color *= 1. - ( .01 + ceil(mod( (st.x+.5)*iResolution.x, 3.) ) * (.995-1.01) )*showScanlines;
#endif

    // Border mask
#ifdef CURVATURE
        float m = max(0.0, 1. - 2.*max(abs(uv.x), abs(uv.y) ) );
        m = min(m*200., 1.);
        color *= m;
#endif

    // Color correction
#ifdef COLOR_CORRECTION
    color = postEffects(color, st);
#endif

	fragColor = vec4(max(vec3(.0), min(vec3(1.), color)), 1.);
}
