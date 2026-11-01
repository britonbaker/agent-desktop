#include <metal_stdlib>
using namespace metal;

// The face, entirely in a fragment shader. No geometry, no mask texture: a fullscreen
// triangle, and every pixel works out for itself which dot of the grid it belongs to
// and whether that dot sits inside an eye, a brow or the mouth.
//
// Output is extended-range sRGB: gamma-encoded like the canvas, so the arithmetic
// below is the same arithmetic the canvas renderer does and the two cannot drift on
// colour. Extended *linear* was tried first and gave a visibly darker, more
// saturated face — correct physics, wrong picture, because these numbers were tuned
// compositing in sRGB.
//
// The range is what this exists for: values above 1.0 are not clipped, and on a
// display with EDR headroom they drive the panel genuinely brighter than white. The
// bright band in each eye is the thing that wants it. A canvas in a webview tops out
// at white however it is written, which is what the SDR renderer approximates.

struct Uniforms {
    float2 res;
    float  time;
    float  mouth;   // -1 frown .. 0 flat .. 1 the drawn smile, beyond for wider
    float  lift;    // brows raised
    float  tilt;    // inner ends up (+) or set (-)
    float  skew;    // one brow alone
    float  open;    // eye openness
    float  level;   // mic level 0..1
    float  blink;
    float  hue;     // degrees
    float  sat;     // 0..1
    float  nod;     // -1..1, vertical gesture offset
    float  shake;   // -1..1, horizontal gesture offset
    float  wake;    // 0..1, eyes opening on launch
    float  gaze;    // -1..1 horizontal
    float  gazeY;   // -1..1 vertical
    float  pupil;       // where the band sits inside the eye: -up .. +down
    float  pupilScale;  // band thickness
    float  edr;         // headroom multiplier for the hot cores
    float  lattice;     // brightness of an unlit cell
    float  panelFrac;   // panel height as a fraction of the window
    float  panelWFrac;  // panel width as a fraction of the window
    float  radiusFrac;  // corner radius as a fraction of the window width
    float  panelTopFrac; // where his panel starts, as a fraction of the window
    float  tiltX;       // radians, his panel turning to face left (-) or right (+)
    float  tiltY;       // radians, tipping back (-) or forward (+)
    // The same two rotations again, written by Rust rather than by the page: how he
    // is being thrown about. Kept separate because they are added to what he is
    // doing with his eyes, not substituted for it, and because the page pushes
    // twenty times a second while a drag needs every frame.
    float  dragX;
    float  dragY;
    // Which part of his face this window is showing, and how much of it.
    //
    // Zero zoom means the whole face, fitted, which is what his own window does.
    // Anything else crops: the point in mask space at `focus` goes to the middle of
    // the window at `zoom` times the normal dot size. It is the same face, the same
    // rig, the same lattice — just a smaller window onto it.
    // Two scalars, not a float2. A float2 is eight-byte aligned in Metal and a
    // [f32; 2] is four-byte aligned in Rust, so with an odd number of floats in
    // front of it the shader reads every field after it from the wrong offset —
    // which looks exactly like the uniform silently not working.
    float  focusX;
    float  focusY;
    float  zoom;
    /// Draw the brows as strokes rather than sampling them into the grid, and
    /// outside the panel rather than clipped to it — floating above it.
    float  smoothBrow;
    /// The shape of the screen itself. Zero is the rounded rectangle he normally
    /// is; one is two circles, one over each eye, with nothing in between.
    float  mask;
    /// Grow each eye by this fraction of its radius. On two circular screens the
    /// drawn eye stopped a ring of cells short of the rim and read as a small eye
    /// on a big screen rather than as a screen that is an eye.
    float  eyeGrow;
    /// Push the eyes apart from the face's centre line by this fraction. A face
    /// sets them where a face wants them; two screens want more air between them.
    float  eyeSpread;
    /// A reflective screen instead of an emissive one.
    ///
    /// Everything else here assumes light comes *out* of him: a lit cell is bright,
    /// it blooms, and on a display with headroom its core goes past white. A
    /// twisted-nematic panel with no lamp behind it does the opposite — the cell
    /// that is on is the cell that has gone dark, and the brightest thing on the
    /// screen is the part that is doing nothing. Same rig, same lattice, same
    /// expressions; the mapping from coverage to colour is turned over.
    float  lcd;
    /// And the lamp behind it. Off is a sheet of polariser read by whatever light
    /// is in the room, which is grey-green and low in contrast. On is the same
    /// panel lit from behind, which is greener, brighter, and darker where it is
    /// dark — the only control the hardware ever had that changed how it looked.
    float  lamp;
    /// The two lids on the circles, past what `open` already says.
    ///
    /// `hood` brings the top one further down than the eye being open that much
    /// would; `lidLow` raises the bottom one, which is a thing an eye does under a
    /// smile and not a thing an eye does on the way to being shut. They are
    /// separate because on him they are separate: he narrows from below when he is
    /// pleased and from above when he is not, and a single openness cannot say
    /// which.
    float  hood;
    float  lidLow;
    /// How far the mouth is open, separately from which way it bows. Tied to the
    /// bow, a frown could only be a thin line.
    float  gape;
    /// The sticky hand's swing, in radians. Written by Rust, not the page: it is
    /// integrated against how fast he is actually moving, which is a thing only the
    /// side holding the window knows.
    float  swing;
    /// How far the readout has scrolled, in cells. A character is eight of them, so
    /// the page hands over a window of the message and the fraction of a character
    /// it is between — which is what makes it slide rather than step.
    float  textShift;
    /// The three buttons under the label, lit 0..1 each. Lit ones go past white on
    /// a display with the headroom, the same way the band in an eye does.
    float  btn[3];
    /// What the strip under his eyes is reading out, as six glyph indices into the
    /// font below. Indices rather than characters: the page owns the words, the
    /// shader owns the shapes, and neither has to agree about an encoding. An array
    /// of floats is four-byte aligned on both sides of the wall, so unlike a float2
    /// it can sit here without shifting everything after it.
    /// Twelve, where nine fit across the strip. The extra three are what is
    /// coming in from the right and going out on the left; the strip's own outline
    /// crops them, so nothing here has to know where its edge is.
    float  text[12];
};

struct VOut { float4 pos [[position]]; float2 uv; };

vertex VOut v_main(uint vid [[vertex_id]]) {
    // one oversized triangle, no vertex buffer
    float2 p = float2((vid << 1) & 2, vid & 2) * 2.0 - 1.0;
    VOut o;
    o.pos = float4(p, 0.0, 1.0);
    o.uv  = p * 0.5 + 0.5;
    return o;
}

// --- geometry, in the design SVG's own 148x158 coordinates --------------------
constant float SVG_W = 148.0, SVG_H = 158.0, PADDING = 14.0;
constant float EYE_Y = 74.7015, EYE_RX = 25.7625, EYE_RY = 29.9906;
constant float EYE_LX = 34.3875, EYE_RX_ = 121.294;
constant float BAND_H = 11.7396;
// A shut eye: the mouth's curve with most of the bend taken out. Same numbers as
// face-mask.mjs, which is the copy the icon and the menu bar glyph read.
constant float LID_STROKE = 8.0, LID_BEND = 9.0, SHUT_AT = 0.22;
constant float STROKE = 10.0, MOUTH_STROKE = 6.5;
// Cells across the mask. His whole face is drawn at thirty, which is the pitch the
// icon and the menu bar glyph are cut at; the circles are drawn at ninety, because
// on the reference the pupil alone is a dozen pixels tall and at thirty it was
// four. Three times the pitch, so his proportions are untouched and only the grain
// changes — the eye goes from thirteen cells across to thirty-eight.
constant float NX_FACE = 30.0, NX_EYES = 90.0;

float nxFor(constant Uniforms &u) { return u.mask > 0.5 ? NX_EYES : NX_FACE; }

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// distance to a quadratic bezier — brows and mouth are both one of these
float sdBezier(float2 pos, float2 A, float2 B, float2 C) {
    float2 a = B - A, b = A - 2.0 * B + C, c = a * 2.0, d = A - pos;
    float kk = 1.0 / max(dot(b, b), 1e-4);
    float kx = kk * dot(a, b);
    float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
    float kz = kk * dot(d, a);
    float p = ky - kx * kx, p3 = p * p * p;
    float q = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
    float h = q * q + 4.0 * p3;
    if (h >= 0.0) {
        h = sqrt(h);
        float2 x = (float2(h, -h) - q) / 2.0;
        float2 uv2 = sign(x) * pow(abs(x), float2(1.0 / 3.0));
        float t = clamp(uv2.x + uv2.y - kx, 0.0, 1.0);
        return length(d + (c + b * t) * t);
    }
    float z = sqrt(-p);
    float v = acos(q / (p * z * 2.0)) / 3.0;
    float m = cos(v), n = sin(v) * 1.732050808;
    float3 t = clamp(float3(m + m, -n - m, n - m) * z - kx, 0.0, 1.0);
    return min(length(d + (c + b * t.x) * t.x), length(d + (c + b * t.y) * t.y));
}

/// Where an eye's centre is, once it has been pushed out from the middle. One
/// place decides it, because the eye, the brow over it and the circle around it all
/// have to agree or they come apart.
float eyeX(float side, constant Uniforms &u) {
    // About the eyes' own midpoint, not the face's. They are not symmetric about
    // the middle of the drawing, so spreading them from it slides the pair sideways
    // as it opens — three points of drift at a third of a spread.
    const float mid = (EYE_LX + EYE_RX_) * 0.5;
    float base = side < 0.0 ? EYE_LX : EYE_RX_;
    return mid + (base - mid) * (1.0 + u.eyeSpread);
}

// ---------------------------------------------------------------------------
// The strip under his eyes, and the font it reads out in.
//
// Three by five, which is the smallest a letter can be and still be a letter, and
// the same three by five the weather card is drawn in. Each glyph is fifteen bits,
// row-major from the top left; the table is indexed rather than keyed by character
// so the page can own the words and the shader can own the shapes without the two
// of them having to agree about an encoding.
//
// The glyphs are placed on whole cells, not in continuous space. Everything here is
// sampled once per cell at that cell's centre, so a letter laid out in cells comes
// out as whole dots with no fitting and no fringe — the text is made of the same
// pixels his eyes are, because it is being drawn by the same grid.
constant uint FONT[40] = {
    0u, 23530u, 15083u, 25166u, 15211u, 29391u, 4815u, 27470u,
    23533u, 29847u, 11044u, 23277u, 29257u, 23549u, 24573u, 11114u,
    4843u, 26474u, 23275u, 14478u, 9367u, 31597u, 11117u, 24557u,
    23213u, 9389u, 29351u, 31599u, 29850u, 29671u, 31207u, 18925u,
    31183u, 31695u, 9383u, 31727u, 31215u, 8192u, 1040u, 448u,
};

// The strip, in cells of the circles' own grid: six glyphs, each pixel of them three
// cells square, with a glyph pixel of gap between. Written as cell indices because
// that is the only place they can be and land on whole dots — and at three cells to
// a glyph pixel the letters stay the size they were when the grid was a third as
// fine, rather than shrinking with it.
// Written out rather than derived: a `floor` in a program-scope constant is a
// global constructor, which Metal will not link. 176/90 and 186/95, where 95 is
// floor(90 * 186/176) — the same row count layoutFor works out.
constant float CELL_W = 1.9555556;
constant float CELL_H = 1.9578947;
constant int   GLYPH_S = 2;                                  // cells per glyph pixel
constant int   TEXT_X = 11, TEXT_Y = 131;                    // top-left cell
constant int   TEXT_N = 12;                                  // slots; nine are visible
// Under the bar rather than over it. The bar is what becomes his mouth while he
// talks, and on the thing this is copied from the label sits below the mouth, not
// between it and the eyes.
constant float STRIP_CX = 91.84, STRIP_CY = 265.3;           // centre, mask units
constant float STRIP_HW = 73.0, STRIP_HH = 21.0;             // half extent
// The plastic, and the mouth printed on it. Mask units for the body and the strip,
// SVG units for the mouth, because that is the space faceMask and browCov work in.
constant float BODY_CX = 92.0, BODY_CY = 179.0;
constant float BODY_HW = 92.0, BODY_HH = 177.0;
// The perforation around his middle, at the eyes' own height, and the yellow he is
// bracketed and bordered in.
constant float SEAM_Y = 88.70;
// The roll he is. Its axis runs left to right at this height, with this radius, and
// below this it stops being a roll and becomes the flat panel the buttons are on.
constant float ROLL_AX = 116.0, ROLL_R = 175.0;
// Where the roll stops being one. Not a line — a line is a step in the map and a
// step in the map is a seam across him, which is what the first attempt drew.
constant float ROLL_FADE0 = 205.0, ROLL_FADE1 = 290.0;
// And the second one, between the label and the buttons. The first says he is a
// roll; this one says the panel under him is a separate moulding.
constant float SEAM2_Y = 300.0;
constant float3 YELLOW = float3(0.957, 0.757, 0.208);
// The three buttons, and the colours they are moulded in.
constant float BTN_Y = 320.0, BTN_DX = 46.0;
constant float BTN_HW = 19.0, BTN_HH = 15.0;
// Where the mouth sits under the eyes: a little under two eye-radii down, which is
// where the reference puts it.
constant float MOUTH_CX = 77.84, MOUTH_CY = 136.0;
/// Half the thickness a shut mouth keeps. Below this the opening is a stroke.
constant float LIP = 2.1;

/// Coverage of the readout at a point in SVG space.
float textCov(float2 p, constant Uniforms &u) {
    if (u.mask < 0.5) return 0.0;
    // Mask space, then cells. The one place in this shader that wants a cell index
    // rather than a position, because a letter that is not on the grid is a smudge.
    // The shift slides the whole grid left under a fixed strip, and is the one
    // thing in here that wants a fractional cell: everything else lands on whole
    // ones, and this is the part that is moving.
    int cx = int(floor((p.x + PADDING) / CELL_W + u.textShift)) - TEXT_X;
    int cy = int(floor((p.y + PADDING) / CELL_H)) - TEXT_Y;
    if (cx < 0 || cy < 0) return 0.0;
    int gx = cx / GLYPH_S, gy = cy / GLYPH_S;   // which pixel of which glyph
    if (gy > 4) return 0.0;
    int slot = gx / 4;                          // three pixels of glyph, one of gap
    int col = gx - slot * 4;
    if (slot >= TEXT_N || col > 2) return 0.0;
    uint bits = FONT[clamp(int(u.text[slot]), 0, 39)];
    return (bits & (1u << uint(gy * 3 + col))) != 0u ? 0.90 : 0.0;
}

/// Coverage of the brows alone, so they can either be sampled into the dot grid
/// with everything else or stroked straight onto the panel.
float2 browCov(float2 p, constant Uniforms &u) {
    float2 cov = float2(0.0);
    // Cropped to the circles the eyes are two thirds again as big, so a brow that
    // travels the distance it travels on his whole face covers about half as much
    // of the eye under it: the same expression, played smaller. The travel grows
    // with the eye. The brow itself does not — it was asked to be small.
    // Half again on the circles, past what the eye's own growth asks for: the brows
    // are the smallest thing on him and the only one that can say anything while
    // the eyes are two dots, so they get the gain.
    float move = u.mask > 0.5 ? (1.0 + u.eyeGrow) * 1.55 : 1.0;
    float browDX = u.gaze * 4.5 * 0.6 * move;
    for (int s = 0; s < 2; s++) {
        float side = s == 0 ? -1.0 : 1.0;
        float2 A = float2(side < 0.0 ? 53.2969 : 87.2578, 6.21875);
        float2 B = float2(side < 0.0 ? 19.0652 : 121.489, 3.2504);
        float2 C = float2(side < 0.0 ? 4.43632 : 136.118, 19.3109);
        float2 mid = (A + C) * 0.5;
        // On the circles each brow slides to sit over the middle of its own eye.
        // The drawn face puts them where they belong on a face, which is not the
        // same place once everything but the eyes has been masked away.
        // The midpoint of its ends, which is the middle of the shape you see.
        float centre = eyeX(side, u) - mid.x;
        float ang = side * u.tilt * 0.34 * move;
        float ca = cos(ang), sa = sin(ang);
        // One vertical number, and bounded.
        //
        // The lift and the eye's own opening both raise the brows, they were
        // applied at two different points either side of the rotation, and neither
        // had a limit. Frightened — lift up, eyes wide, and the live read adding
        // its own — took them clean off the top of the case. Together, clamped, and
        // the ceiling is where the moulding is.
        float dy = (u.gazeY * 3.5 * 1.5 - (u.open - 1.0) * 22.0 + u.blink * 3.0) * move
                 - (u.lift * 9.0 + (side < 0.0 ? u.skew * 9.0 : 0.0)) * move;
        float2 q = p - float2(browDX + centre * u.mask, clamp(dy, -13.0, 22.0)) - mid;
        q = float2(q.x * ca + q.y * sa, -q.x * sa + q.y * ca) + mid;

        // Smaller on the circles. Scaling the space the curve is measured in rather
        // than the curve takes the stroke with it, so the brow thins in proportion
        // instead of staying a face's brow drawn shorter.
        if (u.mask > 0.5) q = (q - mid) / 0.62 + mid;
        float d = sdBezier(q, A, B, C);
        // Thick at the inner end and drawn out to a point at the outer one. A
        // constant width is a stroke; an eyebrow is a shape with a direction to it.
        float t = clamp((q.x - C.x) / (A.x - C.x), 0.0, 1.0);
        // Pointed at both ends, thickest across the middle. It used to taper one
        // way only, from a blunt inner end out to a thinner outer one, which is a
        // stroke that ran out rather than a brow — on the toy both ends come to a
        // point and the weight is in the middle of the curve.
        float halfW = STROKE * 0.5 * (0.16 + 0.84 * sin(t * 3.14159265));
        cov.x = max(cov.x, (1.0 - smoothstep(halfW - 1.0, halfW + 1.0, d)) * 0.70);
        // The same shape, spread. Every dot on the panel sits on the panel's ground
        // and in its bloom; a brow stroked outside the screens sits on nothing, and
        // that difference is the whole of why they never looked like the mouth.
        cov.y = max(cov.y, 1.0 - smoothstep(halfW - 1.0, halfW + 7.0, d));
    }
    return cov;
}

// coverage of the face at a point in SVG space: 0 nothing, up to 1 solid
float faceMask(float2 p, constant Uniforms &u) {
    float cov = 0.0;

    float openRaw = u.open * (1.0 - u.blink) * u.wake;
    float openF = max(0.05, openRaw);
    float grow = 1.0 + u.eyeGrow;
    float erx = EYE_RX * grow;
    float ry = EYE_RY * grow * openF;
    // An ellipse squashed towards nothing tapers to points at both ends, so the
    // last of it wide enough to cover a cell is the middle two or three dots: he
    // lost his eyes rather than closing them. Below SHUT_AT they become lids.
    float shutF = 1.0 - smoothstep(0.0, SHUT_AT, openRaw);

    // The eye moves a little; the band inside it moves about three times as far and
    // is cut off against the far edge. That difference is what makes an eye read as
    // looking somewhere rather than as a shape being translated.
    for (int i = 0; i < 2; i++) {
        float ex = eyeX(i == 0 ? -1.0 : 1.0, u) + u.gaze * 1.8;
        float ey = EYE_Y + u.gazeY * 1.5;
        float2 d = (p - float2(ex, ey)) / float2(erx, ry);
        float inside = 1.0 - smoothstep(0.92, 1.04, length(d));

        if (u.mask > 0.5) {
            // A screen with a shutter over it, which is what the reference is: the
            // circle is lit glass, a lid comes down flat across the top of it with
            // one bold line along its edge, and the pupil is a dot hanging off that
            // line rather than a bar drawn through the middle.
            //
            // The dot hangs *from* the lid, not inside the eye, so it needs no
            // occlusion of its own: as the eye shuts the lid descends, takes the
            // pupil with it, and both leave the circle together. That also makes
            // the blink a shutter closing, which is what a lid on a screen does and
            // what the old bent arc was drawing a picture of.
            float side = i == 0 ? -1.0 : 1.0;
            float R = erx * 0.90;                 // the radius the circle really is
            float2 q = p - float2(ex, ey);
            // The glass does not squash — the lid comes down over it. `inside` is
            // the old eye, whose vertical radius collapses with `open`, and using
            // it here shut the eye by flattening the screen down to a slit. This
            // one is the circle, at full size whatever the lid is doing.
            //
            // Hard, like everything else in here. Coverage is sampled once per cell
            // and then quantised to four shades, so anything that fades across an
            // edge puts a row of middle shades along it — a dither. A screen with
            // four levels does not dither its own pupil: a pixel is on or it is
            // off, the edge steps, and the step is the look. What is smooth is the
            // lens over the top, which is glass and not a pixel.
            float within = 1.0 - step(R, length(q));
            float lash = R * 0.085;               // half-thickness of a lid's edge

            // The top lid, tilted so it falls toward the middle of his face. It is
            // his resting look and it is not symmetric about the eye, so the edge
            // is a sloped line rather than a height: `side` mirrors it, and the
            // brows' own tilt bends it further, because a lid that stayed flat
            // while the brow over it moved read as two unrelated parts.
            // Slight. At a fifth of a radian across the lid, plus the lid itself
            // sitting on the eye at rest, the pair of them read as a squint — which
            // is to say as angry, which he is not.
            float aT = 0.08 - u.tilt * 0.30;
            // Shut, the edge rests on the bottom rim; wide, it is off the top of
            // the circle entirely. `hood` is the expression pulling it down past
            // where openness alone would have it.
            // Off the top of the circle at rest, not resting on it. Anything the
            // lid covers while he is simply open is a narrowing, and a narrowed eye
            // under a brow is a glare.
            float topY = (0.94 - (openF - u.hood) * 2.32) * R;
            float tEdge = topY - side * aT * q.x;

            // And the bottom one, which comes up the way a cheek does under a
            // smile. Not the same movement as closing: it rises to about a third
            // and stops, and the pupil stays above it rather than being covered.
            float botY = mix(1.10, 0.40, clamp(u.lidLow, 0.0, 1.0)) * R;

            float lidT = within * (1.0 - step(tEdge, q.y));
            float lidB = within * step(botY, q.y);
            cov = max(cov, max(lidT, lidB) * 0.38);      // darkens a little, no more

            float eT = within * (1.0 - step(lash, abs(q.y - tEdge)));
            float eB = within * (1.0 - step(lash, abs(q.y - botY)));
            float edge = max(eT, eB);
            cov = max(cov, edge * 0.90);   // the darkest shade, but not the hot one

            // The pupil sits in the eye and the lids cover it, rather than hanging
            // off the top one. With a lid coming up from underneath as well there
            // is no one edge for it to hang from, and on the reference it is plainly
            // floating in the middle of the glass with the lids closing over it.
            //
            // A third of the eye across, measured off the reference rather than
            // guessed at — and it has to survive being rounded to whole cells, so
            // the two earlier guesses came out three cells and two, which read as a
            // full stop rather than a pupil.
            // A little over a quarter of the eye across. A third was right against
            // the reference's wide-open eye and too much against ours, which has
            // lids taking green out of the field around it.
            // Measured off the product shot, where nothing is squinting: the pupil
            // is a bit under four tenths of the eye across. A fifth was right while
            // the lids were eating the field around it and far too small once they
            // stopped.
            // `pupilScale` sized the bright band's thickness on his own face and
            // has nothing to do on the circles, where there is no band. It sizes
            // the pupil instead: the same idea — how much of the eye the dark part
            // takes — against different geometry. A small pupil in a wide eye is
            // most of what fear looks like.
            float pr = R * 0.31 * clamp(u.pupilScale, 0.30, 1.6);
            float2 pc = float2(u.gaze * R * 0.26, u.gazeY * R * 0.14 - R * 0.06);
            float dot = within * (1.0 - step(pr, length(q - pc)));
            cov = max(cov, dot * (1.0 - max(max(lidT, lidB), edge)));
            continue;
        }

        cov = max(cov, inside * 0.38 * (1.0 - shutF));       // dim body
        float bh = BAND_H * max(0.45, openF) * u.pupilScale;
        float py = ey + u.gazeY * 4.5 + u.pupil * ry;
        float band = inside * (1.0 - smoothstep(bh * 0.42, bh * 0.56, abs(p.y - py)));
        cov = max(cov, band * (1.0 - shutF));

        float2 lA = float2(ex - erx, ey);
        float2 lB = float2(ex, ey + LID_BEND * grow);
        float2 lC = float2(ex + erx, ey);
        float dl = sdBezier(p, lA, lB, lC);
        // Brow and mouth weight, not pupil weight: the bright band *is* the
        // pupil, and one behind a closed lid is not visible.
        float lid = 1.0 - smoothstep(LID_STROKE * 0.5 - 1.0, LID_STROKE * 0.5 + 1.0, dl);
        cov = max(cov, lid * shutF * 0.70);
    }

    // brows: mirrored quadratics, rotated about their own midpoint for tilt. They
    // also ride with the eyes — less than one-to-one sideways, more than one-to-one
    // vertically, up with a wide eye and down with a squint, dipping through a blink.
    if (u.smoothBrow < 0.5) cov = max(cov, browCov(p, u).x);


    cov = max(cov, textCov(p, u));

    // mouth: control offsets scale with `mouth`, so 1.0 is exactly the drawn smile.
    // Not on the circles — it was outside them and invisible anyway, and the strip
    // that is there now runs straight through where it is drawn.
    if (u.mask < 0.5) {
        float2 A = float2(37.5703, 141.477);
        float2 B = float2(71.3, 141.477 + 20.8 * u.mouth);
        float2 C = float2(106.117, 141.477);
        float d = sdBezier(p, A, B, C);
        cov = max(cov, (1.0 - smoothstep(MOUTH_STROKE * 0.5 - 1.0, MOUTH_STROKE * 0.5 + 1.0, d)) * 0.70);
    }
    return cov;
}

float3 hsl2rgb(float h, float s, float l) {
    float3 k = fract(h / 360.0 + float3(0.0, 2.0 / 3.0, 1.0 / 3.0));
    float3 p = abs(k * 6.0 - 3.0);
    float3 c = clamp(p - 1.0, 0.0, 1.0);
    return l + s * min(l, 1.0 - l) * (2.0 * c - 1.0);
}

// ---------------------------------------------------------------------------
// The four shades a Game Boy had.
//
// Not a green filter over the same picture. The hardware could address four levels
// and no more, and that constraint is most of why anything drawn for it looks the
// way it does — so the coverage is quantised to four before it is coloured. It
// lands on them almost by itself: the dim body of an eye is one step, a brow or the
// mouth is two, the band inside an eye is three.
//
// Two ramps, because the lamp is not a brightness knob. Unlit, the screen is
// whatever light is in the room bouncing off grey-green polariser: pale, olive,
// and low in contrast because the darkest it can be is still reflecting. Lit from
// behind it is a different screen — properly green, and far deeper in the darks,
// since the light it is blocking is the lamp's rather than yours.
constant float3 DMG_DIM[4] = {
    float3(0.690, 0.816, 0.722),   // b0d0b8  the glass, doing nothing
    float3(0.494, 0.627, 0.541),   // 7ea08a
    float3(0.290, 0.408, 0.353),   // 4a685a
    float3(0.149, 0.227, 0.196),   // 263a32
};
constant float3 DMG_LAMP[4] = {
    float3(0.635, 0.886, 0.698),   // a2e2b2
    // The hardware's second shade is all but its first — a quirk every emulator
    // inherits and nobody notices, because a sprite that used it used it for one
    // pixel. A whole eye is drawn at this level, so it is stepped down until it is
    // a shade rather than a rounding error.
    float3(0.408, 0.706, 0.510),   // 68b482
    float3(0.173, 0.431, 0.298),   // 2c6e4c
    float3(0.071, 0.227, 0.157),   // 123a28
};

float3 dmg(float shade, constant Uniforms &u) {
    int i = int(clamp(shade, 0.0, 3.0));
    if (u.lcd > 1.5) {
        constexpr float neutral[4] = {1.0, 0.016, 0.009, 0.006};
        float brightness = i == 0 ? 1.0 + max(0.0, u.edr - 1.0) * 0.45 * u.lamp : 1.0;
        return float3(neutral[i] * brightness);
    }
    float3 c = mix(DMG_DIM[i], DMG_LAMP[i], clamp(u.lamp, 0.0, 1.0));
    // A lit screen is not a greener screen, it is a brighter one.
    //
    // The lamp was a second palette and nothing else, so switching it on changed
    // the hue and left the brightness where it was — which is why it read as a
    // filter rather than as a light. This is the headroom the band in an eye has
    // always used: on a display that has it, a backlit cell goes past white, and
    // that is the only thing that looks like a lamp behind glass.
    //
    // Only the shades letting light through. The dark ones are blocking it, and a
    // backlight makes those deeper rather than brighter.
    // Enough that green alone goes past one. Take red and blue over with it and the
    // screen blows out to white, which is a lamp that is too close rather than a
    // lamp behind a green panel.
    if (i < 2) c *= 1.0 + clamp(u.lamp, 0.0, 1.0) * u.edr * (i == 0 ? 0.105 : 0.060);
    return c;
}

/// Signed distance to a fat line: the one primitive a rubber hand is made of.
float sdSeg(float2 p, float2 a, float2 b, float r) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

/// His sticky hand, hung on the handle.
///
/// The cursor one is the same toy doing its job; this is it at rest, looped over
/// the bar with the hand dangling in front of him. Six capsules and a palm — a
/// sticky hand is a shape you know by its silhouette and by nothing else, which is
/// why the fingers have to splay and the arm has to be far too long for it.
///
/// Mask units, and it hangs from the right so it does not cross his face.
float stickySDF(float2 pm, constant Uniforms &u) {
    if (u.mask < 0.5) return 1e9;
    float2 w = float2(-5.0, 4.0);               // where it grips the left arm
    // The grip does not move; everything below it hangs off it. So the band is
    // measured where it is and the rest is measured in a frame rotated about the
    // pivot — which is the same thing as swinging it, and costs one rotation
    // instead of a transform per capsule.
    float d = sdSeg(pm, w + float2(0.0, -11.0), w + float2(0.0, 9.0), 5.4);
    float2 piv = w + float2(0.0, 6.0);
    float ca = cos(u.swing), sa = sin(u.swing);
    float2 q = pm - piv;
    float2 pr = piv + float2(q.x * ca + q.y * sa, -q.x * sa + q.y * ca);
    // The hand lags the arm: whatever the arm has done, the hand is still catching
    // up. A second, smaller rotation about the wrist is the cheapest double
    // pendulum there is and it is most of what stops it reading as one rigid piece.
    float2 wrist = float2(3.0, 52.0);
    float cb = cos(u.swing * 0.55), sb = sin(u.swing * 0.55);
    float2 r2 = pr - wrist;
    float2 ph = wrist + float2(r2.x * cb + r2.y * sb, -r2.x * sb + r2.y * cb);
    pm = pr;                                    // the arm swings
    d = min(d, sdSeg(pm, w + float2(1.0, 6.0), wrist, 3.6));
    pm = ph;                                    // the hand swings again, a little
    float2 palm = float2(5.0, 62.0);
    d = min(d, length((pm - palm) / float2(8.4, 7.4)) * 7.4 - 7.4);
    // Four fingers and a thumb, splayed, all of them shorter than they should be
    // because the palm is where the weight reads.
    d = min(d, sdSeg(pm, palm + float2(-5.0, 4.0), palm + float2(-9.0, 14.0), 2.5));
    d = min(d, sdSeg(pm, palm + float2(-1.6, 6.0), palm + float2(-2.6, 17.0), 2.6));
    d = min(d, sdSeg(pm, palm + float2( 2.0, 6.0), palm + float2( 3.4, 17.0), 2.6));
    d = min(d, sdSeg(pm, palm + float2( 5.4, 4.0), palm + float2( 9.6, 13.0), 2.5));
    d = min(d, sdSeg(pm, palm + float2(-7.0, -1.0), palm + float2(-15.0, -4.0), 2.6));
    return d;
}

/// Signed distance to a rounded rectangle, negative inside.
float sdRoundRect(float2 p, float2 half_, float r) {
    float2 q = abs(p) - half_ + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// How much face is at this grid cell, and where its centre sits.
struct Cell { float m; float2 cen; float2 cellSz; float cell; bool onFace; };

Cell cellAt(float2 px, float2 origin, float2 size, float2 cellSz, constant Uniforms &u) {
    Cell c;
    c.cellSz = cellSz;
    c.cell = min(cellSz.x, cellSz.y);
    float2 g = floor((px - origin) / cellSz);
    c.cen = origin + (g + 0.5) * cellSz;
    float MW = SVG_W + PADDING * 2.0, MH = SVG_H + PADDING * 2.0;
    float nx = nxFor(u);
    float NY = floor(nx * MH / MW);
    // The lattice stops at the mask's rectangle. That is right for the whole face
    // and wrong for the circles: spread apart, the right eye reaches about a cell
    // and a half past the mask's right edge while the left one barely crosses its
    // own, so those cells fell through to bare lattice — a dark strip down the
    // right of the right eye and nowhere else. Inside the circles there is nothing
    // but eye to draw, so let the grid run past the edge.
    c.onFace = u.mask > 0.5 || (g.x >= 0.0 && g.y >= 0.0 && g.x < nx && g.y < NY);
    c.m = 0.0;
    if (c.onFace) {
        float2 svg = ((c.cen - origin) / size) * float2(MW, MH) - PADDING;
        c.m = faceMask(svg, u);
    }
    return c;
}

/// Where the grid lands, worked out once and shared by every pass so they cannot
/// disagree about which pixel belongs to which dot.
struct Layout {
    float2 origin;
    float2 size;
    float2 cellSz;
    float  cell;
    float  panelH;
    float  panelW;
    float  radius;
};

Layout layoutFor(constant Uniforms &u) {
    Layout L;
    L.panelH = u.res.y * u.panelFrac;
    L.panelW = u.res.x * u.panelWFrac;
    L.radius = L.panelW * u.radiusFrac;
    float MW = SVG_W + PADDING * 2.0, MH = SVG_H + PADDING * 2.0;
    float fit = min(L.panelW * 0.94 / MW, L.panelH * 0.86 / MH);
    if (u.zoom > 0.001) fit = L.panelW * 0.94 / MW * u.zoom;
    L.size = float2(MW, MH) * fit;
    float nx = nxFor(u);
    float NY = floor(nx * MH / MW);
    L.cellSz = L.size / float2(nx, NY);
    L.cell = min(L.cellSz.x, L.cellSz.y);
    L.origin = (float2(L.panelW, L.panelH) - L.size) * 0.5
             + float2(u.shake * L.cell * 1.9, u.nod * L.cell * 1.6);
    // Cropped: put the focus point in the middle instead of the whole face.
    if (u.zoom > 0.001) {
        L.origin = float2(L.panelW, L.panelH) * 0.5 - float2(u.focusX, u.focusY) * fit
                 + float2(u.shake * L.cell * 1.9, u.nod * L.cell * 1.6);
    }
    return L;
}

/// Window pixel to panel pixel, undoing the perspective his panel is drawn in.
///
/// The window itself cannot be deformed — an NSWindow is a rectangle and always
/// will be. What can be deformed is what is drawn inside it, and since this shader
/// already maps every window pixel into the panel before it decides anything, one
/// more step in that map turns the panel into a trapezoid: a rotation about the
/// vertical axis, a perspective divide, and the rounded rect, the lattice, the dots
/// and the sheen all follow without knowing anything happened.
///
/// Doing it here rather than with a CALayer transform matters. A layer transform
/// resamples a finished image — his dots would arrive soft, and the buttons and
/// text in the webview above would tip over with him. This is drawn correctly at
/// native resolution, and only he moves.
float2 warp(float2 px, constant Uniforms &u, Layout L) {
    float tx = u.tiltX + u.dragX;
    float ty = u.tiltY + u.dragY;
    if (abs(tx) < 0.001 && abs(ty) < 0.001) return px;

    // Distance to the viewer, in half-panel-widths. Small enough for the far edge
    // to visibly shorten, large enough that it reads as a panel turning rather than
    // as a fisheye.
    const float D = 3.2;

    float2 half_ = float2(L.panelW, L.panelH) * 0.5;
    float2 q = (px - half_) / half_;

    float c = cos(tx), s = sin(tx);
    float a = q.x / max(0.25, c - q.x * s / D);
    float b = q.y * (1.0 + a * s / D);

    float c2 = cos(ty), s2 = sin(ty);
    float b2 = b / max(0.25, c2 - b * s2 / D);
    float a2 = a * (1.0 + b2 * s2 / D);

    // The near edge grows as he turns, and there is no room outside the window for
    // it to grow into, so he draws himself a little smaller while turned. It also
    // happens to be what turning away looks like.
    float pull = 1.0 + 0.30 * (abs(tx) + abs(ty));
    return half_ + float2(a2, b2) * half_ * pull;
}

/// The colour a single dot contributes at `px`, or zero if `px` is in a gap.
///
/// Cells are snapped to whole pixels and the GAP is what stays constant. The grid
/// pitch is fractional — the panel is not a whole number of cells across — so
/// testing against a fixed half-size around each centre lands some gaps a pixel
/// wider than their neighbours, and at this scale a pixel is a visible difference.
/// Deriving the rect from rounded cell edges makes every gap identical; what varies
/// instead is the dot, by at most a pixel, which reads as nothing.
///
/// `lit` returns only what emits: the lattice is excluded, because an unlit pixel
/// does not glow and feeding it to the bloom lifts the whole panel into grey haze.
/// The brows, stroked onto the panel instead of sampled into the grid.
///
/// Cropped to one eye the cells are two and a half times their usual size, and a
/// curve that thin built out of them is a staircase rather than a brow. Same
/// coverage, same colour ramp a dot of that coverage would get — it has to belong
/// to the same panel, it just is not made of its pixels.
float4 browSmooth(float2 px, Layout L, constant Uniforms &u, thread float &halo) {
    halo = 0.0;
    if (u.smoothBrow < 0.5) return float4(0.0);
    float MWc = SVG_W + PADDING * 2.0;
    float fit = L.size.x / MWc;
    // Minus the padding. Everything faceMask reasons about is in SVG space, and
    // (px - origin) / fit is mask space, which is SVG plus a 14-unit border on
    // every side. Sampling fourteen units right and down draws the brow fourteen
    // units left and up — which is the "too high and to the left" that survived
    // three attempts to nudge it, because the nudges were fighting a coordinate
    // system rather than a position.
    float2 bc = browCov((px - L.origin) / fit - PADDING, u);
    float m = bc.x;
    halo = bc.y;
    if (m < 0.02 && bc.y < 0.02) return float4(0.0);
    float cover = m / 0.70;                       // 0.70 is the brow's own weight
    if (u.lcd > 0.5) {
        // The mouth's shade, which is the shade anything drawn at this weight takes
        // — the brow is not a lit part of the screen, it is a drawn part of him. It
        // was the glass's own colour for a while on the grounds that a dark brow on
        // a dark desktop would vanish; it does not, because the desktop is darker
        // than the second shade is, and matching the rest of him matters more than
        // standing off the wallpaper.
        return float4(dmg(2.0, u) * cover, cover);
    }
    // The colour a dot of this coverage would be, which is to say the mouth's,
    // since the mouth is drawn at the same weight. Not a grey of its own: hand-
    // picking one put the brows a visibly different grey from the only other thing
    // on his face drawn like them. Everything but the hot core, which belongs to
    // the band in his eye and nothing else.
    float a  = (0.62 + 0.38 * m) * (0.84 + u.level * 0.16) * 1.12;
    float l  = 0.30 + u.level * 0.04 + m * 0.26;
    float sa = max(0.20, u.sat * (1.0 - m * 0.30));
    // The colour and nothing else. What makes it the mouth's grey rather than a
    // tenth darker and three degrees off is everything the panel puts under and
    // around a dot, and that is added where the panel's own terms are — in f_main.
    return float4(hsl2rgb(u.hue, sa, l) * a * cover, cover);
}

/// The plastic he is printed on.
///
/// Until now the circles floated on nothing, which was fine while they were the
/// whole character and wrong as soon as there was a mouth and a label to hold. This
/// is the body: one rounded slab behind everything, with the screens inset into it.
float bodySDF(float2 px, Layout L, constant Uniforms &u) {
    if (u.mask < 0.5) return 1e9;
    float MWc = SVG_W + PADDING * 2.0;
    float fit = L.size.x / MWc;
    float2 c = L.origin + float2(BODY_CX, BODY_CY) * fit;
    return sdRoundRect(px - c, float2(BODY_HW, BODY_HH) * fit, 30.0 * fit);
}

/// One glyph from the font, at any size and anywhere — not on the cell grid.
///
/// The label is a screen, so its letters land on cells. The numbers moulded into
/// the buttons are not: they are printed on plastic like the brows are, and cell
/// alignment for them would be alignment to a grid that is not there.
float glyphAt(float2 p, float2 org, float s, int idx) {
    float2 g = floor((p - org) / s);
    if (g.x < 0.0 || g.x > 2.0 || g.y < 0.0 || g.y > 4.0) return 0.0;
    uint bits = FONT[clamp(idx, 0, 39)];
    return (bits & (1u << uint(int(g.y) * 3 + int(g.x)))) != 0u ? 1.0 : 0.0;
}

/// The bracket he hangs in.
///
/// It was an arch sitting on his head, which is the shape you draw if you have
/// only seen the top of him. It is a holder: two arms down either side with a bar
/// across the top, and the roll between them — so the arms have to be wider than
/// the case and run far enough down to read as arms rather than as ears.
float handleSDF(float2 px, Layout L, constant Uniforms &u) {
    if (u.mask < 0.5) return 1e9;
    float MWc = SVG_W + PADDING * 2.0;
    float fit = L.size.x / MWc;
    float outer = sdRoundRect(px - (L.origin + float2(92.0, 85.0) * fit),
                              float2(106.0, 145.0) * fit, 30.0 * fit);
    float inner = sdRoundRect(px - (L.origin + float2(92.0, 103.0) * fit),
                              float2(88.0, 145.0) * fit, 16.0 * fit);
    return max(outer, -inner);
}

/// What is printed on the plastic: the brows, and the mouth with its tongue.
///
/// Printed, not displayed — these are ink on the case, not cells of a screen, so
/// they are drawn smooth while everything inside the lenses is drawn hard.
float4 faceInk(float2 p, constant Uniforms &u) {
    const float3 INK = float3(0.086, 0.075, 0.071);
    float cov = browCov(p, u).x / 0.70;

    // The perforation around his middle. He is a roll of paper, and the one line
    // that says so is the one you would tear along.
    float2 pm = p + PADDING;
    float seam = max(1.0 - smoothstep(0.7, 1.5, abs(pm.y - SEAM_Y)),
                     (1.0 - smoothstep(0.6, 1.2, abs(pm.y - SEAM2_Y)))
                     * step(0.0, pm.x - 22.0) * step(pm.x, 162.0))
               * step(0.30, fract(pm.x / 9.0));
    float3 col = INK;
    if (seam > 0.02 && cov < 0.02) {
        // Grey, not ink: it is a join in the plastic, not something drawn on it.
        return float4(float3(0.62, 0.60, 0.57), seam * 0.85);
    }

    // The mouth is a disc with its top taken off along a line that rises at the
    // corners. A stroked curve is a mouth on a face that has a mouth drawn on it;
    // this one is a hole with a tongue in it.
    // An oval with its top or its bottom pushed through.
    //
    // Three keyframes, drawn as SVG: a plain circle, the same circle with a notch
    // lifted into its lower edge, and the same circle again with a notch pressed
    // down into its upper one. One number slides between them, and because it is
    // one number the shape can be anywhere in between and never stops being a
    // deformed circle — which is what makes it animate rather than cut.
    //
    // Replaces a disc cut off along a line, which could only ever be a D and had
    // to be told separately how wide, how deep and how bowed it was. The notch
    // reaches about one and three tenths of the half-height, taken off the file:
    // far enough to push past the middle, which is what gives both extremes their
    // pinch.
    float2 c = float2(MOUTH_CX, MOUTH_CY);
    float Rx = 19.5, Ry = 13.0 * clamp(0.18 + u.gape * 0.86, 0.12, 1.25);
    float dx = p.x - c.x;
    float ux = dx / Rx;
    if (abs(ux) >= 1.0) return float4(col, cov);
    float sq = sqrt(max(0.0, 1.0 - ux * ux));
    float k = 1.0 - ux * ux;                       // the notch, deepest in the middle
    // The two sides are not scaled the same, because his mouth is not: it idles at
    // 1.0 and goes to 1.9 when he is delighted, but only to about -1.15 the other
    // way. Matching factors put the whole smile keyframe on the resting face with
    // nowhere left to go.
    float notch = (max(0.0, -u.mouth) * 1.25 + max(0.0, u.mouth) * 0.78) * Ry * k;
    // A middle line and a thickness, rather than a top edge and a bottom one. Same
    // shape while it is open, and it is what happens as it shuts that matters: an
    // ellipse closing to nothing is two spikes meeting in the middle, where a mouth
    // shutting is a line of one thickness following the same curve. Below the lip's
    // own width it stops being an opening and starts being a stroke.
    float mid = c.y + (u.mouth < 0.0 ? 1.0 : -1.0) * notch * 0.5;
    float hh = max(LIP, Ry * sq - notch * 0.5);
    float ty = mid - hh, by = mid + hh;
    float m = step(ty, p.y) * (1.0 - step(by, p.y));

    // Nothing inside a mouth that is shut.
    if (m > 0.5 && hh > LIP * 1.9) {
        float h = max(by - ty, 0.8);
        // A lighter rim just inside the opening, so it reads as a hole in the case
        // rather than a flat blob the colour of the brows.
        float rim = min(min(p.y - ty, by - p.y) / h, (1.0 - abs(ux)) * 2.2);
        if (rim < 0.13) col = float3(0.31, 0.26, 0.24);
        // Teeth along the upper lip, tongue at the lower one, and the dark of the
        // mouth between them. Tongue first so the teeth win where they meet.
        if (p.y > by - h * 0.30 && abs(ux) < 0.42) col = float3(0.78, 0.31, 0.31);
        if (p.y > ty + h * 0.07 && p.y < ty + h * 0.26 && abs(ux) < 0.56)
            col = float3(0.95, 0.94, 0.92);
    }
    cov = max(cov, m);
    return float4(col, max(cov, m));
}

/// One light, for everything on him that has a surface.
constant float3 LGT = float3(-0.4157, -0.6929, 0.5742);   // already normalized

/// Screen pixel to surface pixel: where on the roll this part of the screen is.
///
/// He is a cylinder lying on its side, and everything printed or displayed on him
/// is on its curved face. So a band of equal height near the middle covers less
/// surface than one near the edge, and the map between the two is an arcsine — the
/// screen sees R·sin(θ), the surface measures R·θ.
///
/// This is the whole of what makes him round. The lighting could always fake a
/// cylinder; what it could not do is move things: his brows, his seam and the top
/// of his eyes now crowd together toward the edge the way marks on a real roll do,
/// and when he turns they slide around him rather than skewing with him.
///
/// Only what is drawn on the surface. His outline is still measured flat, because
/// the silhouette of a cylinder is a rectangle and bending it would round off a
/// shape that is not round.
float2 bendRoll(float2 px, Layout L, constant Uniforms &u) {
    if (u.mask < 0.5) return px;
    float MWc = SVG_W + PADDING * 2.0;
    float fit = L.size.x / MWc;
    float ym = (px.y - L.origin.y) / fit;
    float t = clamp((ym - ROLL_AX) / ROLL_R, -0.985, 0.985);
    float bent = ROLL_AX + asin(t) * ROLL_R;
    // Eased out over the gap between his chin and the label, so the curve runs out
    // where nothing is drawn rather than under something that is.
    float k = 1.0 - smoothstep(ROLL_FADE0, ROLL_FADE1, ym);
    return float2(px.x, L.origin.y + mix(ym, bent, k) * fit);
}

/// The case's surface normal.
///
/// Not a raymarch: his silhouette is still the flat rounded rect it always was.
/// But this is a real normal, taken from the gradient of the same distance field
/// the outline comes from — flat across the middle, rolling away over the last few
/// units to the rim. That roll is what a moulded plastic edge does, and having it
/// is most of the difference between an object and a sticker.
float3 caseNormal(float2 px, Layout L, constant Uniforms &u, float bd, float fit) {
    float e = 1.2 * fit;
    float2 g = float2(bodySDF(px + float2(e, 0.0), L, u) - bodySDF(px - float2(e, 0.0), L, u),
                      bodySDF(px + float2(0.0, e), L, u) - bodySDF(px - float2(0.0, e), L, u));
    g = normalize(g + float2(1e-6, 1e-6));
    float roll = smoothstep(-10.0 * fit, 0.0, bd);
    float2 xy = g * roll * 0.94;
    return float3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

/// The lens over each eye, as a dome rather than a highlight painted on.
///
/// Returns how much light the surface takes and how much it throws straight back.
/// A cap, not a hemisphere: the curvature is eased out across the middle so the
/// picture underneath stays flat and readable, and only bites near the rim where
/// the glass actually turns.
float2 lensAt(float2 px, Layout L, constant Uniforms &u) {
    if (u.mask < 0.5) return float2(0.0);
    float MWc = SVG_W + PADDING * 2.0;
    float fit = L.size.x / MWc;
    float R = EYE_RX * (1.0 + u.eyeGrow) * 0.90 * fit;
    float2 best = float2(0.0);
    for (int i = 0; i < 2; i++) {
        float2 c = L.origin
                 + float2(eyeX(i == 0 ? -1.0 : 1.0, u) + PADDING, EYE_Y + PADDING) * fit;
        float2 q = (px - c) / R;
        float r2 = dot(q, q);
        if (r2 >= 1.0) continue;
        float2 xy = q * smoothstep(0.10, 1.0, r2) * 0.96;
        float3 n = float3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
        float diff = max(0.0, dot(n, LGT));
        float spec = pow(max(0.0, dot(reflect(-LGT, n), float3(0.0, 0.0, 1.0))), 24.0);
        best = max(best, float2(diff, spec));
    }
    return best;
}

/// The lens over an eye: a sweep of light across the top and the rim catching it.
///
/// It is the one part of him that is not a screen and not a print. Without it the
/// circles read as holes cut in the case; with it there is glass in front of them,
/// which is what the reference has and most of why its eyes look like objects.
float glossAt(float2 px, Layout L, constant Uniforms &u) {
    if (u.mask < 0.5) return 0.0;
    float MWc = SVG_W + PADDING * 2.0;
    float fit = L.size.x / MWc;
    float R = EYE_RX * (1.0 + u.eyeGrow) * 0.90 * fit;
    float g = 0.0;
    for (int i = 0; i < 2; i++) {
        float2 c = L.origin
                 + float2(eyeX(i == 0 ? -1.0 : 1.0, u) + PADDING, EYE_Y + PADDING) * fit;
        float2 q = px - c;
        // High and narrow, hugging the rim.
        //
        // It used to be a broad sweep across the whole upper third, which is where
        // the top lid is — so the lid's own shade was being lifted straight back
        // out by the glass over it, and a closing eye read as a line with nothing
        // behind it. A lens highlight is a small bright thing near the edge, not a
        // wash over the picture.
        float2 a = (q - float2(-0.30 * R, -0.74 * R)) / float2(R * 0.42, R * 0.15);
        float sweep = smoothstep(1.0, 0.10, length(a));
        float rim = smoothstep(0.86, 0.99, length(q) / R)
                  * smoothstep(0.10, -0.80, q.y / R);
        g = max(g, sweep * 0.46 + rim * 0.30);
    }
    return g;
}

/// The screen's outline: a rounded rectangle, or two circles over his eyes.
///
/// Two windows would have let the eyes drift apart from each other, and would have
/// taken the buttons and the text field with them. One window whose *shape* is two
/// circles keeps the pair rigid and keeps everything that hangs off his panel.
float screenSDF(float2 px, Layout L, constant Uniforms &u) {
    if (u.mask < 0.5) {
        float2 half_ = float2(L.panelW, L.panelH) * 0.5;
        return sdRoundRect(px - half_, half_, L.radius);
    }
    float MWc = SVG_W + PADDING * 2.0;
    float fit = L.size.x / MWc;
    float2 l = L.origin + float2(eyeX(-1.0, u) + PADDING, EYE_Y + PADDING) * fit;
    float2 r = L.origin + float2(eyeX(1.0, u) + PADDING, EYE_Y + PADDING) * fit;
    // Inside the ellipse's *solid* part, not on its edge.
    //
    // `inside` fades from 1 to 0 between d 0.92 and 1.04, so a rim at 1.04 sat
    // exactly on the fade and the last cells before it came out dim — a dark band
    // hugging one side, worse on whichever eye the grid happened to favour. At 0.90
    // every cell the circle contains is fully lit and the rim simply crops them.
    float rad = EYE_RX * (1.0 + u.eyeGrow) * 0.90 * fit;
    // And the strip under them. Part of the same screen rather than a panel of its
    // own, so it gets the same grid, the same shades and the same perspective when
    // he turns — a separate element would have to be told about all three and would
    // still sit flat while he tipped.
    float2 sc = L.origin + float2(STRIP_CX, STRIP_CY) * fit;   // mask units already
    float strip = sdRoundRect(px - sc, float2(STRIP_HW, STRIP_HH) * fit, 11.0 * fit);
    return min(min(length(px - l) - rad, length(px - r) - rad), strip);
}

float3 dotAt(float2 px, float2 pw, Layout L, constant Uniforms &u, bool lit) {
    Cell c = cellAt(px, L.origin, L.size, L.cellSz, u);
    float2 g = floor((px - L.origin) / L.cellSz);
    // Fine grids cannot be drawn on whole pixels.
    //
    // Rounding each cell's edges to the screen's own grid is what makes the dots
    // crisp at eight pixels to a cell. At two and a half it does the opposite:
    // consecutive boundaries round to a two or a three, so every other dot comes
    // out a pixel wider than its neighbour, and the one-pixel floor under the gap
    // eats a third of the cell. Below about five pixels the cell is placed and
    // measured in real numbers instead and its edges are feathered — which is what
    // the feather was already there to do under a tilt.
    float fine = smoothstep(5.5, 3.5, L.cell);
    float2 a0 = L.origin + g * L.cellSz;
    float2 a1 = L.origin + (g + 1.0) * L.cellSz;
    float2 e0 = mix(round(a0), a0, fine);
    float2 e1 = mix(round(a1), a1, fine);
    // A hairline, not a mortar course. The gaps on the reference are barely there:
    // it is a screen with pixels, not a mosaic.
    float gap = mix(max(1.0, round(L.cell * 0.08)), L.cell * 0.08, fine);

    // The feather, worked out before the rectangle is, because whether a side is
    // grown past its boundary depends on how wide the feather is.
    float tilt = abs(u.tiltX + u.dragX) + abs(u.tiltY + u.dragY);
    float soft = max(smoothstep(0.0, 0.03, tilt), fine);
    float2 h = max(2e-3, max(pw, 1e-4) * 0.5 * soft);

    // A shear, per row and per column — never per cell.
    //
    // It used to be per cell: g.x was in the x term, the y term was a hash of the
    // whole cell, and the amount was damped by that cell's own coverage. Three
    // reasons for neighbours to slide past each other, and when they did, one gap
    // closed while the one beside it doubled. At two pixels of travel on an
    // eight-pixel cell that does not read as texture, it reads as a row of dots
    // coming apart — which is exactly what it looks like cropped to his eyes.
    //
    // A shear moves a whole row together, so every gap inside it stays the width it
    // was drawn and the grid still crawls. Kept to a single pixel: whole pixels,
    // because a fractional offset against these edges is an uneven gap arriving by
    // another route, and one pixel is all a four-pixel cell has to give.
    float amp = 0.35 + u.level * 0.9;
    float2 j = round(float2(sin(g.y * 0.24 + u.time * (0.4 + u.level)),
                            hash21(float2(g.x, 0.0)) - 0.5) * amp);
    // A lit cell fills its cell and a little past it; an unlit one keeps its gap.
    //
    // This started as a rule about neighbours — cut the gap between two cells of
    // the same shade — which needed four extra lookups and answered a question
    // nobody was asking. What a lit element actually does is bleed: it is bigger
    // than its own cell, and the dark grid you see is the space the *unlit* ones
    // leave. That single rule gives all three cases at once. Two lit cells touch
    // and merge. A lit cell against an unlit one leaves half a gap, so the lit one
    // looks the larger of the two. Two unlit cells leave the whole of it, which is
    // the lattice you can see.
    //
    // Past the boundary by the width of the feather, not merely up to it: two
    // cells each feathering toward a shared edge both fall short of it, and that
    // shortfall is a faint line exactly where the gap was meant to have gone.
    //
    // Only on the reflective screen. His own face *is* a dot matrix, and the gaps
    // between its dots are the whole of what he is made of.
    float2 lo = float2(0.0), hi = float2(gap);
    if (u.lcd > 0.5 && c.m >= 0.25) { lo = -h; hi = -h; }
    float2 p0 = e0 + lo + j, p1 = e1 - hi + j;

    // Antialiased against the screen — but only once there is something to
    // antialias.
    //
    // Square on, a dot's rectangle is whole panel pixels and whole screen pixels at
    // once, and a hard in-or-out test is exactly right: that is what makes them
    // crisp. Tilted, the panel is a trapezoid, those same edges fall between screen
    // pixels, and the hard test rounds each dot to a different place in the grid —
    // rows stop being rows and the lines between them come apart. So the feather is
    // one screen pixel wide, faded in with the tilt, and nothing changes at rest.
    float2 e = smoothstep(p0 - h, p0 + h, px) * (1.0 - smoothstep(p1 - h, p1 + h, px));
    float cov = e.x * e.y;

    if (u.lcd > 0.5) {
        // Nothing here emits, so there is nothing for the bloom pass to collect.
        if (lit) return float3(0.0);
        // Absolute, not additive: on a reflective panel the cells *are* the
        // picture. The gaps are the mask between them — the same glass a hair
        // darker, which is the grid you can see in sunlight and not in a
        // photograph — and they are certainly not black.
        return mix(dmg(0.0, u) * 0.90, dmg(floor(clamp(c.m, 0.0, 1.0) * 3.999), u), cov);
    }

    if (cov <= 0.002) return float3(0.0);

    if (c.m < 0.06) return lit ? float3(0.0) : float3(0.49, 0.58, 0.72) * u.lattice * cov;

    float a  = (0.62 + 0.38 * c.m) * (0.84 + u.level * 0.16) * 1.12;
    float l  = 0.30 + u.level * 0.04 + c.m * 0.26;
    float sa = max(0.20, u.sat * (1.0 - c.m * 0.30));
    float3 col = hsl2rgb(u.hue, sa, l) * a;

    // The whole dot emits hotter on full coverage — not an inner square, which
    // reads as a smaller bright pixel inside a dim one rather than as something
    // lit. This is the term that goes past 1.0: on a display with headroom the band
    // in each eye is not white, it is brighter than white.
    if (c.m > 0.92)
        col += hsl2rgb(u.hue, max(0.22, u.sat * 0.70), 0.56) * (0.28 + u.level * 0.14) * u.edr;
    return col * cov;
}

// ---------------------------------------------------------------------------
// Pass 1 — the emitters, at half resolution.
//
// Only what is lit. This texture is what gets blurred, so anything written here
// that does not actually emit light will glow, and the lattice does not emit.
// ---------------------------------------------------------------------------
fragment float4 f_emit(VOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 px = float2(in.uv.x, 1.0 - in.uv.y) * u.res;
    px.y -= u.res.y * u.panelTopFrac;      // the band above him belongs to the page
    Layout L = layoutFor(u);
    px = warp(px, u, L);
    // One screen pixel, in panel units. Taken here rather than inside dotAt because
    // a derivative is only defined where every lane of the quad is still together,
    // and f_main has already branched by the time it draws its dots.
    float2 pw = fwidth(px);
    float hb;
    float3 col = dotAt(px, pw, L, u, true);
    // Nothing on a reflective panel emits, and on the circles the brows are ink on
    // the case rather than light coming off him.
    if (u.lcd < 0.5 && u.mask < 0.5) col += browSmooth(px, L, u, hb).rgb;
    return float4(max(col, 0.0), 1.0);
}

// ---------------------------------------------------------------------------
// Passes 2 and 3 — a separable Gaussian over the bright parts only.
//
// This replaces sampling the face on rings around each pixel. Rings are a
// quadrature rule with far too few points: too few angles and the halo is a
// rosette, too few radii and it is a set of contour lines, and jittering either one
// trades the structure for visible noise. A Gaussian has neither failure mode
// because it is not sampling a shape, it is convolving an image.
//
// Tight, and thresholded. A wide soft bloom over the whole face put a haze between
// the dots and the black behind them and made the panel look dirty. What is wanted
// is the thing a real emitter does: the brightest pixels bleed a little into their
// neighbours, and everything else stays exactly where it is.
// ---------------------------------------------------------------------------
struct BlurParams { float2 dir; float sigma; float thresh; };

fragment float4 f_blur(VOut in [[stage_in]],
                       texture2d<float> src [[texture(0)]],
                       constant BlurParams &b [[buffer(0)]]) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float2 texel = 1.0 / float2(src.get_width(), src.get_height());
    int r = int(clamp(ceil(b.sigma * 2.5), 1.0, 48.0));
    float inv = 1.0 / (2.0 * b.sigma * b.sigma);

    float3 sum = float3(0.0);
    float wsum = 0.0;
    for (int i = -r; i <= r; i++) {
        float w = exp(-float(i * i) * inv);
        float3 c = src.sample(smp, in.uv + b.dir * texel * float(i)).rgb;
        // Bright pass, on the first of the two directions only. Blooming everything
        // spreads the dim body of every eye across the dark and the whole panel goes
        // muddy; taking only what is already brighter than the threshold means the
        // glow sits on the hot cores and nowhere else.
        if (b.thresh > 0.0) c = max(c - b.thresh, 0.0);
        sum += c * w;
        wsum += w;
    }
    return float4(sum / wsum, 1.0);
}

// ---------------------------------------------------------------------------
// Pass 4 — the picture.
// ---------------------------------------------------------------------------
fragment float4 f_main(VOut in [[stage_in]],
                       texture2d<float> tight [[texture(0)]],
                       constant Uniforms &u [[buffer(0)]]) {
    float2 px = float2(in.uv.x, 1.0 - in.uv.y) * u.res;
    px.y -= u.res.y * u.panelTopFrac;      // the band above him belongs to the page
    Layout L = layoutFor(u);
    px = warp(px, u, L);
    // Where this pixel is, before he is bent. The outline, the bracket, the hand
    // and the lighting are all measured here; everything printed or displayed on
    // the roll is measured after.
    float2 flat = px;
    px = bendRoll(px, L, u);
    // Taken after the bend, because the grid lives on his surface and this is what
    // says how much of it one screen pixel covers — which is not the same near his
    // edge as it is in the middle.
    float2 pw = fwidth(px);

    // The panel is the rounded rectangle the page draws its window as. Outside it
    // the layer must be fully transparent — it sits *behind* the webview, so
    // anything it paints past the corners squares off the window and no CSS can
    // reach it.
    float d = screenSDF(px, L, u);
    // A fixed panel-unit feather is a fixed *screen* feather only while the panel
    // is square on. Tilted, the far side is compressed and its rim hardens back
    // into a staircase, which is the same fault the dots had.
    float aa = max(max(1.0, L.panelW / 600.0), max(pw.x, pw.y));
    float panel = 1.0 - smoothstep(-aa, aa, d);
    // The brows float above the screen rather than being cut out of it, so they are
    // drawn whether or not this pixel is on it.
    float hb;
    float4 brow = browSmooth(px, L, u, hb);
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    // Flipped on the way back in. Rendering to a texture puts NDC's top row — uv.y
    // of 1 — at texture row 0, while sampling reads row 0 at uv.y of 0. Writing and
    // reading with the same uv therefore mirrors the bloom vertically, which shows
    // up as every feature's halo sitting where its reflection would be.
    float2 uv = float2(in.uv.x, 1.0 - in.uv.y);
    float3 glow = tight.sample(smp, uv).rgb * (1.45 + u.level * 0.45);

    if (u.mask > 0.5) {
        // He has a body now.
        //
        // The circles floated on nothing while they were the whole of him, and that
        // stopped being right the moment there was a mouth and a label to hold. So
        // the window's shape is the case, the screens are let into it, and what is
        // over them is glass — three materials, in the order light meets them.
        float bd = bodySDF(flat, L, u);
        float hd = handleSDF(flat, L, u);
        float MWc = SVG_W + PADDING * 2.0;
        float fit = L.size.x / MWc;
        float2 svg = (px - L.origin) / fit - PADDING;
        float sd = stickySDF((flat - L.origin) / fit, u) * fit;
        float body = 1.0 - smoothstep(-aa, aa, bd);
        float handle = 1.0 - smoothstep(-aa, aa, hd);
        float sticky = 1.0 - smoothstep(-aa, aa, sd);
        float alpha = max(max(max(body, handle), panel), sticky);
        if (alpha <= 0.002) return float4(0.0);

        // He is a cylinder, not a card.
        //
        // The fall down the case was the only shading on him, and a flat panel with
        // a slight vertical gradient reads as paper. What makes a roll a roll is
        // the light going away from you around both sides at once — so the shade is
        // a half-cycle across his width, off centre because the light is, with the
        // moulded edge picking up a little of it back at the very rim.
        float ymFlat = (flat.y - L.origin.y) / fit;
        float bt = clamp((ymFlat - (BODY_CY - BODY_HH)) / (2.0 * BODY_HH), 0.0, 1.0);
        // The real normal of the roll, not a gradient painted across it: straight
        // at you on the axis and turning away above and below by exactly as much as
        // the surface does. Flat under ROLL_END, because the panel down there is a
        // flat panel.
        float sinT = clamp((ymFlat - ROLL_AX) / ROLL_R, -1.0, 1.0)
                   * (1.0 - smoothstep(ROLL_FADE0, ROLL_FADE1, ymFlat));
        float3 cylN = float3(0.0, sinT, sqrt(max(0.0, 1.0 - sinT * sinT)));
        // Plus the moulding at the rim, which the cylinder knows nothing about:
        // the last few units to the left and right edges turn away too.
        float3 nrm = normalize(cylN
                   + float3(caseNormal(flat, L, u, bd, fit).x * 0.9, 0.0, 0.0));
        float roll = 1.0;
        // Lifted so the flat middle is barely shaded at all. At 0.66 the whole case
        // came down to four fifths of its own colour and the warm white read grey —
        // the roll of the edge is the point, not an overall dimming.
        float lam = 0.82 + 0.26 * max(0.0, dot(nrm, LGT));
        float sp = pow(max(0.0, dot(reflect(-LGT, nrm), float3(0.0, 0.0, 1.0))), 30.0);
        float3 plastic = float3(0.945, 0.929, 0.902) * roll * lam * (1.02 - 0.055 * bt)
                       + sp * 0.26;

        float4 ink = faceInk(svg, u);
        float3 face = mix(plastic, ink.rgb, clamp(ink.a, 0.0, 1.0));

        // The frame round the label, which is the only yellow on the case itself.
        float2 sc = L.origin + float2(STRIP_CX, STRIP_CY) * fit;
        float fo = sdRoundRect(px - sc, float2(STRIP_HW + 6.0, STRIP_HH + 6.0) * fit, 17.0 * fit);
        face = mix(face, YELLOW * 0.96,
                   (1.0 - smoothstep(-aa, aa, fo)) * smoothstep(-aa, aa, d));

        // Three buttons under it. One, a dial, two — and the lit one is the only
        // thing on the case that goes past white, the way the band in an eye does.
        for (int i = 0; i < 3; i++) {
            float2 bcm = float2(BODY_CX + (float(i) - 1.0) * BTN_DX, BTN_Y);
            float bdd = sdRoundRect(px - (L.origin + bcm * fit),
                                    float2(BTN_HW, BTN_HH) * fit, 7.0 * fit);
            float on = 1.0 - smoothstep(-aa, aa, bdd);
            if (on <= 0.002) continue;
            float3 base = i == 0 ? float3(0.957, 0.757, 0.208)
                        : i == 1 ? float3(0.239, 0.616, 0.851)
                                 : float3(0.878, 0.278, 0.239);
            float lit = clamp(u.btn[i], 0.0, 1.0);
            float3 b = base * (0.70 + 0.30 * lit);
            float gs = 4.2;
            float g = glyphAt(svg, bcm - PADDING - float2(1.5, 2.5) * gs, gs,
                              i == 0 ? 28 : (i == 1 ? 15 : 29));
            b = mix(b, float3(0.99, 0.98, 0.96), g * 0.88);

            // Moulded in clear plastic, not printed on. The face of the button is
            // flat and its edges roll away, same as the case but over a few units
            // rather than a few tens — which is what makes something small read as
            // domed. Then one hard highlight, because that is what a shiny lump of
            // plastic does with a light and the only thing that says glass.
            float2 q = (px - (L.origin + bcm * fit)) / (float2(BTN_HW, BTN_HH) * fit);
            float bevel = smoothstep(0.42, 1.0, max(abs(q.x), abs(q.y)));
            float2 nxy = q * bevel * 0.90;
            float3 bn = float3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
            b *= 0.74 + 0.36 * max(0.0, dot(bn, LGT));
            b += pow(max(0.0, dot(reflect(-LGT, bn), float3(0.0, 0.0, 1.0))), 34.0) * 0.55;
            // A lit one glows through its own plastic rather than off it.
            b += base * lit * (0.38 + 0.26 * u.level) * u.edr;
            face = mix(face, b, on);
        }

        // The bracket goes behind the case, so the case is drawn over it.
        float3 col = mix(YELLOW * (0.86 + 0.14 * (1.0 - bt)) * handle, face, body);

        // A shadow in the case where each screen is let into it, so they sit in the
        // plastic rather than on it.
        col *= 1.0 - (1.0 - smoothstep(0.0, 3.0 * fit, d)) * (1.0 - panel) * 0.42;

        float3 screen = u.lcd > 0.5
            ? dotAt(px, pw, L, u, false)
            : float3(0.012, 0.016, 0.027) + dotAt(px, pw, L, u, false) + glow;
        col = mix(col, screen, panel);

        // The glass: what the dome takes, and what it throws back. The painted
        // sweep is still under it at a fraction of its old weight — a real
        // highlight is a small hot thing, and the sweep is the soft wash of the
        // room behind it.
        float2 lens = lensAt(px, L, u);
        float reflection = u.lcd > 1.5 ? smoothstep(0.05, 0.5, dot(screen, float3(0.333333))) : 1.0;
        col += panel * reflection * (glossAt(px, L, u) * 0.16 + lens.x * 0.055 + lens.y * 0.62)
             * float3(0.98, 1.0, 0.97);

        float n = hash21(px * 0.63 + floor(u.time * 9.0) * 7.31);
        col += (n - 0.5) * 0.012;

        // The hand, over everything, because it is hanging in front of him.
        //
        // Glass rather than paint: a normal off its own distance field, so the arm
        // and each finger round away at their edges, one specular, and a rim that
        // lights up where the shape turns away — which is what you actually see on
        // a lump of translucent rubber and the reason it does not read as a sticker.
        if (sticky > 0.002) {
            float e = 1.1 * fit;
            float2 gr = float2(stickySDF(svg + PADDING + float2( e, 0.0) / fit, u)
                             - stickySDF(svg + PADDING + float2(-e, 0.0) / fit, u),
                               stickySDF(svg + PADDING + float2(0.0,  e) / fit, u)
                             - stickySDF(svg + PADDING + float2(0.0, -e) / fit, u));
            gr = normalize(gr + float2(1e-6, 1e-6));
            float roll2 = smoothstep(-4.5 * fit, 0.0, sd);
            float2 nxy = gr * roll2 * 0.96;
            float3 sn = float3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
            float3 rub = float3(0.129, 0.286, 0.784)
                       * (0.70 + 0.42 * max(0.0, dot(sn, LGT)));
            // Light coming through the thin parts, which is most of what says
            // rubber rather than plastic.
            rub += float3(0.24, 0.40, 0.92) * (1.0 - roll2) * 0.28;
            rub += pow(max(0.0, dot(reflect(-LGT, sn), float3(0.0, 0.0, 1.0))), 28.0) * 0.75;
            rub += float3(0.55, 0.70, 1.0) * pow(roll2, 3.0) * 0.16;
            col = mix(col, rub, sticky);
        }
        float materialLight = smoothstep(0.08, 0.55, max(max(col.r, col.g), col.b));
        float materialGain = 1.0 + (min(u.edr, 2.0) - 1.0) * 0.32 * materialLight;
        col *= mix(materialGain, 1.0, panel);
        return float4(max(col, 0.0) * alpha, alpha);
    }

    if (panel <= 0.001) {
        // Everything the panel puts under a dot, put under this one.
        //
        // A dot on his face is never only its own colour: it is that colour over
        // the panel's ground, under the panel's sheen, inside the panel's vignette
        // and wearing the bloom every emitter gets. A brow stroked outside the
        // screens had none of the four, which is a tenth of its brightness and
        // three degrees of its hue — the whole of what you could see between it and
        // the mouth. Same expressions as below, evaluated at the same place.
        //
        // The ground and the sheen ride the brow's own alpha, because they sit
        // under it. The bloom rides the wider halo and carries no alpha of its own,
        // because it is light and light adds to whatever is behind it. Masked to
        // the brow, so the screens do not grow a ring around their bezels.
        float2 pn = px / float2(L.panelW, L.panelH);
        float sh = smoothstep(1.15, 0.05, length((pn - float2(0.36, 0.20)) * float2(1.0, 1.15)));
        float vg = smoothstep(1.35, 0.35, length((pn - 0.5) * float2(1.0, 1.05)) * 1.55);
        float3 under = float3(0.012, 0.016, 0.027)
                     + float3(0.052, 0.070, 0.108) * sh * 0.34;
        float3 out = (brow.rgb + under * brow.a + glow * hb) * (0.90 + 0.10 * vg);
        return float4(out, brow.a);
    }

    if (u.lcd > 0.5) {
        // No ground of its own and nothing added on top.
        //
        // The emissive path starts from near-black and adds: the dot, then its
        // bloom, then the sheen, because that is how light arrives at an eye. A
        // reflective panel does not add anything to a room, it subtracts — so its
        // cells are already the finished colour and all that goes over them is the
        // glass they sit under.
        if (panel <= 0.001) return brow;          // premultiplied, already a shade
        float3 c = brow.rgb + dotAt(px, pw, L, u, false) * (1.0 - brow.a);

        float2 pn = px / float2(L.panelW, L.panelH);
        // The glass matters more here than it does on the emissive panel: with
        // nothing shining out, the reflection is the only thing saying there is a
        // surface in front of the picture rather than a picture.
        float sh = smoothstep(1.15, 0.05, length((pn - float2(0.36, 0.20)) * float2(1.0, 1.15)));
        c += float3(0.090, 0.095, 0.072) * sh * 0.17;
        float vg = smoothstep(1.35, 0.35, length((pn - 0.5) * float2(1.0, 1.05)) * 1.55);
        c *= 0.87 + 0.13 * vg;
        // Flat, not scaled by signal. On the emissive panel grain in the black was
        // mottling; here the darkest shade is still a surface being looked at, and
        // an even speckle over all of it is what that surface has.
        float n = hash21(px * 0.63 + floor(u.time * 9.0) * 7.31);
        c += (n - 0.5) * 0.020;
        return float4(max(c, 0.0) * panel, panel);
    }

    float3 col = float3(0.012, 0.016, 0.027);    // just off black

    // The channels used to be sampled from their own offsets while you spoke — a
    // lens coming apart. It read as a malfunction, not as attention. He leans in
    // and widens his eyes instead, which says listening without saying broken.
    col += dotAt(px, pw, L, u, false) + brow.rgb;

    col += glow;

    // What makes something look like a lit screen rather than lit shapes on black.
    //
    // Not more bloom: bloom follows the features, and anything wide enough to read
    // as brightness also puts a haze around every eye, which is what went wrong the
    // first two times. This is the glass instead — a broad, fixed sheen that does
    // not know where the face is and therefore cannot smear it, plus a slight
    // falloff at the edges so the middle reads brighter by comparison.
    //
    // Deliberately tiny. At peak it is about two percent, which you would not
    // notice as a gradient and do notice as the thing being on.
    float2 pn = px / float2(L.panelW, L.panelH);
    float sheen = smoothstep(1.15, 0.05, length((pn - float2(0.36, 0.20)) * float2(1.0, 1.15)));
    col += float3(0.052, 0.070, 0.108) * sheen * 0.34;

    float vign = smoothstep(1.35, 0.35, length((pn - 0.5) * float2(1.0, 1.05)) * 1.55);
    col *= 0.90 + 0.10 * vign;

    // Grain, crawling — and scaled by what is already lit. Added flat, the same
    // amplitude is a rounding error on a bright dot and a 40% modulation on a
    // near-black gap, which is most of the mottling in the dark. Film grain rides
    // on signal; it does not speckle the black.
    float n = hash21(px * 0.63 + floor(u.time * 9.0) * 7.31);
    float sig = dot(col, float3(0.299, 0.587, 0.114));
    col += (n - 0.5) * 0.030 * min(1.0, sig * 2.2);

    col = max(col, 0.0);
    return float4(col * panel, panel);            // premultiplied
}
