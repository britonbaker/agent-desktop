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
float3 worldToScout(thread float3& p, constant NativeUniforms& U)
{
    float heading = U.pose.x + (precise::atan2(sin(3.1415927410125732421875 - U.pose.x), cos(3.1415927410125732421875 - U.pose.x)) * U.pose.w);
    float c = cos(heading);
    float s = sin(heading);
    p = float3((c * p.x) - (s * p.z), p.y, (s * p.x) + (c * p.z));
    float a = U.pose.w * 1.5707962512969970703125;
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
    float3 _3014 = worldToScout(param, U);
    ro = _3014;
    float3 param_1 = fast::normalize(ground - eye);
    float3 _3020 = worldToScout(param_1, U);
    rd = _3020;
}

static inline __attribute__((always_inline))
float3 objectStudioMiss(thread const float3& rgb, thread float& objectCoverage)
{
    objectCoverage = 0.0;
    return rgb;
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
    float2 _930;
    if (a.x < b)
    {
        _930 = a;
    }
    else
    {
        _930 = float2(b, id);
    }
    return _930;
}

static inline __attribute__((always_inline))
float scRod(thread const float3& p, thread const float3& a, thread const float3& b, thread const float& r)
{
    float3 d = b - a;
    return length((p - a) - (d * fast::clamp(dot(p - a, d) / dot(d, d), 0.0, 1.0))) - r;
}

static inline __attribute__((always_inline))
float2 scScene(thread const float3& p, constant NativeUniforms& U)
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
    bool _1115 = w.y < 0.38999998569488525390625;
    bool _1122;
    if (_1115)
    {
        _1122 = w.y > (-0.37999999523162841796875);
    }
    else
    {
        _1122 = _1115;
    }
    if (_1122 && (ax > 0.3499999940395355224609375))
    {
        float r = length(w.yz);
        float angle = precise::atan2(w.y, w.z) + (U.pose.y / (U.viewport.z * 0.2949999868869781494140625));
        float treadAngle = (24.0 * angle) + (4.400000095367431640625 * abs(w.x / 0.14499999582767486572265625));
        float notch = smoothstep(0.0599999986588954925537109375, 0.589999973773956298828125, cos(treadAngle)) * 0.01200000010430812835693359375;
        float param_27 = (r - 0.2949999868869781494140625) + (notch * smoothstep(0.2150000035762786865234375, 0.2569999992847442626953125, r));
        float param_28 = abs(w.x) - 0.1410000026226043701171875;
        float param_29 = 0.04500000178813934326171875;
        float tire = scSection(param_27, param_28, param_29);
        tire = fast::max(tire, -fast::max(r - 0.1689999997615814208984375, 0.0540000014007091522216796875 - w.x));
        float2 param_30 = obj;
        float param_31 = tire;
        float param_32 = 4.0;
        obj = scAdd(param_30, param_31, param_32);
        float param_33 = r - 0.1599999964237213134765625;
        float param_34 = abs(w.x - 0.097999997437000274658203125) - 0.0350000001490116119384765625;
        float param_35 = 0.0130000002682209014892578125;
        float hub = scSection(param_33, param_34, param_35);
        float2 param_36 = obj;
        float param_37 = hub;
        float param_38 = 5.0;
        obj = scAdd(param_36, param_37, param_38);
        float param_39 = r - 0.063000001013278961181640625;
        float param_40 = abs(w.x - 0.12899999320507049560546875) - 0.014999999664723873138427734375;
        float param_41 = 0.008000000379979610443115234375;
        float cap = scSection(param_39, param_40, param_41);
        float2 param_42 = obj;
        float param_43 = cap;
        float param_44 = 6.0;
        obj = scAdd(param_42, param_43, param_44);
    }
    if (p.y < (-0.1019999980926513671875))
    {
        float3 mirror = float3(ax, p.y, abs(p.z));
        float3 param_45 = p - float3(0.0, -0.1689999997615814208984375, -0.017999999225139617919921875);
        float3 param_46 = float3(0.605000019073486328125, 0.063000001013278961181640625, 0.62999999523162841796875);
        float param_47 = 0.04500000178813934326171875;
        float2 param_48 = obj;
        float param_49 = scBox(param_45, param_46, param_47);
        float param_50 = 7.0;
        obj = scAdd(param_48, param_49, param_50);
        float3 param_51 = p - float3(0.0, -0.2529999911785125732421875, -0.00999999977648258209228515625);
        float3 param_52 = float3(0.425000011920928955078125, 0.08200000226497650146484375, 0.522000014781951904296875);
        float param_53 = 0.0670000016689300537109375;
        float2 param_54 = obj;
        float param_55 = scBox(param_51, param_52, param_53);
        float param_56 = 8.0;
        obj = scAdd(param_54, param_55, param_56);
        float3 param_57 = mirror;
        float3 param_58 = float3(0.5950000286102294921875, -0.4740000069141387939453125, 0.4320000112056732177734375);
        float3 param_59 = float3(0.4189999997615814208984375, -0.2479999959468841552734375, 0.2849999964237213134765625);
        float param_60 = 0.04500000178813934326171875;
        float2 param_61 = obj;
        float param_62 = scRod(param_57, param_58, param_59, param_60);
        float param_63 = 6.0;
        obj = scAdd(param_61, param_62, param_63);
        float3 param_64 = mirror;
        float3 param_65 = float3(0.602999985218048095703125, -0.4550000131130218505859375, 0.4189999997615814208984375);
        float3 param_66 = float3(0.528999984264373779296875, -0.22200000286102294921875, 0.014999999664723873138427734375);
        float param_67 = 0.034000001847743988037109375;
        float2 param_68 = obj;
        float param_69 = scRod(param_64, param_65, param_66, param_67);
        float param_70 = 8.0;
        obj = scAdd(param_68, param_69, param_70);
        float3 param_71 = float3(ax - 0.53100001811981201171875, p.y + 0.23499999940395355224609375, p.z);
        float3 param_72 = float3(0.054999999701976776123046875, 0.039999999105930328369140625, 0.5);
        float param_73 = 0.02999999932944774627685546875;
        float sill = scBox(param_71, param_72, param_73);
        float2 param_74 = obj;
        float param_75 = sill;
        float param_76 = 5.0;
        obj = scAdd(param_74, param_75, param_76);
        if (p.z > 0.38999998569488525390625)
        {
            float3 bumper = p - float3(0.0, -0.23199999332427978515625, 0.58399999141693115234375);
            float param_77 = abs(length(bumper.xy / float2(1.5, 1.0)) - 0.063000001013278961181640625) - 0.014999999664723873138427734375;
            float param_78 = abs(bumper.z) - 0.02500000037252902984619140625;
            float param_79 = 0.006000000052154064178466796875;
            float hook = scSection(param_77, param_78, param_79);
            float2 param_80 = obj;
            float param_81 = hook;
            float param_82 = 9.0;
            obj = scAdd(param_80, param_81, param_82);
        }
    }
    bool _1400 = p.y > 0.3499999940395355224609375;
    bool _1407;
    if (_1400)
    {
        _1407 = p.x < (-0.119999997317790985107421875);
    }
    else
    {
        _1407 = _1400;
    }
    if (_1407)
    {
        float3 a = float3(-0.4050000011920928955078125, 0.4550000131130218505859375, -0.15600000321865081787109375);
        float3 b = float3(-0.4050000011920928955078125, 0.681999981403350830078125, -0.17700000107288360595703125);
        float3 param_83 = p;
        float3 param_84 = a;
        float3 param_85 = b;
        float param_86 = 0.0320000015199184417724609375;
        float2 param_87 = obj;
        float param_88 = scRod(param_83, param_84, param_85, param_86);
        float param_89 = 5.0;
        obj = scAdd(param_87, param_88, param_89);
        float3 param_90 = p - a;
        float3 param_91 = float3(0.085000000894069671630859375, 0.0350000001490116119384765625, 0.0670000016689300537109375);
        float param_92 = 0.02199999988079071044921875;
        float2 param_93 = obj;
        float param_94 = scBox(param_90, param_91, param_92);
        float param_95 = 8.0;
        obj = scAdd(param_93, param_94, param_95);
        float3 center = float3(-0.4099999964237213134765625, 0.726000010967254638671875, -0.15299999713897705078125);
        float3 n = float3(-0.4294420778751373291015625, 0.559273421764373779296875, 0.70907878875732421875);
        float3 ex = fast::normalize(cross(float3(0.0, 1.0, 0.0), n));
        float3 ey = cross(n, ex);
        float3 t = p - center;
        float3 d = float3(dot(t, ex), dot(t, ey), dot(t, n));
        float r_1 = length(d.xy);
        float z = (0.939999997615814208984375 * r_1) * r_1;
        float param_96 = r_1 - 0.2109999954700469970703125;
        float param_97 = abs(d.z - z) - 0.01400000043213367462158203125;
        float param_98 = 0.008000000379979610443115234375;
        float bowl = scSection(param_96, param_97, param_98);
        float2 param_99 = obj;
        float param_100 = bowl;
        float param_101 = 10.0;
        obj = scAdd(param_99, param_100, param_101);
        float2 param_102 = obj;
        float param_103 = length(float2(r_1 - 0.20700000226497650146484375, d.z - 0.039999999105930328369140625)) - 0.01200000010430812835693359375;
        float param_104 = 5.0;
        obj = scAdd(param_102, param_103, param_104);
        float3 param_105 = p;
        float3 param_106 = center + (n * 0.004999999888241291046142578125);
        float3 param_107 = center + (n * 0.115000002086162567138671875);
        float param_108 = 0.0130000002682209014892578125;
        float2 param_109 = obj;
        float param_110 = scRod(param_105, param_106, param_107, param_108);
        float param_111 = 8.0;
        obj = scAdd(param_109, param_110, param_111);
        float3 tip = p - (center + (n * 0.11699999868869781494140625));
        float2 param_112 = obj;
        float param_113 = length(tip) - 0.026000000536441802978515625;
        float param_114 = 9.0;
        obj = scAdd(param_112, param_113, param_114);
    }
    float3 param_115 = p - float3(-0.4600000083446502685546875, 0.430000007152557373046875, 0.568000018596649169921875);
    float3 param_116 = float3(0.07400000095367431640625, 0.0350000001490116119384765625, 0.026000000536441802978515625);
    float param_117 = 0.01600000075995922088623046875;
    float2 param_118 = obj;
    float param_119 = scBox(param_115, param_116, param_117);
    float param_120 = 12.0;
    obj = scAdd(param_118, param_119, param_120);
    float3 param_121 = p - float3(0.4600000083446502685546875, 0.430000007152557373046875, 0.568000018596649169921875);
    float3 param_122 = float3(0.07400000095367431640625, 0.0350000001490116119384765625, 0.026000000536441802978515625);
    float param_123 = 0.01600000075995922088623046875;
    float2 param_124 = obj;
    float param_125 = scBox(param_121, param_122, param_123);
    float param_126 = 12.0;
    obj = scAdd(param_124, param_125, param_126);
    return obj;
}

static inline __attribute__((always_inline))
float3 scNormal(thread const float3& p, constant NativeUniforms& U)
{
    float2 e = float2(0.001150000025518238544464111328125, -0.001150000025518238544464111328125);
    float3 param = p + e.xyy;
    float3 param_1 = p + e.yyx;
    float3 param_2 = p + e.yxy;
    float3 param_3 = p + e.xxx;
    return fast::normalize((((e.xyy * scScene(param, U).x) + (e.yyx * scScene(param_1, U).x)) + (e.yxy * scScene(param_2, U).x)) + (e.xxx * scScene(param_3, U).x));
}

static inline __attribute__((always_inline))
float scPixelBox(thread const float2& p, thread const float2& halfSize)
{
    return step(fast::max(abs(p.x) - halfSize.x, abs(p.y) - halfSize.y), 0.0);
}

static inline __attribute__((always_inline))
float scFinder(thread const float2& p, thread float2& h, thread const float& blink, thread const float2& eye, thread const bool& think)
{
    h.y = fast::max(1.0, floor((h.y * blink) + 0.5));
    if (h.y <= 1.0)
    {
        float2 param = p;
        float2 param_1 = float2(h.x - 1.0, 0.550000011920928955078125);
        return scPixelBox(param, param_1);
    }
    float2 d = abs(p);
    float chamfer = step(d.x + d.y, (h.x + h.y) - 2.0);
    float2 param_2 = p;
    float2 param_3 = h;
    float edge = scPixelBox(param_2, param_3) * chamfer;
    float2 param_4 = p;
    float2 param_5 = h - float2(1.2999999523162841796875);
    float core = scPixelBox(param_4, param_5) * step(d.x + d.y, (h.x + h.y) - 4.0);
    float bracket = (edge - core) * (0.7200000286102294921875 + (0.2800000011920928955078125 * step(fast::min(abs(d.x - h.x), abs(d.y - h.y)), 1.0)));
    float2 k = p - eye;
    float2 param_6 = k;
    float2 param_7 = float2(2.5, 3.5);
    float focus = scPixelBox(param_6, param_7) * step(abs(k.x) + abs(k.y), 4.0);
    float2 param_8 = k - float2(-1.0, 2.0);
    float2 param_9 = float2(0.5);
    focus *= (1.0 - scPixelBox(param_8, param_9));
    if (think)
    {
        float2 param_10 = k;
        float2 param_11 = float2(2.0, 0.60000002384185791015625);
        float2 param_12 = k;
        float2 param_13 = float2(0.60000002384185791015625, 2.0);
        focus = fast::max(scPixelBox(param_10, param_11), scPixelBox(param_12, param_13));
    }
    return fast::max(bracket, core * focus);
}

static inline __attribute__((always_inline))
float baseFaceInk(thread const float2& cell, thread const float& mode, thread const float& t, thread const float2& look)
{
    bool listen = mode == 1.0;
    bool think = mode == 2.0;
    bool speak = mode == 3.0;
    bool sleep = mode == 4.0;
    float2 p = floor(cell) - float2(31.0, 24.0);
    float _350;
    if (sleep)
    {
        _350 = 0.0;
    }
    else
    {
        _350 = smoothstep(0.0199999995529651641845703125, 0.1599999964237213134765625, abs(mod(t + 0.85000002384185791015625, 5.349999904632568359375) - 0.1599999964237213134765625));
    }
    float blink = _350;
    float signX = (p.x < 0.0) ? (-1.0) : 1.0;
    float2 gaze = floor((look * 2.0) + float2(0.5));
    gaze.x += floor((1.10000002384185791015625 * sin(0.800000011920928955078125 * t)) + 0.5);
    if (think)
    {
        gaze = float2(floor((3.0 * sin(t * 1.37999999523162841796875)) + 0.5), 1.0);
    }
    float2 eye = p - float2(10.0 * signX, 3.0);
    float _407;
    if (listen)
    {
        _407 = (signX > 0.0) ? 7.0 : 5.0;
    }
    else
    {
        _407 = 6.0;
    }
    float radius = _407;
    if (think && (signX < 0.0))
    {
        eye.y -= 2.0;
    }
    float2 param = eye;
    float2 param_1 = float2(radius, (think && (signX > 0.0)) ? 4.0 : 6.0);
    float param_2 = blink;
    float2 param_3 = gaze;
    bool param_4 = think;
    float _445 = scFinder(param, param_1, param_2, param_3, param_4);
    float v = _445;
    if (!sleep)
    {
        float2 param_5 = p - float2(0.0, 5.0);
        float2 param_6 = float2(2.5, 0.5);
        v = fast::max(v, 0.519999980926513671875 * scPixelBox(param_5, param_6));
    }
    float2 mouth = p - float2(0.0, -9.0);
    if (speak)
    {
        float x = abs(mouth.x);
        float height = floor(((1.0 - (x / 7.0)) * (2.400000095367431640625 + (2.2999999523162841796875 * sin((11.0 * t) - (0.7799999713897705078125 * x))))) + 1.0);
        float2 param_7 = float2(mouth.x, mouth.y);
        float2 param_8 = float2(6.0, fast::max(0.0, height));
        v = fast::max(v, scPixelBox(param_7, param_8) * step(mod(x, 2.0), 0.5));
    }
    else
    {
        float arc = floor(((0.0900000035762786865234375 * mouth.x) * mouth.x) + 0.5);
        if (think)
        {
            arc = floor((0.2199999988079071044921875 * mouth.x) + 0.5);
        }
        if (sleep)
        {
            arc = 0.0;
        }
        float2 param_9 = float2(mouth.x, mouth.y - arc);
        float2 param_10 = float2(sleep ? 2.0 : 4.0, 0.550000011920928955078125);
        v = fast::max(v, scPixelBox(param_9, param_10));
    }
    if (listen)
    {
        float h = floor(1.0 + (1.2000000476837158203125 * (0.5 + (0.5 * sin(5.0 * t)))));
        float2 param_11 = float2(abs(p.x) - 21.0, p.y - 3.0);
        float2 param_12 = float2(0.550000011920928955078125, h);
        v = fast::max(v, 0.7200000286102294921875 * scPixelBox(param_11, param_12));
    }
    return v;
}

static inline __attribute__((always_inline))
float actingFace(thread const float2& cell, thread const float& state, thread const float& age, thread const float2& look)
{
    float2 p = floor(cell);
    float phase = fract(age / 3.0);
    if (state < 4.5)
    {
        float turn = sin(phase * 6.28299999237060546875);
        float2 nudge = float2(floor(fast::clamp(look.x, -1.0, 1.0) + 0.5), 0.0);
        float2 param = cell - nudge;
        float param_1 = 2.0;
        float param_2 = age;
        float2 param_3 = look;
        float ink = baseFaceInk(param, param_1, param_2, param_3);
        for (int i = 0; i < 2; i++)
        {
            float side = (2.0 * float(i)) - 1.0;
            float2 peak = p - float2(31.0 + (side * 7.0), 38.0);
            float ridge = step(abs((peak.y + abs(peak.x)) - 2.0), 0.550000011920928955078125) * step(abs(peak.x), 3.0);
            float2 param_4 = peak - float2(0.0, 4.0);
            float2 param_5 = float2(0.60000002384185791015625);
            float pin = scPixelBox(param_4, param_5);
            ink = fast::max(ink, fast::max(ridge, pin) * (0.61000001430511474609375 + ((0.37000000476837158203125 * side) * turn)));
        }
        return ink;
    }
    float focus = smoothstep(0.1599999964237213134765625, 0.7200000286102294921875, phase);
    float side_1 = 1.0 - (2.0 * step(0.5, fract(age / 6.0)));
    float2 target = float2(31.0 + (side_1 * (9.0 - (4.0 * focus))), 10.0);
    float2 param_6 = cell;
    float param_7 = 1.0;
    float param_8 = age;
    float2 param_9 = (look * 0.550000011920928955078125) + float2(side_1 * (1.0 - (0.5 * focus)), -0.85000002384185791015625);
    float ink_1 = baseFaceInk(param_6, param_7, param_8, param_9);
    float2 aim = p - floor(target + float2(0.5));
    float2 extent = float2(3.0 + floor(4.0 * (1.0 - focus)), 2.0 + floor(2.0 * (1.0 - focus)));
    float2 corner = abs(aim) - extent;
    float2 param_10 = corner + float2(1.0, 0.0);
    float2 param_11 = float2(1.0, 0.550000011920928955078125);
    float2 param_12 = corner + float2(0.0, 1.0);
    float2 param_13 = float2(0.550000011920928955078125, 1.0);
    float brackets = fast::max(scPixelBox(param_10, param_11), scPixelBox(param_12, param_13));
    float diamond = step(abs((abs(aim.x) + abs(aim.y)) - 1.0), 0.5);
    float2 param_14 = aim;
    float2 param_15 = float2(0.550000011920928955078125);
    float lock = scPixelBox(param_14, param_15) * step(0.7599999904632568359375, phase);
    return fast::max(ink_1, fast::max(0.86000001430511474609375 * brackets, fast::max(0.670000016689300537109375 * diamond, lock)));
}

static inline __attribute__((always_inline))
float faceInk(thread const float2& cell, thread const float& mode, thread const float& t, thread const float2& look, thread float& pcExpression)
{
    float state = (pcExpression < 0.0) ? mode : pcExpression;
    if ((state == 2.0) || (state == 5.0))
    {
        float2 param = cell;
        float param_1 = state;
        float param_2 = t;
        float2 param_3 = look;
        return actingFace(param, param_1, param_2, param_3);
    }
    float2 param_4 = cell;
    float param_5 = mode;
    float param_6 = t;
    float2 param_7 = look;
    return baseFaceInk(param_4, param_5, param_6, param_7);
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
float3 scLCD(thread const float3& p, thread const float3& v, thread const float& mode, thread const float& age, thread const float2& look, thread float& pcExpression, constant NativeUniforms& U)
{
    float2 s = p.xy - float2(0.0, 0.1550000011920928955078125);
    float2 inner = s - ((v.xy * 0.0089999996125698089599609375) / float2(fast::max(v.z, 0.2700000107288360595703125)));
    float2 g = (inner / float2(0.014499999582767486572265625)) + float2(32.0, 24.0);
    float2 f = fract(g);
    float2 cell = floor(g);
    float2 side = sign(f - float2(0.5));
    float2 halfPixel = fast::clamp((float2(0.17000000178813934326171875, 0.1599999964237213134765625) * (500.0 / fast::max(1.0, U.viewport.y))) / float2(fast::max(v.z, 0.439999997615814208984375), 1.0), float2(0.054999999701976776123046875), float2(0.4699999988079071044921875));
    float2 blend = fast::clamp(float2(1.0) - (fast::min(f, float2(1.0) - f) / halfPixel), float2(0.0), float2(1.0)) * 0.5;
    float2 param = cell;
    float param_1 = mode;
    float param_2 = age;
    float2 param_3 = look;
    float ink = faceInk(param, param_1, param_2, param_3, pcExpression);
    if (blend.x > 0.001000000047497451305389404296875)
    {
        float2 param_4 = cell + float2(side.x, 0.0);
        float param_5 = mode;
        float param_6 = age;
        float2 param_7 = look;
        ink = mix(ink, faceInk(param_4, param_5, param_6, param_7, pcExpression), blend.x);
    }
    if (blend.y > 0.001000000047497451305389404296875)
    {
        float2 param_8 = cell + float2(0.0, side.y);
        float param_9 = mode;
        float param_10 = age;
        float2 param_11 = look;
        float alt = faceInk(param_8, param_9, param_10, param_11, pcExpression);
        if (blend.x > 0.001000000047497451305389404296875)
        {
            float2 param_12 = cell + side;
            float param_13 = mode;
            float param_14 = age;
            float2 param_15 = look;
            alt = mix(alt, faceInk(param_12, param_13, param_14, param_15, pcExpression), blend.x);
        }
        ink = mix(ink, alt, blend.y);
    }
    float2 h = halfPixel;
    float param_16 = (g.x + h.x) + 0.0425000004470348358154296875;
    float param_17 = (g.x - h.x) + 0.0425000004470348358154296875;
    float param_18 = (g.y + h.y) + 0.0425000004470348358154296875;
    float param_19 = (g.y - h.y) + 0.0425000004470348358154296875;
    float2 gaps = float2(scGridInt(param_16) - scGridInt(param_17), scGridInt(param_18) - scGridInt(param_19)) / (h * 2.0);
    float aperture = (1.0 - gaps.x) * (1.0 - gaps.y);
    float3 base = float3(0.0130000002682209014892578125, 0.02099999971687793731689453125, 0.0240000002086162567138671875) * (0.939999997615814208984375 + (0.0599999986588954925537109375 * aperture));
    float3 ff = reflect(-v, fast::normalize(float3(s.x * 0.540000021457672119140625, s.y * 0.839999973773956298828125, 1.0)));
    float card = 0.01400000043213367462158203125 + (0.07500000298023223876953125 * smoothstep(0.119999997317790985107421875, 0.87000000476837158203125, ff.y - (0.12999999523162841796875 * ff.x)));
    float3 lit = mix(float3(0.88999998569488525390625, 0.625999987125396728515625, 0.24500000476837158203125), float3(0.579999983310699462890625, 0.416999995708465576171875, 0.185000002384185791015625), float3(float(mode == 4.0)));
    float3 param_20 = ff;
    return mix(base, lit * (0.790000021457672119140625 + (0.20999999344348907470703125 * aperture)), float3(ink)) + (scEnv(param_20) * card);
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
float scDash(thread const float& d, thread const float& w)
{
    return 1.0 - smoothstep(w, w + 0.0040000001899898052215576171875, abs(d));
}

static inline __attribute__((always_inline))
float scTick(thread const float& d)
{
    return 1.0 - smoothstep(0.001000000047497451305389404296875, 0.006000000052154064178466796875, abs(d));
}

static inline __attribute__((always_inline))
float3 scHousing(thread const float3& p, thread const float3& n, thread const float3& v, thread const float& id, constant NativeUniforms& U)
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
    if (id < 1.5)
    {
        if (abs(n.x) > 0.60000002384185791015625)
        {
            float2 s = float2(p.z, p.y);
            float2 param_2 = s - float2(-0.017999999225139617919921875, 0.138999998569488525390625);
            float2 param_3 = float2(0.3120000064373016357421875, 0.20499999821186065673828125);
            float param_4 = 0.0460000000894069671630859375;
            float panel = scRect(param_2, param_3, param_4);
            float param_5 = panel;
            float param_6 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.4199999868869781494140625 * scDash(param_5, param_6)));
            bool _1971 = s.x < 0.18899999558925628662109375;
            bool _1978;
            if (_1971)
            {
                _1978 = s.x > (-0.2899999916553497314453125);
            }
            else
            {
                _1978 = _1971;
            }
            bool _1985;
            if (_1978)
            {
                _1985 = s.y > (-0.0030000000260770320892333984375);
            }
            else
            {
                _1985 = _1978;
            }
            bool _1992;
            if (_1985)
            {
                _1992 = s.y < 0.20999999344348907470703125;
            }
            else
            {
                _1992 = _1985;
            }
            if (_1992)
            {
                float k = floor(((s.x + 0.2290000021457672119140625) / 0.076999999582767486572265625) + 0.5);
                float2 l = s - float2((-0.2290000021457672119140625) + (k * 0.076999999582767486572265625), 0.092000000178813934326171875);
                l.x += (0.3300000131130218505859375 * l.y);
                float2 param_7 = l;
                float2 param_8 = float2(0.01400000043213367462158203125, 0.07299999892711639404296875);
                float param_9 = 0.01200000010430812835693359375;
                float hole = scRect(param_7, param_8, param_9);
                metal *= (1.0 - (0.7599999904632568359375 * (1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, hole))));
                float param_10 = hole - 0.007000000216066837310791015625;
                metal += (float3(0.0810000002384185791015625) * scTick(param_10));
            }
            float2 badge = s - float2(0.10300000011920928955078125, 0.2759999930858612060546875);
            float2 param_11 = badge;
            float2 param_12 = float2(0.104999996721744537353515625, 0.0170000009238719940185546875);
            float param_13 = 0.007000000216066837310791015625;
            float mark = scRect(param_11, param_12, param_13);
            metal = mix(metal, float3(0.7599999904632568359375, 0.134000003337860107421875, 0.02300000004470348358154296875) * (0.60000002384185791015625 + (0.449999988079071044921875 * key)), float3(1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, mark)));
        }
        if (n.y > 0.75)
        {
            float2 s_1 = float2(p.x, p.z + 0.0949999988079071044921875);
            float2 param_14 = s_1;
            float2 param_15 = float2(0.3190000057220458984375, 0.2249999940395355224609375);
            float param_16 = 0.0419999994337558746337890625;
            float panel_1 = scRect(param_14, param_15, param_16);
            float param_17 = panel_1;
            float param_18 = 0.0030000000260770320892333984375;
            metal *= (1.0 - (0.4600000083446502685546875 * scDash(param_17, param_18)));
            bool _2113 = abs(s_1.x) < 0.263999998569488525390625;
            bool _2121;
            if (_2113)
            {
                _2121 = abs(s_1.y) < 0.16300000250339508056640625;
            }
            else
            {
                _2121 = _2113;
            }
            if (_2121)
            {
                float k_1 = floor(((s_1.y + 0.12800000607967376708984375) / 0.05099999904632568359375) + 0.5);
                float2 param_19 = s_1 - float2(0.0, (-0.12800000607967376708984375) + (0.05099999904632568359375 * k_1));
                float2 param_20 = float2(0.20999999344348907470703125, 0.008000000379979610443115234375);
                float param_21 = 0.006000000052154064178466796875;
                float line = scRect(param_19, param_20, param_21);
                metal *= (1.0 - (0.540000021457672119140625 * (1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0040000001899898052215576171875, line))));
            }
            float2 screw = float2(abs(p.x) - 0.48500001430511474609375, abs(p.z + 0.004999999888241291046142578125) - 0.305000007152557373046875);
            float rad = length(screw);
            float param_22 = rad - 0.02199999988079071044921875;
            float param_23 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.569999992847442626953125 * scDash(param_22, param_23)));
            float param_24 = screw.x + (0.5 * screw.y);
            float param_25 = 0.00200000009499490261077880859375;
            metal *= (1.0 - ((0.62000000476837158203125 * scDash(param_24, param_25)) * (1.0 - smoothstep(0.01400000043213367462158203125, 0.017999999225139617919921875, rad))));
        }
        if (n.z < (-0.64999997615814208984375))
        {
            float2 s_2 = p.xy - float2(0.0, 0.1459999978542327880859375);
            float2 param_26 = s_2;
            float2 param_27 = float2(0.4650000035762786865234375, 0.20900000631809234619140625);
            float param_28 = 0.05200000107288360595703125;
            float door = scRect(param_26, param_27, param_28);
            float param_29 = door;
            float param_30 = 0.0030000000260770320892333984375;
            metal *= (1.0 - (0.5099999904632568359375 * scDash(param_29, param_30)));
            bool _2232 = abs(s_2.x) < 0.2989999949932098388671875;
            bool _2240;
            if (_2232)
            {
                _2240 = abs(s_2.y) < 0.13099999725818634033203125;
            }
            else
            {
                _2240 = _2232;
            }
            if (_2240)
            {
                float2 uv = s_2 - float2(0.0, 0.01600000075995922088623046875);
                float line_1 = floor(((uv.y + 0.083999998867511749267578125) / 0.0430000014603137969970703125) + 0.5);
                float2 param_31 = uv - float2(0.0, (-0.083999998867511749267578125) + (0.0430000014603137969970703125 * line_1));
                float2 param_32 = float2(0.2610000073909759521484375, 0.0089999996125698089599609375);
                float param_33 = 0.006000000052154064178466796875;
                float vent = scRect(param_31, param_32, param_33);
                metal *= (1.0 - (0.689999997615814208984375 * (1.0 - smoothstep(-0.00200000009499490261077880859375, 0.00200000009499490261077880859375, vent))));
            }
            float2 tailLamp = s_2 - float2(sign(s_2.x) * 0.3689999878406524658203125, -0.14699999988079071044921875);
            float2 param_34 = tailLamp;
            float2 param_35 = float2(0.034000001847743988037109375, 0.01200000010430812835693359375);
            float param_36 = 0.006000000052154064178466796875;
            float tape = scRect(param_34, param_35, param_36);
            metal = mix(metal, float3(0.7799999713897705078125, 0.125, 0.0350000001490116119384765625), float3(1.0 - smoothstep(-0.001000000047497451305389404296875, 0.0030000000260770320892333984375, tape)));
            float2 screw_1 = abs(s_2) - float2(0.3919999897480010986328125, 0.14200000464916229248046875);
            float r = length(screw_1);
            float param_37 = r - 0.02199999988079071044921875;
            float param_38 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.4799999892711639404296875 * scDash(param_37, param_38)));
            float param_39 = screw_1.x - screw_1.y;
            float param_40 = 0.00200000009499490261077880859375;
            metal *= (1.0 - ((0.540000021457672119140625 * scDash(param_39, param_40)) * (1.0 - smoothstep(0.01200000010430812835693359375, 0.0170000009238719940185546875, r))));
        }
        return metal;
    }
    if (id < 2.5)
    {
        float2 s_3 = p.xy - float2(0.0, 0.1550000011920928955078125);
        float2 param_41 = s_3;
        float2 param_42 = float2(0.5490000247955322265625, 0.24199999868869781494140625);
        float param_43 = 0.0610000006854534149169921875;
        float trim = scRect(param_41, param_42, param_43);
        float3 frame = (float3(0.041000001132488250732421875, 0.05200000107288360595703125, 0.064999997615814208984375) * (0.60000002384185791015625 + (0.430000007152557373046875 * key))) + (env * 0.07999999821186065673828125);
        if (n.z > 0.449999988079071044921875)
        {
            float param_44 = trim;
            float param_45 = 0.00150000001303851604461669921875;
            frame += (float3(0.063000001013278961181640625, 0.0570000000298023223876953125, 0.046999998390674591064453125) * scDash(param_44, param_45));
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
        float a = precise::atan2(w.x, w.y) + (U.pose.y / (U.viewport.z * 0.2949999868869781494140625));
        float rim = abs(p.x) - 0.653999984264373779296875;
        float striation = 0.540000021457672119140625 + (0.4600000083446502685546875 * cos((24.0 * a) + (4.400000095367431640625 * abs(rim / 0.14499999582767486572265625))));
        float3 color = (float3(0.02099999971687793731689453125, 0.026000000536441802978515625, 0.02899999916553497314453125) * (0.800000011920928955078125 + (0.589999973773956298828125 * key))) + (float3(0.0170000009238719940185546875) * env);
        color *= (0.88999998569488525390625 + (0.10999999940395355224609375 * striation));
        if (rim > 0.0949999988079071044921875)
        {
            float param_46 = r_2 - 0.21199999749660491943359375;
            float param_47 = 0.0040000001899898052215576171875;
            color *= (1.0 - (0.2800000011920928955078125 * scDash(param_46, param_47)));
            float param_48 = r_2 - 0.2339999973773956298828125;
            float param_49 = 0.001000000047497451305389404296875;
            color += (float3(0.00999999977648258209228515625) * scDash(param_48, param_49));
        }
        return color;
    }
    if (id < 5.5)
    {
        bool _2514 = abs(p.x) > 0.709999978542327880859375;
        bool _2521;
        if (_2514)
        {
            _2521 = p.y < (-0.180000007152557373046875);
        }
        else
        {
            _2521 = _2514;
        }
        if (_2521)
        {
            float2 w_1 = float2(p.y + 0.47200000286102294921875, abs(p.z) - 0.4309999942779541015625);
            float r_3 = length(w_1);
            float a_1 = precise::atan2(w_1.x, w_1.y) + (U.pose.y / (U.viewport.z * 0.2949999868869781494140625));
            float holes = length(float2(r_3 - 0.1040000021457672119140625, sin(a_1 * 3.0) * 0.115000002086162567138671875)) - 0.01899999938905239105224609375;
            metal = mix(metal, float3(0.034000001847743988037109375, 0.039999999105930328369140625, 0.041000001132488250732421875), float3(1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, holes)));
            float param_50 = r_3 - 0.14200000464916229248046875;
            float param_51 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.3400000035762786865234375 * scDash(param_50, param_51)));
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
float3 pcHousing(thread const float2& uv, thread const float& mode, thread const float& age, thread const float& t, thread const float2& orbit, thread const float2& look, thread float& pcExpression, thread float& objectCoverage, thread bool& pipGlassHit, constant NativeUniforms& U)
{
    float2 param = uv;
    float2 param_1 = orbit;
    float3 param_2;
    float3 param_3;
    scCamera(param, param_1, param_2, param_3, U);
    float3 ro = param_2;
    float3 rd = param_3;
    float3 col = mix(float3(0.89999997615814208984375, 0.890999972820281982421875, 0.857999980449676513671875), float3(0.953000009059906005859375, 0.9409999847412109375, 0.90600001811981201171875), float3(fast::clamp((0.38999998569488525390625 - (uv.y * 0.5)) - (uv.x * 0.189999997615814208984375), 0.0, 1.0)));
    if (rd.y < (-0.008000000379979610443115234375))
    {
        float g = ((-0.767000019550323486328125) - ro.y) / rd.y;
        if (g > 0.0)
        {
            float2 xy = (ro + (rd * g)).xz;
            float2 groundPatch = float2(abs(xy.x) - 0.6480000019073486328125, abs(xy.y) - 0.4280000030994415283203125) / float2(0.189999997615814208984375, 0.14000000059604644775390625);
            float2 shade = (xy - float2(0.1599999964237213134765625, -0.0900000035762786865234375)) / float2(0.7799999713897705078125, 0.579999983310699462890625);
            col *= ((1.0 - (0.37999999523162841796875 * exp(-dot(groundPatch, groundPatch)))) - (0.2199999988079071044921875 * exp((-dot(shade, shade)) * 0.939999997615814208984375)));
        }
    }
    float c = dot(ro, rd);
    float disc = ((c * c) - dot(ro, ro)) + 1.50062501430511474609375;
    if (disc < 0.0)
    {
        float3 param_4 = col;
        float3 _3136 = objectStudioMiss(param_4, objectCoverage);
        return _3136;
    }
    float d = (-c) - sqrt(disc);
    float farD = (-c) + sqrt(disc);
    float2 h = float2(1.0);
    for (int i = 0; i < 83; i++)
    {
        float3 param_5 = ro + (rd * d);
        h = scScene(param_5, U);
        if ((h.x < 0.000720000010915100574493408203125) || (d > farD))
        {
            break;
        }
        d += fast::max(0.0004900000058114528656005859375, h.x * 0.699999988079071044921875);
    }
    bool _3190 = d > farD;
    bool _3198;
    if (!_3190)
    {
        _3198 = h.x > 0.00209999992512166500091552734375;
    }
    else
    {
        _3198 = _3190;
    }
    if (_3198)
    {
        float3 param_6 = col;
        float3 _3203 = objectStudioMiss(param_6, objectCoverage);
        return _3203;
    }
    float3 p = ro + (rd * d);
    float3 param_7 = p;
    float3 n = scNormal(param_7, U);
    float3 v = -rd;
    float3 linear;
    if (h.y == 12.0)
    {
        linear = float3(4.0, 3.7000000476837158203125, 2.7999999523162841796875);
    }
    else
    {
        bool _3230 = h.y == 3.0;
        bool _3236;
        if (_3230)
        {
            _3236 = n.z > 0.939999997615814208984375;
        }
        else
        {
            _3236 = _3230;
        }
        if (_3236)
        {
            pipGlassHit = true;
            float3 param_8 = p + (v * ((0.515999972820281982421875 - p.z) / v.z));
            float3 param_9 = v;
            float param_10 = mode;
            float param_11 = age;
            float2 param_12 = look;
            linear = scLCD(param_8, param_9, param_10, param_11, param_12, pcExpression, U);
        }
        else
        {
            float3 param_13 = p;
            float3 param_14 = n;
            float3 param_15 = v;
            float param_16 = h.y;
            linear = scHousing(param_13, param_14, param_15, param_16, U);
        }
    }
    return fast::max(linear, float3(0.0));
}

static inline __attribute__((always_inline))
float3 renderBot(thread const float2& uv, thread const float& mode, thread const float& age, thread const float& t, thread const float2& orbit, thread const float2& look, thread float& pcExpression, thread float& objectCoverage, thread bool& pipGlassHit, constant NativeUniforms& U)
{
    pcExpression = mode;
    float2 param = uv;
    float param_1 = (mode == 5.0) ? 2.0 : mode;
    float param_2 = age;
    float param_3 = t;
    float2 param_4 = orbit;
    float2 param_5 = look;
    float3 _3293 = pcHousing(param, param_1, param_2, param_3, param_4, param_5, pcExpression, objectCoverage, pipGlassHit, U);
    return _3293;
}

fragment main0_out main0(constant NativeUniforms& U [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float pcExpression = -1.0;
    float objectCoverage = 1.0;
    bool pipGlassHit = false;
    float2 pixel = float2(gl_FragCoord.x, U.viewport.y - gl_FragCoord.y) / float2(U.viewport.w);
    float2 uv = (pixel - float2(150.0, 200.0)) / float2(U.viewport.z);
    float2 param = uv;
    float param_1 = U.pose.z;
    float param_2 = U.options.x;
    float param_3 = U.eye.w;
    float2 param_4 = float2(0.0);
    float2 param_5 = float2(0.0);
    float3 _3338 = renderBot(param, param_1, param_2, param_3, param_4, param_5, pcExpression, objectCoverage, pipGlassHit, U);
    float3 color = _3338;
    float coverage = objectCoverage;
    float c = cos(U.pose.x);
    float s = sin(U.pose.x);
    float2 p = float2((c * uv.x) - (s * uv.y), (s * uv.x) + (c * uv.y));
    float shadow = (0.2599999904632568359375 * exp(-dot(p / float2(0.819999992847442626953125, 0.64999997615814208984375), p / float2(0.819999992847442626953125, 0.64999997615814208984375)))) * (1.0 - (0.64999997615814208984375 * U.pose.w));
    for (int x = -1; x <= 1; x += 2)
    {
        for (int z = -1; z <= 1; z += 2)
        {
            float2 d = (p - float2(float(x) * 0.689999997615814208984375, float(z) * 0.430000007152557373046875)) / float2(0.20999999344348907470703125, 0.189999997615814208984375);
            shadow += ((0.36000001430511474609375 * exp((-dot(d, d)) * 2.0)) * (1.0 - U.pose.w));
        }
    }
    float beam = 0.0;
    for (int i = -1; i <= 1; i += 2)
    {
        float2 d_1 = p - float2(float(i) * 0.4600000083446502685546875, 0.60000002384185791015625);
        float width = 0.0599999986588954925537109375 + (fast::max(0.0, d_1.y) * 0.310000002384185791015625);
        beam += ((exp((-powr(d_1.x / width, 2.0)) * 2.0) * exp((-fast::max(0.0, d_1.y)) * 2.0)) * smoothstep(0.0, 0.0599999986588954925537109375, d_1.y));
    }
    float lightAlpha = (beam * 0.20000000298023223876953125) * (1.0 - U.pose.w);
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
