// inspired by RoquefortCheese's fluidsim (github.com/RoquefortCheese/fluidsim)

// this is a stateless version: pass one draws what the ticks converge on (a
// smooth hue field, a contour staircase for the strata, a second-order domain
// warp so the strata flow instead of ringing, and three dithers on one grain
// cell grid), pass two runs exactly one tick of the real rule off the mipmap
// and then shows the raw hue wheel, or maps it onto a warm or a cool palette
// loop.

// `--set scale=1.0`: patch size, 1 is the reference (patches about a sixth of
// the screen height)
#ifndef WP_PARAM_scale
#define WP_PARAM_scale 1.0
#endif
// `--set grain=0.5`: how much of the field is grain; 1 is about the reference's
// density, 0 is none. half, so the strata show through
#ifndef WP_PARAM_grain
#define WP_PARAM_grain 0.5
#endif
// `--set cell=5`: grain cell size in screen pixels (the reference is one pixel
// of a 512 canvas)
#ifndef WP_PARAM_cell
#define WP_PARAM_cell 5.0
#endif
// `--set palette=0`: 0 shows the raw hue wheel like the original (with its pow
// 0.5 display gamma), 1 maps it onto the warm or cool loop
#ifndef WP_PARAM_palette
#define WP_PARAM_palette 0
#endif
// `--set halo=1.5`: the tick's push strength, the original's m. 0 skips the
// tick
#ifndef WP_PARAM_halo
#define WP_PARAM_halo 1.5
#endif
// `--set flow=4`: how hard the coordinates are warped before drawing; 0 is
// concentric rings
#ifndef WP_PARAM_flow
#define WP_PARAM_flow 4.0
#endif
// `--set smear=0.08`: random nudge of the warped position per grain cell, in
// field units (one unit is about a sixth of the screen height); spreads the
// warp's folds. 0 is a hard fold
#ifndef WP_PARAM_smear
#define WP_PARAM_smear 0.08
#endif
// `--set bands=8`: how finely the strata field is cut; more is more, thinner
// rings
#ifndef WP_PARAM_bands
#define WP_PARAM_bands 8.0
#endif
// `--set step=0.12`: turns of hue per ring (0.12 is about 45 degrees)
#ifndef WP_PARAM_step
#define WP_PARAM_step 0.12
#endif
// `--set soft=0.5`: how much of each band is a blend into the next; 0 is a hard
// step, 1 is a ramp
#ifndef WP_PARAM_soft
#define WP_PARAM_soft 0.5
#endif
// `--set jitter=0.4`: how far a ring's edge is dithered, in bands; 0 is a clean
// contour line
#ifndef WP_PARAM_jitter
#define WP_PARAM_jitter 0.4
#endif
// `--set flip=0.7`: how far from the neighborhood a pixel has to be before it
// joins it instead of pushing away, the original's t (1/sqrt(2) is a 90 degree
// hue gap)
#ifndef WP_PARAM_flip
#define WP_PARAM_flip 0.7
#endif
// `--set warmth=1`: 0 is the cool loop, 1 the warm loop, between mixes (muddy).
// a seeded coin flip if unset

// the hue wheel, once around, as a closed loop of six stops in each palette
constant float3 rq_warm[6] = {
  float3(0xf3, 0xe6, 0xc9) / 255.0,   // cream
  float3(0xe0, 0xb3, 0x5a) / 255.0,   // ochre
  float3(0xcf, 0x6a, 0x3c) / 255.0,   // terracotta
  float3(0x8f, 0x3a, 0x3f) / 255.0,   // brick
  float3(0x5a, 0x2e, 0x4b) / 255.0,   // plum
  float3(0xb8, 0x8a, 0x7a) / 255.0,   // dusty rose
};
constant float3 rq_cool[6] = {
  float3(0xe4, 0xed, 0xf1) / 255.0,   // ice
  float3(0x9f, 0xc4, 0xcf) / 255.0,   // pale teal
  float3(0x3f, 0x7f, 0x8c) / 255.0,   // teal
  float3(0x2a, 0x4a, 0x6b) / 255.0,   // slate
  float3(0x1f, 0x2a, 0x4a) / 255.0,   // indigo
  float3(0x7a, 0x8b, 0xb0) / 255.0,   // lavender gray
};

inline float3 rq_loop(constant float3* stops, float h) {
  float x = fract(h) * 6.0;
  int i = int(floor(x));
  return mix(stops[i], stops[(i + 1) % 6], fract(x));
}

// hue angle of a color, 0..1 from red
inline float rq_hue(float3 c) {
  float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
  float d = max(mx - mn, 1e-5);
  float h = (mx == c.r) ? fmod((c.g - c.b) / d + 6.0, 6.0) : (mx == c.g) ? (c.b - c.r) / d + 2.0 : (c.r - c.g) / d + 4.0;
  return h / 6.0;
}

// the automaton's state space: one channel at 0, one at 1, a pure hue
inline float3 rq_normalize(float3 c) {
  float mn = min(c.r, min(c.g, c.b)), mx = max(c.r, max(c.g, c.b));
  return (c - mn) / max(mx - mn, 1e-5);
}

// `--set radius=8`: the tick's box radius, in pixels of the original's 512
// canvas
#ifndef WP_PARAM_radius
#define WP_PARAM_radius 8.0
#endif
constant float rq_radius = WP_PARAM_radius / 512.0;

float4 wp_main(float2 uv, constant Uniforms& u) {
  float aspect = u.res.x / u.res.y;
  float2 p = (uv - 0.5) * float2(aspect, 1.0);
  float2 so = float2(hash11(u.seed + 40.0), hash11(u.seed + 41.0)) * 100.0;

  // the field: a smooth noise per channel at patch scale, normalized to a pure
  // hue. that is what the first five ticks of the flip branch do to white noise
  // (a blur, renormalized). at 1:1 the original has no edges at all: a patch is
  // where most of the grain sits near one hue, and the hue drifts inside it. so
  // the field stays smooth and the grain does the rest
  float freq = 6.0 / WP_PARAM_scale;
  // the flow: the coordinates go through two noise fields before anything is
  // drawn, so the strata come out as tongues and folds instead of concentric
  // rings. the second warp is fed by the first (a straight warp still reads as
  // rings, just wobbly ones)
  float2 q = p * freq + so;
  float2 w1 = float2(fbm(q * 0.5 + float2(3.1, 7.7), 3), fbm(q * 0.5 + float2(-5.9, 2.3), 3)) - 0.5;
  float2 w2 = float2(fbm(q * 0.9 + w1 * 2.0 + float2(8.2, -1.4), 3), fbm(q * 0.9 + w1 * 2.0 + float2(-2.7, 6.6), 3)) - 0.5;
  q += (w1 + w2 * 0.6) * WP_PARAM_flow;
  // the smear: where the warp folds over itself the field jumps, so the sampled
  // position gets a random nudge per grain cell and the jump spreads across a
  // band
  float2 cellp = floor(uv * u.res / WP_PARAM_cell);
  q += (float2(hash21(cellp + so + 31.0), hash21(cellp + so + 37.0)) - 0.5) * WP_PARAM_smear;
  float3 c = float3(fbm(q, 3),
                    fbm(q + float2(31.7, 17.3), 3),
                    fbm(q + float2(-23.1, 44.9), 3));
  float h = rq_hue(rq_normalize(c));

  // the strata. in the original every tick's halo is itself an edge for the
  // next, so rings of born hue march outward from a patch with the hue stepping
  // the same way each ring: magenta core, blue rim, cyan beyond. that is a
  // contour map: one scalar field cut into bands, and the hue steps once per
  // band. the cut is jittered per grain cell, so a band edge is a mix that tips
  // over rather than a line
  float2 cellq = floor(uv * u.res / (WP_PARAM_cell * 2.0) + 0.37);
  float f = fbm(q * 0.7 + float2(12.1, -8.4), 4);
  float jitter = (hash21(cellp + so + 21.0) - 0.5) * WP_PARAM_jitter;
  float x = (f - 0.5) * WP_PARAM_bands + jitter;
  // a staircase with a ramp at the end of each step, so one stratum blends into
  // the next over `soft` of a band instead of switching in a pixel
  float band = floor(x) + smoothstep(1.0 - WP_PARAM_soft, 1.0, fract(x));
  h += band * WP_PARAM_step;

  // the grain: the half of itself a pixel keeps through every flip. two layers
  // of cells, one twice the other, so it clumps; the kick is triangular (two
  // draws), mostly small, sometimes anywhere on the wheel. the reference has
  // 37% of pixels >30 degrees off their surroundings and 19% >60
  float kick = 0.0;
  if (hash21(cellp + so) < WP_PARAM_grain * 0.5) kick += (hash21(cellp + so + 7.0) - hash21(cellp + so + 13.0)) * 0.7;
  if (hash21(cellq + so + 3.0) < WP_PARAM_grain * 0.3) kick += (hash21(cellq + so + 9.0) - hash21(cellq + so + 17.0)) * 0.7;
  h += kick;
  return float4(hsv2rgb(float3(fract(h), 1.0, 1.0)), 1.0);
}

float4 wp_post(float2 uv, texture2d<float> scene, constant Uniforms& u) {
  float3 self = wp_scene(scene, uv).rgb;

  // one tick of the rule. the box mean comes from the mipmap: four taps one
  // level under the box's size, offset by half a radius, is close enough to a
  // box of that width
  float rpx = rq_radius * WP_PARAM_scale * u.res.y;
  float lod = log2(max(rpx, 1.0));
  float2 d = float2(rpx * 0.5) / u.res;
  float3 mean = (wp_scene(scene, uv + float2(-d.x, -d.y), lod).rgb + wp_scene(scene, uv + float2(d.x, -d.y), lod).rgb +
                 wp_scene(scene, uv + float2(-d.x, d.y), lod).rgb + wp_scene(scene, uv + float2(d.x, d.y), lod).rgb) * 0.25;
  float3 diff = self - mean;
  float iso = length(diff);
  self = (iso > WP_PARAM_flip) ? self - diff * WP_PARAM_halo : self + diff * WP_PARAM_halo;
  self = rq_normalize(self);

  // the palette
#ifdef WP_PARAM_warmth
  float warmth = WP_PARAM_warmth;
#else
  // a coin flip: the mixes between the loops go muddy, so a seed gets one or the other
  float warmth = step(0.5, hash11(u.seed + 5.0));
#endif
  float h = rq_hue(self);
  float3 color = (WP_PARAM_palette < 0.5) ? pow(self, float3(0.5)) : mix(rq_loop(rq_cool, h), rq_loop(rq_warm, h), warmth);
  return float4(color, 1.0);
}
