// Derived from the selected Casting Room Scout SDF. Regenerate with scripts/compile-scout.py.
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct NativeUniforms
{
    float4 viewport;
    float4 eye;
    float4 pose;
    float4 options;
};

struct main0_out
{
    float4 outputColor [[color(0)]];
};

static inline __attribute__((always_inline))
float scKitSearchAngle(thread const float& age)
{
    float t = mod(fast::max(age, 0.0), 8.0);
    return ((0.939999997615814208984375 * smoothstep(0.119999997317790985107421875, 2.0, t)) - (1.980000019073486328125 * smoothstep(2.6099998950958251953125, 5.429999828338623046875, t))) + (1.03999996185302734375 * smoothstep(6.19999980926513671875, 7.900000095367431640625, t));
}

static inline __attribute__((always_inline))
void scKitPose(thread const float& style, thread const float& mode, thread const float& age, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, constant NativeUniforms& U)
{
    scKitOn = style > 0.5;
    float _2961;
    if (scKitOn && (mode == 6.0))
    {
        float param = age;
        _2961 = scKitSearchAngle(param);
    }
    else
    {
        _2961 = 0.0;
    }
    float yaw = _2961;
    scKitYawCS = float2(cos(yaw), sin(yaw));
    float angle = (6.283185482025146484375 * mod(fast::max(age, 0.0), 3.2000000476837158203125)) / 3.2000000476837158203125;
    scKitRoll = U.pose.y / (U.viewport.z * 0.2949999868869781494140625);
}

static inline __attribute__((always_inline))
float scKitFaceMode(thread const float& mode)
{
    float _2926;
    if (mode == 6.0)
    {
        _2926 = 2.0;
    }
    else
    {
        _2926 = (mode == 7.0) ? 0.0 : mode;
    }
    return _2926;
}

static inline __attribute__((always_inline))
float3 worldToScout(thread float3& p, constant NativeUniforms& U)
{
    float heading = U.pose.x + (precise::atan2(sin(3.1415927410125732421875 - U.pose.x), cos(3.1415927410125732421875 - U.pose.x)) * U.pose.w);
    float c = cos(heading);
    float s = sin(heading);
    p = float3((c * p.x) - (s * p.z), p.y, (s * p.x) + (c * p.z));
    float a = (U.pose.w * 1.5707962512969970703125) + U.options.z;
    float cx = cos(a);
    float sx = sin(a);
    return float3(p.x, (cx * p.y) - (sx * p.z), (sx * p.y) + (cx * p.z));
}

static inline __attribute__((always_inline))
void scCamera(thread const float2& uv, thread const float2& orbit, thread float3& ro, thread float3& rd, constant NativeUniforms& U)
{
    float3 ground = float3(uv.x, -0.767000019550323486328125, uv.y);
    float3 eye = U.eye.xyz;
    float3 param = eye - float3(0.0, U.pose.w * 1.0499999523162841796875, 0.0);
    float3 _8361 = worldToScout(param, U);
    ro = _8361;
    float a = U.options.z;
    float c = cos(a);
    float s = sin(a);
    float3 pivot = float3(0.0, -0.47200000286102294921875, -0.4309999942779541015625);
    ro += (pivot - float3(pivot.x, (c * pivot.y) - (s * pivot.z), (s * pivot.y) + (c * pivot.z)));
    float3 param_1 = fast::normalize(ground - eye);
    float3 _8405 = worldToScout(param_1, U);
    rd = _8405;
}

static inline __attribute__((always_inline))
float3 galleryMiss(thread const float2& uv, thread const float3& ro, thread const float3& rd, thread const float& age, thread float& objectCoverage)
{
    objectCoverage = 0.0;
    return float3(0.0);
}

static inline __attribute__((always_inline))
float2 scKitRange(thread const float3& o, thread const float3& rd, thread const float3& h)
{
    float3 safe = fast::max(abs(rd), float3(9.9999999747524270787835121154785e-07)) * float3((rd.x < 0.0) ? (-1.0) : 1.0, (rd.y < 0.0) ? (-1.0) : 1.0, (rd.z < 0.0) ? (-1.0) : 1.0);
    float3 a = ((-h) - o) / safe;
    float3 b = (h - o) / safe;
    float3 lo = fast::min(a, b);
    float3 hi = fast::max(a, b);
    return float2(fast::max(lo.x, fast::max(lo.y, lo.z)), fast::min(hi.x, fast::min(hi.y, hi.z)));
}

static inline __attribute__((always_inline))
float2 scKitRayVolumes(thread const float3& ro, thread const float3& rd)
{
    float3 param = ro - float3(-0.4050000011920928955078125, 0.736000001430511474609375, -0.15600000321865081787109375);
    float3 param_1 = rd;
    float3 param_2 = float3(0.2790000140666961669921875, 0.24400000274181365966796875, 0.2790000140666961669921875);
    float2 d = scKitRange(param, param_1, param_2);
    float3 param_3 = ro - float3(0.0, -0.4709999859333038330078125, 0.0);
    float3 param_4 = rd;
    float3 param_5 = float3(0.811999976634979248046875, 0.3089999854564666748046875, 0.7400000095367431640625);
    float2 w = scKitRange(param_3, param_4, param_5);
    return float2(float(d.x < d.y), float(w.x < w.y));
}

static inline __attribute__((always_inline))
void scKitConstrainRay(thread const float3& ro, thread const float3& rd, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread float& scKitSweepMask)
{
    float3 param = ro;
    float3 param_1 = rd;
    float2 volumes = scKitRayVolumes(param, param_1);
    if (volumes.x < 0.5)
    {
        scKitYawCS = float2(1.0, 0.0);
    }
    if (volumes.y < 0.5)
    {
        scKitRoll = 0.0;
    }
    bool _3125;
    if (scKitOn)
    {
        _3125 = fast::max(volumes.x, volumes.y) > 0.5;
    }
    else
    {
        _3125 = scKitOn;
    }
    scKitSweepMask = _3125 ? 0.670000016689300537109375 : 0.0;
}

static inline __attribute__((always_inline))
float galleryLift(thread const float& mode, thread const float& age)
{
    if ((mode == 4.0) || (mode == 6.0))
    {
        return 1.0 - smoothstep(0.0599999986588954925537109375, 1.17999994754791259765625, age);
    }
    if (mode == 5.0)
    {
        return (1.0 - smoothstep(0.07999999821186065673828125, 0.9900000095367431640625, age)) + smoothstep(1.2200000286102294921875, 2.21000003814697265625, age);
    }
    return 1.0;
}

static inline __attribute__((always_inline))
float scBox(thread const float3& p, thread const float3& h, thread const float& r)
{
    float3 d = (abs(p) - h) + float3(r);
    return (fast::min(fast::max(d.x, fast::max(d.y, d.z)), 0.0) + length(fast::max(d, float3(0.0)))) - r;
}

static inline __attribute__((always_inline))
float scRect(thread const float2& p, thread const float2& h, thread const float& r)
{
    float2 d = (abs(p) - h) + float2(r);
    return (fast::min(fast::max(d.x, d.y), 0.0) + length(fast::max(d, float2(0.0)))) - r;
}

static inline __attribute__((always_inline))
float scSection(thread const float& a, thread const float& b, thread const float& r)
{
    float2 d = float2(a, b) + float2(r);
    return (length(fast::max(d, float2(0.0))) + fast::min(fast::max(d.x, d.y), 0.0)) - r;
}

static inline __attribute__((always_inline))
float2 scAdd(thread const float2& a, thread const float& b, thread const float& id)
{
    float2 _2913;
    if (a.x < b)
    {
        _2913 = a;
    }
    else
    {
        _2913 = float2(b, id);
    }
    return _2913;
}

static inline __attribute__((always_inline))
float scKitWheelAngle(thread const float3& p, thread const float& neutral, thread float& scKitRoll)
{
    float _3131;
    if (p.z < 0.0)
    {
        _3131 = -scKitRoll;
    }
    else
    {
        _3131 = scKitRoll;
    }
    return neutral + _3131;
}

static inline __attribute__((always_inline))
float scKitBore(thread const float& r, thread const float& a)
{
    float f = mod(a + 0.52359879016876220703125, 1.0471975803375244140625) - 0.52359879016876220703125;
    return length((float2(cos(f), sin(f)) * r) - float2(0.104999996721744537353515625, 0.0)) - 0.0199999995529651641845703125;
}

static inline __attribute__((always_inline))
float2 scKitWheelInside(thread float2& object, thread const float3& wheel, thread const float& radius)
{
    float param = radius - 0.1480000019073486328125;
    float param_1 = abs(wheel.x + 0.001000000047497451305389404296875) - 0.082999996840953826904296875;
    float param_2 = 0.01400000043213367462158203125;
    float barrel = scSection(param, param_1, param_2);
    float2 param_3 = object;
    float param_4 = barrel;
    float param_5 = 11.0;
    object = scAdd(param_3, param_4, param_5);
    float param_6 = radius - 0.1599999964237213134765625;
    float param_7 = abs(wheel.x + 0.114000000059604644775390625) - 0.0320000015199184417724609375;
    float param_8 = 0.0170000009238719940185546875;
    float backplate = scSection(param_6, param_7, param_8);
    float2 param_9 = object;
    float param_10 = fast::max(backplate, 0.0430000014603137969970703125 - radius);
    float param_11 = 12.0;
    object = scAdd(param_9, param_10, param_11);
    float param_12 = radius - 0.06800000369548797607421875;
    float param_13 = abs(wheel.x + 0.14200000464916229248046875) - 0.01899999938905239105224609375;
    float param_14 = 0.0089999996125698089599609375;
    float socket = scSection(param_12, param_13, param_14);
    float2 param_15 = object;
    float param_16 = socket;
    float param_17 = 12.0;
    return scAdd(param_15, param_16, param_17);
}

static inline __attribute__((always_inline))
float2 scKitUndertray(thread float2& object, thread const float3& p)
{
    float x = abs(p.x);
    float skirt = fast::clamp((p.y + 0.5030000209808349609375) / 0.259000003337860107421875, 0.0, 1.0);
    float halfWidth = 0.4239999949932098388671875 + (0.0579999983310699462890625 * skirt);
    float halfLength = 0.4970000088214874267578125 + (0.0610000006854534149169921875 * skirt);
    float3 param = p - float3(0.0, -0.3490000069141387939453125, -0.008000000379979610443115234375);
    float3 param_1 = float3(halfWidth, 0.180000007152557373046875, halfLength);
    float param_2 = 0.1089999973773956298828125;
    float pan = scBox(param, param_1, param_2);
    float2 param_3 = object;
    float param_4 = pan;
    float param_5 = 16.0;
    object = scAdd(param_3, param_4, param_5);
    float radius = length(float2(p.y + 0.47200000286102294921875, abs(p.z) - 0.4309999942779541015625));
    float taper = smoothstep(0.38999998569488525390625, 0.50499999523162841796875, x);
    float param_6 = radius - mix(0.08699999749660491943359375, 0.05200000107288360595703125, taper);
    float param_7 = abs(x - 0.486999988555908203125) - 0.12800000607967376708984375;
    float param_8 = 0.0170000009238719940185546875;
    float stub = scSection(param_6, param_7, param_8);
    float2 param_9 = object;
    float param_10 = stub;
    float param_11 = 14.0;
    return scAdd(param_9, param_10, param_11);
}

static inline __attribute__((always_inline))
float scRod(thread const float3& p, thread const float3& a, thread const float3& b, thread const float& r)
{
    float3 d = b - a;
    return length((p - a) - (d * fast::clamp(dot(p - a, d) / dot(d, d), 0.0, 1.0))) - r;
}

static inline __attribute__((always_inline))
float3 scKitDishPoint(thread const float3& p, thread float2& scKitYawCS)
{
    float3 d = p - float3(-0.4050000011920928955078125, 0.4550000131130218505859375, -0.15600000321865081787109375);
    return float3(-0.4050000011920928955078125, 0.4550000131130218505859375, -0.15600000321865081787109375) + float3((scKitYawCS.x * d.x) - (scKitYawCS.y * d.z), d.y, (scKitYawCS.y * d.x) + (scKitYawCS.x * d.z));
}

static inline __attribute__((always_inline))
float3 scKitBowlLocal(thread const float3& p)
{
    float3 off = p - float3(-0.4099999964237213134765625, 0.726000010967254638671875, -0.15299999713897705078125);
    float3 axis = float3(-0.4294420778751373291015625, 0.559273421764373779296875, 0.70907878875732421875);
    float3 ex = fast::normalize(cross(float3(0.0, 1.0, 0.0), axis));
    float3 ey = cross(axis, ex);
    return float3(dot(off, ex), dot(off, ey), dot(off, axis));
}

static inline __attribute__((always_inline))
float2 scKitDish(thread float2& s, thread const float3& p, thread float2& scKitYawCS)
{
    float3 pivot = float3(-0.4050000011920928955078125, 0.4550000131130218505859375, -0.15600000321865081787109375);
    float3 param = p - pivot;
    float3 param_1 = float3(0.085000000894069671630859375, 0.0350000001490116119384765625, 0.0670000016689300537109375);
    float param_2 = 0.02199999988079071044921875;
    float2 param_3 = s;
    float param_4 = scBox(param, param_1, param_2);
    float param_5 = 8.0;
    s = scAdd(param_3, param_4, param_5);
    float3 foot = p - (pivot + float3(0.0, 0.0379999987781047821044921875, 0.0));
    float param_6 = length(foot.xz) - 0.056000001728534698486328125;
    float param_7 = abs(foot.y) - 0.02500000037252902984619140625;
    float param_8 = 0.008000000379979610443115234375;
    float2 param_9 = s;
    float param_10 = scSection(param_6, param_7, param_8);
    float param_11 = 13.0;
    s = scAdd(param_9, param_10, param_11);
    float3 param_12 = p;
    float3 m = scKitDishPoint(param_12, scKitYawCS);
    float3 joint = float3(-0.4050000011920928955078125, 0.681999981403350830078125, -0.17700000107288360595703125);
    float3 center = float3(-0.4099999964237213134765625, 0.726000010967254638671875, -0.15299999713897705078125);
    float3 axis = float3(-0.4294420778751373291015625, 0.559273421764373779296875, 0.70907878875732421875);
    float3 param_13 = m;
    float3 param_14 = pivot + float3(0.0, 0.048000000417232513427734375, 0.0);
    float3 param_15 = joint;
    float param_16 = 0.02999999932944774627685546875;
    float2 param_17 = s;
    float param_18 = scRod(param_13, param_14, param_15, param_16);
    float param_19 = 5.0;
    s = scAdd(param_17, param_18, param_19);
    float3 param_20 = m;
    float3 param_21 = joint;
    float3 param_22 = center - (axis * 0.017999999225139617919921875);
    float param_23 = 0.0309999994933605194091796875;
    float2 param_24 = s;
    float param_25 = scRod(param_20, param_21, param_22, param_23);
    float param_26 = 11.0;
    s = scAdd(param_24, param_25, param_26);
    float3 param_27 = m;
    float3 d = scKitBowlLocal(param_27);
    float r = length(d.xy);
    float depth = (0.939999997615814208984375 * r) * r;
    float param_28 = r - 0.2109999954700469970703125;
    float param_29 = abs(d.z - depth) - 0.01400000043213367462158203125;
    float param_30 = 0.008000000379979610443115234375;
    float2 param_31 = s;
    float param_32 = scSection(param_28, param_29, param_30);
    float param_33 = 10.0;
    s = scAdd(param_31, param_32, param_33);
    float2 param_34 = s;
    float param_35 = length(float2(r - 0.20700000226497650146484375, d.z - 0.039999999105930328369140625)) - 0.01200000010430812835693359375;
    float param_36 = 5.0;
    s = scAdd(param_34, param_35, param_36);
    float3 param_37 = d;
    float3 param_38 = float3(0.0, 0.0, 0.006000000052154064178466796875);
    float3 param_39 = float3(0.01899999938905239105224609375, -0.01600000075995922088623046875, 0.114000000059604644775390625);
    float param_40 = 0.0130000002682209014892578125;
    float2 param_41 = s;
    float param_42 = scRod(param_37, param_38, param_39, param_40);
    float param_43 = 8.0;
    s = scAdd(param_41, param_42, param_43);
    float2 param_44 = s;
    float param_45 = length(d - float3(0.0199999995529651641845703125, -0.01600000075995922088623046875, 0.11699999868869781494140625)) - 0.026000000536441802978515625;
    float param_46 = 9.0;
    s = scAdd(param_44, param_45, param_46);
    float3 tangential = float3((0.875 * d.x) + (0.4839999973773956298828125 * d.y), ((-0.4839999973773956298828125) * d.x) + (0.875 * d.y), d.z);
    float3 param_47 = tangential - float3(0.203999996185302734375, 0.0, 0.041000001132488250732421875);
    float3 param_48 = float3(0.01899999938905239105224609375, 0.0379999987781047821044921875, 0.0170000009238719940185546875);
    float param_49 = 0.00999999977648258209228515625;
    float2 param_50 = s;
    float param_51 = scBox(param_47, param_48, param_49);
    float param_52 = 11.0;
    s = scAdd(param_50, param_51, param_52);
    float3 param_53 = tangential - float3(0.212999999523162841796875, 0.0, 0.0439999997615814208984375);
    float3 param_54 = float3(0.0130000002682209014892578125, 0.02700000070035457611083984375, 0.0199999995529651641845703125);
    float param_55 = 0.007000000216066837310791015625;
    float2 param_56 = s;
    float param_57 = scBox(param_53, param_54, param_55);
    float param_58 = 15.0;
    s = scAdd(param_56, param_57, param_58);
    return s;
}

static inline __attribute__((always_inline))
float2 scScene(thread const float3& p, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS)
{
    float ax = abs(p.x);
    float3 q = p - float3(0.0, 0.1480000019073486328125, 0.0199999995529651641845703125);
    float width = (0.662000000476837158203125 - (0.1599999964237213134765625 * fast::max(q.y, 0.0))) - (0.119999997317790985107421875 * fast::max((-q.z) - 0.180000007152557373046875, 0.0));
    float3 param = q;
    float3 param_1 = float3(width, 0.3260000050067901611328125, 0.4880000054836273193359375);
    float param_2 = 0.083999998867511749267578125;
    float housing = scBox(param, param_1, param_2);
    float aftRoof = ((q.y - (0.46700000762939453125 * q.z)) - 0.4519999921321868896484375) * 0.9049999713897705078125;
    housing = fast::max(housing, aftRoof);
    float2 display = p.xy - float2(0.0, 0.1550000011920928955078125);
    float2 param_3 = display;
    float2 param_4 = float2(0.54799997806549072265625, 0.24199999868869781494140625);
    float param_5 = 0.06599999964237213134765625;
    float well = fast::max(scRect(param_3, param_4, param_5), 0.3650000095367431640625 - p.z);
    housing = fast::max(housing, -well);
    float2 obj = float2(housing, 1.0);
    if (p.z > 0.2899999916553497314453125)
    {
        float2 param_6 = display;
        float2 param_7 = float2(0.57400000095367431640625, 0.2669999897480010986328125);
        float param_8 = 0.07500000298023223876953125;
        float param_9 = scRect(param_6, param_7, param_8);
        float param_10 = abs(p.z - 0.4749999940395355224609375) - 0.0719999969005584716796875;
        float param_11 = 0.02500000037252902984619140625;
        float lip = scSection(param_9, param_10, param_11);
        float2 param_12 = display;
        float2 param_13 = float2(0.5030000209808349609375, 0.1969999969005584716796875);
        float param_14 = 0.048000000417232513427734375;
        lip = fast::max(lip, -fast::max(scRect(param_12, param_13, param_14), 0.4320000112056732177734375 - p.z));
        float2 param_15 = obj;
        float param_16 = lip;
        float param_17 = 2.0;
        obj = scAdd(param_15, param_16, param_17);
        float2 param_18 = display;
        float2 param_19 = float2(0.510999977588653564453125, 0.20499999821186065673828125);
        float param_20 = 0.0529999993741512298583984375;
        float param_21 = scRect(param_18, param_19, param_20);
        float param_22 = abs(p.z - 0.5) - 0.01600000075995922088623046875;
        float param_23 = 0.008000000379979610443115234375;
        float glass = scSection(param_21, param_22, param_23);
        float2 param_24 = obj;
        float param_25 = glass;
        float param_26 = 3.0;
        obj = scAdd(param_24, param_25, param_26);
    }
    float3 w = float3(ax - 0.653999984264373779296875, p.y + 0.47200000286102294921875, abs(p.z) - 0.4309999942779541015625);
    bool _3770 = w.y < 0.38999998569488525390625;
    bool _3777;
    if (_3770)
    {
        _3777 = w.y > (-0.37999999523162841796875);
    }
    else
    {
        _3777 = _3770;
    }
    if (_3777 && (ax > 0.3499999940395355224609375))
    {
        float r = length(w.yz);
        float3 param_27 = p;
        float param_28 = precise::atan2(w.y, w.z);
        float angle = scKitWheelAngle(param_27, param_28, scKitRoll);
        float treadAngle = (24.0 * angle) + (4.400000095367431640625 * abs(w.x / 0.14499999582767486572265625));
        float notch = smoothstep(0.0599999986588954925537109375, 0.589999973773956298828125, cos(treadAngle)) * 0.01200000010430812835693359375;
        float param_29 = (r - 0.2949999868869781494140625) + (notch * smoothstep(0.2150000035762786865234375, 0.2569999992847442626953125, r));
        float param_30 = abs(w.x) - 0.1410000026226043701171875;
        float param_31 = 0.04500000178813934326171875;
        float tire = scSection(param_29, param_30, param_31);
        tire = fast::max(tire, -fast::max(r - 0.1689999997615814208984375, 0.0540000014007091522216796875 - w.x));
        if (scKitOn)
        {
            tire = fast::max(tire, -fast::max(r - 0.15600000321865081787109375, w.x + 0.064000003039836883544921875));
            tire = fast::max(tire, 0.092000000178813934326171875 - r);
        }
        float2 param_32 = obj;
        float param_33 = tire;
        float param_34 = 4.0;
        obj = scAdd(param_32, param_33, param_34);
        float param_35 = r - 0.1599999964237213134765625;
        float param_36 = abs(w.x - 0.097999997437000274658203125) - 0.0350000001490116119384765625;
        float param_37 = 0.0130000002682209014892578125;
        float hub = scSection(param_35, param_36, param_37);
        if (scKitOn)
        {
            float param_38 = r;
            float param_39 = angle;
            hub = fast::max(hub, -scKitBore(param_38, param_39));
            float2 param_40 = obj;
            float3 param_41 = w;
            float param_42 = r;
            float2 _3900 = scKitWheelInside(param_40, param_41, param_42);
            obj = _3900;
        }
        float2 param_43 = obj;
        float param_44 = hub;
        float param_45 = 5.0;
        obj = scAdd(param_43, param_44, param_45);
        float param_46 = r - 0.063000001013278961181640625;
        float param_47 = abs(w.x - 0.12899999320507049560546875) - 0.014999999664723873138427734375;
        float param_48 = 0.008000000379979610443115234375;
        float cap = scSection(param_46, param_47, param_48);
        float2 param_49 = obj;
        float param_50 = cap;
        float param_51 = 6.0;
        obj = scAdd(param_49, param_50, param_51);
    }
    if (p.y < (-0.1019999980926513671875))
    {
        float3 param_52 = p - float3(0.0, -0.1689999997615814208984375, -0.017999999225139617919921875);
        float3 param_53 = float3(0.605000019073486328125, 0.063000001013278961181640625, 0.62999999523162841796875);
        float param_54 = 0.04500000178813934326171875;
        float2 param_55 = obj;
        float param_56 = scBox(param_52, param_53, param_54);
        float param_57 = 7.0;
        obj = scAdd(param_55, param_56, param_57);
        if (scKitOn)
        {
            float2 param_58 = obj;
            float3 param_59 = p;
            float2 _3957 = scKitUndertray(param_58, param_59);
            obj = _3957;
        }
        else
        {
            float3 mirror = float3(ax, p.y, abs(p.z));
            float3 param_60 = p - float3(0.0, -0.2529999911785125732421875, -0.00999999977648258209228515625);
            float3 param_61 = float3(0.425000011920928955078125, 0.08200000226497650146484375, 0.522000014781951904296875);
            float param_62 = 0.0670000016689300537109375;
            float2 param_63 = obj;
            float param_64 = scBox(param_60, param_61, param_62);
            float param_65 = 8.0;
            obj = scAdd(param_63, param_64, param_65);
            float3 param_66 = mirror;
            float3 param_67 = float3(0.5950000286102294921875, -0.4740000069141387939453125, 0.4320000112056732177734375);
            float3 param_68 = float3(0.4189999997615814208984375, -0.2479999959468841552734375, 0.2849999964237213134765625);
            float param_69 = 0.04500000178813934326171875;
            float2 param_70 = obj;
            float param_71 = scRod(param_66, param_67, param_68, param_69);
            float param_72 = 6.0;
            obj = scAdd(param_70, param_71, param_72);
            float3 param_73 = mirror;
            float3 param_74 = float3(0.602999985218048095703125, -0.4550000131130218505859375, 0.4189999997615814208984375);
            float3 param_75 = float3(0.528999984264373779296875, -0.22200000286102294921875, 0.014999999664723873138427734375);
            float param_76 = 0.034000001847743988037109375;
            float2 param_77 = obj;
            float param_78 = scRod(param_73, param_74, param_75, param_76);
            float param_79 = 8.0;
            obj = scAdd(param_77, param_78, param_79);
            float3 param_80 = float3(ax - 0.53100001811981201171875, p.y + 0.23499999940395355224609375, p.z);
            float3 param_81 = float3(0.054999999701976776123046875, 0.039999999105930328369140625, 0.5);
            float param_82 = 0.02999999932944774627685546875;
            float sill = scBox(param_80, param_81, param_82);
            float2 param_83 = obj;
            float param_84 = sill;
            float param_85 = 5.0;
            obj = scAdd(param_83, param_84, param_85);
        }
        if (p.z > 0.38999998569488525390625)
        {
            float3 bumper = p - float3(0.0, -0.23199999332427978515625, 0.58399999141693115234375);
            float param_86 = abs(length(bumper.xy / float2(1.5, 1.0)) - 0.063000001013278961181640625) - 0.014999999664723873138427734375;
            float param_87 = abs(bumper.z) - 0.02500000037252902984619140625;
            float param_88 = 0.006000000052154064178466796875;
            float hook = scSection(param_86, param_87, param_88);
            float2 param_89 = obj;
            float param_90 = hook;
            float param_91 = 9.0;
            obj = scAdd(param_89, param_90, param_91);
        }
    }
    bool _4084;
    if (scKitOn)
    {
        _4084 = p.y > 0.3499999940395355224609375;
    }
    else
    {
        _4084 = scKitOn;
    }
    bool _4091;
    if (_4084)
    {
        _4091 = p.x < (-0.119999997317790985107421875);
    }
    else
    {
        _4091 = _4084;
    }
    if (_4091)
    {
        float2 param_92 = obj;
        float3 param_93 = p;
        float2 _4098 = scKitDish(param_92, param_93, scKitYawCS);
        obj = _4098;
    }
    else
    {
        bool _4102 = p.y > 0.3499999940395355224609375;
        bool _4108;
        if (_4102)
        {
            _4108 = p.x < (-0.119999997317790985107421875);
        }
        else
        {
            _4108 = _4102;
        }
        if (_4108)
        {
            float3 a = float3(-0.4050000011920928955078125, 0.4550000131130218505859375, -0.15600000321865081787109375);
            float3 b = float3(-0.4050000011920928955078125, 0.681999981403350830078125, -0.17700000107288360595703125);
            float3 param_94 = p;
            float3 param_95 = a;
            float3 param_96 = b;
            float param_97 = 0.0320000015199184417724609375;
            float2 param_98 = obj;
            float param_99 = scRod(param_94, param_95, param_96, param_97);
            float param_100 = 5.0;
            obj = scAdd(param_98, param_99, param_100);
            float3 param_101 = p - a;
            float3 param_102 = float3(0.085000000894069671630859375, 0.0350000001490116119384765625, 0.0670000016689300537109375);
            float param_103 = 0.02199999988079071044921875;
            float2 param_104 = obj;
            float param_105 = scBox(param_101, param_102, param_103);
            float param_106 = 8.0;
            obj = scAdd(param_104, param_105, param_106);
            float3 center = float3(-0.4099999964237213134765625, 0.726000010967254638671875, -0.15299999713897705078125);
            float3 n = float3(-0.4294420778751373291015625, 0.559273421764373779296875, 0.70907878875732421875);
            float3 ex = fast::normalize(cross(float3(0.0, 1.0, 0.0), n));
            float3 ey = cross(n, ex);
            float3 t = p - center;
            float3 d = float3(dot(t, ex), dot(t, ey), dot(t, n));
            float r_1 = length(d.xy);
            float z = (0.939999997615814208984375 * r_1) * r_1;
            float param_107 = r_1 - 0.2109999954700469970703125;
            float param_108 = abs(d.z - z) - 0.01400000043213367462158203125;
            float param_109 = 0.008000000379979610443115234375;
            float bowl = scSection(param_107, param_108, param_109);
            float2 param_110 = obj;
            float param_111 = bowl;
            float param_112 = 10.0;
            obj = scAdd(param_110, param_111, param_112);
            float2 param_113 = obj;
            float param_114 = length(float2(r_1 - 0.20700000226497650146484375, d.z - 0.039999999105930328369140625)) - 0.01200000010430812835693359375;
            float param_115 = 5.0;
            obj = scAdd(param_113, param_114, param_115);
            float3 param_116 = p;
            float3 param_117 = center + (n * 0.004999999888241291046142578125);
            float3 param_118 = center + (n * 0.115000002086162567138671875);
            float param_119 = 0.0130000002682209014892578125;
            float2 param_120 = obj;
            float param_121 = scRod(param_116, param_117, param_118, param_119);
            float param_122 = 8.0;
            obj = scAdd(param_120, param_121, param_122);
            float3 tip = p - (center + (n * 0.11699999868869781494140625));
            float2 param_123 = obj;
            float param_124 = length(tip) - 0.026000000536441802978515625;
            float param_125 = 9.0;
            obj = scAdd(param_123, param_124, param_125);
        }
    }
    return obj;
}

static inline __attribute__((always_inline))
float2 liftLampDeck(thread const float2& stock, thread const float3& p)
{
    if (stock.y != 1.0)
    {
        return stock;
    }
    float2 param = float2(p.x, p.z - 0.3449999988079071044921875);
    float2 param_1 = float2(0.513000011444091796875, 0.079000003635883331298828125);
    float param_2 = 0.01200000010430812835693359375;
    float outline = scRect(param, param_1, param_2);
    float cutter = fast::max(outline, 0.4309999942779541015625 - p.y);
    float2 _7148;
    if ((-cutter) > stock.x)
    {
        _7148 = float2(-cutter, 43.0);
    }
    else
    {
        _7148 = stock;
    }
    return _7148;
}

static inline __attribute__((always_inline))
float2 liftSinCos(thread float& kitLift)
{
    float angle = 1.4835298061370849609375 * smoothstep(0.0, 1.0, kitLift);
    return float2(sin(angle), cos(angle));
}

static inline __attribute__((always_inline))
float liftAxialPin(thread const float2& radial, thread const float& x, thread const float& halfLength, thread const float& radius)
{
    float param = length(radial) - radius;
    float param_1 = abs(x) - halfLength;
    float param_2 = 0.00200000009499490261077880859375;
    return scSection(param, param_1, param_2);
}

static inline __attribute__((always_inline))
float2 liftLampMap(thread const float3& p, thread float& kitLift)
{
    float3 param = p - float3(0.0, 0.522000014781951904296875, 0.3459999859333038330078125);
    float3 param_1 = float3(0.515999972820281982421875, 0.098999999463558197021484375, 0.085000000894069671630859375);
    float param_2 = 0.0;
    float gate = scBox(param, param_1, param_2);
    if (gate > 0.0350000001490116119384765625)
    {
        return float2(gate, 42.0);
    }
    float2 sc = liftSinCos(kitLift);
    float2 delta = p.yz - float2(0.4709999859333038330078125, 0.27799999713897705078125);
    float2 along = float2(sc.x, sc.y);
    float2 front = float2(-sc.y, sc.x);
    float u = dot(delta, along);
    float w = dot(delta, front);
    float mx = abs(p.x);
    float3 param_3 = float3(p.x, u - 0.071000002324581146240234375, w - 0.00069999997504055500030517578125);
    float3 param_4 = float3(0.505999982357025146484375, 0.06800000369548797607421875, 0.00540000014007091522216796875);
    float param_5 = 0.00430000014603137969970703125;
    float cap = scBox(param_3, param_4, param_5);
    float2 hit = float2(cap, 47.0);
    float3 q = float3(p.x, u - 0.07400000095367431640625, w);
    float3 param_6 = q - float3(0.0, 0.0, 0.0185000002384185791015625);
    float3 param_7 = float3(0.5, 0.0555000007152557373046875, 0.01679999940097332000732421875);
    float param_8 = 0.0074999998323619365692138671875;
    float bezel = scBox(param_6, param_7, param_8);
    float2 param_9 = q.xy;
    float2 param_10 = float2(0.4690000116825103759765625, 0.02899999916553497314453125);
    float param_11 = 0.010999999940395355224609375;
    float slot = scRect(param_9, param_10, param_11);
    bezel = fast::max(bezel, -fast::max(slot, 0.0199999995529651641845703125 - w));
    float2 param_12 = hit;
    float param_13 = bezel;
    float param_14 = 40.0;
    hit = scAdd(param_12, param_13, param_14);
    float2 param_15 = q.xy;
    float2 param_16 = float2(0.4709999859333038330078125, 0.0309999994933605194091796875);
    float param_17 = 0.01200000010430812835693359375;
    float param_18 = scRect(param_15, param_16, param_17);
    float param_19 = abs(w - 0.0274999998509883880615234375) - 0.0040000001899898052215576171875;
    float param_20 = 0.002700000070035457611083984375;
    float glass = scSection(param_18, param_19, param_20);
    float2 param_21 = hit;
    float param_22 = glass;
    float param_23 = 41.0;
    hit = scAdd(param_21, param_22, param_23);
    float2 param_24 = delta;
    float param_25 = p.x;
    float param_26 = 0.4519999921321868896484375;
    float param_27 = 0.0057999999262392520904541015625;
    float axle = liftAxialPin(param_24, param_25, param_26, param_27);
    float2 param_28 = hit;
    float param_29 = axle;
    float param_30 = 45.0;
    hit = scAdd(param_28, param_29, param_30);
    float2 param_31 = delta;
    float param_32 = mx - 0.347999989986419677734375;
    float param_33 = 0.04500000178813934326171875;
    float param_34 = 0.010200000368058681488037109375;
    float moving = liftAxialPin(param_31, param_32, param_33, param_34);
    float3 param_35 = float3(mx - 0.347999989986419677734375, u - 0.0089999996125698089599609375, w - 0.00319999991916120052337646484375);
    float3 param_36 = float3(0.04500000178813934326171875, 0.01400000043213367462158203125, 0.0063000000081956386566162109375);
    float param_37 = 0.0030000000260770320892333984375;
    float fold = scBox(param_35, param_36, param_37);
    float2 param_38 = hit;
    float param_39 = fast::min(moving, fold);
    float param_40 = 42.0;
    hit = scAdd(param_38, param_39, param_40);
    float2 param_41 = delta;
    float param_42 = mx - 0.4189999997615814208984375;
    float param_43 = 0.0240000002086162567138671875;
    float param_44 = 0.010200000368058681488037109375;
    float fixedBarrel = liftAxialPin(param_41, param_42, param_43, param_44);
    float3 foot = float3(mx - 0.4189999997615814208984375, p.y - 0.44900000095367431640625, p.z - 0.2790000140666961669921875);
    float3 param_45 = foot;
    float3 param_46 = float3(0.02500000037252902984619140625, 0.02300000004470348358154296875, 0.010999999940395355224609375);
    float param_47 = 0.0030000000260770320892333984375;
    float fixedLeaf = scBox(param_45, param_46, param_47);
    float2 param_48 = hit;
    float param_49 = fast::min(fixedBarrel, fixedLeaf);
    float param_50 = 42.0;
    hit = scAdd(param_48, param_49, param_50);
    return hit;
}

static inline __attribute__((always_inline))
float2 galleryBody(thread const float3& p, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread float& kitLift)
{
    float3 param = p;
    float2 param_1 = scScene(param, scKitOn, scKitRoll, scKitYawCS);
    float3 param_2 = p;
    float2 a = liftLampDeck(param_1, param_2);
    float3 param_3 = p;
    float2 b = liftLampMap(param_3, kitLift);
    return select(a, b, bool2(b.x < a.x));
}

static inline __attribute__((always_inline))
float3 galleryNormal(thread const float3& p, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread float& kitLift)
{
    float2 e = float2(0.001150000025518238544464111328125, -0.001150000025518238544464111328125);
    float3 param = p + e.xyy;
    float3 param_1 = p + e.yyx;
    float3 param_2 = p + e.yxy;
    float3 param_3 = p + e.xxx;
    return fast::normalize((((e.xyy * galleryBody(param, scKitOn, scKitRoll, scKitYawCS, kitLift).x) + (e.yyx * galleryBody(param_1, scKitOn, scKitRoll, scKitYawCS, kitLift).x)) + (e.yxy * galleryBody(param_2, scKitOn, scKitRoll, scKitYawCS, kitLift).x)) + (e.xxx * galleryBody(param_3, scKitOn, scKitRoll, scKitYawCS, kitLift).x));
}

static inline __attribute__((always_inline))
float scGridInt(thread const float& x)
{
    return (floor(x) * 0.085000000894069671630859375) + fast::min(fract(x), 0.085000000894069671630859375);
}

static inline __attribute__((always_inline))
float scSq(thread const float& x)
{
    return x * x;
}

static inline __attribute__((always_inline))
float3 scEnv(thread const float3& r)
{
    float sky = 0.37999999523162841796875 + (0.25 * smoothstep(-0.5099999904632568359375, 0.589999973773956298828125, r.y));
    float param = r.x - 0.5299999713897705078125;
    float param_1 = r.y - 0.070000000298023223876953125;
    float flag = exp(((-8.0) * scSq(param)) - (3.0 * scSq(param_1)));
    float param_2 = r.x + 0.540000021457672119140625;
    float param_3 = r.y - 0.519999980926513671875;
    float window = exp(((-3.5) * scSq(param_2)) - (5.0 * scSq(param_3)));
    float param_4 = r.x - 0.85000002384185791015625;
    float param_5 = r.y - 0.2899999916553497314453125;
    float strip = exp(((-33.0) * scSq(param_4)) - (2.0 * scSq(param_5)));
    float param_6 = r.y - 0.829999983310699462890625;
    float param_7 = r.x + 0.180000007152557373046875;
    float crown = exp(((-18.0) * scSq(param_6)) - (2.0 * scSq(param_7)));
    return ((((float3(0.2599999904632568359375, 0.2899999916553497314453125, 0.319999992847442626953125) * sky) - (float3(0.11699999868869781494140625) * flag)) + (float3(1.25, 1.11000001430511474609375, 0.939999997615814208984375) * window)) + (float3(0.920000016689300537109375, 0.9900000095367431640625, 1.10000002384185791015625) * strip)) + (float3(0.670000016689300537109375, 0.7400000095367431640625, 0.819999992847442626953125) * crown);
}

static inline __attribute__((always_inline))
float dialOval(thread const float2& p, thread const float2& radius)
{
    float2 d = p / radius;
    return step(dot(d, d), 1.0);
}

static inline __attribute__((always_inline))
float scPixelBox(thread const float2& p, thread const float2& halfSize)
{
    return step(fast::max(abs(p.x) - halfSize.x, abs(p.y) - halfSize.y), 0.0);
}

static inline __attribute__((always_inline))
float dialSearch(thread float& t)
{
    t = mod(t, 8.0);
    return ((0.939999997615814208984375 * smoothstep(0.119999997317790985107421875, 2.0, t)) - (1.980000019073486328125 * smoothstep(2.6099998950958251953125, 5.429999828338623046875, t))) + (1.03999996185302734375 * smoothstep(6.19999980926513671875, 7.900000095367431640625, t));
}

static inline __attribute__((always_inline))
float dialRound(thread const float& x)
{
    return floor(x + 0.5);
}

static inline __attribute__((always_inline))
float scoutOriginalInk(thread const float2& cell, thread const float& mode, thread const float& age, thread const float2& look)
{
    float2 p = floor(cell) - float2(31.0, 24.0);
    bool _504 = abs(p.x) > 16.0;
    bool _512;
    if (!_504)
    {
        _512 = p.y < (-14.0);
    }
    else
    {
        _512 = _504;
    }
    bool _520;
    if (!_512)
    {
        _520 = p.y > 14.0;
    }
    else
    {
        _520 = _512;
    }
    if (_520)
    {
        return 0.0;
    }
    float t = fast::max(0.0, age);
    if (p.y < (-6.0))
    {
        float2 m = p - float2(0.0, -11.0);
        if ((mode == 3.0) || (mode == 1.0))
        {
            float _549;
            if (mode == 1.0)
            {
                _549 = 1.64999997615814208984375;
            }
            else
            {
                _549 = 1.10000002384185791015625 + (2.25 * (0.5 + (0.5 * sin((12.0 * t) + (0.5 * sin(4.0 * t))))));
            }
            float h = _549;
            float2 param = m;
            float2 param_1 = float2(2.7999999523162841796875, h + 0.25);
            float2 param_2 = m;
            float2 param_3 = float2(1.58000004291534423828125, fast::max(0.449999988079071044921875, h - 0.89999997615814208984375));
            return dialOval(param, param_1) * (1.0 - dialOval(param_2, param_3));
        }
        if (mode == 4.0)
        {
            float2 param_4 = m;
            float2 param_5 = float2(1.14999997615814208984375, 0.5);
            return 0.7200000286102294921875 * scPixelBox(param_4, param_5);
        }
        if (mode == 2.0)
        {
            m.x -= 1.0;
        }
        if ((mode == 2.0) || (mode == 5.0))
        {
            float _626;
            if (mode == 2.0)
            {
                _626 = step(1.0, m.x);
            }
            else
            {
                _626 = step(2.0, m.x);
            }
            float y = _626;
            return step(abs(m.x), 3.0) * step(abs(m.y - y), 0.5);
        }
        return 0.0;
    }
    float side = (p.x < 0.0) ? (-1.0) : 1.0;
    float2 q = p - float2(9.0 * side, 3.0);
    float h_1 = 8.0;
    float aim = -2.0;
    float lift = 0.0;
    float2 point = fast::clamp(look, float2(-1.0), float2(1.0));
    if (mode == 0.0)
    {
        aim += ((step(0.699999988079071044921875, fract(t / 6.5)) * 2.0) - (step(0.810000002384185791015625, fract(t / 6.5)) * 2.0));
    }
    if (mode == 1.0)
    {
        lift = 1.0;
        if (side > 0.0)
        {
            q.y -= 1.0;
        }
    }
    if (mode == 2.0)
    {
        aim = mix(-2.0, 2.0, smoothstep(0.3499999940395355224609375, 0.560000002384185791015625, fract(t / 3.7000000476837158203125)));
        lift = 1.0;
        if (side > 0.0)
        {
            h_1 -= 1.0;
        }
    }
    if (mode == 5.0)
    {
        aim = 2.0 - (3.0 * smoothstep(0.180000007152557373046875, 0.62999999523162841796875, fract(t / 3.2000000476837158203125)));
        lift = -1.0;
        if (side < 0.0)
        {
            h_1 -= 1.0;
        }
    }
    if (mode == 6.0)
    {
        float param_6 = t;
        float _747 = dialSearch(param_6);
        aim = 3.0 * _747;
        lift = 1.0;
    }
    if (mode == 7.0)
    {
        aim = 1.0;
        lift = -1.0;
        h_1 -= 1.0;
    }
    float param_7 = fast::clamp(aim + (point.x * 3.5), -2.0, 2.0);
    aim = dialRound(param_7);
    float param_8 = fast::clamp(lift + point.y, -1.0, 1.0);
    lift = dialRound(param_8);
    float blink = abs(mod(t + 0.63999998569488525390625, 5.349999904632568359375) - 0.17000000178813934326171875);
    float _784;
    if (mode == 4.0)
    {
        _784 = 0.0;
    }
    else
    {
        _784 = smoothstep(0.04500000178813934326171875, 0.1500000059604644775390625, blink);
    }
    float lid = _784;
    if (lid < 0.1599999964237213134765625)
    {
        float _801;
        if (mode == 4.0)
        {
            _801 = (-1.0) + floor(abs(q.x) * 0.300000011920928955078125);
        }
        else
        {
            _801 = 1.0 - floor(abs(q.x) * 0.300000011920928955078125);
        }
        float y_1 = _801;
        return (0.839999973773956298828125 * step(abs(q.x), 4.0)) * step(abs(q.y - y_1), 0.5);
    }
    float param_9 = h_1 * lid;
    h_1 = fast::max(2.0, dialRound(param_9));
    float band = h_1 - abs(q.y);
    float x = abs(q.x);
    float _855;
    if (band < 0.5)
    {
        _855 = 3.0;
    }
    else
    {
        _855 = (band < 1.5) ? 4.0 : 5.0;
    }
    float outer = step(0.0, band) * step(x, _855);
    float hollow = step(1.5, band) * step(x, 4.0);
    float rim = outer * (1.0 - hollow);
    float2 a = q - float2(aim, lift);
    float pupilH = fast::max(1.0, h_1 - 3.0);
    float edge = pupilH - abs(a.y);
    float _902;
    if (edge < 0.5)
    {
        _902 = 1.5;
    }
    else
    {
        _902 = (edge < 1.5) ? 2.0 : 2.599999904632568359375;
    }
    float pupil = step(0.0, edge) * step(abs(a.x + 0.449999988079071044921875), _902);
    float param_10 = 0.579999983310699462890625 * pupilH;
    float2 param_11 = a - float2(-1.0, dialRound(param_10));
    float2 param_12 = float2(0.449999988079071044921875);
    pupil *= (1.0 - scPixelBox(param_11, param_12));
    return fast::max(rim, outer * pupil);
}

static inline __attribute__((always_inline))
float3 scoutFriendlyMarks(thread const float2& cell, thread const float& mode, thread const float& age, thread const float2& look)
{
    float2 p = floor(cell) - float2(31.0, 24.0);
    bool _2244 = abs(p.x) > 24.0;
    bool _2252;
    if (!_2244)
    {
        _2252 = p.y < (-13.0);
    }
    else
    {
        _2252 = _2244;
    }
    bool _2260;
    if (!_2252)
    {
        _2260 = p.y > 15.0;
    }
    else
    {
        _2260 = _2252;
    }
    if (_2260)
    {
        return float3(0.0);
    }
    float side = (p.x < 0.0) ? (-1.0) : 1.0;
    float t = fast::max(0.0, age);
    float _2276;
    if (mode == 6.0)
    {
        float param = t;
        float _2281 = dialSearch(param);
        _2276 = _2281;
    }
    else
    {
        _2276 = 0.0;
    }
    float turn = _2276;
    float _2287;
    if (mode == 5.0)
    {
        _2287 = smoothstep(0.119999997317790985107421875, 0.680000007152557373046875, fract(t / 3.2000000476837158203125));
    }
    else
    {
        _2287 = 0.0;
    }
    float focus = _2287;
    float2 aim = fast::clamp(look, float2(-1.0), float2(1.0)) * float2(1.60000002384185791015625, 1.10000002384185791015625);
    float h = 7.19999980926513671875;
    float cy = 1.7999999523162841796875;
    float brow = 12.0;
    if ((mode == 1.0) && (side > 0.0))
    {
        h += 0.699999988079071044921875;
        cy += 0.699999988079071044921875;
        brow += 1.0;
    }
    if (mode == 2.0)
    {
        aim = float2(1.7999999523162841796875 * (1.0 - (2.0 * step(0.550000011920928955078125, fract(t / 3.7000000476837158203125)))), 1.10000002384185791015625) + (aim * 0.300000011920928955078125);
        if (side < 0.0)
        {
            brow += 1.0;
        }
        else
        {
            h -= 1.2000000476837158203125;
        }
    }
    if (mode == 5.0)
    {
        aim = float2(1.60000002384185791015625 * (1.0 - focus), -0.800000011920928955078125) + (aim * 0.3499999940395355224609375);
        if (side < 0.0)
        {
            h -= (1.5 * focus);
        }
    }
    if (mode == 6.0)
    {
        aim = float2(2.0 * turn, 0.60000002384185791015625) + (aim * 0.3499999940395355224609375);
        brow += step(0.4199999868869781494140625, side * turn);
    }
    if (mode == 7.0)
    {
        aim = float2(1.60000002384185791015625, -1.0) + (aim * 0.4000000059604644775390625);
        h -= 0.60000002384185791015625;
    }
    aim = floor(fast::clamp(aim, float2(-2.0, -1.0), float2(2.0, 1.0)) + float2(0.5));
    float blink = abs(mod(t + 0.790000021457672119140625, 5.349999904632568359375) - 0.1500000059604644775390625);
    float _2410;
    if (mode == 4.0)
    {
        _2410 = 0.0;
    }
    else
    {
        _2410 = smoothstep(0.0379999987781047821044921875, 0.1599999964237213134765625, blink);
    }
    float lid = _2410;
    float param_1 = cy;
    float2 eye = p - float2(10.0 * side, dialRound(param_1));
    float amber = 0.0;
    float glint = 0.0;
    if (lid < 0.119999997317790985107421875)
    {
        float _2436;
        if (mode == 4.0)
        {
            _2436 = (-1.0) + floor(0.36000001430511474609375 * abs(eye.x));
        }
        else
        {
            _2436 = 1.0 - floor(0.319999992847442626953125 * abs(eye.x));
        }
        float y = _2436;
        amber = (0.819999992847442626953125 * step(abs(eye.x), 4.0)) * step(abs(eye.y - y), 0.550000011920928955078125);
    }
    else
    {
        h = fast::max(1.7000000476837158203125, h * lid);
        float2 param_2 = eye;
        float2 param_3 = float2(6.150000095367431640625, h + 0.1500000059604644775390625);
        float outside = dialOval(param_2, param_3);
        float2 pupil = eye - float2(aim.x, aim.y * lid);
        float2 param_4 = pupil;
        float2 param_5 = float2(3.7200000286102294921875, fast::max(0.75, h - 2.0499999523162841796875));
        float2 param_6 = eye;
        float2 param_7 = float2(5.0799999237060546875, fast::max(0.800000011920928955078125, h - 1.14999997615814208984375));
        float center = dialOval(param_4, param_5) * dialOval(param_6, param_7);
        amber = (outside * (1.0 - center)) * (0.769999980926513671875 + (0.23000000417232513427734375 * smoothstep(-h, h, eye.y)));
        if (h > 3.400000095367431640625)
        {
            float param_8 = 0.3499999940395355224609375 * h;
            float2 k = pupil - float2(-1.5, dialRound(param_8));
            float2 param_9 = k;
            float2 param_10 = float2(1.519999980926513671875, 1.5299999713897705078125);
            float shine = dialOval(param_9, param_10);
            float2 param_11 = pupil - float2(2.0, -1.0);
            float2 param_12 = float2(0.550000011920928955078125);
            float fleck = 0.699999988079071044921875 * scPixelBox(param_11, param_12);
            glint = (outside * center) * fast::max(shine, fleck);
        }
    }
    if (mode != 4.0)
    {
        float param_13 = (0.37000000476837158203125 * (2.599999904632568359375 - abs(eye.x))) - ((0.1500000059604644775390625 * side) * eye.x);
        float by = brow + dialRound(param_13);
        amber = fast::max(amber, (0.86000001430511474609375 * step(abs(eye.x), 3.5)) * step(abs(p.y - by), 0.5));
    }
    float2 cheek = float2(abs(p.x) - 20.0, p.y + 4.0);
    float2 param_14 = cheek;
    float2 param_15 = float2(3.099999904632568359375, 1.5499999523162841796875);
    float blush = dialOval(param_14, param_15) * (0.7599999904632568359375 + (0.23999999463558197021484375 * step(cheek.x, 0.0)));
    if (mode == 4.0)
    {
        blush *= 0.4199999868869781494140625;
    }
    float2 m = p - float2(0.0, -9.0);
    if (mode == 3.0)
    {
        float beat = 0.5 + (0.5 * sin((12.0 * t) + sin(5.0 * t)));
        float opening = 1.89999997615814208984375 + floor(2.2000000476837158203125 * beat);
        float2 param_16 = m;
        float2 param_17 = float2(4.599999904632568359375, opening + 0.300000011920928955078125);
        float outer = dialOval(param_16, param_17);
        float2 param_18 = m - float2(0.0, 0.3499999940395355224609375);
        float2 param_19 = float2(2.849999904632568359375, fast::max(0.800000011920928955078125, opening - 1.0));
        float inner = dialOval(param_18, param_19);
        amber = fast::max(amber, outer * (1.0 - inner));
        blush = fast::max(blush, (0.7799999713897705078125 * inner) * step(m.y, -1.0));
    }
    else
    {
        if (mode == 1.0)
        {
            float2 param_20 = m;
            float2 param_21 = float2(2.7999999523162841796875, 2.400000095367431640625);
            float2 param_22 = m;
            float2 param_23 = float2(1.4500000476837158203125, 1.2999999523162841796875);
            amber = fast::max(amber, 0.920000016689300537109375 * (dialOval(param_20, param_21) - dialOval(param_22, param_23)));
        }
        else
        {
            float _2715;
            if (mode == 4.0)
            {
                _2715 = 2.0;
            }
            else
            {
                float _2721;
                if (mode == 2.0)
                {
                    _2721 = 3.0;
                }
                else
                {
                    float _2727;
                    if (mode == 5.0)
                    {
                        _2727 = 3.0;
                    }
                    else
                    {
                        _2727 = (mode == 7.0) ? 5.0 : 4.0;
                    }
                    _2721 = _2727;
                }
                _2715 = _2721;
            }
            float width = _2715;
            if (mode == 2.0)
            {
                m.x -= 1.0;
            }
            float bend = (mode == 2.0) ? 0.085000000894069671630859375 : 0.1599999964237213134765625;
            float param_24 = (bend * m.x) * m.x;
            float y_1 = dialRound(param_24);
            float previous = fast::max(abs(m.x) - 1.0, 0.0);
            float param_25 = (bend * previous) * previous;
            float lower = dialRound(param_25) + 1.0;
            if ((mode == 2.0) || (mode == 5.0))
            {
                y_1 += step(1.5, m.x);
            }
            amber = fast::max(amber, (step(abs(m.x), width) * step(fast::min(y_1, lower), m.y)) * step(m.y, y_1));
        }
    }
    return float3(amber, glint, blush);
}

static inline __attribute__((always_inline))
float dialArc(thread const float2& p, thread const float& width, thread const float& weight)
{
    float y = 1.0 - floor(0.430000007152557373046875 * abs(p.x));
    return step(abs(p.x), width) * step(abs(p.y - y), weight);
}

static inline __attribute__((always_inline))
float dialBinocular(thread const float2& p, thread const float& mode, thread const float2& gaze, thread const float& lid, thread const float& focus, thread const float& turn)
{
    float side = (p.x < 0.0) ? (-1.0) : 1.0;
    float2 q = p - float2(10.0 * side, 3.0);
    if ((mode == 1.0) && (side > 0.0))
    {
        q.y -= 1.0;
    }
    if ((mode == 2.0) && (side < 0.0))
    {
        q.y -= 1.0;
    }
    if (lid < 0.100000001490116119384765625)
    {
        float2 param = q;
        float2 param_1 = float2(8.69999980926513671875, 4.80000019073486328125);
        float2 param_2 = q;
        float2 param_3 = float2(7.400000095367431640625, 3.599999904632568359375);
        float glasses = dialOval(param, param_1) - dialOval(param_2, param_3);
        float2 param_4 = p - float2(0.0, 5.0);
        float2 param_5 = float2(2.0, 0.60000002384185791015625);
        float bridge = scPixelBox(param_4, param_5);
        float2 param_6 = q;
        float param_7 = 5.0;
        float param_8 = 0.550000011920928955078125;
        return fast::max(0.87999999523162841796875 * dialArc(param_6, param_7, param_8), ((mode == 4.0) ? 0.2800000011920928955078125 : 0.550000011920928955078125) * fast::max(glasses, bridge));
    }
    float h = ((mode == 1.0) && (side > 0.0)) ? 8.0 : 7.0;
    bool _1289 = (mode == 2.0) && (side > 0.0);
    bool _1298;
    if (!_1289)
    {
        _1298 = (mode == 5.0) && (side < 0.0);
    }
    else
    {
        _1298 = _1289;
    }
    if (_1298 || (mode == 7.0))
    {
        h -= 2.0;
    }
    h = fast::max(2.0, floor((h * lid) + 0.5));
    float2 param_9 = q;
    float2 param_10 = float2(6.80000019073486328125, fast::max(0.89999997615814208984375, h - 1.85000002384185791015625));
    float inside = dialOval(param_9, param_10);
    float2 param_11 = q;
    float2 param_12 = float2(9.25, h + 0.25);
    float rim = dialOval(param_11, param_12) - inside;
    float ink = rim * (0.769999980926513671875 + (0.23000000417232513427734375 * step(-1.0, q.y)));
    float2 a = q - gaze;
    float2 param_13 = a;
    float2 param_14 = float2(3.0499999523162841796875, fast::min(3.650000095367431640625, h - 1.0));
    float pupil = dialOval(param_13, param_14);
    float2 param_15 = a - float2(-1.0, 2.0);
    float2 param_16 = float2(0.5);
    pupil *= (1.0 - (0.87999999523162841796875 * scPixelBox(param_15, param_16)));
    if ((mode == 5.0) && (side > 0.0))
    {
        float r = dot(a, a);
        float ring = step(3.099999904632568359375, r) * step(r, 11.0);
        float2 param_17 = a;
        float2 param_18 = float2(0.5);
        pupil = fast::max(0.790000021457672119140625 * ring, focus * scPixelBox(param_17, param_18));
    }
    ink = fast::max(ink, inside * pupil);
    float2 param_19 = p - float2(0.0, 5.0);
    float2 param_20 = float2(2.0, 0.60000002384185791015625);
    float bridge_1 = 0.87000000476837158203125 * scPixelBox(param_19, param_20);
    if (mode == 6.0)
    {
        float2 e = p - float2(side * 23.0, 4.0);
        float2 param_21 = e;
        float2 param_22 = float2(0.550000011920928955078125, 1.5);
        float tick = scPixelBox(param_21, param_22);
        ink = fast::max(ink, (0.7200000286102294921875 * tick) * step(0.60000002384185791015625, turn * side));
    }
    return fast::max(ink, bridge_1);
}

static inline __attribute__((always_inline))
float dialWaypoint(thread const float2& p, thread const float& mode, thread const float2& gaze, thread const float& lid, thread const float& focus, thread const float& turn)
{
    float side = (p.x < 0.0) ? (-1.0) : 1.0;
    float2 q = p - float2(10.0 * side, 4.0);
    bool _1458 = (mode == 1.0) && (side > 0.0);
    bool _1467;
    if (!_1458)
    {
        _1467 = (mode == 2.0) && (side < 0.0);
    }
    else
    {
        _1467 = _1458;
    }
    if (_1467)
    {
        q.y -= 2.0;
    }
    if (mode == 6.0)
    {
        q.y -= (2.0 * step(0.449999988079071044921875, side * turn));
    }
    if (mode == 7.0)
    {
        q.x += floor((fast::max(0.0, -q.y) * 0.23000000417232513427734375) + 0.5);
    }
    if (lid < 0.100000001490116119384765625)
    {
        float tip = step(abs(q.x), 3.0) * step(abs((q.y + 4.0) - abs(q.x)), 0.5);
        float2 param = q;
        float param_1 = 4.0;
        float param_2 = 0.550000011920928955078125;
        return fast::max(0.87999999523162841796875 * dialArc(param, param_1, param_2), ((mode == 4.0) ? 0.3400000035762786865234375 : 0.560000002384185791015625) * tip);
    }
    float h = fast::max(2.0, floor((6.19999980926513671875 * lid) + 0.5));
    float drop = ((mode == 5.0) && (side > 0.0)) ? 11.0 : 9.0;
    float2 param_3 = q;
    float2 param_4 = float2(6.650000095367431640625, h + 0.300000011920928955078125);
    float head = dialOval(param_3, param_4);
    float tail = (step(-drop, q.y) * step(q.y, -1.0)) * step(abs(q.x), 0.790000021457672119140625 * (q.y + drop));
    float pin = fast::max(head, tail);
    float2 a = q - gaze;
    float2 param_5 = a;
    float2 param_6 = float2(3.4500000476837158203125, fast::min(3.400000095367431640625, h));
    float hole = dialOval(param_5, param_6);
    float2 param_7 = a - float2(-1.0, 1.0);
    float2 param_8 = float2(0.5);
    float glint = 0.699999988079071044921875 * scPixelBox(param_7, param_8);
    float ink = (pin * (0.85000002384185791015625 + (0.1500000059604644775390625 * step(-1.0, q.y)))) * (1.0 - (hole * (1.0 - glint)));
    if ((mode == 5.0) && (side > 0.0))
    {
        float2 param_9 = a;
        float2 param_10 = float2(1.39999997615814208984375, 0.5);
        float2 param_11 = a;
        float2 param_12 = float2(0.5, 1.39999997615814208984375);
        float crossMark = fast::max(scPixelBox(param_9, param_10), scPixelBox(param_11, param_12));
        ink = fast::max(ink, ((0.930000007152557373046875 * focus) * crossMark) * hole);
        float2 param_13 = q + float2(0.0, 12.0);
        float2 param_14 = float2(2.0, 0.5);
        ink = fast::max(ink, (0.64999997615814208984375 * focus) * scPixelBox(param_13, param_14));
    }
    if (mode == 6.0)
    {
        float2 ping = p - float2(20.0 * side, 4.0);
        ink = fast::max(ink, (0.689999997615814208984375 * step(0.519999980926513671875, turn * side)) * step(abs((abs(ping.x) + abs(ping.y)) - 2.0), 0.5));
    }
    return ink;
}

static inline __attribute__((always_inline))
float dialSweep(thread const float2& p, thread const float& mode, thread const float2& gaze, thread const float& lid, thread const float& focus, thread const float& turn, thread const float& t)
{
    float2 q = p - float2(0.0, 3.0);
    float x = abs(q.x);
    float hi = 5.0 - floor((fast::max(x - 17.0, 0.0) * 0.5) + 0.25);
    float lo = ((-5.0) + floor((fast::max(x - 17.0, 0.0) * 0.5) + 0.25)) + step(x, 2.0);
    bool _1723 = x > 23.0;
    bool _1731;
    if (!_1723)
    {
        _1731 = q.y < lo;
    }
    else
    {
        _1731 = _1723;
    }
    bool _1739;
    if (!_1731)
    {
        _1739 = q.y > hi;
    }
    else
    {
        _1739 = _1731;
    }
    if (_1739)
    {
        return 0.0;
    }
    float top = step(hi - 0.89999997615814208984375, q.y);
    float bottom = step(q.y, lo + 0.89999997615814208984375);
    float caps = step(21.5, x);
    float rim = fast::max(0.930000007152557373046875 * top, fast::max(0.62000000476837158203125 * bottom, 0.819999992847442626953125 * caps));
    float side = (q.x < 0.0) ? (-1.0) : 1.0;
    float2 a = (q - float2(9.0 * side, 0.0)) - gaze;
    if ((mode == 1.0) && (side > 0.0))
    {
        a.y -= 1.0;
    }
    if (lid < 0.100000001490116119384765625)
    {
        float2 param = a;
        float param_1 = 3.0;
        float param_2 = 0.550000011920928955078125;
        return fast::max(((mode == 4.0) ? 0.37999999523162841796875 : 0.75) * rim, 0.7799999713897705078125 * dialArc(param, param_1, param_2));
    }
    float _1817;
    if (mode == 6.0)
    {
        float param_3 = 18.0 * turn;
        _1817 = dialRound(param_3);
    }
    else
    {
        float _1828;
        if (mode == 5.0)
        {
            float param_4 = 12.0 * (1.0 - focus);
            _1828 = dialRound(param_4);
        }
        else
        {
            float _1839;
            if (mode == 2.0)
            {
                _1839 = -12.0;
            }
            else
            {
                _1839 = floor(38.0 * fract(t / 5.75)) - 19.0;
            }
            _1828 = _1839;
        }
        _1817 = _1828;
    }
    float scan = _1817;
    float offset = scan - (q.x + floor(q.y * 0.4799999892711639404296875));
    float trail = (step(0.0, offset) * step(offset, 2.0)) * (1.0 - (0.300000011920928955078125 * offset));
    float _1882;
    if (mode == 6.0)
    {
        _1882 = 0.660000026226043701171875;
    }
    else
    {
        _1882 = (mode == 5.0) ? 0.37000000476837158203125 : 0.20000000298023223876953125;
    }
    float ink = fast::max(rim, trail * _1882);
    float _1898;
    if (mode == 7.0)
    {
        _1898 = 2.0;
    }
    else
    {
        float _1907;
        if ((mode == 2.0) && (side > 0.0))
        {
            _1907 = 1.5499999523162841796875;
        }
        else
        {
            _1907 = ((mode == 1.0) && (side > 0.0)) ? 3.25 : 2.7999999523162841796875;
        }
        _1898 = _1907;
    }
    float h = _1898;
    float2 param_5 = a;
    float2 param_6 = float2(3.0, fast::max(0.699999988079071044921875, h * lid));
    float pupil = dialOval(param_5, param_6);
    float2 param_7 = a - float2(-1.0, 1.0);
    float2 param_8 = float2(0.5);
    pupil *= (1.0 - (0.839999973773956298828125 * scPixelBox(param_7, param_8)));
    if (mode == 5.0)
    {
        float2 b = abs(q) - float2(2.0);
        float2 param_9 = b + float2(1.0, 0.0);
        float2 param_10 = float2(1.0, 0.5);
        float2 param_11 = b + float2(0.0, 1.0);
        float2 param_12 = float2(0.5, 1.0);
        float target = fast::max(scPixelBox(param_9, param_10), scPixelBox(param_11, param_12));
        ink = fast::max(ink, (0.85000002384185791015625 * focus) * target);
    }
    if (mode == 7.0)
    {
        float2 speed = float2(x - 17.0, q.y + 1.0);
        float2 param_13 = speed;
        float2 param_14 = float2(1.5, 0.5);
        ink = fast::max(ink, 0.560000002384185791015625 * scPixelBox(param_13, param_14));
    }
    return fast::max(ink, pupil);
}

static inline __attribute__((always_inline))
float dialMouth(thread const float2& p, thread const float& mode, thread const float& t, thread const float& style)
{
    float2 m = p - float2(0.0, -8.0);
    if (mode == 4.0)
    {
        float2 param = m;
        float2 param_1 = float2((style == 1.0) ? 2.0 : 1.0, 0.5);
        return 0.63999998569488525390625 * scPixelBox(param, param_1);
    }
    if (mode == 3.0)
    {
        float beat = 1.0 - abs((2.0 * fract((t * 2.599999904632568359375) + (0.07999999821186065673828125 * style))) - 1.0);
        float h = 1.0 + floor(3.0 * beat);
        float w = (style == 2.0) ? 4.0 : 3.0;
        float2 param_2 = m;
        float2 param_3 = float2(w + 0.60000002384185791015625, h + 0.5);
        float outer = dialOval(param_2, param_3);
        float _1035;
        if (h > 1.5)
        {
            float2 param_4 = m - float2(0.0, 1.0);
            float2 param_5 = float2(w - 1.0, fast::max(0.89999997615814208984375, h - 1.0));
            _1035 = dialOval(param_4, param_5);
        }
        else
        {
            _1035 = 0.0;
        }
        float hollow = _1035;
        return outer * (1.0 - (0.87999999523162841796875 * hollow));
    }
    if (mode == 2.0)
    {
        m.x -= 2.0;
        float y = floor((0.2700000107288360595703125 * m.x) + 0.5);
        float2 param_6 = float2(m.x, m.y - y);
        float2 param_7 = float2(3.0, 0.5);
        return 0.910000026226043701171875 * scPixelBox(param_6, param_7);
    }
    if (mode == 5.0)
    {
        float x = abs(m.x);
        float y_1 = step(2.0, m.x);
        return step(x, 3.0) * step(abs(m.y - y_1), 0.5);
    }
    bool _1111 = mode == 1.0;
    bool _1120;
    if (!_1111)
    {
        _1120 = (mode == 6.0) && (style == 1.0);
    }
    else
    {
        _1120 = _1111;
    }
    if (_1120)
    {
        float2 r = select(float2(2.7799999713897705078125, 2.650000095367431640625), float2(2.7200000286102294921875, 2.4500000476837158203125), bool2(mode == 1.0));
        float2 param_8 = m;
        float2 param_9 = r;
        float2 param_10 = m;
        float2 param_11 = float2(1.519999980926513671875);
        return dialOval(param_8, param_9) * (1.0 - (0.9700000286102294921875 * dialOval(param_10, param_11)));
    }
    float width = (style == 3.0) ? 3.0 : 4.0;
    if (mode == 7.0)
    {
        width += 1.0;
    }
    float y_2 = floor(((0.104999996721744537353515625 * m.x) * m.x) + 0.5);
    bool _1172 = style == 2.0;
    bool _1178;
    if (_1172)
    {
        _1178 = m.x > 1.0;
    }
    else
    {
        _1178 = _1172;
    }
    if (_1178)
    {
        y_2 += 1.0;
    }
    return step(abs(m.x), width) * step(abs((m.y - y_2) + 0.5), 0.550000011920928955078125);
}

static inline __attribute__((always_inline))
float scoutDialInk(thread const float2& cell, thread const float& mode, thread const float& age, thread const float2& look, thread const float& style)
{
    float2 p = floor(cell) - float2(31.0, 24.0);
    bool _2001 = abs(p.x) > 26.0;
    bool _2008;
    if (!_2001)
    {
        _2008 = p.y < (-12.0);
    }
    else
    {
        _2008 = _2001;
    }
    bool _2015;
    if (!_2008)
    {
        _2015 = p.y > 12.0;
    }
    else
    {
        _2015 = _2008;
    }
    if (_2015)
    {
        return 0.0;
    }
    float t = fast::max(0.0, age);
    float _2025;
    if (mode == 6.0)
    {
        float param = t;
        float _2030 = dialSearch(param);
        _2025 = _2030;
    }
    else
    {
        _2025 = 0.0;
    }
    float turn = _2025;
    float blink = abs(mod((t + 0.670000016689300537109375) + (0.310000002384185791015625 * style), 5.349999904632568359375) - 0.180000007152557373046875);
    float _2047;
    if (mode == 4.0)
    {
        _2047 = 0.0;
    }
    else
    {
        float _2054;
        if (blink < 0.05200000107288360595703125)
        {
            _2054 = 0.0;
        }
        else
        {
            _2054 = (blink < 0.115000002086162567138671875) ? 0.449999988079071044921875 : 1.0;
        }
        _2047 = _2054;
    }
    float lid = _2047;
    float2 point = fast::clamp(look, float2(-1.0), float2(1.0));
    float focus = smoothstep(0.2199999988079071044921875, 0.689999997615814208984375, fract(t / 3.2000000476837158203125));
    float2 gaze = floor((point * float2(2.0, 1.0)) + float2(0.5));
    if (mode == 0.0)
    {
        gaze.x += (step(0.64999997615814208984375, fract(t / 6.69999980926513671875)) - step(0.769999980926513671875, fract(t / 6.69999980926513671875)));
    }
    if (mode == 2.0)
    {
        float param_1 = point.x + (2.0 * (1.0 - (2.0 * step(0.5, fract(t / 4.0)))));
        gaze = float2(dialRound(param_1), 1.0);
    }
    if (mode == 5.0)
    {
        float param_2 = ((1.0 - focus) * 2.0) + (point.x * 0.5);
        gaze = float2(dialRound(param_2), 0.0);
    }
    if (mode == 6.0)
    {
        float param_3 = (2.0 * turn) + (0.5 * point.x);
        float param_4 = 0.5 * point.y;
        gaze = float2(dialRound(param_3), dialRound(param_4));
    }
    if (mode == 7.0)
    {
        float param_5 = 1.0 + point.x;
        gaze = float2(dialRound(param_5), -1.0);
    }
    if (mode == 4.0)
    {
        gaze = float2(0.0);
    }
    gaze = fast::clamp(gaze, float2(-2.0, -1.0), float2(2.0, 1.0));
    float _2170;
    if (style < 1.5)
    {
        float2 param_6 = p;
        float param_7 = mode;
        float2 param_8 = gaze;
        float param_9 = lid;
        float param_10 = focus;
        float param_11 = turn;
        _2170 = dialBinocular(param_6, param_7, param_8, param_9, param_10, param_11);
    }
    else
    {
        float _2190;
        if (style < 2.5)
        {
            float2 param_12 = p;
            float param_13 = mode;
            float2 param_14 = gaze;
            float param_15 = lid;
            float param_16 = focus;
            float param_17 = turn;
            _2190 = dialWaypoint(param_12, param_13, param_14, param_15, param_16, param_17);
        }
        else
        {
            float2 param_18 = p;
            float param_19 = mode;
            float2 param_20 = gaze;
            float param_21 = lid;
            float param_22 = focus;
            float param_23 = turn;
            float param_24 = t;
            _2190 = dialSweep(param_18, param_19, param_20, param_21, param_22, param_23, param_24);
        }
        _2170 = _2190;
    }
    float ink = _2170;
    float2 param_25 = p;
    float param_26 = mode;
    float param_27 = t;
    float param_28 = style;
    return fast::max(ink, dialMouth(param_25, param_26, param_27, param_28));
}

static inline __attribute__((always_inline))
float scoutLcdInk(thread const float2& cell, thread const float& age, thread const float2& look, constant NativeUniforms& U)
{
    if (true)
    {
        float2 param = cell;
        float param_1 = U.pose.z;
        float param_2 = age;
        float2 param_3 = look;
        return scoutOriginalInk(param, param_1, param_2, param_3);
    }
    if (false)
    {
        float2 param_4 = cell;
        float param_5 = U.pose.z;
        float param_6 = age;
        float2 param_7 = look;
        float3 marks = scoutFriendlyMarks(param_4, param_5, param_6, param_7);
        return fast::max(0.87999999523162841796875 * marks.x, fast::max(marks.y, 0.449999988079071044921875 * marks.z));
    }
    float2 param_8 = cell;
    float param_9 = U.pose.z;
    float param_10 = age;
    float2 param_11 = look;
    float param_12 = 0.0;
    return scoutDialInk(param_8, param_9, param_10, param_11, param_12);
}

static inline __attribute__((always_inline))
float scoutSmileDistance(thread const float2& p, thread const float& mode)
{
    float radius = (mode == 7.0) ? 3.7000000476837158203125 : 3.0;
    float2 q = float2(abs(p.x), (p.y + 11.6499996185302734375) - radius);
    float2 tip = float2(0.930000007152557373046875, -0.3680000007152557373046875) * radius;
    float _961;
    if (dot(q, float2(0.3680000007152557373046875, 0.930000007152557373046875)) > 0.0)
    {
        _961 = length(q - tip);
    }
    else
    {
        _961 = abs(length(q) - radius);
    }
    return _961;
}

static inline __attribute__((always_inline))
float3 scLCD(thread const float3& p, thread const float3& v, thread const float& mode, thread const float& age, thread const float2& look, constant NativeUniforms& U)
{
    float2 s = p.xy - float2(0.0, 0.1550000011920928955078125);
    float2 inner = s - ((v.xy * 0.0089999996125698089599609375) / float2(fast::max(v.z, 0.2700000107288360595703125)));
    float2 g = (inner / float2(0.014499999582767486572265625)) + float2(32.0, 24.0);
    float2 h = fast::clamp((float2(0.17000000178813934326171875, 0.1599999964237213134765625) * (500.0 / fast::max(1.0, U.viewport.y))) / float2(fast::max(v.z, 0.439999997615814208984375), 1.0), float2(0.054999999701976776123046875), float2(0.4699999988079071044921875));
    float param = (g.x + h.x) + 0.0425000004470348358154296875;
    float param_1 = (g.x - h.x) + 0.0425000004470348358154296875;
    float param_2 = (g.y + h.y) + 0.0425000004470348358154296875;
    float param_3 = (g.y - h.y) + 0.0425000004470348358154296875;
    float2 gaps = float2(scGridInt(param) - scGridInt(param_1), scGridInt(param_2) - scGridInt(param_3)) / (h * 2.0);
    float aperture = (1.0 - gaps.x) * (1.0 - gaps.y);
    float3 ff = reflect(-v, fast::normalize(float3(s.x * 0.540000021457672119140625, s.y * 0.839999973773956298828125, 1.0)));
    float card = 0.0089999996125698089599609375 + (0.0489999987185001373291015625 * smoothstep(0.119999997317790985107421875, 0.87000000476837158203125, ff.y - (0.12999999523162841796875 * ff.x)));
    float3 param_4 = ff;
    float3 glass = (float3(0.010599999688565731048583984375, 0.01219999976456165313720703125, 0.01620000042021274566650390625) * (0.939999997615814208984375 + (0.0599999986588954925537109375 * aperture))) + (scEnv(param_4) * card);
    float2 cell = floor(g);
    float2 offset = fract(g) - float2(0.5);
    bool _6155 = abs(cell.x - 31.0) > 29.0;
    bool _6164;
    if (!_6155)
    {
        _6164 = abs(cell.y - 24.0) > 18.0;
    }
    else
    {
        _6164 = _6155;
    }
    if (_6164)
    {
        return glass;
    }
    float direct = 0.0;
    float scatter = 0.0;
    for (int y = -2; y <= 2; y++)
    {
        for (int x = -2; x <= 2; x++)
        {
            float2 tap = float2(float(x), float(y));
            float2 delta = tap - offset;
            float r2 = dot(delta, delta);
            if (r2 < 4.80000019073486328125)
            {
                float2 param_5 = cell + tap;
                float param_6 = age;
                float2 param_7 = look;
                float ink = scoutLcdInk(param_5, param_6, param_7, U);
                float2 cover = fast::clamp(((float2(0.5) + h) - abs(delta)) / (h * 2.0), float2(0.0), float2(1.0));
                direct += ((ink * cover.x) * cover.y);
                scatter += ((ink * exp2((-1.13999998569488525390625) * r2)) * (1.0 - smoothstep(3.0, 4.80000019073486328125, r2)));
            }
        }
    }
    float2 glyph = g - float2(31.5, 24.5);
    bool _6280;
    if (true)
    {
        bool _6265 = U.pose.z == 0.0;
        bool _6272;
        if (!_6265)
        {
            _6272 = U.pose.z == 6.0;
        }
        else
        {
            _6272 = _6265;
        }
        bool _6279;
        if (!_6272)
        {
            _6279 = U.pose.z == 7.0;
        }
        else
        {
            _6279 = _6272;
        }
        _6280 = _6279;
    }
    else
    {
        _6280 = true;
    }
    bool _6287;
    if (_6280)
    {
        _6287 = abs(glyph.x) < 7.0;
    }
    else
    {
        _6287 = _6280;
    }
    bool _6293;
    if (_6287)
    {
        _6293 = glyph.y < (-6.0);
    }
    else
    {
        _6293 = _6287;
    }
    if (_6293)
    {
        float2 param_8 = glyph;
        float param_9 = U.pose.z;
        float d = scoutSmileDistance(param_8, param_9);
        float aa = fast::max(0.119999997317790985107421875, 0.7799999713897705078125 * fast::max(h.x, h.y));
        direct = fast::max(direct, 1.0 - smoothstep(0.38999998569488525390625 - aa, 0.38999998569488525390625 + aa, d));
        scatter += exp2(((-1.62999999523162841796875) * d) * d);
    }
    float emission = ((0.88999998569488525390625 + (0.10999999940395355224609375 * aperture)) * direct) + ((0.041000001132488250732421875 * scatter) * (1.0 - (0.64999997615814208984375 * direct)));
    emission *= ((U.pose.z == 4.0) ? 0.680000007152557373046875 : 1.0);
    return glass + (float3(0.9900000095367431640625, 0.688000023365020751953125, 0.296999990940093994140625) * emission);
}

static inline __attribute__((always_inline))
float liftLampGain(thread float& kitLift)
{
    return smoothstep(0.7400000095367431640625, 0.9700000286102294921875, kitLift);
}

static inline __attribute__((always_inline))
float scBrush(thread const float3& p, constant NativeUniforms& U)
{
    float a = ((p.y * 1270.0) + (p.z * 156.0)) + (0.800000011920928955078125 * sin((p.z * 82.0) + (p.x * 18.0)));
    float micro = ((0.36000001430511474609375 * sin(a)) + (0.23000000417232513427734375 * sin((a * 0.638000011444091796875) + 0.699999988079071044921875))) + (0.12999999523162841796875 * sin((a * 1.36399996280670166015625) + (p.z * 9.0)));
    float fine = fast::clamp((U.viewport.y - 280.0) / 650.0, 0.07999999821186065673828125, 0.85000002384185791015625);
    return ((fine * micro) + (0.20000000298023223876953125 * sin((p.y * 108.0) + (p.z * 9.0)))) + (0.119999997317790985107421875 * sin((p.y * 171.0) + (0.5 * sin(p.x * 47.0))));
}

static inline __attribute__((always_inline))
float3 hwAxis(thread const float& style)
{
    if (style < 1.5)
    {
        return float3(0.08737452328205108642578125, -0.22329044342041015625, 0.97082805633544921875);
    }
    if (style < 2.5)
    {
        return float3(0.0, -0.17715299129486083984375, 0.98418331146240234375);
    }
    return float3(0.0446349270641803741455078125, -0.119026474654674530029296875, 0.9918873310089111328125);
}

static inline __attribute__((always_inline))
float3 headOrigin(thread const float& style, thread const float& side)
{
    if (style < 1.5)
    {
        return float3(side * 0.4329999983310699462890625, -0.203999996185302734375, 0.734000027179718017578125);
    }
    if (style < 2.5)
    {
        return float3(side * 0.23700000345706939697265625, 0.509000003337860107421875, 0.5360000133514404296875);
    }
    return float3(side * 0.736000001430511474609375, 0.08200000226497650146484375, 0.614000022411346435546875);
}

static inline __attribute__((always_inline))
float3 hwPartFrame(thread const float3& p, thread const float& style)
{
    float param = style;
    float3 a = hwAxis(param);
    float3 ex = fast::normalize(float3(a.z, 0.0, -a.x));
    float3 ey = cross(a, ex);
    float param_1 = style;
    float param_2 = 1.0;
    float3 origin = headOrigin(param_1, param_2);
    if ((style > 1.5) && (style < 2.5))
    {
        origin.x = 0.0;
    }
    float3 q = p - origin;
    return float3(dot(q, ex), dot(q, ey), dot(q, a));
}

static inline __attribute__((always_inline))
float hwLine(thread const float& d, thread const float& radius)
{
    return 1.0 - smoothstep(radius, radius + 0.0040000001899898052215576171875, abs(d));
}

static inline __attribute__((always_inline))
float hwSpot(thread const float2& p, thread const float2& center, thread const float2& radii)
{
    float2 a = (p - center) / radii;
    return exp(-dot(a, a));
}

static inline __attribute__((always_inline))
float3 headFinish(thread const float3& p, thread const float3& n, thread const float3& v, thread const float& id, thread const float& style, thread const float& power)
{
    float3 m = float3(abs(p.x), p.yz);
    float3 param = select(m, p, bool3((style > 1.5) && (style < 2.5)));
    float param_1 = style;
    float3 q = hwPartFrame(param, param_1);
    float3 _6501;
    if ((style > 1.5) && (style < 2.5))
    {
        _6501 = v;
    }
    else
    {
        _6501 = float3(v.x * ((p.x < 0.0) ? (-1.0) : 1.0), v.yz);
    }
    float3 vm = _6501;
    float param_2 = style;
    float3 a = hwAxis(param_2);
    float3 ex = fast::normalize(float3(a.z, 0.0, -a.x));
    float3 ey = cross(a, ex);
    float3 eye = float3(dot(vm, ex), dot(vm, ey), dot(vm, a));
    float light = fast::max(0.0, dot(n, float3(-0.411974132061004638671875, 0.727013170719146728515625, 0.549298822879791259765625)));
    float3 param_3 = reflect(-v, n);
    float3 reflected = scEnv(param_3);
    float rim = powr(1.0 - fast::clamp(dot(n, v), 0.0, 1.0), 3.0);
    float3 dark = (float3(0.0379999987781047821044921875, 0.0489999987185001373291015625, 0.0579999983310699462890625) * (0.569999992847442626953125 + (0.7200000286102294921875 * light))) + (reflected * (0.07400000095367431640625 + (0.085000000894069671630859375 * rim)));
    float3 nickel = (float3(0.090999998152256011962890625, 0.097999997437000274658203125, 0.101000003516674041748046875) * (0.63999998569488525390625 + (0.4799999892711639404296875 * light))) + (reflected * float3(0.61000001430511474609375, 0.660000026226043701171875, 0.699999988079071044921875));
    if (id < 20.5)
    {
        float param_4 = q.z + 0.0670000016689300537109375;
        float param_5 = 0.00200000009499490261077880859375;
        float param_6 = q.z + 0.090999998152256011962890625;
        float param_7 = 0.00200000009499490261077880859375;
        float fin = hwLine(param_4, param_5) + hwLine(param_6, param_7);
        return dark * (1.0 - (0.37000000476837158203125 * fast::clamp(fin, 0.0, 1.0)));
    }
    if (id < 21.5)
    {
        float2 lug = float2(abs(q.x) - 0.083999998867511749267578125, abs(q.y) - 0.07299999892711639404296875);
        float stud = 1.0 - smoothstep(0.004999999888241291046142578125, 0.008000000379979610443115234375, length(lug));
        return mix(nickel, dark * 0.670000016689300537109375, float3(stud));
    }
    if (id < 22.5)
    {
        float2 d = q.xy / float2(0.10300000011920928955078125);
        float2 parallax = d - ((eye.xy * 0.17000000178813934326171875) / float2(fast::max(eye.z, 0.319999992847442626953125)));
        float r = length(d);
        float b = length(parallax);
        float groove = sin((parallax.x * 27.0) + ((1.7000000476837158203125 * parallax.y) * parallax.y));
        float flank = smoothstep(-0.660000026226043701171875, 0.839999973773956298828125, groove);
        float ridge = powr(fast::max(0.0, groove), 8.0);
        float bowl = (0.180000007152557373046875 + (0.4600000083446502685546875 * (1.0 - smoothstep(0.180000007152557373046875, 1.16999995708465576171875, b)))) + (0.300000011920928955078125 * flank);
        float param_8 = r - 0.88999998569488525390625;
        float param_9 = 0.01200000010430812835693359375;
        float ring = hwLine(param_8, param_9);
        float3 cold = (float3(0.180000007152557373046875, 0.115999996662139892578125, 0.0599999986588954925537109375) * (0.310000002384185791015625 + (0.88999998569488525390625 * bowl))) + (reflected * ((0.119999997317790985107421875 + (0.189999997615814208984375 * ridge)) + (0.17000000178813934326171875 * rim)));
        cold += (float3(0.1040000021457672119140625, 0.07299999892711639404296875, 0.037000000476837158203125) * ring);
        float2 param_10 = parallax;
        float2 param_11 = float2(0.0, -0.070000000298023223876953125);
        float2 param_12 = float2(0.3300000131130218505859375, 0.14000000059604644775390625);
        float filament = hwSpot(param_10, param_11, param_12);
        float hot = ((0.23999999463558197021484375 + (0.689999997615814208984375 * bowl)) + (0.14000000059604644775390625 * ridge)) * (1.0 - (0.2800000011920928955078125 * smoothstep(0.790000021457672119140625, 1.0, r)));
        return cold + (((float3(1.36000001430511474609375, 0.68599998950958251953125, 0.24400000274181365966796875) * hot) + (float3(0.800000011920928955078125, 0.709999978542327880859375, 0.540000021457672119140625) * filament)) * power);
    }
    if (id < 23.5)
    {
        return (dark * 0.800000011920928955078125) + (nickel * 0.180000007152557373046875);
    }
    if (id < 24.5)
    {
        bool _6777 = eye.z > 0.0;
        bool _6784;
        if (_6777)
        {
            _6784 = q.z > (-0.007000000216066837310791015625);
        }
        else
        {
            _6784 = _6777;
        }
        if (_6784)
        {
            float2 screw = float2(abs(q.x) - 0.490999996662139892578125, q.y);
            float param_13 = length(screw) - 0.00999999977648258209228515625;
            float param_14 = 0.00200000009499490261077880859375;
            return mix(dark, nickel * 0.540000021457672119140625, float3(hwLine(param_13, param_14)));
        }
        float param_15 = q.z + 0.0379999987781047821044921875;
        float param_16 = 0.00200000009499490261077880859375;
        float param_17 = q.z + 0.06800000369548797607421875;
        float param_18 = 0.00200000009499490261077880859375;
        float fin_1 = hwLine(param_15, param_16) + hwLine(param_17, param_18);
        return dark * (1.0 - (0.3400000035762786865234375 * fast::clamp(fin_1, 0.0, 1.0)));
    }
    if (id < 25.5)
    {
        float cell = fract((q.x + 0.4639999866485595703125) / 0.115999996662139892578125) - 0.5;
        float seam = smoothstep(0.4050000011920928955078125, 0.4939999878406524658203125, abs(cell));
        float y = q.y / 0.02999999932944774627685546875;
        float optic = 1.0 - smoothstep(0.119999997317790985107421875, 1.07000005245208740234375, length(float2(cell * 1.39999997615814208984375, y * 0.800000011920928955078125)));
        float crease = 0.5 + (0.5 * cos((cell * 21.0) + (y * 1.5)));
        float guide = exp(((-12.0) * (y + 0.0500000007450580596923828125)) * (y + 0.0500000007450580596923828125));
        float3 cold_1 = mix(float3(0.0529999993741512298583984375, 0.0719999969005584716796875, 0.086000002920627593994140625), float3(0.17200000584125518798828125, 0.2150000035762786865234375, 0.240999996662139892578125), float3((0.7200000286102294921875 * optic) + (0.2199999988079071044921875 * crease)));
        cold_1 += (reflected * (0.12999999523162841796875 + (0.2199999988079071044921875 * rim)));
        float3 lit = float3(0.769999980926513671875, 0.959999978542327880859375, 1.14999997615814208984375) * (((0.310000002384185791015625 + (0.550000011920928955078125 * optic)) + (0.17000000178813934326171875 * guide)) + (0.100000001490116119384765625 * crease));
        return mix(cold_1 + (lit * power), (dark + float3(0.026000000536441802978515625)) + (float3(0.23999999463558197021484375, 0.310000002384185791015625, 0.37000000476837158203125) * power), float3(seam * 0.88999998569488525390625));
    }
    if (id < 26.5)
    {
        float front = smoothstep(-0.0199999995529651641845703125, 0.0240000002086162567138671875, q.z);
        float2 screw_1 = abs(q.xy) - float2(0.097999997437000274658203125, 0.078000001609325408935546875);
        float socket = 1.0 - smoothstep(0.006000000052154064178466796875, 0.010999999940395355224609375, length(screw_1));
        float param_19 = length(screw_1) - 0.00999999977648258209228515625;
        float param_20 = 0.001000000047497451305389404296875;
        float flash = hwLine(param_19, param_20);
        float param_21 = q.z + 0.0570000000298023223876953125;
        float param_22 = 0.0030000000260770320892333984375;
        float param_23 = q.z + 0.08900000154972076416015625;
        float param_24 = 0.0030000000260770320892333984375;
        float param_25 = q.z + 0.119999997317790985107421875;
        float param_26 = 0.0030000000260770320892333984375;
        float rib = (hwLine(param_21, param_22) + hwLine(param_23, param_24)) + hwLine(param_25, param_26);
        float3 parkerized = (dark * float3(0.86000001430511474609375, 0.930000007152557373046875, 1.03999996185302734375)) * (1.0 - (0.36000001430511474609375 * fast::clamp(rib, 0.0, 1.0)));
        return mix(parkerized, float3(0.01899999938905239105224609375) + ((nickel * 0.23000000417232513427734375) * flash), float3(front * socket));
    }
    if (id < 27.5)
    {
        return nickel * float3(0.4699999988079071044921875, 0.560000002384185791015625, 0.62999999523162841796875);
    }
    float2 d_1 = q.xy / float2(0.06800000369548797607421875);
    float2 pupil = d_1 - ((eye.xy * 0.23999999463558197021484375) / float2(fast::max(eye.z, 0.3300000131130218505859375)));
    float r_1 = length(d_1);
    float pr = length(pupil);
    float pupilCore = exp(((-3.7000000476837158203125) * pr) * pr);
    float ring_1 = exp(((-120.0) * (pr - 0.60000002384185791015625)) * (pr - 0.60000002384185791015625));
    float2 param_27 = d_1;
    float2 param_28 = float2(-0.319999992847442626953125, 0.36000001430511474609375);
    float2 param_29 = float2(0.23000000417232513427734375, 0.115000002086162567138671875);
    float glint = hwSpot(param_27, param_28, param_29);
    float3 cold_2 = float3(0.01899999938905239105224609375, 0.0439999997615814208984375, 0.061999998986721038818359375) + (reflected * (0.14000000059604644775390625 + (0.439999997615814208984375 * rim)));
    cold_2 += ((float3(0.039999999105930328369140625, 0.083999998867511749267578125, 0.115000002086162567138671875) * ring_1) + (float3(0.180000007152557373046875, 0.2599999904632568359375, 0.300000011920928955078125) * glint));
    return cold_2 + (((float3(1.67999994754791259765625, 1.940000057220458984375, 2.099999904632568359375) * pupilCore) + ((float3(0.2800000011920928955078125, 0.5299999713897705078125, 0.670000016689300537109375) * (0.319999992847442626953125 + (0.589999973773956298828125 * ring_1))) * (1.0 - smoothstep(0.790000021457672119140625, 1.0, r_1)))) * power);
}

static inline __attribute__((always_inline))
float3 liftLampSurface(thread const float3& p, thread const float3& n, thread const float3& view, thread const float& id, thread const float& power, thread float& kitLift, constant NativeUniforms& U)
{
    float key = fast::max(0.0, dot(n, float3(-0.411974132061004638671875, 0.727013170719146728515625, 0.549298822879791259765625)));
    float3 param = reflect(-view, n);
    float3 env = scEnv(param);
    if (id == 47.0)
    {
        float3 param_1 = p;
        float brush = scBrush(param_1, U);
        return ((float3(0.21699999272823333740234375, 0.2430000007152557373046875, 0.2599999904632568359375) * (0.60000002384185791015625 + (0.689999997615814208984375 * key))) + ((float3(0.579999983310699462890625, 0.62000000476837158203125, 0.660000026226043701171875) * env) * (0.790000021457672119140625 + (0.07500000298023223876953125 * brush)))) + (float3(0.02199999988079071044921875, 0.02099999971687793731689453125, 0.0199999995529651641845703125) * (0.5 + brush));
    }
    if (id < 41.5)
    {
        float2 sc = liftSinCos(kitLift);
        float2 d = p.yz - float2(0.4709999859333038330078125, 0.27799999713897705078125);
        float u = dot(d, sc);
        float w = dot(d, float2(-sc.y, sc.x));
        float param_2 = 2.0;
        float3 a = hwAxis(param_2);
        float3 virtualPoint = float3(p.x, (float2(0.509000003337860107421875, 0.5360000133514404296875) + (float2(a.z, -a.y) * (u - 0.07400000095367431640625))) + (a.yz * (3.0 * (w - 0.0315000005066394805908203125))));
        float3 param_3 = virtualPoint;
        float3 param_4 = n;
        float3 param_5 = view;
        float param_6 = (id < 40.5) ? 24.0 : 25.0;
        float param_7 = 2.0;
        float param_8 = power;
        return headFinish(param_3, param_4, param_5, param_6, param_7, param_8);
    }
    float rim = powr(1.0 - fast::clamp(dot(n, view), 0.0, 1.0), 3.0);
    if (id == 43.0)
    {
        return (float3(0.02899999916553497314453125, 0.0350000001490116119384765625, 0.039999999105930328369140625) * (0.7200000286102294921875 + (0.4000000059604644775390625 * key))) + (env * (0.039999999105930328369140625 + (0.039999999105930328369140625 * rim)));
    }
    if (id == 45.0)
    {
        return (float3(0.14000000059604644775390625, 0.157000005245208740234375, 0.17299999296665191650390625) * (0.540000021457672119140625 + (0.4799999892711639404296875 * key))) + (env * float3(0.319999992847442626953125, 0.37000000476837158203125, 0.4199999868869781494140625));
    }
    return (float3(0.064999997615814208984375, 0.07400000095367431640625, 0.07999999821186065673828125) * (0.62999999523162841796875 + (0.4799999892711639404296875 * key))) + (env * (0.1599999964237213134765625 + (0.064999997615814208984375 * rim)));
}

static inline __attribute__((always_inline))
float kitPaintCard(thread const float3& ray, thread const float3& direction, thread const float2& size, thread const float& softness)
{
    float3 across = fast::normalize(float3(direction.z, 0.0, -direction.x));
    float3 up = cross(direction, across);
    float depth = dot(ray, direction);
    float2 edge = (size * depth) - abs(float2(dot(ray, across), dot(ray, up)));
    return smoothstep(-softness, softness, fast::min(edge.x, edge.y));
}

static inline __attribute__((always_inline))
float kitPaintPanel(thread const float3& p, thread const float3& ray, thread const float3& center, thread const float2& size, thread const float& softness)
{
    float3 direction = fast::normalize(center);
    float3 across = fast::normalize(float3(direction.z, 0.0, -direction.x));
    float aim = dot(ray, direction);
    float3 hit = (p + (ray * (dot(center - p, direction) / fast::max(0.0500000007450580596923828125, aim)))) - center;
    float2 edge = size - abs(float2(dot(hit, across), dot(hit, cross(direction, across))));
    return smoothstep(0.0500000007450580596923828125, 0.2199999988079071044921875, aim) * smoothstep(-softness, softness, fast::min(edge.x, edge.y));
}

static inline __attribute__((always_inline))
float kitPaintHash(thread float3& cell)
{
    cell = fract(cell * float3(0.103100001811981201171875, 0.113689996302127838134765625, 0.13786999881267547607421875));
    cell += float3(dot(cell, cell.yzx + float3(19.1900005340576171875)));
    return fract((cell.x + cell.y) * cell.z);
}

static inline __attribute__((always_inline))
float kitPaintRelief(thread const float3& p, thread const float& key, thread const float3& environment, thread const float3& stock, constant NativeUniforms& U)
{
    float3 param = p;
    float brush = scBrush(param, U);
    float3 titanium = (float3(0.21699999272823333740234375, 0.2430000007152557373046875, 0.2599999904632568359375) * (0.60000002384185791015625 + (0.689999997615814208984375 * key))) + ((float3(0.579999983310699462890625, 0.62000000476837158203125, 0.660000026226043701171875) * environment) * (0.790000021457672119140625 + (0.07500000298023223876953125 * brush)));
    titanium = (titanium * (0.7599999904632568359375 + (0.23999999463558197021484375 * smoothstep(-0.20999999344348907470703125, 0.0, p.y)))) + (float3(0.02199999988079071044921875, 0.02099999971687793731689453125, 0.0199999995529651641845703125) * (0.5 + brush));
    float3 lum = float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875);
    return fast::clamp(dot(stock, lum) / fast::max(0.02500000037252902984619140625, dot(titanium, lum)), 0.100000001490116119384765625, 1.2999999523162841796875);
}

static inline __attribute__((always_inline))
float3 kitPaintFinish(thread const float3& p, thread const float3& n, thread const float3& v, thread const float& id, thread const float3& stock, thread const float& paint, thread bool& scoutRoofHit, constant NativeUniforms& U)
{
    bool _7732 = scoutRoofHit || (paint < 0.5);
    bool _7741;
    if (!_7732)
    {
        _7741 = (id != 1.0) && (id != 47.0);
    }
    else
    {
        _7741 = _7732;
    }
    if (_7741)
    {
        return stock;
    }
    bool shell = id == 1.0;
    bool ivory = (paint > 1.5) && (paint < 2.5);
    bool blue = paint >= 2.5;
    float3 reflection = reflect(-v, n);
    float3 param = reflection;
    float3 environment = scEnv(param);
    float key = fast::max(dot(n, float3(-0.411974132061004638671875, 0.727013170719146728515625, 0.549298822879791259765625)), 0.0);
    float facing = fast::clamp(dot(n, v), 0.0, 1.0);
    float edge = 1.0 - facing;
    float diffuse = (((0.37999999523162841796875 + (0.14000000059604644775390625 * ((n.y * 0.5) + 0.5))) + (0.63999998569488525390625 * key)) + (0.064999997615814208984375 * fast::max(dot(n, float3(0.654892385005950927734375, 0.3929354250431060791015625, -0.64553678035736083984375)), 0.0))) * (0.87000000476837158203125 + (0.12999999523162841796875 * smoothstep(-0.20999999344348907470703125, 0.039999999105930328369140625, p.y)));
    diffuse *= mix(ivory ? 0.939999997615814208984375 : 0.7200000286102294921875, 1.0, smoothstep(-0.1599999964237213134765625, 0.430000007152557373046875, p.y));
    float3 _7814;
    if (ivory)
    {
        _7814 = float3(0.8849999904632568359375, 0.80400002002716064453125, 0.638000011444091796875);
    }
    else
    {
        _7814 = select(float3(0.7400000095367431640625, 0.014999999664723873138427734375, 0.017999999225139617919921875), float3(0.0089999996125698089599609375, 0.064999997615814208984375, 0.540000021457672119140625), bool3(blue));
    }
    float3 pigment = _7814;
    float _7829;
    if (ivory)
    {
        _7829 = 0.14200000464916229248046875;
    }
    else
    {
        _7829 = blue ? 0.0570000000298023223876953125 : 0.03599999845027923583984375;
    }
    float rough = _7829;
    float3 param_1 = reflection;
    float3 param_2 = float3(-0.711458265781402587890625, 0.58998978137969970703125, 0.38175809383392333984375);
    float2 param_3 = float2(0.560000002384185791015625, 0.2199999988079071044921875);
    float param_4 = rough;
    float first = kitPaintCard(param_1, param_2, param_3, param_4);
    float3 param_5 = p;
    float3 param_6 = reflection;
    float3 param_7 = float3(-0.7799999713897705078125, 1.40999996662139892578125, -2.2400000095367431640625);
    float2 param_8 = float2(0.800000011920928955078125, 0.1599999964237213134765625);
    float param_9 = rough * 3.7999999523162841796875;
    float rail = kitPaintPanel(param_5, param_6, param_7, param_8, param_9);
    float3 param_10 = p;
    float3 param_11 = reflection;
    float3 param_12 = float3(1.9500000476837158203125, -0.17000000178813934326171875, -1.90999996662139892578125);
    float2 param_13 = float2(0.5, 0.5099999904632568359375);
    float param_14 = 0.1500000059604644775390625 + (rough * 8.0);
    float side = kitPaintPanel(param_10, param_11, param_12, param_13, param_14);
    float3 param_15 = p;
    float3 param_16 = reflection;
    float3 param_17 = float3(2.25, 0.0599999986588954925537109375, 1.53999996185302734375);
    float2 param_18 = float2(0.2899999916553497314453125, 0.810000002384185791015625);
    float param_19 = 0.0350000001490116119384765625 + (rough * 3.599999904632568359375);
    float shoulder = kitPaintPanel(param_15, param_16, param_17, param_18, param_19);
    float3 cards = (float3(1.0, 0.930000007152557373046875, 0.86000001430511474609375) * ((1.059999942779541015625 * first) + (2.2200000286102294921875 * shoulder))) + (float3(0.89999997615814208984375, 0.959999978542327880859375, 1.0) * ((0.7599999904632568359375 * rail) + (0.300000011920928955078125 * side)));
    float fresnel = (((edge * edge) * edge) * edge) * edge;
    float _7933;
    if (ivory)
    {
        _7933 = 0.034000001847743988037109375;
    }
    else
    {
        _7933 = blue ? 0.056000001728534698486328125 : 0.0670000016689300537109375;
    }
    float3 spec = ((environment * 0.89999997615814208984375) + (cards * 3.650000095367431640625)) * _7933;
    spec += ((((environment * 0.680000007152557373046875) + (cards * 1.2999999523162841796875)) * fresnel) * (ivory ? 0.25 : 0.730000019073486328125));
    float3 coat = (pigment * diffuse) + spec;
    if (blue)
    {
        float3 cells = p * 68.0;
        float3 delta = fract(cells) - float3(0.5);
        float3 param_20 = floor(cells);
        float _7976 = kitPaintHash(param_20);
        float seed = _7976;
        float flake = (1.0 - smoothstep(0.119999997317790985107421875, 0.4900000095367431640625, length(delta))) * smoothstep(0.4600000083446502685546875, 0.920000016689300537109375, seed);
        float lod = fast::clamp((U.viewport.y - 140.0) / 540.0, 0.02500000037252902984619140625, 0.920000016689300537109375) * (0.300000011920928955078125 + (0.699999988079071044921875 * facing));
        float blueSheen = ((0.36000001430511474609375 * environment.z) + (0.23999999463558197021484375 * (first + side))) + (0.430000007152557373046875 * rail);
        coat += ((float3(0.01200000010430812835693359375, 0.064000003039836883544921875, 0.1870000064373016357421875) * blueSheen) + (((float3(0.100000001490116119384765625, 0.2599999904632568359375, 0.430000007152557373046875) * flake) * lod) * (0.10999999940395355224609375 + blueSheen)));
    }
    if (ivory && shell)
    {
        float2 param_21 = float2(p.z + 0.056000001728534698486328125, p.y - 0.10300000011920928955078125);
        float2 param_22 = float2(0.23700000345706939697265625, 0.097999997437000274658203125);
        float param_23 = 0.02199999988079071044921875;
        float grille = scRect(param_21, param_22, param_23);
        float inset = smoothstep(0.63999998569488525390625, 0.87999999523162841796875, abs(n.x)) * (1.0 - smoothstep(-0.0030000000260770320892333984375, 0.00200000009499490261077880859375, grille));
        coat = mix(coat, (float3(0.08699999749660491943359375, 0.10300000011920928955078125, 0.10999999940395355224609375) * (0.60000002384185791015625 + (0.5 * key))) + (spec * 0.75), float3(inset));
        float tab = (((1.0 - smoothstep(0.01600000075995922088623046875, 0.0199999995529651641845703125, abs(p.x - 0.5429999828338623046875))) * smoothstep(0.26800000667572021484375, 0.273999989032745361328125, p.z)) * (1.0 - smoothstep(0.5030000209808349609375, 0.510999977588653564453125, p.z))) * smoothstep(0.333000004291534423828125, 0.34700000286102294921875, p.y);
        coat = mix(coat, (float3(0.9049999713897705078125, 0.1550000011920928955078125, 0.017999999225139617919921875) * diffuse) + spec, float3(tab));
    }
    if (shell)
    {
        float3 param_24 = p;
        float param_25 = key;
        float3 param_26 = environment;
        float3 param_27 = stock;
        float relief = kitPaintRelief(param_24, param_25, param_26, param_27, U);
        coat *= fast::min(1.0, relief);
        coat = mix(coat, float3(0.01400000043213367462158203125, 0.017999999225139617919921875, 0.02300000004470348358154296875) * (0.689999997615814208984375 + (0.36000001430511474609375 * key)), float3(0.550000011920928955078125 * smoothstep(0.560000002384185791015625, 0.769999980926513671875, 1.0 - relief)));
        coat += (float3(0.0949999988079071044921875, 0.1019999980926513671875, 0.10300000011920928955078125) * fast::max(relief - 1.0, 0.0));
        float marking = smoothstep(0.10999999940395355224609375, 0.37999999523162841796875, stock.x - stock.y) * smoothstep(1.32000005245208740234375, 2.349999904632568359375, stock.x / fast::max(0.014999999664723873138427734375, stock.y));
        coat = mix(coat, stock, float3(marking));
    }
    return coat;
}

static inline __attribute__((always_inline))
float scDash(thread const float& d, thread const float& w)
{
    return 1.0 - smoothstep(w, w + 0.0040000001899898052215576171875, abs(d));
}

static inline __attribute__((always_inline))
float3 scKitChassisFinish(thread const float3& p, thread const float3& n, thread const float3& v, thread const float& id, thread const float3& metal, thread const float3& env, thread const float& key, thread float& scKitRoll, thread float2& scKitYawCS)
{
    float wx = abs(p.x) - 0.653999984264373779296875;
    float2 w = float2(p.y + 0.47200000286102294921875, abs(p.z) - 0.4309999942779541015625);
    float r = length(w);
    float3 param = p;
    float param_1 = precise::atan2(w.x, w.y);
    float a = scKitWheelAngle(param, param_1, scKitRoll);
    if (id == 10.0)
    {
        float3 param_2 = p;
        float3 param_3 = scKitDishPoint(param_2, scKitYawCS);
        float3 d = scKitBowlLocal(param_3);
        float rad = length(d.xy);
        bool inside = d.z > ((0.939999997615814208984375 * rad) * rad);
        float param_4 = rad - 0.171000003814697265625;
        float param_5 = 0.00200000009499490261077880859375;
        float rolled = scDash(param_4, param_5);
        float param_6 = rad - 0.107000000774860382080078125;
        float param_7 = 0.001000000047497451305389404296875;
        float grain = scDash(param_6, param_7);
        if (inside)
        {
            return ((metal * float3(1.0750000476837158203125, 1.03499996662139892578125, 0.959999978542327880859375)) * ((0.9900000095367431640625 - (0.119999997317790985107421875 * rolled)) - (0.04500000178813934326171875 * grain))) + (env * 0.02999999932944774627685546875);
        }
        float ribs = 0.5 + (0.5 * cos(3.0 * precise::atan2(d.y, d.x)));
        float spine = smoothstep(0.967999994754791259765625, 0.999000012874603271484375, ribs) * smoothstep(0.032999999821186065673828125, 0.07999999821186065673828125, rad);
        return (metal * float3(0.769999980926513671875, 0.839999973773956298828125, 0.86000001430511474609375)) * (0.839999973773956298828125 + (0.180000007152557373046875 * spine));
    }
    if (id == 11.0)
    {
        float3 graphite = (float3(0.068999998271465301513671875, 0.085000000894069671630859375, 0.092000000178813934326171875) * (0.64999997615814208984375 + (0.4199999868869781494140625 * key))) + (env * 0.104999996721744537353515625);
        bool _4576 = (p.y < (-0.17000000178813934326171875)) && (wx < (-0.134000003337860107421875));
        bool _4584;
        if (_4576)
        {
            _4584 = abs(n.x) > 0.61000001430511474609375;
        }
        else
        {
            _4584 = _4576;
        }
        if (_4584)
        {
            float param_8 = r - 0.05900000035762786865234375;
            float param_9 = 0.0035000001080334186553955078125;
            graphite *= (1.0 - (0.37999999523162841796875 * scDash(param_8, param_9)));
        }
        return graphite;
    }
    if (id == 12.0)
    {
        float3 hub = (float3(0.0320000015199184417724609375, 0.0390000008046627044677734375, 0.0439999997615814208984375) * (0.709999978542327880859375 + (0.4699999988079071044921875 * key))) + (fast::min(env, float3(1.10000002384185791015625)) * 0.04500000178813934326171875);
        if (abs(n.x) > 0.540000021457672119140625)
        {
            float param_10 = r - 0.1360000073909759521484375;
            float param_11 = 0.0024999999441206455230712890625;
            hub *= (1.0 - (0.20999999344348907470703125 * scDash(param_10, param_11)));
            float param_12 = r - 0.14000000059604644775390625;
            float param_13 = 0.00209999992512166500091552734375;
            hub += (float3(0.007000000216066837310791015625) * scDash(param_12, param_13));
        }
        return hub;
    }
    if (id == 13.0)
    {
        return (float3(0.0570000000298023223876953125, 0.07500000298023223876953125, 0.083999998867511749267578125) * (0.699999988079071044921875 + (0.519999980926513671875 * key))) + (env * 0.112999998033046722412109375);
    }
    if (id == 14.0)
    {
        float param_14 = abs(p.x) - 0.486000001430511474609375;
        float param_15 = 0.0035000001080334186553955078125;
        float seat = scDash(param_14, param_15);
        return ((float3(0.02500000037252902984619140625, 0.0309999994933605194091796875, 0.034000001847743988037109375) * (0.7599999904632568359375 + (0.430000007152557373046875 * key))) * (1.0 - (0.1599999964237213134765625 * seat))) + (fast::min(env, float3(1.10000002384185791015625)) * 0.02300000004470348358154296875);
    }
    if (id == 16.0)
    {
        float facing = fast::clamp(dot(n, v), 0.0, 1.0);
        float param_16 = p.y + 0.2750000059604644775390625;
        float param_17 = 0.0024999999441206455230712890625;
        float seam = scDash(param_16, param_17) * (1.0 - abs(n.y));
        float3 carbon = (float3(0.00999999977648258209228515625, 0.0130000002682209014892578125, 0.014999999664723873138427734375) * (0.769999980926513671875 + (0.4900000095367431640625 * key))) + (fast::min(env, float3(1.08000004291534423828125)) * 0.01899999938905239105224609375);
        return (carbon * (1.0 - (0.20000000298023223876953125 * seam))) + (float3(0.00999999977648258209228515625, 0.01200000010430812835693359375, 0.0130000002682209014892578125) * powr(1.0 - facing, 4.0));
    }
    return (float3(0.790000021457672119140625, 0.18199999630451202392578125, 0.02899999916553497314453125) * (0.7200000286102294921875 + (0.4699999988079071044921875 * key))) + (env * 0.0949999988079071044921875);
}

static inline __attribute__((always_inline))
float scTick(thread const float& d)
{
    return 1.0 - smoothstep(0.001000000047497451305389404296875, 0.006000000052154064178466796875, abs(d));
}

static inline __attribute__((always_inline))
float roofWord(thread const float& column, thread const float& mode)
{
    float4 letters;
    float last;
    if (mode == 0.0)
    {
        letters = float4(23275.0, 29391.0, 23530.0, 15211.0);
        last = 9389.0;
    }
    else
    {
        if (mode == 1.0)
        {
            letters = float4(29257.0, 29847.0, 31183.0, 9367.0);
            last = 24573.0;
        }
        else
        {
            if (mode == 2.0)
            {
                letters = float4(9367.0, 23533.0, 29847.0, 24573.0);
                last = 23277.0;
            }
            else
            {
                if (mode == 3.0)
                {
                    letters = float4(31183.0, 4843.0, 29391.0, 23530.0);
                    last = 23277.0;
                }
                else
                {
                    if (mode == 4.0)
                    {
                        letters = float4(31183.0, 29257.0, 29391.0, 29391.0);
                        last = 4843.0;
                    }
                    else
                    {
                        if (mode == 5.0)
                        {
                            letters = float4(9367.0, 31599.0, 31599.0, 29257.0);
                            last = 31183.0;
                        }
                        else
                        {
                            if (mode == 6.0)
                            {
                                letters = float4(31183.0, 29263.0, 23530.0, 24573.0);
                                last = 0.0;
                            }
                            else
                            {
                                letters = float4(15211.0, 23275.0, 29847.0, 11117.0);
                                last = 29391.0;
                            }
                        }
                    }
                }
            }
        }
    }
    if (column < 1.0)
    {
        return letters.x;
    }
    if (column < 2.0)
    {
        return letters.y;
    }
    if (column < 3.0)
    {
        return letters.z;
    }
    if (column < 4.0)
    {
        return letters.w;
    }
    return last;
}

static inline __attribute__((always_inline))
float3 roofNavigation(thread const float2& s, thread const float3& v, constant NativeUniforms& U)
{
    float2 param = s;
    float2 param_1 = float2(0.351000010967254638671875, 0.21699999272823333740234375);
    float param_2 = 0.0390000008046627044677734375;
    float bezel = scRect(param, param_1, param_2);
    if (bezel > (-0.0089999996125698089599609375))
    {
        return float3(0.0949999988079071044921875, 0.100000001490116119384765625, 0.1040000021457672119140625);
    }
    if (bezel > (-0.01899999938905239105224609375))
    {
        return float3(0.02199999988079071044921875, 0.02300000004470348358154296875, 0.0240000002086162567138671875);
    }
    float2 q = float2(-s.x, s.y);
    float2 cell = floor((float2(q.x, -q.y) - float2(-0.2939999997615814208984375, -0.17599999904632568359375)) / float2(0.02099999971687793731689453125));
    float light = 0.0;
    bool _4896 = cell.x >= 0.0;
    bool _4902;
    if (_4896)
    {
        _4902 = cell.x < 19.0;
    }
    else
    {
        _4902 = _4896;
    }
    bool _4908;
    if (_4902)
    {
        _4908 = cell.y >= 0.0;
    }
    else
    {
        _4908 = _4902;
    }
    bool _4914;
    if (_4908)
    {
        _4914 = cell.y < 5.0;
    }
    else
    {
        _4914 = _4908;
    }
    bool _4921;
    if (_4914)
    {
        _4921 = mod(cell.x, 4.0) < 3.0;
    }
    else
    {
        _4921 = _4914;
    }
    if (_4921)
    {
        float param_3 = floor(cell.x / 4.0);
        float param_4 = U.pose.z;
        light = mod(floor(roofWord(param_3, param_4) / exp2(mod(cell.x, 4.0) + (3.0 * cell.y))), 2.0);
    }
    float2 map = q - float2(-0.06599999964237213134765625, -0.082999996840953826904296875);
    bool _4954 = abs(map.x) < 0.2240000069141387939453125;
    bool _4961;
    if (_4954)
    {
        _4961 = abs(map.y) < 0.082999996840953826904296875;
    }
    else
    {
        _4961 = _4954;
    }
    if (_4961)
    {
        float2 grid = abs(fract((map / float2(0.0540000014007091522216796875)) + float2(0.5)) - float2(0.5));
        light = fast::max(light, 0.05200000107288360595703125 * (1.0 - smoothstep(0.0199999995529651641845703125, 0.12999999523162841796875, fast::min(grid.x, grid.y))));
        float route = (0.02700000070035457611083984375 * sin(17.0 * map.x)) + (0.01400000043213367462158203125 * sin(36.0 * map.x));
        float _5001;
        if (U.pose.z == 7.0)
        {
            _5001 = (-0.1599999964237213134765625) + (0.319999992847442626953125 * fract(U.options.x / 3.2000000476837158203125));
        }
        else
        {
            _5001 = 0.08699999749660491943359375;
        }
        float x = _5001;
        float2 marker = map - float2(x, (0.02700000070035457611083984375 * sin(17.0 * x)) + (0.01400000043213367462158203125 * sin(36.0 * x)));
        light = fast::max(light, fast::max(0.430000007152557373046875 * (1.0 - smoothstep(0.00200000009499490261077880859375, 0.007000000216066837310791015625, abs(map.y - route))), 1.0 - smoothstep(0.010999999940395355224609375, 0.01899999938905239105224609375, length(marker))));
    }
    float2 b = abs(q - float2(0.23000000417232513427734375, 0.1270000040531158447265625));
    float frame = fast::max(b.x - 0.05900000035762786865234375, b.y - 0.0309999994933605194091796875);
    light = fast::max(light, 0.63999998569488525390625 * (1.0 - smoothstep(0.00200000009499490261077880859375, 0.006000000052154064178466796875, abs(frame))));
    bool _5068 = b.x < 0.0460000000894069671630859375;
    bool _5074;
    if (_5068)
    {
        _5074 = b.y < 0.017999999225139617919921875;
    }
    else
    {
        _5074 = _5068;
    }
    if (_5074)
    {
        light = fast::max(light, 0.86000001430511474609375 * step(0.25, fract((q.x - 0.17000000178813934326171875) / 0.02999999932944774627685546875)));
    }
    return (float3(0.0089999996125698089599609375, 0.01200000010430812835693359375, 0.014999999664723873138427734375) + float3(0.0170000009238719940185546875 * powr(1.0 - abs(v.y), 2.0))) + (float3(0.9900000095367431640625, 0.688000023365020751953125, 0.296999990940093994140625) * light);
}

static inline __attribute__((always_inline))
float3 scHousing(thread const float3& p, thread const float3& n, thread const float3& v, thread const float& id, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread bool& scoutRoofHit, constant NativeUniforms& U)
{
    float3 light = float3(-0.411974132061004638671875, 0.727013170719146728515625, 0.549298822879791259765625);
    float key = fast::max(dot(n, light), 0.0);
    float facing = fast::clamp(dot(n, v), 0.0, 1.0);
    float3 ref = reflect(-v, n);
    float3 param = ref;
    float3 env = scEnv(param);
    float3 param_1 = p;
    float brush = scBrush(param_1, U);
    float ao = 0.7599999904632568359375 + (0.23999999463558197021484375 * smoothstep(-0.20999999344348907470703125, 0.0, p.y));
    float3 metal = ((float3(0.21699999272823333740234375, 0.2430000007152557373046875, 0.2599999904632568359375) * (0.60000002384185791015625 + (0.689999997615814208984375 * key))) + ((float3(0.579999983310699462890625, 0.62000000476837158203125, 0.660000026226043701171875) * env) * (0.790000021457672119140625 + (0.07500000298023223876953125 * brush)))) * ao;
    metal += (float3(0.02199999988079071044921875, 0.02099999971687793731689453125, 0.0199999995529651641845703125) * (0.5 + brush));
    if (scKitOn && (id >= 10.0))
    {
        float3 param_2 = p;
        float3 param_3 = n;
        float3 param_4 = v;
        float param_5 = id;
        float3 param_6 = metal;
        float3 param_7 = env;
        float param_8 = key;
        return scKitChassisFinish(param_2, param_3, param_4, param_5, param_6, param_7, param_8, scKitRoll, scKitYawCS);
    }
    if (id < 1.5)
    {
        if (abs(n.x) > 0.60000002384185791015625)
        {
            float2 s = float2(p.z, p.y);
            float2 param_9 = s - float2(-0.017999999225139617919921875, 0.138999998569488525390625);
            float2 param_10 = float2(0.3120000064373016357421875, 0.20499999821186065673828125);
            float param_11 = 0.0460000000894069671630859375;
            float panel = scRect(param_9, param_10, param_11);
            float param_12 = panel;
            float param_13 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.4199999868869781494140625 * scDash(param_12, param_13)));
            bool _5221 = s.x < 0.18899999558925628662109375;
            bool _5228;
            if (_5221)
            {
                _5228 = s.x > (-0.2899999916553497314453125);
            }
            else
            {
                _5228 = _5221;
            }
            bool _5235;
            if (_5228)
            {
                _5235 = s.y > (-0.0030000000260770320892333984375);
            }
            else
            {
                _5235 = _5228;
            }
            bool _5241;
            if (_5235)
            {
                _5241 = s.y < 0.20999999344348907470703125;
            }
            else
            {
                _5241 = _5235;
            }
            if (_5241)
            {
                float k = floor(((s.x + 0.2290000021457672119140625) / 0.076999999582767486572265625) + 0.5);
                float2 l = s - float2((-0.2290000021457672119140625) + (k * 0.076999999582767486572265625), 0.092000000178813934326171875);
                l.x += (0.3300000131130218505859375 * l.y);
                float2 param_14 = l;
                float2 param_15 = float2(0.01400000043213367462158203125, 0.07299999892711639404296875);
                float param_16 = 0.01200000010430812835693359375;
                float hole = scRect(param_14, param_15, param_16);
                metal *= (1.0 - (0.7599999904632568359375 * (1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, hole))));
                float param_17 = hole - 0.007000000216066837310791015625;
                metal += (float3(0.0810000002384185791015625) * scTick(param_17));
            }
            float2 badge = s - float2(0.10300000011920928955078125, 0.2759999930858612060546875);
            float2 param_18 = badge;
            float2 param_19 = float2(0.104999996721744537353515625, 0.0170000009238719940185546875);
            float param_20 = 0.007000000216066837310791015625;
            float mark = scRect(param_18, param_19, param_20);
            metal = mix(metal, float3(0.7599999904632568359375, 0.134000003337860107421875, 0.02300000004470348358154296875) * (0.60000002384185791015625 + (0.449999988079071044921875 * key)), float3(1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, mark)));
        }
        if (n.y > 0.75)
        {
            float2 s_1 = float2(p.x, p.z + 0.0949999988079071044921875);
            s_1.x -= 0.097999997437000274658203125;
            float2 param_21 = s_1;
            float2 param_22 = float2(0.351000010967254638671875, 0.21699999272823333740234375);
            float param_23 = 0.0390000008046627044677734375;
            if (scRect(param_21, param_22, param_23) < 0.0)
            {
                scoutRoofHit = true;
                float2 param_24 = s_1;
                float3 param_25 = v;
                return roofNavigation(param_24, param_25, U);
            }
            float2 screw = float2(abs(p.x) - 0.48500001430511474609375, abs(p.z + 0.004999999888241291046142578125) - 0.305000007152557373046875);
            float rad = length(screw);
            float param_26 = rad - 0.02199999988079071044921875;
            float param_27 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.569999992847442626953125 * scDash(param_26, param_27)));
            float param_28 = screw.x + (0.5 * screw.y);
            float param_29 = 0.00200000009499490261077880859375;
            metal *= (1.0 - ((0.62000000476837158203125 * scDash(param_28, param_29)) * (1.0 - smoothstep(0.01400000043213367462158203125, 0.017999999225139617919921875, rad))));
        }
        if (n.z < (-0.64999997615814208984375))
        {
            float2 s_2 = p.xy - float2(0.0, 0.1459999978542327880859375);
            float2 param_30 = s_2;
            float2 param_31 = float2(0.4650000035762786865234375, 0.20900000631809234619140625);
            float param_32 = 0.05200000107288360595703125;
            float door = scRect(param_30, param_31, param_32);
            float param_33 = door;
            float param_34 = 0.0030000000260770320892333984375;
            metal *= (1.0 - (0.5099999904632568359375 * scDash(param_33, param_34)));
            bool _5428 = abs(s_2.x) < 0.2989999949932098388671875;
            bool _5436;
            if (_5428)
            {
                _5436 = abs(s_2.y) < 0.13099999725818634033203125;
            }
            else
            {
                _5436 = _5428;
            }
            if (_5436)
            {
                float2 uv = s_2 - float2(0.0, 0.01600000075995922088623046875);
                float line = floor(((uv.y + 0.083999998867511749267578125) / 0.0430000014603137969970703125) + 0.5);
                float2 param_35 = uv - float2(0.0, (-0.083999998867511749267578125) + (0.0430000014603137969970703125 * line));
                float2 param_36 = float2(0.2610000073909759521484375, 0.0089999996125698089599609375);
                float param_37 = 0.006000000052154064178466796875;
                float vent = scRect(param_35, param_36, param_37);
                metal *= (1.0 - (0.689999997615814208984375 * (1.0 - smoothstep(-0.00200000009499490261077880859375, 0.00200000009499490261077880859375, vent))));
            }
            float2 tailLamp = s_2 - float2(sign(s_2.x) * 0.3689999878406524658203125, -0.14699999988079071044921875);
            float2 param_38 = tailLamp;
            float2 param_39 = float2(0.034000001847743988037109375, 0.01200000010430812835693359375);
            float param_40 = 0.006000000052154064178466796875;
            float tape = scRect(param_38, param_39, param_40);
            metal = mix(metal, float3(0.7799999713897705078125, 0.125, 0.0350000001490116119384765625), float3(1.0 - smoothstep(-0.001000000047497451305389404296875, 0.0030000000260770320892333984375, tape)));
            float2 screw_1 = abs(s_2) - float2(0.3919999897480010986328125, 0.14200000464916229248046875);
            float r = length(screw_1);
            float param_41 = r - 0.02199999988079071044921875;
            float param_42 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.4799999892711639404296875 * scDash(param_41, param_42)));
            float param_43 = screw_1.x - screw_1.y;
            float param_44 = 0.00200000009499490261077880859375;
            metal *= (1.0 - ((0.540000021457672119140625 * scDash(param_43, param_44)) * (1.0 - smoothstep(0.01200000010430812835693359375, 0.0170000009238719940185546875, r))));
        }
        return metal;
    }
    if (id < 2.5)
    {
        float2 s_3 = p.xy - float2(0.0, 0.1550000011920928955078125);
        float2 param_45 = s_3;
        float2 param_46 = float2(0.5490000247955322265625, 0.24199999868869781494140625);
        float param_47 = 0.0610000006854534149169921875;
        float trim = scRect(param_45, param_46, param_47);
        float3 frame = (float3(0.041000001132488250732421875, 0.05200000107288360595703125, 0.064999997615814208984375) * (0.60000002384185791015625 + (0.430000007152557373046875 * key))) + (env * 0.07999999821186065673828125);
        if (n.z > 0.449999988079071044921875)
        {
            float param_48 = trim;
            float param_49 = 0.00150000001303851604461669921875;
            frame += (float3(0.063000001013278961181640625, 0.0570000000298023223876953125, 0.046999998390674591064453125) * scDash(param_48, param_49));
            float2 bolt = abs(s_3) - float2(0.532000005245208740234375, 0.2150000035762786865234375);
            float r_1 = length(bolt);
            frame = mix(frame, metal * 0.62000000476837158203125, float3(1.0 - smoothstep(0.01200000010430812835693359375, 0.0170000009238719940185546875, r_1)));
        }
        return frame;
    }
    if (id < 3.5)
    {
        return float3(0.0240000002086162567138671875, 0.034000001847743988037109375, 0.0379999987781047821044921875) + (env * 0.180000007152557373046875);
    }
    if (id < 4.5)
    {
        float2 w = float2(p.y + 0.47200000286102294921875, abs(p.z) - 0.4309999942779541015625);
        float r_2 = length(w);
        float3 param_50 = p;
        float param_51 = precise::atan2(w.x, w.y);
        float a = scKitWheelAngle(param_50, param_51, scKitRoll);
        float rim = abs(p.x) - 0.653999984264373779296875;
        float striation = 0.540000021457672119140625 + (0.4600000083446502685546875 * cos((24.0 * a) + (4.400000095367431640625 * abs(rim / 0.14499999582767486572265625))));
        float3 color = (float3(0.02099999971687793731689453125, 0.026000000536441802978515625, 0.02899999916553497314453125) * (0.800000011920928955078125 + (0.589999973773956298828125 * key))) + (float3(0.0170000009238719940185546875) * env);
        color *= (0.88999998569488525390625 + (0.10999999940395355224609375 * striation));
        if (rim > 0.0949999988079071044921875)
        {
            float param_52 = r_2 - 0.21199999749660491943359375;
            float param_53 = 0.0040000001899898052215576171875;
            color *= (1.0 - (0.2800000011920928955078125 * scDash(param_52, param_53)));
            float param_54 = r_2 - 0.2339999973773956298828125;
            float param_55 = 0.001000000047497451305389404296875;
            color += (float3(0.00999999977648258209228515625) * scDash(param_54, param_55));
            if (scKitOn)
            {
                float dotMark = length((float2(cos(a - 0.810000002384185791015625), sin(a - 0.810000002384185791015625)) * r_2) - float2(0.2199999988079071044921875, 0.0));
                color = mix(color, float3(0.4000000059604644775390625, 0.3039999902248382568359375, 0.1689999997615814208984375) * (0.62000000476837158203125 + (0.449999988079071044921875 * key)), float3(1.0 - smoothstep(0.0089999996125698089599609375, 0.0130000002682209014892578125, dotMark)));
            }
        }
        if (scKitOn)
        {
            float shoulder = (smoothstep(-0.098999999463558197021484375, -0.0579999983310699462890625, rim) * (1.0 - smoothstep(0.071000002324581146240234375, 0.101000003516674041748046875, rim))) * smoothstep(0.2579999864101409912109375, 0.282000005245208740234375, r_2);
            float stripe = ((a + (0.119999997317790985107421875 * abs(rim / 0.14499999582767486572265625))) - 0.5099999904632568359375) - ((p.x < 0.0) ? 0.560000002384185791015625 : 0.0);
            float witness = 1.0 - smoothstep(0.0320000015199184417724609375, 0.064999997615814208984375, abs(sin(0.5 * stripe)));
            float wear = 1.0 - smoothstep(0.026000000536441802978515625, 0.0610000006854534149169921875, abs(sin(0.5 * (stripe + 1.90999996662139892578125))));
            color = mix(color, float3(0.1319999992847442626953125, 0.1369999945163726806640625, 0.11900000274181365966796875) * (0.660000026226043701171875 + (0.4600000083446502685546875 * key)), float3((shoulder * witness) * 0.7799999713897705078125));
            color = mix(color, float3(0.068999998271465301513671875, 0.076999999582767486572265625, 0.076999999582767486572265625) * (0.63999998569488525390625 + (0.449999988079071044921875 * key)), float3((shoulder * wear) * 0.62999999523162841796875));
        }
        return color;
    }
    if (id < 5.5)
    {
        bool _5800 = abs(p.x) > 0.709999978542327880859375;
        bool _5807;
        if (_5800)
        {
            _5807 = p.y < (-0.180000007152557373046875);
        }
        else
        {
            _5807 = _5800;
        }
        if (_5807)
        {
            float2 w_1 = float2(p.y + 0.47200000286102294921875, abs(p.z) - 0.4309999942779541015625);
            float r_3 = length(w_1);
            float3 param_56 = p;
            float param_57 = precise::atan2(w_1.x, w_1.y);
            float a_1 = scKitWheelAngle(param_56, param_57, scKitRoll);
            float holes = length(float2(r_3 - 0.1040000021457672119140625, sin(a_1 * 3.0) * 0.115000002086162567138671875)) - 0.01899999938905239105224609375;
            metal = mix(metal, float3(0.034000001847743988037109375, 0.039999999105930328369140625, 0.041000001132488250732421875), float3(1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, holes)));
            float param_58 = r_3 - 0.14200000464916229248046875;
            float param_59 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.3400000035762786865234375 * scDash(param_58, param_59)));
            if (scKitOn)
            {
                float index = (1.0 - smoothstep(0.0130000002682209014892578125, 0.0170000009238719940185546875, abs(r_3 - 0.115999996662139892578125))) * smoothstep(0.927999973297119140625, 0.97399997711181640625, cos(a_1 - 0.819999992847442626953125));
                metal = mix(metal, (float3(0.920000016689300537109375, 0.20900000631809234619140625, 0.0350000001490116119384765625) * (0.7200000286102294921875 + (0.5 * key))) + (env * 0.0599999986588954925537109375), float3(index));
            }
        }
        return metal * 0.85000002384185791015625;
    }
    if (id < 6.5)
    {
        return (metal * 0.5) + float3(0.0240000002086162567138671875);
    }
    if (id < 7.5)
    {
        return (float3(0.1019999980926513671875, 0.120999999344348907470703125, 0.1360000073909759521484375) * (0.589999973773956298828125 + (0.670000016689300537109375 * key))) + (env * 0.2599999904632568359375);
    }
    if (id < 8.5)
    {
        return (float3(0.02999999932944774627685546875, 0.0390000008046627044677734375, 0.046999998390674591064453125) * (0.62999999523162841796875 + (0.519999980926513671875 * key))) + (env * 0.0599999986588954925537109375);
    }
    if (id < 9.5)
    {
        return (float3(0.907000005245208740234375, 0.12399999797344207763671875, 0.0130000002682209014892578125) * (0.560000002384185791015625 + (0.660000026226043701171875 * key))) + (env * 0.07400000095367431640625);
    }
    return (metal * float3(1.08000004291534423828125, 1.0, 0.87999999523162841796875)) + (float3(0.054999999701976776123046875) * powr(1.0 - facing, 3.0));
}

static inline __attribute__((always_inline))
float3 pcHousing(thread const float2& uv, thread const float& mode, thread const float& age, thread const float& t, thread const float2& orbit, thread const float2& look, thread float& objectCoverage, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread float& scKitSweepMask, thread bool& scoutRoofHit, thread float& kitLift, thread float& galleryHingeMask, thread float& galleryDriveMode, thread bool& galleryFloorOnly, thread bool& pipGlassHit, constant NativeUniforms& U)
{
    float2 param = uv;
    float2 param_1 = orbit;
    float3 param_2;
    float3 param_3;
    scCamera(param, param_1, param_2, param_3, U);
    float3 ro = param_2;
    float3 rd = param_3;
    if (galleryFloorOnly)
    {
        float2 param_4 = uv;
        float3 param_5 = ro;
        float3 param_6 = rd;
        float param_7 = age;
        float3 _8428 = galleryMiss(param_4, param_5, param_6, param_7, objectCoverage);
        return _8428;
    }
    float3 param_8 = ro;
    float3 param_9 = rd;
    scKitConstrainRay(param_8, param_9, scKitOn, scKitRoll, scKitYawCS, scKitSweepMask);
    float3 param_10 = ro - float3(0.0, 0.522000014781951904296875, 0.3459999859333038330078125);
    float3 param_11 = rd;
    float3 param_12 = float3(0.5230000019073486328125, 0.10300000011920928955078125, 0.087999999523162841796875);
    float2 window = scKitRange(param_10, param_11, param_12);
    galleryHingeMask = (window.x < window.y) ? 0.699999988079071044921875 : 0.0;
    float _8454;
    if (galleryHingeMask > 0.5)
    {
        float param_13 = galleryDriveMode;
        float param_14 = age;
        _8454 = galleryLift(param_13, param_14);
    }
    else
    {
        _8454 = 1.0;
    }
    kitLift = _8454;
    float c = dot(ro, rd);
    float disc = ((c * c) - dot(ro, ro)) + 1.50062501430511474609375;
    if (disc < 0.0)
    {
        float2 param_15 = uv;
        float3 param_16 = ro;
        float3 param_17 = rd;
        float param_18 = age;
        float3 _8490 = galleryMiss(param_15, param_16, param_17, param_18, objectCoverage);
        return _8490;
    }
    float d = (-c) - sqrt(disc);
    float farD = (-c) + sqrt(disc);
    float2 h = float2(1.0);
    for (int i = 0; i < 83; i++)
    {
        float3 param_19 = ro + (rd * d);
        h = galleryBody(param_19, scKitOn, scKitRoll, scKitYawCS, kitLift);
        if ((h.x < 0.000720000010915100574493408203125) || (d > farD))
        {
            break;
        }
        d += fast::max(0.0004900000058114528656005859375, h.x * 0.699999988079071044921875);
    }
    bool _8544 = d > farD;
    bool _8551;
    if (!_8544)
    {
        _8551 = h.x > 0.00209999992512166500091552734375;
    }
    else
    {
        _8551 = _8544;
    }
    if (_8551)
    {
        float2 param_20 = uv;
        float3 param_21 = ro;
        float3 param_22 = rd;
        float param_23 = age;
        float3 _8562 = galleryMiss(param_20, param_21, param_22, param_23, objectCoverage);
        return _8562;
    }
    float3 p = ro + (rd * d);
    float3 param_24 = p;
    float3 n = galleryNormal(param_24, scKitOn, scKitRoll, scKitYawCS, kitLift);
    float3 v = -rd;
    bool _8579 = h.y == 3.0;
    bool _8585;
    if (_8579)
    {
        _8585 = n.z > 0.939999997615814208984375;
    }
    else
    {
        _8585 = _8579;
    }
    float3 linear;
    if (_8585)
    {
        pipGlassHit = true;
        float3 param_25 = p + (v * ((0.515999972820281982421875 - p.z) / v.z));
        float3 param_26 = v;
        float param_27 = mode;
        float param_28 = age;
        float2 param_29 = look;
        linear = scLCD(param_25, param_26, param_27, param_28, param_29, U);
    }
    else
    {
        if (h.y >= 40.0)
        {
            float3 param_30 = p;
            float3 param_31 = n;
            float3 param_32 = v;
            float param_33 = h.y;
            float param_34 = liftLampGain(kitLift);
            float3 param_35 = p;
            float3 param_36 = n;
            float3 param_37 = v;
            float param_38 = h.y;
            float3 param_39 = liftLampSurface(param_30, param_31, param_32, param_33, param_34, kitLift, U);
            float param_40 = 0.0;
            linear = kitPaintFinish(param_35, param_36, param_37, param_38, param_39, param_40, scoutRoofHit, U);
        }
        else
        {
            float3 param_41 = p;
            float3 param_42 = n;
            float3 param_43 = v;
            float param_44 = h.y;
            float3 _8649 = scHousing(param_41, param_42, param_43, param_44, scKitOn, scKitRoll, scKitYawCS, scoutRoofHit, U);
            float3 param_45 = p;
            float3 param_46 = n;
            float3 param_47 = v;
            float param_48 = h.y;
            float3 param_49 = _8649;
            float param_50 = 0.0;
            linear = kitPaintFinish(param_45, param_46, param_47, param_48, param_49, param_50, scoutRoofHit, U);
        }
    }
    return fast::max(linear, float3(0.0));
}

static inline __attribute__((always_inline))
float3 renderBot(thread const float2& uv, thread const float& mode, thread const float& age, thread const float& t, thread const float2& orbit, thread const float2& look, thread float& pcExpression, thread float& objectCoverage, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread float& scKitSweepMask, thread bool& scoutRoofHit, thread float& kitLift, thread float& galleryHingeMask, thread float& galleryDriveMode, thread bool& galleryFloorOnly, thread bool& pipGlassHit, constant NativeUniforms& U)
{
    galleryDriveMode = mode;
    float param = 1.0;
    float param_1 = mode;
    float param_2 = age;
    scKitPose(param, param_1, param_2, scKitOn, scKitRoll, scKitYawCS, U);
    float param_3 = mode;
    float face = scKitFaceMode(param_3);
    pcExpression = face;
    float2 param_4 = uv;
    float param_5 = (face == 5.0) ? 2.0 : face;
    float param_6 = age;
    float param_7 = t;
    float2 param_8 = orbit;
    float2 param_9 = look;
    float3 _8693 = pcHousing(param_4, param_5, param_6, param_7, param_8, param_9, objectCoverage, scKitOn, scKitRoll, scKitYawCS, scKitSweepMask, scoutRoofHit, kitLift, galleryHingeMask, galleryDriveMode, galleryFloorOnly, pipGlassHit, U);
    return _8693;
}

fragment main0_out main0(constant NativeUniforms& U [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float pcExpression = -1.0;
    float objectCoverage = 1.0;
    bool scKitOn = false;
    float scKitRoll = 0.0;
    float2 scKitYawCS = float2(1.0, 0.0);
    float scKitSweepMask = 0.0;
    bool scoutRoofHit = false;
    float kitLift = 1.0;
    float galleryHingeMask = 0.0;
    float galleryDriveMode = 0.0;
    bool galleryGroundSample = false;
    bool galleryFloorOnly = false;
    bool pipGlassHit = false;
    float2 pixel = float2(gl_FragCoord.x, U.viewport.y - gl_FragCoord.y) / float2(U.viewport.w);
    float2 uv = (pixel - float2(150.0, 200.0)) / float2(U.viewport.z);
    float2 param = uv;
    float param_1 = U.pose.z;
    float param_2 = U.options.x;
    float param_3 = U.eye.w;
    float2 param_4 = float2(0.0);
    float2 param_5 = float2(0.0);
    float3 _8736 = renderBot(param, param_1, param_2, param_3, param_4, param_5, pcExpression, objectCoverage, scKitOn, scKitRoll, scKitYawCS, scKitSweepMask, scoutRoofHit, kitLift, galleryHingeMask, galleryDriveMode, galleryFloorOnly, pipGlassHit, U);
    float3 color = _8736;
    float coverage = objectCoverage;
    float c = cos(U.pose.x);
    float s = sin(U.pose.x);
    float2 p = float2((c * uv.x) - (s * uv.y), (s * uv.x) + (c * uv.y));
    float shadow = (0.2599999904632568359375 * exp(-dot(p / float2(0.819999992847442626953125, 0.64999997615814208984375), p / float2(0.819999992847442626953125, 0.64999997615814208984375)))) * (1.0 - (0.64999997615814208984375 * U.pose.w));
    float _8824;
    for (int x = -1; x <= 1; x += 2)
    {
        for (int z = -1; z <= 1; z += 2)
        {
            float2 d = (p - float2(float(x) * 0.689999997615814208984375, float(z) * 0.430000007152557373046875)) / float2(0.20999999344348907470703125, 0.189999997615814208984375);
            if (z > 0)
            {
                _8824 = exp((-U.options.z) * 5.0);
            }
            else
            {
                _8824 = 1.0;
            }
            shadow += (((0.36000001430511474609375 * exp((-dot(d, d)) * 2.0)) * (1.0 - U.pose.w)) * _8824);
        }
    }
    float beam = 0.0;
    for (int i = -1; i <= 1; i += 2)
    {
        float2 d_1 = p - float2(float(i) * 0.4600000083446502685546875, 0.60000002384185791015625);
        float width = 0.0599999986588954925537109375 + (fast::max(0.0, d_1.y) * 0.310000002384185791015625);
        beam += ((exp((-powr(d_1.x / width, 2.0)) * 2.0) * exp((-fast::max(0.0, d_1.y)) * 2.0)) * smoothstep(0.0, 0.0599999986588954925537109375, d_1.y));
    }
    float lightAlpha = ((beam * 0.20000000298023223876953125) * (1.0 - U.pose.w)) * exp((-U.options.z) * 6.0);
    float groundAlpha = fast::clamp(shadow + lightAlpha, 0.0, 0.800000011920928955078125);
    float3 groundRGB = float3(1.39999997615814208984375, 1.25, 0.819999992847442626953125) * lightAlpha;
    float3 rgb = (color * coverage) + (groundRGB * (1.0 - coverage));
    float alpha = coverage + (groundAlpha * (1.0 - coverage));
    float peak = fast::max(fast::max(rgb.x, rgb.y), rgb.z);
    rgb *= fast::min(1.0, U.options.y / fast::max(peak, 9.9999997473787516355514526367188e-05));
    out.outputColor = float4(rgb, alpha);
    return out;
}


vertex float4 scout_vertex(uint id [[vertex_id]]) {
 return float4(id==1?3.:-1.,id==2?3.:-1.,0.,1.);
}
