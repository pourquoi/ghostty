#define TIME        iTime
#define RESOLUTION  iResolution

// START OF PORT

//
// ╓――――――――――――――――――╖
// ║    CRT Effect    ║░
// ║        by        ║░
// ║   DeanTheCoder   ║░
// ╙――――――――――――――――――╜░
//  ░░░░░░░░░░░░░░░░░░░░
//
// Effects: Fish eye, scan lines, vignette, screen jitter,
//          background noise, electron bar, shadows,
//          screen glare, fake surround (with reflections).
//
// License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License

// Parameterized values
const vec3 brightnessBoost = pow(vec3(1.,1.,1.), vec3(2.));
const float 
    enableScanlines       = 1.
  , enableSurround        = 1.
  , enableSignalDistortion= 1.
  , enableShadows         = 1.
  ;

vec2 fisheye(vec2 uv)
{
    float r = 2.5;
    uv *= 1.05;
    return r * uv / sqrt(r * r - dot(uv, uv));
}

float bar(float y)
{
    y += 0.5;
    y = fract(y * 0.7 - TIME * 0.1);
    return smoothstep(0.7, 0.98, y) + smoothstep(0.98, 1.0, 1.-y);
}

float h21(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

vec4 image(vec2 q) {
  vec2 p = -1.+2.*q;
  p *= 1.025;
  vec2 b = step(abs(p), vec2(1.));
  q = 0.5+0.5*p;
  vec4 icol = texture(iChannel0, q);
  return vec4(icol.rgb, b.x*b.y*icol.w); 
}

vec3 dtcmain(vec2 fragCoord)
{
    vec2 res = RESOLUTION.xy;
  
    // UV coords in the range of -0.5 to 0.5
    vec2 uv = (fragCoord / res) - 0.5;

    // Apply fisheye and border effect (if enabled).
    vec2 st = enableSurround > 0.5 ? fisheye(uv) : uv;

    float ns = h21(fragCoord); // Random number, to use later.

    // Monitor screen.
    float rnd = h21(fragCoord + TIME); // Jitter.

//    return vec4(imageRgb, 1.0);

    float bev = enableSurround > 0.5 ? (max(abs(st.x), abs(st.y)) - 0.498) / 0.035 : 0.0;
    if (bev > 0.0)
    {
        // We're somewhere outside the CRT screen area.
        // vec3 col = vec3(0.68, 0.68, 0.592);
        vec3 col = vec3(102., 97., 92.)/255.;
        if (bev > 1.0)
        {
            // Monitor face.
            col -= ns * 0.2;
        }
        else
        {
            // Bevel area.
            col *= mix(0.1, 1.0, bev);
            col = col - vec3(0.0, 0.05, 0.1) * ns;

            // Shadow.
            if (enableShadows > 0. && uv.y < 0.0)
                col *= min(1.0, 0.6 * smoothstep(0.8, 1.0, bev) + 0.8 + smoothstep(0.4, 0.3, length(uv * vec2(0.4, 1.0))));

            // Screen reflection in the bevel.
            float dir = sign(-uv.x);
            vec3 tint = vec3(0);
            for (float i = -5.0; i < 5.0; i++)
            {
                for (float j = -5.0; j < 5.0; j++) {
                    vec4 tcol = image((st * 0.9 + vec2(dir * i, j * 2.0) * 0.002 + 0.5));
                    tint += tcol.rgb*tcol.w;
                }
            }

            tint /= 50.0;
            col = mix(tint, col, 0.8 + 0.2 * bev);
        }

        
        return col;
    }

    vec4 imageRgb = image(st + 0.5 + vec2(rnd * enableSignalDistortion, 0)/res);
    float lum = 1.0;

    // Background noise.
    lum += enableSignalDistortion * (rnd - 0.5)*0.15;

    // Scrolling electron bar.
    lum += enableSignalDistortion * bar(uv.y) * 0.2;

    // Apply scanlines (if enabled).
    // if (enableScanlines > 0.5 && (int(fragCoord.y) % 2) == 0)
        // lum *= 0.8;

    if (enableScanlines > 0.5) {
      float showScanlines = 1.;
      if (iResolution.y<360.) showScanlines = 0.;
      
      float s = 1. - smoothstep(320., 1440., iResolution.y) + 1.;
      float j = cos(st.y*iResolution.y*s)*0.1; // values between .01 to .25 are ok.
      lum = lum - lum*j;
      lum *= 1.- ( .01 + ceil(mod( (st.x+.5)*iResolution.x, 3.) ) * (.995-1.01) );
    }

    // Apply main text color tint.
    imageRgb.rgb *= lum * brightnessBoost;


    vec3 col = vec3(0.);
    if (enableShadows > 0.5)
    {
        // Screen shadow.
        float bright = 1.0;
        if (uv.y < 0.0)
            bright = smoothstep(0.43, 0.38, length(uv * vec2(0.4, 1.0)));
        col *= min(1.0, 0.5 + bright);

        // Glare.
        //col = mix(col, vec3(0.75 + 0.25 * ns), bright * 0.25 * smoothstep(0.7, 0.0, length((uv - vec2(0.15, -0.3)) * vec2(1.0, 2.0))));
    }

    col += imageRgb.rgb*imageRgb.w;
    
    // Vignette.
    col *= 1.0 - 1.2 * dot(uv, uv);
    
    return col;
}
// END OF PORT

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 fc = fragCoord;
    // fc.y = RESOLUTION.y - fc.y;
    fragColor = vec4(dtcmain(fc), 1.);
}
