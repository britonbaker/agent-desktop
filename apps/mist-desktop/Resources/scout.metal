// Authored Scout studio, adapted for native EDR. Regenerate with scripts/compile-scout.py.
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
    float4 outfit;
    float4 mechanics;
    float4 wall;
    float4 receiver;
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
    float _3053;
    if (scKitOn && (mode == 6.0))
    {
        float param = age;
        _3053 = scKitSearchAngle(param);
    }
    else
    {
        _3053 = 0.0;
    }
    float yaw = _3053;
    scKitYawCS = float2(cos(yaw), sin(yaw));
    float angle = (6.283185482025146484375 * mod(fast::max(age, 0.0), 3.2000000476837158203125)) / 3.2000000476837158203125;
    scKitRoll = U.pose.y / (U.viewport.z * 0.2949999868869781494140625);
}

static inline __attribute__((always_inline))
float liftLampGain(thread float& kitLift)
{
    return smoothstep(0.7400000095367431640625, 0.9700000286102294921875, kitLift);
}

static inline __attribute__((always_inline))
float3 worldToScout(thread float3& p, constant NativeUniforms& U)
{
    float heading = U.pose.x + (precise::atan2(sin(3.1415927410125732421875 - U.pose.x), cos(3.1415927410125732421875 - U.pose.x)) * U.pose.w);
    float c = cos(heading);
    float s = sin(heading);
    p = float3((c * p.x) - (s * p.z), p.y, (s * p.x) + (c * p.z));
    float cr = cos(U.wall.y);
    float sr = sin(U.wall.y);
    p = float3((cr * p.x) + (sr * p.y), ((-sr) * p.x) + (cr * p.y), p.z);
    float a = (((U.pose.w * 1.2999999523162841796875) + U.options.z) + U.options.w) + U.wall.x;
    float cx = cos(a);
    float sx = sin(a);
    return float3(p.x, (cx * p.y) - (sx * p.z), (sx * p.y) + (cx * p.z));
}

static inline __attribute__((always_inline))
float3 scoutPoint(thread float3& p, constant NativeUniforms& U)
{
    float rise = U.wall.z - (0.767000019550323486328125 * (1.0 - (cos(U.wall.x) * cos(U.wall.y))));
    float3 param = p - float3(0.0, rise, 0.0);
    float3 _6506 = worldToScout(param, U);
    p = _6506;
    float a = ((U.pose.w * 1.2999999523162841796875) + U.options.z) + U.options.w;
    float c = cos(a);
    float s = sin(a);
    float3 pivot = float3(0.0, -0.47200000286102294921875, -0.4309999942779541015625);
    float h = U.pose.x + (precise::atan2(sin(3.1415927410125732421875 - U.pose.x), cos(3.1415927410125732421875 - U.pose.x)) * U.pose.w);
    float3 param_1 = float3(sin(h) * U.wall.w, 0.0, cos(h) * U.wall.w);
    float3 _6556 = worldToScout(param_1, U);
    float3 wheelTranslation = _6556;
    return ((p + pivot) - float3(pivot.x, (c * pivot.y) - (s * pivot.z), (s * pivot.y) + (c * pivot.z))) - wheelTranslation;
}

static inline __attribute__((always_inline))
void scCamera(thread const float2& uv, thread const float2& orbit, thread float3& ro, thread float3& rd, constant NativeUniforms& U)
{
    float3 ground = float3(uv.x, -0.767000019550323486328125, uv.y);
    float3 param = U.eye.xyz;
    float3 _6598 = scoutPoint(param, U);
    ro = _6598;
    float3 param_1 = fast::normalize(ground - U.eye.xyz);
    float3 _6606 = worldToScout(param_1, U);
    rd = _6606;
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
    float2 _3005;
    if (a.x < b)
    {
        _3005 = a;
    }
    else
    {
        _3005 = float2(b, id);
    }
    return _3005;
}

static inline __attribute__((always_inline))
float scKitWheelAngle(thread const float3& p, thread const float& neutral, thread float& scKitRoll)
{
    float _3092;
    if (p.z < 0.0)
    {
        _3092 = -scKitRoll;
    }
    else
    {
        _3092 = scKitRoll;
    }
    return neutral + _3092;
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
    bool _3733 = w.y < 0.38999998569488525390625;
    bool _3740;
    if (_3733)
    {
        _3740 = w.y > (-0.37999999523162841796875);
    }
    else
    {
        _3740 = _3733;
    }
    if (_3740 && (ax > 0.3499999940395355224609375))
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
            float2 _3863 = scKitWheelInside(param_40, param_41, param_42);
            obj = _3863;
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
            float2 _3920 = scKitUndertray(param_58, param_59);
            obj = _3920;
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
    bool _4047;
    if (scKitOn)
    {
        _4047 = p.y > 0.3499999940395355224609375;
    }
    else
    {
        _4047 = scKitOn;
    }
    bool _4054;
    if (_4047)
    {
        _4054 = p.x < (-0.119999997317790985107421875);
    }
    else
    {
        _4054 = _4047;
    }
    if (_4054)
    {
        float2 param_92 = obj;
        float3 param_93 = p;
        float2 _4061 = scKitDish(param_92, param_93, scKitYawCS);
        obj = _4061;
    }
    else
    {
        bool _4065 = p.y > 0.3499999940395355224609375;
        bool _4071;
        if (_4065)
        {
            _4071 = p.x < (-0.119999997317790985107421875);
        }
        else
        {
            _4071 = _4065;
        }
        if (_4071)
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
    float2 _7879;
    if ((-cutter) > stock.x)
    {
        _7879 = float2(-cutter, 43.0);
    }
    else
    {
        _7879 = stock;
    }
    return _7879;
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
void kitDisplayFrame(thread const float& style, thread float3& center, thread float3& halfSize, thread float3& front, thread float3& right, thread float3& up)
{
    if (style < 5.5)
    {
        center = float3(0.3459999859333038330078125, 0.642000019550323486328125, -0.17499999701976776123046875);
        halfSize = float3(0.18199999630451202392578125, 0.1040000021457672119140625, 0.0439999997615814208984375);
        front = float3(0.082981146872043609619140625, 0.200130999088287353515625, 0.976248800754547119140625);
    }
    else
    {
        if (style < 6.5)
        {
            center = float3(0.1369999945163726806640625, 0.637000024318695068359375, 0.0500000007450580596923828125);
            halfSize = float3(0.365999996662139892578125, 0.0810000002384185791015625, 0.032999999821186065673828125);
            front = float3(0.0, 0.398893773555755615234375, 0.916997134685516357421875);
        }
        else
        {
            center = float3(0.35699999332427978515625, 0.688000023365020751953125, -0.15299999713897705078125);
            halfSize = float3(0.119999997317790985107421875, 0.15800000727176666259765625, 0.04500000178813934326171875);
            front = float3(0.2249524891376495361328125, 0.181876480579376220703125, 0.9572446346282958984375);
        }
    }
    right = fast::normalize(float3(front.z, 0.0, -front.x));
    up = cross(front, right);
}

static inline __attribute__((always_inline))
float kitWindowY(thread const float& style)
{
    return (style > 6.5) ? 0.01400000043213367462158203125 : 0.0030000000260770320892333984375;
}

static inline __attribute__((always_inline))
float2 kitWindow(thread const float& style)
{
    if (style < 5.5)
    {
        return float2(0.1509999930858612060546875, 0.076999999582767486572265625);
    }
    if (style < 6.5)
    {
        return float2(0.3350000083446502685546875, 0.0579999983310699462890625);
    }
    return float2(0.09600000083446502685546875, 0.12399999797344207763671875);
}

static inline __attribute__((always_inline))
float kitWindowRadius(thread const float& style)
{
    float _8955;
    if (style < 5.5)
    {
        _8955 = 0.017999999225139617919921875;
    }
    else
    {
        _8955 = (style < 6.5) ? 0.01200000010430812835693359375 : 0.014999999664723873138427734375;
    }
    return _8955;
}

static inline __attribute__((always_inline))
float kitCylinderY(thread const float3& p, thread const float& r, thread const float& h, thread const float& edge)
{
    float param = length(p.xz) - r;
    float param_1 = abs(p.y) - h;
    float param_2 = edge;
    return scSection(param, param_1, param_2);
}

static inline __attribute__((always_inline))
float2 kitDisplayMap(thread const float3& p, thread const float& style)
{
    if ((style < 4.5) || (style > 7.5))
    {
        return float2(20.0, 110.0);
    }
    float3 _8995;
    if (style < 5.5)
    {
        _8995 = float3(0.3459999859333038330078125, 0.605000019073486328125, -0.1689999997615814208984375);
    }
    else
    {
        _8995 = select(float3(0.3670000135898590087890625, 0.658999979496002197265625, -0.14699999988079071044921875), float3(0.1369999945163726806640625, 0.5950000286102294921875, 0.05200000107288360595703125), bool3(style < 6.5));
    }
    float3 bc = _8995;
    float3 _9012;
    if (style < 5.5)
    {
        _9012 = float3(0.20499999821186065673828125, 0.1550000011920928955078125, 0.119999997317790985107421875);
    }
    else
    {
        _9012 = select(float3(0.16500000655651092529296875, 0.20700000226497650146484375, 0.119999997317790985107421875), float3(0.384000003337860107421875, 0.1410000026226043701171875, 0.0949999988079071044921875), bool3(style < 6.5));
    }
    float3 bh = _9012;
    float3 param = p - bc;
    float3 param_1 = bh;
    float param_2 = 0.0;
    float bound = scBox(param, param_1, param_2);
    if (bound > 0.026000000536441802978515625)
    {
        return float2(bound, 110.0);
    }
    float param_3 = style;
    float3 param_4;
    float3 param_5;
    float3 param_6;
    float3 param_7;
    float3 param_8;
    kitDisplayFrame(param_3, param_4, param_5, param_6, param_7, param_8);
    float3 center = param_4;
    float3 h = param_5;
    float3 front = param_6;
    float3 right = param_7;
    float3 up = param_8;
    float3 v = p - center;
    float3 q = float3(dot(v, right), dot(v, up), dot(v, front));
    float param_9 = style;
    float2 s = q.xy - float2(0.0, kitWindowY(param_9));
    float param_10 = style;
    float2 win = kitWindow(param_10);
    float param_11 = style;
    float wr = kitWindowRadius(param_11);
    float _9094;
    if (style < 5.5)
    {
        _9094 = 0.026000000536441802978515625;
    }
    else
    {
        _9094 = (style < 6.5) ? 0.017999999225139617919921875 : 0.02500000037252902984619140625;
    }
    float3 param_12 = q;
    float3 param_13 = h;
    float param_14 = _9094;
    float shell = scBox(param_12, param_13, param_14);
    float2 param_15 = s;
    float2 param_16 = win + float2(0.0040000001899898052215576171875);
    float param_17 = wr + 0.004999999888241291046142578125;
    shell = fast::max(shell, -fast::max(scRect(param_15, param_16, param_17), (h.z - 0.0309999994933605194091796875) - q.z));
    float2 result = float2(shell, 110.0);
    float2 param_18 = s;
    float2 param_19 = win + float2(0.006000000052154064178466796875);
    float param_20 = wr + 0.004999999888241291046142578125;
    float2 param_21 = s;
    float2 param_22 = win - float2(0.0040000001899898052215576171875);
    float param_23 = wr;
    float rubber = fast::max(scRect(param_18, param_19, param_20), -scRect(param_21, param_22, param_23));
    float param_24 = rubber;
    float param_25 = abs(q.z - (h.z - 0.0089999996125698089599609375)) - 0.004999999888241291046142578125;
    float param_26 = 0.00200000009499490261077880859375;
    float2 param_27 = result;
    float param_28 = scSection(param_24, param_25, param_26);
    float param_29 = 111.0;
    result = scAdd(param_27, param_28, param_29);
    float2 param_30 = s;
    float2 param_31 = win - float2(0.0040000001899898052215576171875);
    float param_32 = wr;
    float param_33 = scRect(param_30, param_31, param_32);
    float param_34 = abs(q.z - (h.z - 0.0170000009238719940185546875)) - 0.007000000216066837310791015625;
    float param_35 = 0.0030000000260770320892333984375;
    float glass = scSection(param_33, param_34, param_35);
    float2 param_36 = result;
    float param_37 = glass;
    float param_38 = 112.0;
    result = scAdd(param_36, param_37, param_38);
    if (style < 5.5)
    {
        float3 m = p - float3(0.342999994754791259765625, 0.4769999980926513671875, -0.15899999439716339111328125);
        float3 param_39 = m;
        float3 param_40 = float3(0.0900000035762786865234375, 0.0089999996125698089599609375, 0.054999999701976776123046875);
        float param_41 = 0.006000000052154064178466796875;
        float2 param_42 = result;
        float param_43 = scBox(param_39, param_40, param_41);
        float param_44 = 111.0;
        result = scAdd(param_42, param_43, param_44);
        m.x = abs(m.x) - 0.064000003039836883544921875;
        float3 param_45 = m - float3(0.0, 0.03599999845027923583984375, 0.0);
        float3 param_46 = float3(0.014999999664723873138427734375, 0.037000000476837158203125, 0.034000001847743988037109375);
        float param_47 = 0.007000000216066837310791015625;
        float2 param_48 = result;
        float param_49 = scBox(param_45, param_46, param_47);
        float param_50 = 113.0;
        result = scAdd(param_48, param_49, param_50);
        float3 hub = q - float3(0.0, -0.0949999988079071044921875, -0.01200000010430812835693359375);
        float param_51 = length(hub.yz) - 0.01600000075995922088623046875;
        float param_52 = abs(hub.x) - 0.08200000226497650146484375;
        float param_53 = 0.0040000001899898052215576171875;
        float2 param_54 = result;
        float param_55 = scSection(param_51, param_52, param_53);
        float param_56 = 113.0;
        result = scAdd(param_54, param_55, param_56);
    }
    else
    {
        if (style < 6.5)
        {
            float3 base = p - float3(0.1369999945163726806640625, 0.528999984264373779296875, 0.04500000178813934326171875);
            float3 param_57 = float3(abs(base.x) - 0.24699999392032623291015625, p.y - 0.4769999980926513671875, base.z);
            float3 param_58 = float3(0.05099999904632568359375, 0.0089999996125698089599609375, 0.048000000417232513427734375);
            float param_59 = 0.006000000052154064178466796875;
            float foot = scBox(param_57, param_58, param_59);
            float2 param_60 = result;
            float param_61 = foot;
            float param_62 = 111.0;
            result = scAdd(param_60, param_61, param_62);
            float3 param_63 = base;
            float3 param_64 = float3(0.2939999997615814208984375, 0.05099999904632568359375, 0.048000000417232513427734375);
            float param_65 = 0.01200000010430812835693359375;
            float saddle = scBox(param_63, param_64, param_65);
            saddle = fast::max(saddle, ((base.z * 0.449999988079071044921875) - base.y) - 0.02999999932944774627685546875);
            float2 param_66 = result;
            float param_67 = saddle;
            float param_68 = 110.0;
            result = scAdd(param_66, param_67, param_68);
            float3 param_69 = q - float3(0.0, -0.07400000095367431640625, -0.0170000009238719940185546875);
            float3 param_70 = float3(0.3030000030994415283203125, 0.017999999225139617919921875, 0.02300000004470348358154296875);
            float param_71 = 0.006000000052154064178466796875;
            float2 param_72 = result;
            float param_73 = scBox(param_69, param_70, param_71);
            float param_74 = 111.0;
            result = scAdd(param_72, param_73, param_74);
        }
        else
        {
            float3 foot_1 = p - float3(0.3540000021457672119140625, 0.4769999980926513671875, -0.13500000536441802978515625);
            float3 param_75 = foot_1;
            float param_76 = 0.070000000298023223876953125;
            float param_77 = 0.010999999940395355224609375;
            float param_78 = 0.004999999888241291046142578125;
            float2 param_79 = result;
            float param_80 = kitCylinderY(param_75, param_76, param_77, param_78);
            float param_81 = 111.0;
            result = scAdd(param_79, param_80, param_81);
            float3 param_82 = foot_1 - float3(0.0, 0.0309999994933605194091796875, 0.0);
            float param_83 = 0.0529999993741512298583984375;
            float param_84 = 0.026000000536441802978515625;
            float param_85 = 0.006000000052154064178466796875;
            float2 param_86 = result;
            float param_87 = kitCylinderY(param_82, param_83, param_84, param_85);
            float param_88 = 113.0;
            result = scAdd(param_86, param_87, param_88);
            float3 param_89 = q - float3(0.0, -0.14900000393390655517578125, -0.014999999664723873138427734375);
            float3 param_90 = float3(0.0500000007450580596923828125, 0.02199999988079071044921875, 0.0240000002086162567138671875);
            float param_91 = 0.008000000379979610443115234375;
            float2 param_92 = result;
            float param_93 = scBox(param_89, param_90, param_91);
            float param_94 = 113.0;
            result = scAdd(param_92, param_93, param_94);
            float3 knob = q - float3(0.12399999797344207763671875, -0.063000001013278961181640625, -0.00200000009499490261077880859375);
            float radial = length(knob.yz) - (0.02899999916553497314453125 + (0.00179999996908009052276611328125 * cos(16.0 * precise::atan2(knob.y, knob.z))));
            float param_95 = radial;
            float param_96 = abs(knob.x) - 0.0130000002682209014892578125;
            float param_97 = 0.004999999888241291046142578125;
            float2 param_98 = result;
            float param_99 = scSection(param_95, param_96, param_97);
            float param_100 = 114.0;
            result = scAdd(param_98, param_99, param_100);
            float3 key = q - float3(0.0, -0.1319999992847442626953125, h.z);
            key.x = abs(key.x) - 0.037000000476837158203125;
            float3 param_101 = key;
            float3 param_102 = float3(0.017999999225139617919921875, 0.006000000052154064178466796875, 0.006000000052154064178466796875);
            float param_103 = 0.0040000001899898052215576171875;
            float2 param_104 = result;
            float param_105 = scBox(param_101, param_102, param_103);
            float param_106 = 115.0;
            result = scAdd(param_104, param_105, param_106);
        }
    }
    return result;
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
float hwDome(thread const float3& q, thread const float& aperture, thread const float& sphereRadius, thread const float& depth)
{
    float sphere = length(q + float3(0.0, 0.0, sphereRadius)) - sphereRadius;
    return fast::max(fast::max(sphere, length(q.xy) - aperture), (-depth) - q.z);
}

static inline __attribute__((always_inline))
float hwShoulderProfile(thread const float2& p)
{
    float2 param = p;
    float2 param_1 = float2(0.125, 0.104999996721744537353515625);
    float param_2 = 0.017999999225139617919921875;
    return fast::max(scRect(param, param_1, param_2), ((abs(p.x) + abs(p.y)) - 0.19599999487400054931640625) * 0.707107007503509521484375);
}

static inline __attribute__((always_inline))
float2 headParts(thread const float3& p, thread const float& style)
{
    if (style < 0.5)
    {
        return float2(12.0, 20.0);
    }
    float3 m = float3(abs(p.x), p.yz);
    if (style < 1.5)
    {
        float3 param = m - float3(0.4329999983310699462890625, -0.19599999487400054931640625, 0.64300000667572021484375);
        float3 param_1 = float3(0.15800000727176666259765625, 0.15199999511241912841796875, 0.1550000011920928955078125);
        float param_2 = 0.0;
        float guard = scBox(param, param_1, param_2);
        if (guard > 0.04500000178813934326171875)
        {
            return float2(guard, 20.0);
        }
        float3 param_3 = m;
        float param_4 = style;
        float3 q = hwPartFrame(param_3, param_4);
        float r = length(q.xy);
        float shellRadius = mix(0.07500000298023223876953125, 0.119999997317790985107421875, smoothstep(-0.16099999845027923583984375, -0.0579999983310699462890625, q.z));
        float param_5 = r - shellRadius;
        float param_6 = abs(q.z + 0.0900000035762786865234375) - 0.075999997556209564208984375;
        float param_7 = 0.0130000002682209014892578125;
        float2 part = float2(scSection(param_5, param_6, param_7), 20.0);
        float param_8 = abs(r - 0.111500002443790435791015625) - 0.012500000186264514923095703125;
        float param_9 = abs(q.z + 0.010999999940395355224609375) - 0.02199999988079071044921875;
        float param_10 = 0.004999999888241291046142578125;
        float band = scSection(param_8, param_9, param_10);
        float2 param_11 = part;
        float param_12 = band;
        float param_13 = 21.0;
        part = scAdd(param_11, param_12, param_13);
        float3 param_14 = q;
        float param_15 = 0.10300000011920928955078125;
        float param_16 = 0.3089999854564666748046875;
        float param_17 = 0.02700000070035457611083984375;
        float2 param_18 = part;
        float param_19 = hwDome(param_14, param_15, param_16, param_17);
        float param_20 = 22.0;
        part = scAdd(param_18, param_19, param_20);
        float3 param_21 = m - float3(0.4289999902248382568359375, -0.1940000057220458984375, 0.60399997234344482421875);
        float3 param_22 = float3(0.070000000298023223876953125, 0.0390000008046627044677734375, 0.0610000006854534149169921875);
        float param_23 = 0.0130000002682209014892578125;
        float foot = scBox(param_21, param_22, param_23);
        float2 param_24 = part;
        float param_25 = foot;
        float param_26 = 23.0;
        part = scAdd(param_24, param_25, param_26);
        return part;
    }
    if (style < 2.5)
    {
        float3 param_27 = p - float3(0.0, 0.490999996662139892578125, 0.4550000131130218505859375);
        float3 param_28 = float3(0.550000011920928955078125, 0.087999999523162841796875, 0.134000003337860107421875);
        float param_29 = 0.0;
        float guard_1 = scBox(param_27, param_28, param_29);
        if (guard_1 > 0.04500000178813934326171875)
        {
            return float2(guard_1, 20.0);
        }
        float3 param_30 = p;
        float param_31 = style;
        float3 q_1 = hwPartFrame(param_30, param_31);
        float3 param_32 = q_1 - float3(0.0, 0.0, -0.048000000417232513427734375);
        float3 param_33 = float3(0.51800000667572021484375, 0.05099999904632568359375, 0.064000003039836883544921875);
        float param_34 = 0.0170000009238719940185546875;
        float shell = scBox(param_32, param_33, param_34);
        float2 param_35 = q_1.xy;
        float2 param_36 = float2(0.4690000116825103759765625, 0.02899999916553497314453125);
        float param_37 = 0.01200000010430812835693359375;
        float slot = scRect(param_35, param_36, param_37);
        shell = fast::max(shell, -fast::max(slot, (-0.039999999105930328369140625) - q_1.z));
        float2 part_1 = float2(shell, 24.0);
        float2 param_38 = q_1.xy;
        float2 param_39 = float2(0.4709999859333038330078125, 0.0309999994933605194091796875);
        float param_40 = 0.01200000010430812835693359375;
        float param_41 = scRect(param_38, param_39, param_40);
        float param_42 = abs(q_1.z + 0.01400000043213367462158203125) - 0.01400000043213367462158203125;
        float param_43 = 0.004999999888241291046142578125;
        float lens = scSection(param_41, param_42, param_43);
        float2 param_44 = part_1;
        float param_45 = lens;
        float param_46 = 25.0;
        part_1 = scAdd(param_44, param_45, param_46);
        float3 param_47 = m - float3(0.3959999978542327880859375, 0.4550000131130218505859375, 0.425000011920928955078125);
        float3 param_48 = float3(0.046999998390674591064453125, 0.037000000476837158203125, 0.05900000035762786865234375);
        float param_49 = 0.00999999977648258209228515625;
        float foot_1 = scBox(param_47, param_48, param_49);
        float2 param_50 = part_1;
        float param_51 = foot_1;
        float param_52 = 23.0;
        part_1 = scAdd(param_50, param_51, param_52);
        return part_1;
    }
    float3 param_53 = m - float3(0.697000026702880859375, 0.085000000894069671630859375, 0.4830000102519989013671875);
    float3 param_54 = float3(0.20200000703334808349609375, 0.14000000059604644775390625, 0.20200000703334808349609375);
    float param_55 = 0.0;
    float guard_2 = scBox(param_53, param_54, param_55);
    if (guard_2 > 0.04500000178813934326171875)
    {
        return float2(guard_2, 20.0);
    }
    float3 param_56 = m;
    float param_57 = style;
    float3 q_2 = hwPartFrame(param_56, param_57);
    float r_1 = length(q_2.xy);
    float2 param_58 = q_2.xy;
    float param_59 = hwShoulderProfile(param_58);
    float param_60 = abs(q_2.z + 0.06800000369548797607421875) - 0.1019999980926513671875;
    float param_61 = 0.010999999940395355224609375;
    float shell_1 = scSection(param_59, param_60, param_61);
    shell_1 = fast::max(shell_1, -fast::max(r_1 - 0.086000002920627593994140625, (-0.08699999749660491943359375) - q_2.z));
    float2 part_2 = float2(shell_1, 26.0);
    float param_62 = abs(r_1 - 0.075999997556209564208984375) - 0.010999999940395355224609375;
    float param_63 = abs(q_2.z + 0.0280000008642673492431640625) - 0.02700000070035457611083984375;
    float param_64 = 0.004999999888241291046142578125;
    float retainer = scSection(param_62, param_63, param_64);
    float2 param_65 = part_2;
    float param_66 = retainer;
    float param_67 = 27.0;
    part_2 = scAdd(param_65, param_66, param_67);
    float3 param_68 = q_2;
    float param_69 = 0.06800000369548797607421875;
    float param_70 = 0.11200000345706939697265625;
    float param_71 = 0.0320000015199184417724609375;
    float2 param_72 = part_2;
    float param_73 = hwDome(param_68, param_69, param_70, param_71);
    float param_74 = 28.0;
    part_2 = scAdd(param_72, param_73, param_74);
    float3 param_75 = m - float3(0.657000005245208740234375, 0.071000002324581146240234375, 0.4309999942779541015625);
    float3 param_76 = float3(0.097999997437000274658203125, 0.056000001728534698486328125, 0.079000003635883331298828125);
    float param_77 = 0.01400000043213367462158203125;
    float mount = scBox(param_75, param_76, param_77);
    float2 param_78 = part_2;
    float param_79 = mount;
    float param_80 = 23.0;
    part_2 = scAdd(param_78, param_79, param_80);
    return part_2;
}

static inline __attribute__((always_inline))
float2 studySDF(thread const float3& p, thread const float& style, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread float& kitLift)
{
    float3 param = p;
    float2 base = scScene(param, scKitOn, scKitRoll, scKitYawCS);
    if (style < 0.5)
    {
        return base;
    }
    float2 lamp;
    if (style >= 3.5)
    {
        float2 param_1 = base;
        float3 param_2 = p;
        base = liftLampDeck(param_1, param_2);
        float3 param_3 = p;
        lamp = liftLampMap(param_3, kitLift);
        if (style >= 4.5)
        {
            float3 param_4 = p;
            float param_5 = style;
            float2 instrument = kitDisplayMap(param_4, param_5);
            if (instrument.x < lamp.x)
            {
                lamp = instrument;
            }
        }
    }
    else
    {
        float3 param_6 = p;
        float param_7 = style;
        lamp = headParts(param_6, param_7);
    }
    return select(base, lamp, bool2(lamp.x < base.x));
}

static inline __attribute__((always_inline))
float3 studyNormal(thread const float3& p, thread const float& style, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread float& kitLift)
{
    float2 e = float2(0.0010999999940395355224609375, -0.0010999999940395355224609375);
    float3 param = p + e.xyy;
    float param_1 = style;
    float3 param_2 = p + e.yyx;
    float param_3 = style;
    float3 param_4 = p + e.yxy;
    float param_5 = style;
    float3 param_6 = p + e.xxx;
    float param_7 = style;
    return fast::normalize((((e.xyy * studySDF(param, param_1, scKitOn, scKitRoll, scKitYawCS, kitLift).x) + (e.yyx * studySDF(param_2, param_3, scKitOn, scKitRoll, scKitYawCS, kitLift).x)) + (e.yxy * studySDF(param_4, param_5, scKitOn, scKitRoll, scKitYawCS, kitLift).x)) + (e.xxx * studySDF(param_6, param_7, scKitOn, scKitRoll, scKitYawCS, kitLift).x));
}

static inline __attribute__((always_inline))
float scKitFaceMode(thread const float& mode)
{
    float _3018;
    if (mode == 6.0)
    {
        _3018 = 2.0;
    }
    else
    {
        _3018 = (mode == 7.0) ? 0.0 : mode;
    }
    return _3018;
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
    bool _596 = abs(p.x) > 16.0;
    bool _604;
    if (!_596)
    {
        _604 = p.y < (-14.0);
    }
    else
    {
        _604 = _596;
    }
    bool _612;
    if (!_604)
    {
        _612 = p.y > 14.0;
    }
    else
    {
        _612 = _604;
    }
    if (_612)
    {
        return 0.0;
    }
    float t = fast::max(0.0, age);
    if (p.y < (-6.0))
    {
        float2 m = p - float2(0.0, -11.0);
        if ((mode == 3.0) || (mode == 1.0))
        {
            float _641;
            if (mode == 1.0)
            {
                _641 = 1.64999997615814208984375;
            }
            else
            {
                _641 = 1.10000002384185791015625 + (2.25 * (0.5 + (0.5 * sin((12.0 * t) + (0.5 * sin(4.0 * t))))));
            }
            float h = _641;
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
            float _718;
            if (mode == 2.0)
            {
                _718 = step(1.0, m.x);
            }
            else
            {
                _718 = step(2.0, m.x);
            }
            float y = _718;
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
        float _839 = dialSearch(param_6);
        aim = 3.0 * _839;
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
    float _876;
    if (mode == 4.0)
    {
        _876 = 0.0;
    }
    else
    {
        _876 = smoothstep(0.04500000178813934326171875, 0.1500000059604644775390625, blink);
    }
    float lid = _876;
    if (lid < 0.1599999964237213134765625)
    {
        float _893;
        if (mode == 4.0)
        {
            _893 = (-1.0) + floor(abs(q.x) * 0.300000011920928955078125);
        }
        else
        {
            _893 = 1.0 - floor(abs(q.x) * 0.300000011920928955078125);
        }
        float y_1 = _893;
        return (0.839999973773956298828125 * step(abs(q.x), 4.0)) * step(abs(q.y - y_1), 0.5);
    }
    float param_9 = h_1 * lid;
    h_1 = fast::max(2.0, dialRound(param_9));
    float band = h_1 - abs(q.y);
    float x = abs(q.x);
    float _947;
    if (band < 0.5)
    {
        _947 = 3.0;
    }
    else
    {
        _947 = (band < 1.5) ? 4.0 : 5.0;
    }
    float outer = step(0.0, band) * step(x, _947);
    float hollow = step(1.5, band) * step(x, 4.0);
    float rim = outer * (1.0 - hollow);
    float2 a = q - float2(aim, lift);
    float pupilH = fast::max(1.0, h_1 - 3.0);
    float edge = pupilH - abs(a.y);
    float _994;
    if (edge < 0.5)
    {
        _994 = 1.5;
    }
    else
    {
        _994 = (edge < 1.5) ? 2.0 : 2.599999904632568359375;
    }
    float pupil = step(0.0, edge) * step(abs(a.x + 0.449999988079071044921875), _994);
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
    bool _2336 = abs(p.x) > 24.0;
    bool _2344;
    if (!_2336)
    {
        _2344 = p.y < (-13.0);
    }
    else
    {
        _2344 = _2336;
    }
    bool _2352;
    if (!_2344)
    {
        _2352 = p.y > 15.0;
    }
    else
    {
        _2352 = _2344;
    }
    if (_2352)
    {
        return float3(0.0);
    }
    float side = (p.x < 0.0) ? (-1.0) : 1.0;
    float t = fast::max(0.0, age);
    float _2368;
    if (mode == 6.0)
    {
        float param = t;
        float _2373 = dialSearch(param);
        _2368 = _2373;
    }
    else
    {
        _2368 = 0.0;
    }
    float turn = _2368;
    float _2379;
    if (mode == 5.0)
    {
        _2379 = smoothstep(0.119999997317790985107421875, 0.680000007152557373046875, fract(t / 3.2000000476837158203125));
    }
    else
    {
        _2379 = 0.0;
    }
    float focus = _2379;
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
    float _2502;
    if (mode == 4.0)
    {
        _2502 = 0.0;
    }
    else
    {
        _2502 = smoothstep(0.0379999987781047821044921875, 0.1599999964237213134765625, blink);
    }
    float lid = _2502;
    float param_1 = cy;
    float2 eye = p - float2(10.0 * side, dialRound(param_1));
    float amber = 0.0;
    float glint = 0.0;
    if (lid < 0.119999997317790985107421875)
    {
        float _2528;
        if (mode == 4.0)
        {
            _2528 = (-1.0) + floor(0.36000001430511474609375 * abs(eye.x));
        }
        else
        {
            _2528 = 1.0 - floor(0.319999992847442626953125 * abs(eye.x));
        }
        float y = _2528;
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
            float _2807;
            if (mode == 4.0)
            {
                _2807 = 2.0;
            }
            else
            {
                float _2813;
                if (mode == 2.0)
                {
                    _2813 = 3.0;
                }
                else
                {
                    float _2819;
                    if (mode == 5.0)
                    {
                        _2819 = 3.0;
                    }
                    else
                    {
                        _2819 = (mode == 7.0) ? 5.0 : 4.0;
                    }
                    _2813 = _2819;
                }
                _2807 = _2813;
            }
            float width = _2807;
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
    bool _1381 = (mode == 2.0) && (side > 0.0);
    bool _1390;
    if (!_1381)
    {
        _1390 = (mode == 5.0) && (side < 0.0);
    }
    else
    {
        _1390 = _1381;
    }
    if (_1390 || (mode == 7.0))
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
    bool _1550 = (mode == 1.0) && (side > 0.0);
    bool _1559;
    if (!_1550)
    {
        _1559 = (mode == 2.0) && (side < 0.0);
    }
    else
    {
        _1559 = _1550;
    }
    if (_1559)
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
    bool _1815 = x > 23.0;
    bool _1823;
    if (!_1815)
    {
        _1823 = q.y < lo;
    }
    else
    {
        _1823 = _1815;
    }
    bool _1831;
    if (!_1823)
    {
        _1831 = q.y > hi;
    }
    else
    {
        _1831 = _1823;
    }
    if (_1831)
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
    float _1909;
    if (mode == 6.0)
    {
        float param_3 = 18.0 * turn;
        _1909 = dialRound(param_3);
    }
    else
    {
        float _1920;
        if (mode == 5.0)
        {
            float param_4 = 12.0 * (1.0 - focus);
            _1920 = dialRound(param_4);
        }
        else
        {
            float _1931;
            if (mode == 2.0)
            {
                _1931 = -12.0;
            }
            else
            {
                _1931 = floor(38.0 * fract(t / 5.75)) - 19.0;
            }
            _1920 = _1931;
        }
        _1909 = _1920;
    }
    float scan = _1909;
    float offset = scan - (q.x + floor(q.y * 0.4799999892711639404296875));
    float trail = (step(0.0, offset) * step(offset, 2.0)) * (1.0 - (0.300000011920928955078125 * offset));
    float _1974;
    if (mode == 6.0)
    {
        _1974 = 0.660000026226043701171875;
    }
    else
    {
        _1974 = (mode == 5.0) ? 0.37000000476837158203125 : 0.20000000298023223876953125;
    }
    float ink = fast::max(rim, trail * _1974);
    float _1990;
    if (mode == 7.0)
    {
        _1990 = 2.0;
    }
    else
    {
        float _1999;
        if ((mode == 2.0) && (side > 0.0))
        {
            _1999 = 1.5499999523162841796875;
        }
        else
        {
            _1999 = ((mode == 1.0) && (side > 0.0)) ? 3.25 : 2.7999999523162841796875;
        }
        _1990 = _1999;
    }
    float h = _1990;
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
        float _1127;
        if (h > 1.5)
        {
            float2 param_4 = m - float2(0.0, 1.0);
            float2 param_5 = float2(w - 1.0, fast::max(0.89999997615814208984375, h - 1.0));
            _1127 = dialOval(param_4, param_5);
        }
        else
        {
            _1127 = 0.0;
        }
        float hollow = _1127;
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
    bool _1203 = mode == 1.0;
    bool _1212;
    if (!_1203)
    {
        _1212 = (mode == 6.0) && (style == 1.0);
    }
    else
    {
        _1212 = _1203;
    }
    if (_1212)
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
    bool _1264 = style == 2.0;
    bool _1270;
    if (_1264)
    {
        _1270 = m.x > 1.0;
    }
    else
    {
        _1270 = _1264;
    }
    if (_1270)
    {
        y_2 += 1.0;
    }
    return step(abs(m.x), width) * step(abs((m.y - y_2) + 0.5), 0.550000011920928955078125);
}

static inline __attribute__((always_inline))
float scoutDialInk(thread const float2& cell, thread const float& mode, thread const float& age, thread const float2& look, thread const float& style)
{
    float2 p = floor(cell) - float2(31.0, 24.0);
    bool _2093 = abs(p.x) > 26.0;
    bool _2100;
    if (!_2093)
    {
        _2100 = p.y < (-12.0);
    }
    else
    {
        _2100 = _2093;
    }
    bool _2107;
    if (!_2100)
    {
        _2107 = p.y > 12.0;
    }
    else
    {
        _2107 = _2100;
    }
    if (_2107)
    {
        return 0.0;
    }
    float t = fast::max(0.0, age);
    float _2117;
    if (mode == 6.0)
    {
        float param = t;
        float _2122 = dialSearch(param);
        _2117 = _2122;
    }
    else
    {
        _2117 = 0.0;
    }
    float turn = _2117;
    float blink = abs(mod((t + 0.670000016689300537109375) + (0.310000002384185791015625 * style), 5.349999904632568359375) - 0.180000007152557373046875);
    float _2139;
    if (mode == 4.0)
    {
        _2139 = 0.0;
    }
    else
    {
        float _2146;
        if (blink < 0.05200000107288360595703125)
        {
            _2146 = 0.0;
        }
        else
        {
            _2146 = (blink < 0.115000002086162567138671875) ? 0.449999988079071044921875 : 1.0;
        }
        _2139 = _2146;
    }
    float lid = _2139;
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
    float _2262;
    if (style < 1.5)
    {
        float2 param_6 = p;
        float param_7 = mode;
        float2 param_8 = gaze;
        float param_9 = lid;
        float param_10 = focus;
        float param_11 = turn;
        _2262 = dialBinocular(param_6, param_7, param_8, param_9, param_10, param_11);
    }
    else
    {
        float _2282;
        if (style < 2.5)
        {
            float2 param_12 = p;
            float param_13 = mode;
            float2 param_14 = gaze;
            float param_15 = lid;
            float param_16 = focus;
            float param_17 = turn;
            _2282 = dialWaypoint(param_12, param_13, param_14, param_15, param_16, param_17);
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
            _2282 = dialSweep(param_18, param_19, param_20, param_21, param_22, param_23, param_24);
        }
        _2262 = _2282;
    }
    float ink = _2262;
    float2 param_25 = p;
    float param_26 = mode;
    float param_27 = t;
    float param_28 = style;
    return fast::max(ink, dialMouth(param_25, param_26, param_27, param_28));
}

static inline __attribute__((always_inline))
float scoutLcdInk(thread const float2& cell, thread const float& age, thread const float2& look, constant NativeUniforms& U)
{
    if (U.outfit.z < 0.5)
    {
        float2 param = cell;
        float param_1 = U.pose.z;
        float param_2 = age;
        float2 param_3 = look;
        return scoutOriginalInk(param, param_1, param_2, param_3);
    }
    if (U.outfit.z > 3.5)
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
    float param_12 = U.outfit.z;
    return scoutDialInk(param_8, param_9, param_10, param_11, param_12);
}

static inline __attribute__((always_inline))
float scoutSmileDistance(thread const float2& p, thread const float& mode)
{
    float radius = (mode == 7.0) ? 3.7000000476837158203125 : 3.0;
    float2 q = float2(abs(p.x), (p.y + 11.6499996185302734375) - radius);
    float2 tip = float2(0.930000007152557373046875, -0.3680000007152557373046875) * radius;
    float _1053;
    if (dot(q, float2(0.3680000007152557373046875, 0.930000007152557373046875)) > 0.0)
    {
        _1053 = length(q - tip);
    }
    else
    {
        _1053 = abs(length(q) - radius);
    }
    return _1053;
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
    bool _6169 = abs(cell.x - 31.0) > 29.0;
    bool _6178;
    if (!_6169)
    {
        _6178 = abs(cell.y - 24.0) > 18.0;
    }
    else
    {
        _6178 = _6169;
    }
    if (_6178)
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
    bool _6277 = U.outfit.z < 0.5;
    bool _6297;
    if (_6277)
    {
        bool _6282 = U.pose.z == 0.0;
        bool _6289;
        if (!_6282)
        {
            _6289 = U.pose.z == 6.0;
        }
        else
        {
            _6289 = _6282;
        }
        bool _6296;
        if (!_6289)
        {
            _6296 = U.pose.z == 7.0;
        }
        else
        {
            _6296 = _6289;
        }
        _6297 = _6296;
    }
    else
    {
        _6297 = _6277;
    }
    bool _6304;
    if (_6297)
    {
        _6304 = abs(glyph.x) < 7.0;
    }
    else
    {
        _6304 = _6297;
    }
    bool _6310;
    if (_6304)
    {
        _6310 = glyph.y < (-6.0);
    }
    else
    {
        _6310 = _6304;
    }
    if (_6310)
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
float kitDigit(thread const float2& cell, thread const float& digit)
{
    bool _9449 = fast::min(cell.x, cell.y) < 0.0;
    bool _9456;
    if (!_9449)
    {
        _9456 = cell.x > 2.0;
    }
    else
    {
        _9456 = _9449;
    }
    bool _9463;
    if (!_9456)
    {
        _9463 = cell.y > 4.0;
    }
    else
    {
        _9463 = _9456;
    }
    if (_9463)
    {
        return 0.0;
    }
    float code;
    if (digit < 0.5)
    {
        code = 31599.0;
    }
    else
    {
        if (digit < 1.5)
        {
            code = 9879.0;
        }
        else
        {
            if (digit < 2.5)
            {
                code = 31183.0;
            }
            else
            {
                if (digit < 3.5)
                {
                    code = 31207.0;
                }
                else
                {
                    if (digit < 4.5)
                    {
                        code = 23524.0;
                    }
                    else
                    {
                        if (digit < 5.5)
                        {
                            code = 29671.0;
                        }
                        else
                        {
                            if (digit < 6.5)
                            {
                                code = 29679.0;
                            }
                            else
                            {
                                if (digit < 7.5)
                                {
                                    code = 30866.0;
                                }
                                else
                                {
                                    if (digit < 8.5)
                                    {
                                        code = 31727.0;
                                    }
                                    else
                                    {
                                        code = 31719.0;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return mod(floor(code / exp2((cell.y * 3.0) + cell.x)), 2.0);
}

static inline __attribute__((always_inline))
float kitNumeral(thread const float2& cell, thread const float2& origin, thread const float& digit)
{
    float2 param = floor((cell - origin) * 0.5);
    float param_1 = mod(digit, 10.0);
    return kitDigit(param, param_1);
}

static inline __attribute__((always_inline))
float kitRectPix(thread const float2& p, thread const float2& a, thread const float2& b)
{
    return ((step(a.x, p.x) * step(a.y, p.y)) * step(p.x, b.x)) * step(p.y, b.y);
}

static inline __attribute__((always_inline))
float kitInk(thread const float2& px, thread const float& style, thread const float& mode, thread const float& time, constant NativeUniforms& U)
{
    if (U.mechanics.w > 0.5)
    {
        float2 param = px;
        float param_1 = time;
        float2 param_2 = float2(0.0);
        return scoutLcdInk(param, param_1, param_2, U);
    }
    bool sleep = mode == 4.0;
    bool search = mode == 6.0;
    bool drive = mode == 7.0;
    bool scan = ((mode == 2.0) || (mode == 5.0)) || search;
    float _9602;
    if (sleep)
    {
        _9602 = 0.0;
    }
    else
    {
        _9602 = floor(fast::max(time, 0.0) * 3.0);
    }
    float tick = _9602;
    if (style < 5.5)
    {
        float _9617;
        if (drive)
        {
            _9617 = 83.0 - fast::min(floor(tick / 16.0), 2.0);
        }
        else
        {
            float _9629;
            if (mode == 5.0)
            {
                _9629 = 84.0 - fast::min(floor(tick / 5.0), 2.0);
            }
            else
            {
                float _9646;
                if (((mode == 3.0) || search) || (mode == 2.0))
                {
                    _9646 = 85.0;
                }
                else
                {
                    _9646 = (mode == 1.0) ? 87.0 : 86.0;
                }
                _9629 = _9646;
            }
            _9617 = _9629;
        }
        float charge = _9617;
        float2 param_3 = px;
        float2 param_4 = float2(1.0, 2.0);
        float param_5 = floor(charge / 10.0);
        float2 param_6 = px;
        float2 param_7 = float2(9.0, 2.0);
        float param_8 = charge;
        float k = fast::max(kitNumeral(param_3, param_4, param_5), kitNumeral(param_6, param_7, param_8));
        float2 param_9 = px;
        float2 param_10 = float2(18.0, 3.0);
        float2 param_11 = float2(23.0, 10.0);
        float2 param_12 = px;
        float2 param_13 = float2(19.0, 4.0);
        float2 param_14 = float2(22.0, 9.0);
        float body = kitRectPix(param_9, param_10, param_11) - kitRectPix(param_12, param_13, param_14);
        float2 param_15 = px;
        float2 param_16 = float2(20.0, 11.0);
        float2 param_17 = float2(21.0, 11.0);
        body = fast::max(body, kitRectPix(param_15, param_16, param_17));
        float2 param_18 = px;
        float2 param_19 = float2(19.0, 4.0);
        float2 param_20 = float2(22.0, 7.0 + step(86.0, charge));
        float fill = kitRectPix(param_18, param_19, param_20) * step(mod(px.y, 2.0), 0.100000001490116119384765625);
        return fast::max(k, fast::max(0.62000000476837158203125 * body, 0.930000007152557373046875 * fill)) * (sleep ? 0.540000021457672119140625 : 1.0);
    }
    if (style < 6.5)
    {
        float _9734;
        if (search)
        {
            _9734 = 60.0 + mod(tick, 37.0);
        }
        else
        {
            float _9744;
            if (drive)
            {
                _9744 = 20.0 + mod(floor(tick * 0.5), 32.0);
            }
            else
            {
                float _9755;
                if (mode == 5.0)
                {
                    _9755 = 92.0 + fast::min(tick, 7.0);
                }
                else
                {
                    float _9765;
                    if (mode == 2.0)
                    {
                        _9765 = 41.0 + fast::min(floor(tick * 0.5), 7.0);
                    }
                    else
                    {
                        float _9776;
                        if (mode == 1.0)
                        {
                            _9776 = 24.0;
                        }
                        else
                        {
                            float _9782;
                            if (mode == 3.0)
                            {
                                _9782 = 52.0;
                            }
                            else
                            {
                                _9782 = sleep ? 2.0 : 16.0;
                            }
                            _9776 = _9782;
                        }
                        _9765 = _9776;
                    }
                    _9755 = _9765;
                }
                _9744 = _9755;
            }
            _9734 = _9744;
        }
        float val = _9734;
        float2 param_21 = px;
        float2 param_22 = float2(1.0);
        float param_23 = 0.0;
        float2 param_24 = px;
        float2 param_25 = float2(9.0, 1.0);
        float param_26 = floor(val / 10.0);
        float2 param_27 = px;
        float2 param_28 = float2(17.0, 1.0);
        float param_29 = val;
        float k_1 = fast::max(kitNumeral(param_21, param_22, param_23), fast::max(kitNumeral(param_24, param_25, param_26), kitNumeral(param_27, param_28, param_29)));
        float2 param_30 = px;
        float2 param_31 = float2(25.0, 1.0);
        float2 param_32 = float2(25.0, 10.0);
        k_1 = fast::max(k_1, 0.23999999463558197021484375 * kitRectPix(param_30, param_31, param_32));
        bool _9832 = px.x >= 29.0;
        bool _9839;
        if (_9832)
        {
            _9839 = px.x <= 61.0;
        }
        else
        {
            _9839 = _9832;
        }
        if (_9839)
        {
            float x = px.x - 29.0;
            float marker = mod(tick + (mode * 4.0), 33.0);
            float wave = 4.0 + floor((0.5 + (1.35000002384185791015625 * sin(x * 0.319999992847442626953125))) + (0.680000007152557373046875 * sin(x * 0.790000021457672119140625)));
            wave += floor(((scan ? 4.0 : 2.0) * exp(((-0.11200000345706939697265625) * (x - 18.0)) * (x - 18.0))) + 0.5);
            float trace = (1.0 - step(0.5099999904632568359375, abs(px.y - wave))) * (scan ? 0.87999999523162841796875 : 0.699999988079071044921875);
            float2 param_33 = px;
            float2 param_34 = float2(29.0, 2.0);
            float2 param_35 = float2(61.0, 9.0);
            float cursor = (1.0 - step(0.5099999904632568359375, abs(x - marker))) * kitRectPix(param_33, param_34, param_35);
            float ticks = step(mod(x, 4.0), 0.100000001490116119384765625) * step(abs(px.y - 1.0), 0.100000001490116119384765625);
            k_1 = fast::max(k_1, fast::max(trace, fast::max(0.2800000011920928955078125 * cursor, 0.37999999523162841796875 * ticks)));
        }
        return k_1 * (sleep ? 0.4600000083446502685546875 : 1.0);
    }
    float _9934;
    if (drive)
    {
        _9934 = 27.0 + floor((4.0 * sin(tick * 0.180000007152557373046875)) + 0.5);
    }
    else
    {
        float _9946;
        if (search)
        {
            _9946 = 42.0 - fast::min(mod(tick, 18.0), 13.0);
        }
        else
        {
            float _9956;
            if (mode == 5.0)
            {
                _9956 = 31.0 - fast::min(tick, 5.0);
            }
            else
            {
                float _9965;
                if (mode == 2.0)
                {
                    _9965 = 35.0 - fast::min(floor(tick * 0.5), 3.0);
                }
                else
                {
                    float _9977;
                    if (mode == 1.0)
                    {
                        _9977 = 28.0;
                    }
                    else
                    {
                        float _9983;
                        if (mode == 3.0)
                        {
                            _9983 = 34.0;
                        }
                        else
                        {
                            _9983 = sleep ? 0.0 : 32.0;
                        }
                        _9977 = _9983;
                    }
                    _9965 = _9977;
                }
                _9956 = _9965;
            }
            _9946 = _9956;
        }
        _9934 = _9946;
    }
    float dist = _9934;
    float2 param_36 = px;
    float2 param_37 = float2(1.0);
    float param_38 = floor(dist / 10.0);
    float2 param_39 = px;
    float2 param_40 = float2(11.0, 1.0);
    float param_41 = dist;
    float k_2 = fast::max(kitNumeral(param_36, param_37, param_38), kitNumeral(param_39, param_40, param_41));
    float2 param_42 = px;
    float2 param_43 = float2(8.0, 1.0);
    float2 param_44 = float2(9.0, 2.0);
    k_2 = fast::max(k_2, kitRectPix(param_42, param_43, param_44));
    float2 param_45 = px;
    float2 param_46 = float2(1.0, 12.0);
    float2 param_47 = float2(17.0, 12.0);
    k_2 = fast::max(k_2, 0.319999992847442626953125 * kitRectPix(param_45, param_46, param_47));
    float2 aim = px - float2(9.0, 20.0);
    float ax = abs(aim.x);
    float ay = abs(aim.y);
    float2 param_48 = float2(ax, ay);
    float2 param_49 = float2(6.0, 3.0);
    float2 param_50 = float2(6.0, 5.0);
    float2 param_51 = float2(ax, ay);
    float2 param_52 = float2(4.0, 5.0);
    float2 param_53 = float2(6.0, 5.0);
    float bracket = fast::max(kitRectPix(param_48, param_49, param_50), kitRectPix(param_51, param_52, param_53));
    float2 param_54 = float2(ax, ay);
    float2 param_55 = float2(2.0, 0.0);
    float2 param_56 = float2(4.0, 0.0);
    float2 param_57 = float2(ax, ay);
    float2 param_58 = float2(0.0, 2.0);
    float2 param_59 = float2(0.0, 4.0);
    float crosshair = fast::max(kitRectPix(param_54, param_55, param_56), kitRectPix(param_57, param_58, param_59));
    float _10084;
    if (search)
    {
        _10084 = floor((2.0 * sin(tick * 0.4199999868869781494140625)) + 0.5);
    }
    else
    {
        float _10095;
        if (scan)
        {
            _10095 = fast::max(0.0, 2.0 - floor(tick * 0.5));
        }
        else
        {
            _10095 = 1.0;
        }
        _10084 = _10095;
    }
    float pos = _10084;
    float dotMark = (1.0 - step(0.4000000059604644775390625, abs(aim.x - pos))) * (1.0 - step(0.4000000059604644775390625, abs(aim.y)));
    return fast::max(k_2, fast::max(0.699999988079071044921875 * bracket, fast::max(0.689999997615814208984375 * crosshair, dotMark))) * (sleep ? 0.4600000083446502685546875 : 1.0);
}

static inline __attribute__((always_inline))
float3 kitScreen(thread const float3& p, thread const float3& view, thread const float& style, constant NativeUniforms& U)
{
    float param = style;
    float3 param_1;
    float3 param_2;
    float3 param_3;
    float3 param_4;
    float3 param_5;
    kitDisplayFrame(param, param_1, param_2, param_3, param_4, param_5);
    float3 center = param_1;
    float3 h = param_2;
    float3 front = param_3;
    float3 right = param_4;
    float3 up = param_5;
    float param_6 = style;
    float2 pos = float2(dot(p - center, right), dot(p - center, up) - kitWindowY(param_6));
    float facing = dot(view, front);
    if (facing < 0.03599999845027923583984375)
    {
        return float3(0.0130000002682209014892578125, 0.01400000043213367462158203125, 0.0130000002682209014892578125);
    }
    float param_7 = style;
    float2 win = kitWindow(param_7) - float2(0.008000000379979610443115234375);
    pos -= ((float2(dot(view, right), dot(view, up)) * 0.010999999940395355224609375) / float2(fast::max(facing, 0.1599999964237213134765625)));
    float param_8 = style;
    float2 param_9 = pos;
    float2 param_10 = win;
    float param_11 = kitWindowRadius(param_8) - 0.0040000001899898052215576171875;
    float inner = scRect(param_9, param_10, param_11);
    float3 color = float3(0.02500000037252902984619140625, 0.0199999995529651641845703125, 0.01400000043213367462158203125);
    if (inner < 0.0)
    {
        float2 _10219;
        if (U.mechanics.w > 0.5)
        {
            _10219 = float2(64.0, 48.0);
        }
        else
        {
            float2 _10228;
            if (style < 5.5)
            {
                _10228 = float2(25.0, 14.0);
            }
            else
            {
                _10228 = select(float2(19.0, 28.0), float2(64.0, 12.0), bool2(style < 6.5));
            }
            _10219 = _10228;
        }
        float2 grid = _10219;
        float2 g = (((pos * 0.5) / win) + float2(0.5)) * grid;
        float2 i = floor(g);
        float2 f = fract(g);
        float2 stepTo = (step(float2(0.5), f) * 2.0) - float2(1.0);
        float footprint = fast::clamp(118.0 / (fast::max(140.0, U.viewport.y) * fast::max(0.300000011920928955078125, facing)), 0.100000001490116119384765625, 0.7400000095367431640625);
        float2 blend = fast::clamp(float2(1.0) - (fast::min(f, float2(1.0) - f) / float2(footprint)), float2(0.0), float2(1.0)) * 0.5;
        float _10289;
        if (false)
        {
            _10289 = 0.800000011920928955078125;
        }
        else
        {
            _10289 = U.options.x;
        }
        float clock = _10289;
        float2 param_12 = i;
        float param_13 = style;
        float param_14 = U.pose.z;
        float param_15 = clock;
        float ia = kitInk(param_12, param_13, param_14, param_15, U);
        float2 param_16 = i + float2(stepTo.x, 0.0);
        float param_17 = style;
        float param_18 = U.pose.z;
        float param_19 = clock;
        float ix = kitInk(param_16, param_17, param_18, param_19, U);
        float2 param_20 = i + float2(0.0, stepTo.y);
        float param_21 = style;
        float param_22 = U.pose.z;
        float param_23 = clock;
        float iy = kitInk(param_20, param_21, param_22, param_23, U);
        float2 param_24 = i + stepTo;
        float param_25 = style;
        float param_26 = U.pose.z;
        float param_27 = clock;
        float ixy = kitInk(param_24, param_25, param_26, param_27, U);
        float ink = mix(mix(ia, ix, blend.x), mix(iy, ixy, blend.x), blend.y);
        float2 dotPos = abs(f - float2(0.5));
        float matrix = 1.0 - smoothstep(0.3400000035762786865234375, 0.5, fast::max(dotPos.x, dotPos.y));
        float detail = fast::clamp(((U.viewport.y * fast::max(0.300000011920928955078125, facing)) - 95.0) / 440.0, 0.100000001490116119384765625, 0.87999999523162841796875);
        float light = ink * mix(0.910000026226043701171875, 0.25 + (0.75 * matrix), detail);
        float vignette = smoothstep(0.0, 0.01400000043213367462158203125, -inner);
        color += (((float3(0.0030000000260770320892333984375, 0.00200000009499490261077880859375, 0.001000000047497451305389404296875) * matrix) + (float3(0.9900000095367431640625, 0.3400000035762786865234375, 0.0460000000894069671630859375) * light)) * vignette);
    }
    float3 r = reflect(-view, front);
    float reflection = powr(fast::max(0.0, dot(r, float3(-0.3172050416469573974609375, 0.71371138095855712890625, 0.62449741363525390625))), 12.0);
    float fres = 1.0 - fast::clamp(facing, 0.0, 1.0);
    fres *= fres;
    return color + (float3(0.0610000006854534149169921875, 0.0610000006854534149169921875, 0.05200000107288360595703125) * (reflection + (0.4799999892711639404296875 * fres)));
}

static inline __attribute__((always_inline))
float3 kitDisplaySurface(thread const float3& p, thread const float3& n, thread const float3& view, thread const float& material, thread const float& style, constant NativeUniforms& U)
{
    float param = style;
    float3 param_1;
    float3 param_2;
    float3 param_3;
    float3 param_4;
    float3 param_5;
    kitDisplayFrame(param, param_1, param_2, param_3, param_4, param_5);
    float3 center = param_1;
    float3 h = param_2;
    float3 front = param_3;
    float3 right = param_4;
    float3 up = param_5;
    float3 v = p - center;
    float3 q = float3(dot(v, right), dot(v, up), dot(v, front));
    float3 param_6 = float3(-0.550000011920928955078125, 0.7599999904632568359375, 0.4699999988079071044921875);
    float3 _10480 = worldToScout(param_6, U);
    float key = 0.319999992847442626953125 + (0.63999998569488525390625 * fast::max(dot(n, fast::normalize(_10480)), 0.0));
    float3 r = reflect(-view, n);
    float strip = exp((((-11.0) * (r.y - 0.61000001430511474609375)) * (r.y - 0.61000001430511474609375)) - ((3.400000095367431640625 * (r.x + 0.319999992847442626953125)) * (r.x + 0.319999992847442626953125)));
    float edge = 1.0 - fast::clamp(dot(n, view), 0.0, 1.0);
    if ((material > 111.5) && (material < 112.5))
    {
        if (dot(n, front) > 0.86000001430511474609375)
        {
            float3 param_7 = p;
            float3 param_8 = view;
            float param_9 = style;
            return kitScreen(param_7, param_8, param_9, U);
        }
        return (float3(0.017999999225139617919921875, 0.02199999988079071044921875, 0.02300000004470348358154296875) * key) + float3(0.0350000001490116119384765625 * strip);
    }
    if (material > 114.5)
    {
        return (float3(0.2800000011920928955078125, 0.119999997317790985107421875, 0.039999999105930328369140625) * key) + float3(0.04500000178813934326171875 * strip);
    }
    if (material > 113.5)
    {
        return ((float3(0.06800000369548797607421875, 0.0719999969005584716796875, 0.064999997615814208984375) * key) + float3(0.078000001609325408935546875 * strip)) + float3(0.01400000043213367462158203125 * edge);
    }
    if (material > 112.5)
    {
        return ((float3(0.25, 0.2800000011920928955078125, 0.2700000107288360595703125) * key) + float3(0.17000000178813934326171875 * strip)) + float3(0.037000000476837158203125 * edge);
    }
    if (material > 110.5)
    {
        return (float3(0.0430000014603137969970703125, 0.04500000178813934326171875, 0.041000001132488250732421875) * key) + float3(0.017999999225139617919921875 * strip);
    }
    float3 _10609;
    if (style < 5.5)
    {
        _10609 = float3(0.12999999523162841796875, 0.14499999582767486572265625, 0.12399999797344207763671875);
    }
    else
    {
        _10609 = select(float3(0.18600000441074371337890625, 0.1550000011920928955078125, 0.108000002801418304443359375), float3(0.115000002086162567138671875, 0.13799999654293060302734375, 0.15600000321865081787109375), bool3(style < 6.5));
    }
    float3 base = _10609;
    float3 col = (base * key) + float3((0.0719999969005584716796875 * strip) + (0.017999999225139617919921875 * edge));
    float nd = dot(n, front);
    if (abs(nd) > 0.819999992847442626953125)
    {
        float2 s = (abs(q.xy) - h.xy) + float2(0.02199999988079071044921875, 0.02300000004470348358154296875);
        float screw = length(s);
        float disk = 1.0 - smoothstep(0.006000000052154064178466796875, 0.00999999977648258209228515625, screw);
        col = mix(col, float3(0.2599999904632568359375, 0.2700000107288360595703125, 0.2430000007152557373046875) * (0.63999998569488525390625 + (0.2800000011920928955078125 * key)), float3(disk));
        col *= (1.0 - ((0.439999997615814208984375 * disk) * (1.0 - smoothstep(0.000600000028498470783233642578125, 0.0024999999441206455230712890625, abs(s.x + (0.4799999892711639404296875 * s.y))))));
    }
    if (nd < (-0.800000011920928955078125))
    {
        float2 param_10 = q.xy;
        float2 param_11 = h.xy - float2(0.014999999664723873138427734375);
        float param_12 = 0.017999999225139617919921875;
        float seam = abs(scRect(param_10, param_11, param_12));
        col *= (1.0 - (0.519999980926513671875 * (1.0 - smoothstep(0.001000000047497451305389404296875, 0.0040000001899898052215576171875, seam))));
        float2 uv = q.xy + float2(0.014999999664723873138427734375, 0.008000000379979610443115234375);
        float grille = step(abs(uv.x), h.x * 0.5) * step(abs(uv.y), h.y * 0.25);
        float grooves = 1.0 - smoothstep(0.001000000047497451305389404296875, 0.0040000001899898052215576171875, abs(fract(uv.y / 0.02099999971687793731689453125) - 0.5) * 0.02099999971687793731689453125);
        col *= (1.0 - ((0.4900000095367431640625 * grille) * grooves));
    }
    return col;
}

static inline __attribute__((always_inline))
bool kitDisplayLiveGlass(thread const float3& p, thread const float3& n, thread const float& id, thread const float& style)
{
    if ((id < 111.5) || (id > 112.5))
    {
        return false;
    }
    float param = style;
    float3 param_1;
    float3 param_2;
    float3 param_3;
    float3 param_4;
    float3 param_5;
    kitDisplayFrame(param, param_1, param_2, param_3, param_4, param_5);
    float3 c = param_1;
    float3 h = param_2;
    float3 f = param_3;
    float3 r = param_4;
    float3 u = param_5;
    return dot(n, f) > 0.980000019073486328125;
}

static inline __attribute__((always_inline))
float3 kitDisplayGlassRay(thread const float3& eye, thread const float3& ray, thread const float& style, constant NativeUniforms& U)
{
    float param = style;
    float3 param_1;
    float3 param_2;
    float3 param_3;
    float3 param_4;
    float3 param_5;
    kitDisplayFrame(param, param_1, param_2, param_3, param_4, param_5);
    float3 center = param_1;
    float3 h = param_2;
    float3 front = param_3;
    float3 right = param_4;
    float3 up = param_5;
    float t = ((h.z - 0.00999999977648258209228515625) - dot(eye - center, front)) / dot(ray, front);
    float3 param_6 = eye + (ray * t);
    float3 param_7 = -ray;
    float param_8 = style;
    return kitScreen(param_6, param_7, param_8, U);
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
float3 headFinish(thread const float3& p, thread const float3& n, thread const float3& v, thread const float& id, thread const float& style, thread const float& power, constant NativeUniforms& U)
{
    float3 m = float3(abs(p.x), p.yz);
    float3 param = select(m, p, bool3((style > 1.5) && (style < 2.5)));
    float param_1 = style;
    float3 q = hwPartFrame(param, param_1);
    float3 _7143;
    if ((style > 1.5) && (style < 2.5))
    {
        _7143 = v;
    }
    else
    {
        _7143 = float3(v.x * ((p.x < 0.0) ? (-1.0) : 1.0), v.yz);
    }
    float3 vm = _7143;
    float param_2 = style;
    float3 a = hwAxis(param_2);
    float3 ex = fast::normalize(float3(a.z, 0.0, -a.x));
    float3 ey = cross(a, ex);
    float3 eye = float3(dot(vm, ex), dot(vm, ey), dot(vm, a));
    float3 param_3 = float3(-0.5099999904632568359375, 0.89999997615814208984375, 0.680000007152557373046875);
    float3 _7191 = worldToScout(param_3, U);
    float light = fast::max(0.0, dot(n, fast::normalize(_7191)));
    float3 param_4 = reflect(-v, n);
    float3 reflected = scEnv(param_4);
    float rim = powr(1.0 - fast::clamp(dot(n, v), 0.0, 1.0), 3.0);
    float3 dark = (float3(0.0379999987781047821044921875, 0.0489999987185001373291015625, 0.0579999983310699462890625) * (0.569999992847442626953125 + (0.7200000286102294921875 * light))) + (reflected * (0.07400000095367431640625 + (0.085000000894069671630859375 * rim)));
    float3 nickel = (float3(0.090999998152256011962890625, 0.097999997437000274658203125, 0.101000003516674041748046875) * (0.63999998569488525390625 + (0.4799999892711639404296875 * light))) + (reflected * float3(0.61000001430511474609375, 0.660000026226043701171875, 0.699999988079071044921875));
    if (id < 20.5)
    {
        float param_5 = q.z + 0.0670000016689300537109375;
        float param_6 = 0.00200000009499490261077880859375;
        float param_7 = q.z + 0.090999998152256011962890625;
        float param_8 = 0.00200000009499490261077880859375;
        float fin = hwLine(param_5, param_6) + hwLine(param_7, param_8);
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
        float param_9 = r - 0.88999998569488525390625;
        float param_10 = 0.01200000010430812835693359375;
        float ring = hwLine(param_9, param_10);
        float3 cold = (float3(0.180000007152557373046875, 0.115999996662139892578125, 0.0599999986588954925537109375) * (0.310000002384185791015625 + (0.88999998569488525390625 * bowl))) + (reflected * ((0.119999997317790985107421875 + (0.189999997615814208984375 * ridge)) + (0.17000000178813934326171875 * rim)));
        cold += (float3(0.1040000021457672119140625, 0.07299999892711639404296875, 0.037000000476837158203125) * ring);
        float2 param_11 = parallax;
        float2 param_12 = float2(0.0, -0.070000000298023223876953125);
        float2 param_13 = float2(0.3300000131130218505859375, 0.14000000059604644775390625);
        float filament = hwSpot(param_11, param_12, param_13);
        float hot = ((0.23999999463558197021484375 + (0.689999997615814208984375 * bowl)) + (0.14000000059604644775390625 * ridge)) * (1.0 - (0.2800000011920928955078125 * smoothstep(0.790000021457672119140625, 1.0, r)));
        return cold + (((float3(1.36000001430511474609375, 0.68599998950958251953125, 0.24400000274181365966796875) * hot) + (float3(0.800000011920928955078125, 0.709999978542327880859375, 0.540000021457672119140625) * filament)) * power);
    }
    if (id < 23.5)
    {
        return (dark * 0.800000011920928955078125) + (nickel * 0.180000007152557373046875);
    }
    if (id < 24.5)
    {
        bool _7421 = eye.z > 0.0;
        bool _7428;
        if (_7421)
        {
            _7428 = q.z > (-0.007000000216066837310791015625);
        }
        else
        {
            _7428 = _7421;
        }
        if (_7428)
        {
            float2 screw = float2(abs(q.x) - 0.490999996662139892578125, q.y);
            float param_14 = length(screw) - 0.00999999977648258209228515625;
            float param_15 = 0.00200000009499490261077880859375;
            return mix(dark, nickel * 0.540000021457672119140625, float3(hwLine(param_14, param_15)));
        }
        float param_16 = q.z + 0.0379999987781047821044921875;
        float param_17 = 0.00200000009499490261077880859375;
        float param_18 = q.z + 0.06800000369548797607421875;
        float param_19 = 0.00200000009499490261077880859375;
        float fin_1 = hwLine(param_16, param_17) + hwLine(param_18, param_19);
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
        float param_20 = length(screw_1) - 0.00999999977648258209228515625;
        float param_21 = 0.001000000047497451305389404296875;
        float flash = hwLine(param_20, param_21);
        float param_22 = q.z + 0.0570000000298023223876953125;
        float param_23 = 0.0030000000260770320892333984375;
        float param_24 = q.z + 0.08900000154972076416015625;
        float param_25 = 0.0030000000260770320892333984375;
        float param_26 = q.z + 0.119999997317790985107421875;
        float param_27 = 0.0030000000260770320892333984375;
        float rib = (hwLine(param_22, param_23) + hwLine(param_24, param_25)) + hwLine(param_26, param_27);
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
    float2 param_28 = d_1;
    float2 param_29 = float2(-0.319999992847442626953125, 0.36000001430511474609375);
    float2 param_30 = float2(0.23000000417232513427734375, 0.115000002086162567138671875);
    float glint = hwSpot(param_28, param_29, param_30);
    float3 cold_2 = float3(0.01899999938905239105224609375, 0.0439999997615814208984375, 0.061999998986721038818359375) + (reflected * (0.14000000059604644775390625 + (0.439999997615814208984375 * rim)));
    cold_2 += ((float3(0.039999999105930328369140625, 0.083999998867511749267578125, 0.115000002086162567138671875) * ring_1) + (float3(0.180000007152557373046875, 0.2599999904632568359375, 0.300000011920928955078125) * glint));
    return cold_2 + (((float3(1.67999994754791259765625, 1.940000057220458984375, 2.099999904632568359375) * pupilCore) + ((float3(0.2800000011920928955078125, 0.5299999713897705078125, 0.670000016689300537109375) * (0.319999992847442626953125 + (0.589999973773956298828125 * ring_1))) * (1.0 - smoothstep(0.790000021457672119140625, 1.0, r_1)))) * power);
}

static inline __attribute__((always_inline))
float3 liftLampSurface(thread const float3& p, thread const float3& n, thread const float3& view, thread const float& id, thread const float& power, thread float& kitLift, constant NativeUniforms& U)
{
    float3 param = float3(-0.5099999904632568359375, 0.89999997615814208984375, 0.680000007152557373046875);
    float3 _8134 = worldToScout(param, U);
    float key = fast::max(0.0, dot(n, fast::normalize(_8134)));
    float3 param_1 = reflect(-view, n);
    float3 env = scEnv(param_1);
    if (id == 47.0)
    {
        float3 param_2 = p;
        float brush = scBrush(param_2, U);
        return ((float3(0.21699999272823333740234375, 0.2430000007152557373046875, 0.2599999904632568359375) * (0.60000002384185791015625 + (0.689999997615814208984375 * key))) + ((float3(0.579999983310699462890625, 0.62000000476837158203125, 0.660000026226043701171875) * env) * (0.790000021457672119140625 + (0.07500000298023223876953125 * brush)))) + (float3(0.02199999988079071044921875, 0.02099999971687793731689453125, 0.0199999995529651641845703125) * (0.5 + brush));
    }
    if (id < 41.5)
    {
        float2 sc = liftSinCos(kitLift);
        float2 d = p.yz - float2(0.4709999859333038330078125, 0.27799999713897705078125);
        float u = dot(d, sc);
        float w = dot(d, float2(-sc.y, sc.x));
        float param_3 = 2.0;
        float3 a = hwAxis(param_3);
        float3 virtualPoint = float3(p.x, (float2(0.509000003337860107421875, 0.5360000133514404296875) + (float2(a.z, -a.y) * (u - 0.07400000095367431640625))) + (a.yz * (3.0 * (w - 0.0315000005066394805908203125))));
        float3 param_4 = virtualPoint;
        float3 param_5 = n;
        float3 param_6 = view;
        float param_7 = (id < 40.5) ? 24.0 : 25.0;
        float param_8 = 2.0;
        float param_9 = power;
        return headFinish(param_4, param_5, param_6, param_7, param_8, param_9, U);
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
    bool _8459 = scoutRoofHit || (paint < 0.5);
    bool _8468;
    if (!_8459)
    {
        _8468 = (id != 1.0) && (id != 47.0);
    }
    else
    {
        _8468 = _8459;
    }
    if (_8468)
    {
        return stock;
    }
    bool shell = id == 1.0;
    bool ivory = (paint > 1.5) && (paint < 2.5);
    bool blue = paint >= 2.5;
    float3 reflection = reflect(-v, n);
    float3 param = reflection;
    float3 environment = scEnv(param);
    float3 param_1 = float3(-0.5099999904632568359375, 0.89999997615814208984375, 0.680000007152557373046875);
    float3 _8497 = worldToScout(param_1, U);
    float key = fast::max(dot(n, fast::normalize(_8497)), 0.0);
    float facing = fast::clamp(dot(n, v), 0.0, 1.0);
    float edge = 1.0 - facing;
    float diffuse = (((0.37999999523162841796875 + (0.14000000059604644775390625 * ((n.y * 0.5) + 0.5))) + (0.63999998569488525390625 * key)) + (0.064999997615814208984375 * fast::max(dot(n, float3(0.654892385005950927734375, 0.3929354250431060791015625, -0.64553678035736083984375)), 0.0))) * (0.87000000476837158203125 + (0.12999999523162841796875 * smoothstep(-0.20999999344348907470703125, 0.039999999105930328369140625, p.y)));
    diffuse *= mix(ivory ? 0.939999997615814208984375 : 0.7200000286102294921875, 1.0, smoothstep(-0.1599999964237213134765625, 0.430000007152557373046875, p.y));
    float3 _8544;
    if (ivory)
    {
        _8544 = float3(0.8849999904632568359375, 0.80400002002716064453125, 0.638000011444091796875);
    }
    else
    {
        _8544 = select(float3(0.7400000095367431640625, 0.014999999664723873138427734375, 0.017999999225139617919921875), float3(0.0089999996125698089599609375, 0.064999997615814208984375, 0.540000021457672119140625), bool3(blue));
    }
    float3 pigment = _8544;
    float _8559;
    if (ivory)
    {
        _8559 = 0.14200000464916229248046875;
    }
    else
    {
        _8559 = blue ? 0.0570000000298023223876953125 : 0.03599999845027923583984375;
    }
    float rough = _8559;
    float3 param_2 = reflection;
    float3 param_3 = float3(-0.711458265781402587890625, 0.58998978137969970703125, 0.38175809383392333984375);
    float2 param_4 = float2(0.560000002384185791015625, 0.2199999988079071044921875);
    float param_5 = rough;
    float first = kitPaintCard(param_2, param_3, param_4, param_5);
    float3 param_6 = p;
    float3 param_7 = reflection;
    float3 param_8 = float3(-0.7799999713897705078125, 1.40999996662139892578125, -2.2400000095367431640625);
    float2 param_9 = float2(0.800000011920928955078125, 0.1599999964237213134765625);
    float param_10 = rough * 3.7999999523162841796875;
    float rail = kitPaintPanel(param_6, param_7, param_8, param_9, param_10);
    float3 param_11 = p;
    float3 param_12 = reflection;
    float3 param_13 = float3(1.9500000476837158203125, -0.17000000178813934326171875, -1.90999996662139892578125);
    float2 param_14 = float2(0.5, 0.5099999904632568359375);
    float param_15 = 0.1500000059604644775390625 + (rough * 8.0);
    float side = kitPaintPanel(param_11, param_12, param_13, param_14, param_15);
    float3 param_16 = p;
    float3 param_17 = reflection;
    float3 param_18 = float3(2.25, 0.0599999986588954925537109375, 1.53999996185302734375);
    float2 param_19 = float2(0.2899999916553497314453125, 0.810000002384185791015625);
    float param_20 = 0.0350000001490116119384765625 + (rough * 3.599999904632568359375);
    float shoulder = kitPaintPanel(param_16, param_17, param_18, param_19, param_20);
    float3 cards = (float3(1.0, 0.930000007152557373046875, 0.86000001430511474609375) * ((1.059999942779541015625 * first) + (2.2200000286102294921875 * shoulder))) + (float3(0.89999997615814208984375, 0.959999978542327880859375, 1.0) * ((0.7599999904632568359375 * rail) + (0.300000011920928955078125 * side)));
    float fresnel = (((edge * edge) * edge) * edge) * edge;
    float _8663;
    if (ivory)
    {
        _8663 = 0.034000001847743988037109375;
    }
    else
    {
        _8663 = blue ? 0.056000001728534698486328125 : 0.0670000016689300537109375;
    }
    float3 spec = ((environment * 0.89999997615814208984375) + (cards * 3.650000095367431640625)) * _8663;
    spec += ((((environment * 0.680000007152557373046875) + (cards * 1.2999999523162841796875)) * fresnel) * (ivory ? 0.25 : 0.730000019073486328125));
    float3 coat = (pigment * diffuse) + spec;
    if (blue)
    {
        float3 cells = p * 68.0;
        float3 delta = fract(cells) - float3(0.5);
        float3 param_21 = floor(cells);
        float _8706 = kitPaintHash(param_21);
        float seed = _8706;
        float flake = (1.0 - smoothstep(0.119999997317790985107421875, 0.4900000095367431640625, length(delta))) * smoothstep(0.4600000083446502685546875, 0.920000016689300537109375, seed);
        float lod = fast::clamp((U.viewport.y - 140.0) / 540.0, 0.02500000037252902984619140625, 0.920000016689300537109375) * (0.300000011920928955078125 + (0.699999988079071044921875 * facing));
        float blueSheen = ((0.36000001430511474609375 * environment.z) + (0.23999999463558197021484375 * (first + side))) + (0.430000007152557373046875 * rail);
        coat += ((float3(0.01200000010430812835693359375, 0.064000003039836883544921875, 0.1870000064373016357421875) * blueSheen) + (((float3(0.100000001490116119384765625, 0.2599999904632568359375, 0.430000007152557373046875) * flake) * lod) * (0.10999999940395355224609375 + blueSheen)));
    }
    if (ivory && shell)
    {
        float2 param_22 = float2(p.z + 0.056000001728534698486328125, p.y - 0.10300000011920928955078125);
        float2 param_23 = float2(0.23700000345706939697265625, 0.097999997437000274658203125);
        float param_24 = 0.02199999988079071044921875;
        float grille = scRect(param_22, param_23, param_24);
        float inset = smoothstep(0.63999998569488525390625, 0.87999999523162841796875, abs(n.x)) * (1.0 - smoothstep(-0.0030000000260770320892333984375, 0.00200000009499490261077880859375, grille));
        coat = mix(coat, (float3(0.08699999749660491943359375, 0.10300000011920928955078125, 0.10999999940395355224609375) * (0.60000002384185791015625 + (0.5 * key))) + (spec * 0.75), float3(inset));
        float tab = (((1.0 - smoothstep(0.01600000075995922088623046875, 0.0199999995529651641845703125, abs(p.x - 0.5429999828338623046875))) * smoothstep(0.26800000667572021484375, 0.273999989032745361328125, p.z)) * (1.0 - smoothstep(0.5030000209808349609375, 0.510999977588653564453125, p.z))) * smoothstep(0.333000004291534423828125, 0.34700000286102294921875, p.y);
        coat = mix(coat, (float3(0.9049999713897705078125, 0.1550000011920928955078125, 0.017999999225139617919921875) * diffuse) + spec, float3(tab));
    }
    if (shell)
    {
        float3 param_25 = p;
        float param_26 = key;
        float3 param_27 = environment;
        float3 param_28 = stock;
        float relief = kitPaintRelief(param_25, param_26, param_27, param_28, U);
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
        bool _4540 = (p.y < (-0.17000000178813934326171875)) && (wx < (-0.134000003337860107421875));
        bool _4548;
        if (_4540)
        {
            _4548 = abs(n.x) > 0.61000001430511474609375;
        }
        else
        {
            _4548 = _4540;
        }
        if (_4548)
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
    if (U.mechanics.w > 0.5)
    {
        float2 g = (q / float2(0.0089999996125698089599609375, 0.007000000216066837310791015625)) + float2(32.0, 24.0);
        float2 param_3 = floor(g);
        float param_4 = U.options.x;
        float2 param_5 = float2(0.0);
        float ink = scoutLcdInk(param_3, param_4, param_5, U);
        float dotMask = 1.0 - smoothstep(0.3400000035762786865234375, 0.4900000095367431640625, fast::max(abs(fract(g).x - 0.5), abs(fract(g).y - 0.5)));
        return float3(0.0089999996125698089599609375, 0.01200000010430812835693359375, 0.014999999664723873138427734375) + ((float3(0.9900000095367431640625, 0.688000023365020751953125, 0.296999990940093994140625) * ink) * mix(0.7200000286102294921875, 1.0, dotMask));
    }
    float2 cell = floor((float2(q.x, -q.y) - float2(-0.2939999997615814208984375, -0.17599999904632568359375)) / float2(0.02099999971687793731689453125));
    float light = 0.0;
    bool _4908 = cell.x >= 0.0;
    bool _4914;
    if (_4908)
    {
        _4914 = cell.x < 19.0;
    }
    else
    {
        _4914 = _4908;
    }
    bool _4920;
    if (_4914)
    {
        _4920 = cell.y >= 0.0;
    }
    else
    {
        _4920 = _4914;
    }
    bool _4926;
    if (_4920)
    {
        _4926 = cell.y < 5.0;
    }
    else
    {
        _4926 = _4920;
    }
    bool _4933;
    if (_4926)
    {
        _4933 = mod(cell.x, 4.0) < 3.0;
    }
    else
    {
        _4933 = _4926;
    }
    if (_4933)
    {
        float param_6 = floor(cell.x / 4.0);
        float param_7 = U.pose.z;
        light = mod(floor(roofWord(param_6, param_7) / exp2(mod(cell.x, 4.0) + (3.0 * cell.y))), 2.0);
    }
    float2 map = q - float2(-0.06599999964237213134765625, -0.082999996840953826904296875);
    bool _4966 = abs(map.x) < 0.2240000069141387939453125;
    bool _4973;
    if (_4966)
    {
        _4973 = abs(map.y) < 0.082999996840953826904296875;
    }
    else
    {
        _4973 = _4966;
    }
    if (_4973)
    {
        float2 grid = abs(fract((map / float2(0.0540000014007091522216796875)) + float2(0.5)) - float2(0.5));
        light = fast::max(light, 0.05200000107288360595703125 * (1.0 - smoothstep(0.0199999995529651641845703125, 0.12999999523162841796875, fast::min(grid.x, grid.y))));
        float route = (0.02700000070035457611083984375 * sin(17.0 * map.x)) + (0.01400000043213367462158203125 * sin(36.0 * map.x));
        float _5013;
        if (U.pose.z == 7.0)
        {
            _5013 = (-0.1599999964237213134765625) + (0.319999992847442626953125 * fract(U.options.x / 3.2000000476837158203125));
        }
        else
        {
            _5013 = 0.08699999749660491943359375;
        }
        float x = _5013;
        float2 marker = map - float2(x, (0.02700000070035457611083984375 * sin(17.0 * x)) + (0.01400000043213367462158203125 * sin(36.0 * x)));
        light = fast::max(light, fast::max(0.430000007152557373046875 * (1.0 - smoothstep(0.00200000009499490261077880859375, 0.007000000216066837310791015625, abs(map.y - route))), 1.0 - smoothstep(0.010999999940395355224609375, 0.01899999938905239105224609375, length(marker))));
    }
    float2 b = abs(q - float2(0.23000000417232513427734375, 0.1270000040531158447265625));
    float frame = fast::max(b.x - 0.05900000035762786865234375, b.y - 0.0309999994933605194091796875);
    light = fast::max(light, 0.63999998569488525390625 * (1.0 - smoothstep(0.00200000009499490261077880859375, 0.006000000052154064178466796875, abs(frame))));
    bool _5079 = b.x < 0.0460000000894069671630859375;
    bool _5085;
    if (_5079)
    {
        _5085 = b.y < 0.017999999225139617919921875;
    }
    else
    {
        _5085 = _5079;
    }
    if (_5085)
    {
        light = fast::max(light, 0.86000001430511474609375 * step(0.25, fract((q.x - 0.17000000178813934326171875) / 0.02999999932944774627685546875)));
    }
    return (float3(0.0089999996125698089599609375, 0.01200000010430812835693359375, 0.014999999664723873138427734375) + float3(0.0170000009238719940185546875 * powr(1.0 - abs(v.y), 2.0))) + (float3(0.9900000095367431640625, 0.688000023365020751953125, 0.296999990940093994140625) * light);
}

static inline __attribute__((always_inline))
float3 scHousing(thread const float3& p, thread const float3& n, thread const float3& v, thread const float& id, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread bool& scoutRoofHit, constant NativeUniforms& U)
{
    float3 param = float3(-0.5099999904632568359375, 0.89999997615814208984375, 0.680000007152557373046875);
    float3 _5113 = worldToScout(param, U);
    float3 light = fast::normalize(_5113);
    float key = fast::max(dot(n, light), 0.0);
    float facing = fast::clamp(dot(n, v), 0.0, 1.0);
    float3 ref = reflect(-v, n);
    float3 param_1 = ref;
    float3 env = scEnv(param_1);
    float3 param_2 = p;
    float brush = scBrush(param_2, U);
    float ao = 0.7599999904632568359375 + (0.23999999463558197021484375 * smoothstep(-0.20999999344348907470703125, 0.0, p.y));
    float3 metal = ((float3(0.21699999272823333740234375, 0.2430000007152557373046875, 0.2599999904632568359375) * (0.60000002384185791015625 + (0.689999997615814208984375 * key))) + ((float3(0.579999983310699462890625, 0.62000000476837158203125, 0.660000026226043701171875) * env) * (0.790000021457672119140625 + (0.07500000298023223876953125 * brush)))) * ao;
    metal += (float3(0.02199999988079071044921875, 0.02099999971687793731689453125, 0.0199999995529651641845703125) * (0.5 + brush));
    if (scKitOn && (id >= 10.0))
    {
        float3 param_3 = p;
        float3 param_4 = n;
        float3 param_5 = v;
        float param_6 = id;
        float3 param_7 = metal;
        float3 param_8 = env;
        float param_9 = key;
        return scKitChassisFinish(param_3, param_4, param_5, param_6, param_7, param_8, param_9, scKitRoll, scKitYawCS);
    }
    if (id < 1.5)
    {
        if (abs(n.x) > 0.60000002384185791015625)
        {
            float2 s = float2(p.z, p.y);
            float2 param_10 = s - float2(-0.017999999225139617919921875, 0.138999998569488525390625);
            float2 param_11 = float2(0.3120000064373016357421875, 0.20499999821186065673828125);
            float param_12 = 0.0460000000894069671630859375;
            float panel = scRect(param_10, param_11, param_12);
            float param_13 = panel;
            float param_14 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.4199999868869781494140625 * scDash(param_13, param_14)));
            bool _5228 = s.x < 0.18899999558925628662109375;
            bool _5235;
            if (_5228)
            {
                _5235 = s.x > (-0.2899999916553497314453125);
            }
            else
            {
                _5235 = _5228;
            }
            bool _5242;
            if (_5235)
            {
                _5242 = s.y > (-0.0030000000260770320892333984375);
            }
            else
            {
                _5242 = _5235;
            }
            bool _5248;
            if (_5242)
            {
                _5248 = s.y < 0.20999999344348907470703125;
            }
            else
            {
                _5248 = _5242;
            }
            if (_5248)
            {
                float k = floor(((s.x + 0.2290000021457672119140625) / 0.076999999582767486572265625) + 0.5);
                float2 l = s - float2((-0.2290000021457672119140625) + (k * 0.076999999582767486572265625), 0.092000000178813934326171875);
                l.x += (0.3300000131130218505859375 * l.y);
                float2 param_15 = l;
                float2 param_16 = float2(0.01400000043213367462158203125, 0.07299999892711639404296875);
                float param_17 = 0.01200000010430812835693359375;
                float hole = scRect(param_15, param_16, param_17);
                metal *= (1.0 - (0.7599999904632568359375 * (1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, hole))));
                float param_18 = hole - 0.007000000216066837310791015625;
                metal += (float3(0.0810000002384185791015625) * scTick(param_18));
            }
            float2 badge = s - float2(0.10300000011920928955078125, 0.2759999930858612060546875);
            float2 param_19 = badge;
            float2 param_20 = float2(0.104999996721744537353515625, 0.0170000009238719940185546875);
            float param_21 = 0.007000000216066837310791015625;
            float mark = scRect(param_19, param_20, param_21);
            metal = mix(metal, float3(0.7599999904632568359375, 0.134000003337860107421875, 0.02300000004470348358154296875) * (0.60000002384185791015625 + (0.449999988079071044921875 * key)), float3(1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, mark)));
        }
        if (n.y > 0.75)
        {
            float2 s_1 = float2(p.x, p.z + 0.0949999988079071044921875);
            s_1.x -= 0.097999997437000274658203125;
            float2 param_22 = s_1;
            float2 param_23 = float2(0.351000010967254638671875, 0.21699999272823333740234375);
            float param_24 = 0.0390000008046627044677734375;
            if (scRect(param_22, param_23, param_24) < 0.0)
            {
                scoutRoofHit = true;
                float2 param_25 = s_1;
                float3 param_26 = v;
                return roofNavigation(param_25, param_26, U);
            }
            float2 screw = float2(abs(p.x) - 0.48500001430511474609375, abs(p.z + 0.004999999888241291046142578125) - 0.305000007152557373046875);
            float rad = length(screw);
            float param_27 = rad - 0.02199999988079071044921875;
            float param_28 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.569999992847442626953125 * scDash(param_27, param_28)));
            float param_29 = screw.x + (0.5 * screw.y);
            float param_30 = 0.00200000009499490261077880859375;
            metal *= (1.0 - ((0.62000000476837158203125 * scDash(param_29, param_30)) * (1.0 - smoothstep(0.01400000043213367462158203125, 0.017999999225139617919921875, rad))));
        }
        if (n.z < (-0.64999997615814208984375))
        {
            float2 s_2 = p.xy - float2(0.0, 0.1459999978542327880859375);
            float2 param_31 = s_2;
            float2 param_32 = float2(0.4650000035762786865234375, 0.20900000631809234619140625);
            float param_33 = 0.05200000107288360595703125;
            float door = scRect(param_31, param_32, param_33);
            float param_34 = door;
            float param_35 = 0.0030000000260770320892333984375;
            metal *= (1.0 - (0.5099999904632568359375 * scDash(param_34, param_35)));
            bool _5435 = abs(s_2.x) < 0.2989999949932098388671875;
            bool _5443;
            if (_5435)
            {
                _5443 = abs(s_2.y) < 0.13099999725818634033203125;
            }
            else
            {
                _5443 = _5435;
            }
            if (_5443)
            {
                float2 uv = s_2 - float2(0.0, 0.01600000075995922088623046875);
                float line = floor(((uv.y + 0.083999998867511749267578125) / 0.0430000014603137969970703125) + 0.5);
                float2 param_36 = uv - float2(0.0, (-0.083999998867511749267578125) + (0.0430000014603137969970703125 * line));
                float2 param_37 = float2(0.2610000073909759521484375, 0.0089999996125698089599609375);
                float param_38 = 0.006000000052154064178466796875;
                float vent = scRect(param_36, param_37, param_38);
                metal *= (1.0 - (0.689999997615814208984375 * (1.0 - smoothstep(-0.00200000009499490261077880859375, 0.00200000009499490261077880859375, vent))));
            }
            float2 tailLamp = s_2 - float2(sign(s_2.x) * 0.3689999878406524658203125, -0.14699999988079071044921875);
            float2 param_39 = tailLamp;
            float2 param_40 = float2(0.034000001847743988037109375, 0.01200000010430812835693359375);
            float param_41 = 0.006000000052154064178466796875;
            float tape = scRect(param_39, param_40, param_41);
            metal = mix(metal, float3(0.7799999713897705078125, 0.125, 0.0350000001490116119384765625), float3(1.0 - smoothstep(-0.001000000047497451305389404296875, 0.0030000000260770320892333984375, tape)));
            float2 screw_1 = abs(s_2) - float2(0.3919999897480010986328125, 0.14200000464916229248046875);
            float r = length(screw_1);
            float param_42 = r - 0.02199999988079071044921875;
            float param_43 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.4799999892711639404296875 * scDash(param_42, param_43)));
            float param_44 = screw_1.x - screw_1.y;
            float param_45 = 0.00200000009499490261077880859375;
            metal *= (1.0 - ((0.540000021457672119140625 * scDash(param_44, param_45)) * (1.0 - smoothstep(0.01200000010430812835693359375, 0.0170000009238719940185546875, r))));
        }
        return metal;
    }
    if (id < 2.5)
    {
        float2 s_3 = p.xy - float2(0.0, 0.1550000011920928955078125);
        float2 param_46 = s_3;
        float2 param_47 = float2(0.5490000247955322265625, 0.24199999868869781494140625);
        float param_48 = 0.0610000006854534149169921875;
        float trim = scRect(param_46, param_47, param_48);
        float3 frame = (float3(0.041000001132488250732421875, 0.05200000107288360595703125, 0.064999997615814208984375) * (0.60000002384185791015625 + (0.430000007152557373046875 * key))) + (env * 0.07999999821186065673828125);
        if (n.z > 0.449999988079071044921875)
        {
            float param_49 = trim;
            float param_50 = 0.00150000001303851604461669921875;
            frame += (float3(0.063000001013278961181640625, 0.0570000000298023223876953125, 0.046999998390674591064453125) * scDash(param_49, param_50));
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
        float3 param_51 = p;
        float param_52 = precise::atan2(w.x, w.y);
        float a = scKitWheelAngle(param_51, param_52, scKitRoll);
        float rim = abs(p.x) - 0.653999984264373779296875;
        float striation = 0.540000021457672119140625 + (0.4600000083446502685546875 * cos((24.0 * a) + (4.400000095367431640625 * abs(rim / 0.14499999582767486572265625))));
        float3 color = (float3(0.02099999971687793731689453125, 0.026000000536441802978515625, 0.02899999916553497314453125) * (0.800000011920928955078125 + (0.589999973773956298828125 * key))) + (float3(0.0170000009238719940185546875) * env);
        color *= (0.88999998569488525390625 + (0.10999999940395355224609375 * striation));
        if (rim > 0.0949999988079071044921875)
        {
            float param_53 = r_2 - 0.21199999749660491943359375;
            float param_54 = 0.0040000001899898052215576171875;
            color *= (1.0 - (0.2800000011920928955078125 * scDash(param_53, param_54)));
            float param_55 = r_2 - 0.2339999973773956298828125;
            float param_56 = 0.001000000047497451305389404296875;
            color += (float3(0.00999999977648258209228515625) * scDash(param_55, param_56));
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
        bool _5807 = abs(p.x) > 0.709999978542327880859375;
        bool _5814;
        if (_5807)
        {
            _5814 = p.y < (-0.180000007152557373046875);
        }
        else
        {
            _5814 = _5807;
        }
        if (_5814)
        {
            float2 w_1 = float2(p.y + 0.47200000286102294921875, abs(p.z) - 0.4309999942779541015625);
            float r_3 = length(w_1);
            float3 param_57 = p;
            float param_58 = precise::atan2(w_1.x, w_1.y);
            float a_1 = scKitWheelAngle(param_57, param_58, scKitRoll);
            float holes = length(float2(r_3 - 0.1040000021457672119140625, sin(a_1 * 3.0) * 0.115000002086162567138671875)) - 0.01899999938905239105224609375;
            metal = mix(metal, float3(0.034000001847743988037109375, 0.039999999105930328369140625, 0.041000001132488250732421875), float3(1.0 - smoothstep(-0.00200000009499490261077880859375, 0.0030000000260770320892333984375, holes)));
            float param_59 = r_3 - 0.14200000464916229248046875;
            float param_60 = 0.00200000009499490261077880859375;
            metal *= (1.0 - (0.3400000035762786865234375 * scDash(param_59, param_60)));
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
float3 liftLampOrigin(thread const float& side, thread float& kitLift)
{
    float2 sc = liftSinCos(kitLift);
    float2 up = float2(sc.x, sc.y);
    float2 front = float2(-sc.y, sc.x);
    return float3(0.23700000345706939697265625 * side, (float2(0.4709999859333038330078125, 0.27799999713897705078125) + (up * 0.07400000095367431640625)) + (front * 0.0315000005066394805908203125));
}

static inline __attribute__((always_inline))
float3 studyLampOrigin(thread const float& style, thread const float& side, thread float& kitLift)
{
    float3 _10830;
    if (style >= 3.5)
    {
        float param = side;
        _10830 = liftLampOrigin(param, kitLift);
    }
    else
    {
        float param_1 = style;
        float param_2 = side;
        _10830 = headOrigin(param_1, param_2);
    }
    return _10830;
}

static inline __attribute__((always_inline))
float3 headTint(thread float& style)
{
    if (style >= 3.5)
    {
        style = 2.0;
    }
    if (style < 1.5)
    {
        return float3(1.0, 0.660000026226043701171875, 0.3499999940395355224609375);
    }
    if (style < 2.5)
    {
        return float3(0.88999998569488525390625, 0.949999988079071044921875, 1.0);
    }
    return float3(0.670000016689300537109375, 0.839999973773956298828125, 1.0);
}

static inline __attribute__((always_inline))
float3 headBounce(thread const float3& p, thread const float3& n, thread const float& style, thread const float& power, thread float& kitLift)
{
    if ((style < 0.5) || (power <= 0.0))
    {
        return float3(0.0);
    }
    float transport = 0.0;
    for (int k = 0; k < 2; k++)
    {
        float side = (k == 0) ? (-1.0) : 1.0;
        float param = style;
        float param_1 = side;
        float3 src = studyLampOrigin(param, param_1, kitLift);
        float3 toward = src - p;
        float d2 = fast::max(9.9999997473787516355514526367188e-05, dot(toward, toward));
        float local = fast::max(0.0, dot(n, toward) * rsqrt(d2));
        transport += ((0.0199999995529651641845703125 * local) * exp((-12.0) * d2));
        float3 toFloor = float3(src.x + (0.119999997317790985107421875 * side), -0.767000019550323486328125, src.z + 1.10000002384185791015625) - p;
        float f2 = dot(toFloor, toFloor);
        transport += (((0.0240000002086162567138671875 * fast::max(0.0, dot(n, toFloor))) * rsqrt(f2)) / (1.0 + f2));
    }
    float param_2 = style;
    float3 _11191 = headTint(param_2);
    return (_11191 * transport) * power;
}

static inline __attribute__((always_inline))
float3 liftLampAxis(thread float& kitLift)
{
    float2 sc = liftSinCos(kitLift);
    return float3(0.0, (float2(-sc.y, sc.x) * 0.995874106884002685546875) - (float2(sc.x, sc.y) * 0.09074600040912628173828125));
}

static inline __attribute__((always_inline))
float3 studyGlare(thread const float3& eye, thread const float3& ray, thread const float& depth, thread const float& style, thread const float& power, thread float& kitLift)
{
    float3 glow = float3(0.0);
    if ((style < 0.5) || (power <= 0.0))
    {
        return glow;
    }
    float3 _11402;
    for (int i = 0; i < 2; i++)
    {
        float side = (float(i) * 2.0) - 1.0;
        float param = style;
        float param_1 = side;
        float3 light = studyLampOrigin(param, param_1, kitLift);
        if (((style > 1.5) && (style < 2.5)) || (style >= 3.5))
        {
            float t = dot(light - eye, ray);
            light.x += fast::clamp((eye + (ray * t)).x - light.x, -0.20000000298023223876953125, 0.20000000298023223876953125);
        }
        float3 d = light - eye;
        float along = dot(d, ray);
        bool _11383 = along <= 0.0;
        bool _11391;
        if (!_11383)
        {
            _11391 = along > (depth + 0.115000002086162567138671875);
        }
        else
        {
            _11391 = _11383;
        }
        if (_11391)
        {
            continue;
        }
        if (style >= 3.5)
        {
            _11402 = liftLampAxis(kitLift);
        }
        else
        {
            _11402 = fast::normalize(float3(0.039999999105930328369140625 * side, -0.12999999523162841796875, 1.0));
        }
        float facing = smoothstep(0.0199999995529651641845703125, 0.920000016689300537109375, dot(fast::normalize(eye - light), _11402));
        float3 sep = d - (ray * along);
        float r2 = dot(sep, sep);
        float radius = (((style > 1.5) && (style < 2.5)) || (style >= 3.5)) ? 0.061999998986721038818359375 : 0.104999996721744537353515625;
        float param_2 = style;
        float3 _11437 = headTint(param_2);
        glow += (((_11437 * ((0.061999998986721038818359375 * exp(((-2.0) * r2) / (radius * radius))) + (0.0089999996125698089599609375 * exp((-20.0) * r2)))) * power) * facing);
    }
    return glow;
}

static inline __attribute__((always_inline))
float nativeShadow(thread const float2& uv, thread const float& style, thread bool& scKitOn, thread float& scKitRoll, thread float2& scKitYawCS, thread float& kitLift, constant NativeUniforms& U)
{
    bool _11466 = U.mechanics.y < 0.5;
    bool _11473;
    if (!_11466)
    {
        _11473 = length(uv) > 3.599999904632568359375;
    }
    else
    {
        _11473 = _11466;
    }
    if (_11473)
    {
        return 0.0;
    }
    float3 param = float3(uv.x, -0.767000019550323486328125, uv.y);
    float3 _11484 = scoutPoint(param, U);
    float3 p = _11484;
    float3 param_1 = float3(-0.5099999904632568359375, 0.89999997615814208984375, 0.680000007152557373046875);
    float3 _11487 = worldToScout(param_1, U);
    float3 light = fast::normalize(_11487);
    float t = 0.02199999988079071044921875;
    float visibility = 1.0;
    for (int i = 0; i < 32; i++)
    {
        float3 param_2 = p + (light * t);
        float param_3 = style;
        float d = studySDF(param_2, param_3, scKitOn, scKitRoll, scKitYawCS, kitLift).x;
        if (d < 0.00179999996908009052276611328125)
        {
            return 0.4199999868869781494140625;
        }
        visibility = fast::min(visibility, (10.0 * d) / fast::max(t, 0.0199999995529651641845703125));
        t += fast::max(0.01200000010430812835693359375, d * 0.85000002384185791015625);
        if (t > 4.19999980926513671875)
        {
            break;
        }
    }
    return 0.4199999868869781494140625 * (1.0 - fast::clamp(visibility, 0.0, 1.0));
}

static inline __attribute__((always_inline))
float3 liftLampReferenceDirection(thread const float3& world, thread float& kitLift)
{
    float3 axis = liftLampAxis(kitLift);
    float param = 2.0;
    float3 reference = hwAxis(param);
    float up = dot(world.yz, float2(axis.z, -axis.y));
    return float3(world.x, (float2(reference.z, -reference.y) * up) + (reference.yz * dot(world, axis)));
}

static inline __attribute__((always_inline))
float sfLobe(thread const float2& angle, thread const float2& width)
{
    float2 q = angle / width;
    return exp(-dot(q, q));
}

static inline __attribute__((always_inline))
float sfCandela(thread const float3& ray, thread const float& style, thread const float& side)
{
    float _10879;
    if (style < 1.5)
    {
        _10879 = 0.20499999821186065673828125;
    }
    else
    {
        _10879 = (style < 2.5) ? 0.4799999892711639404296875 : 0.20000000298023223876953125;
    }
    float skirtGain = _10879;
    float down = fast::max(-ray.y, 0.0);
    float skirt = (((skirtGain * down) * down) * down) * smoothstep(-0.2800000011920928955078125, 0.4199999868869781494140625, ray.z);
    if (ray.z <= 0.008000000379979610443115234375)
    {
        return skirt;
    }
    float2 slope = float2(ray.x, -ray.y) / float2(fast::max(ray.z, 0.07500000298023223876953125));
    float candela;
    if (style < 1.5)
    {
        float x = slope.x - (side * 0.0900000035762786865234375);
        float2 param = float2(x, slope.y - 0.23000000417232513427734375);
        float2 param_1 = float2(0.3400000035762786865234375, 0.23499999940395355224609375);
        float hot = sfLobe(param, param_1);
        float2 param_2 = float2(x, slope.y - 0.38999998569488525390625);
        float2 param_3 = float2(0.7200000286102294921875, 0.4699999988079071044921875);
        float spread = sfLobe(param_2, param_3);
        float2 param_4 = float2(x, slope.y - 0.939999997615814208984375);
        float2 param_5 = float2(1.12000000476837158203125, 0.589999973773956298828125);
        float apron = sfLobe(param_4, param_5);
        candela = ((10.30000019073486328125 * hot) + (3.0499999523162841796875 * spread)) + (0.3300000131130218505859375 * apron);
    }
    else
    {
        if (style < 2.5)
        {
            float x_1 = slope.x - (side * 0.0900000035762786865234375);
            float2 param_6 = float2(x_1, slope.y - 0.300000011920928955078125);
            float2 param_7 = float2(0.910000026226043701171875, 0.13500000536441802978515625);
            float fan = sfLobe(param_6, param_7);
            float2 param_8 = float2(x_1, slope.y - 0.550000011920928955078125);
            float2 param_9 = float2(1.08000004291534423828125, 0.310000002384185791015625);
            float fill = sfLobe(param_8, param_9);
            float2 param_10 = float2(x_1, slope.y - 0.939999997615814208984375);
            float2 param_11 = float2(1.2200000286102294921875, 0.4900000095367431640625);
            float apron_1 = sfLobe(param_10, param_11);
            float cutoff = smoothstep(0.1879999935626983642578125, 0.319999992847442626953125, slope.y + (0.01200000010430812835693359375 * abs(x_1)));
            candela = (((15.3999996185302734375 * fan) * cutoff) + (5.150000095367431640625 * fill)) + (1.12000000476837158203125 * apron_1);
        }
        else
        {
            float x_2 = slope.x - (side * 0.04500000178813934326171875);
            float2 param_12 = float2(x_2, slope.y - 0.21199999749660491943359375);
            float2 param_13 = float2(0.09399999678134918212890625, 0.07500000298023223876953125);
            float core = sfLobe(param_12, param_13);
            float2 param_14 = float2(x_2, slope.y - 0.314999997615814208984375);
            float2 param_15 = float2(0.17299999296665191650390625, 0.125);
            float shoulder = sfLobe(param_14, param_15);
            float2 param_16 = float2(x_2, slope.y - 0.579999983310699462890625);
            float2 param_17 = float2(0.439999997615814208984375, 0.3300000131130218505859375);
            float spill = sfLobe(param_16, param_17);
            float cutoff_1 = smoothstep(0.14699999988079071044921875, 0.208000004291534423828125, slope.y);
            candela = (((82.0 * core) * cutoff_1) + (11.19999980926513671875 * shoulder)) + (1.559999942779541015625 * spill);
        }
    }
    return (candela * smoothstep(0.008000000379979610443115234375, 0.189999997615814208984375, ray.z)) + skirt;
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
    bool pipGlassHit = false;
    float kitLift = 1.0;
    float2 pixel = float2(gl_FragCoord.x, U.viewport.y - gl_FragCoord.y) / float2(U.viewport.w);
    float2 uv = (pixel - U.receiver.xy) / float2(U.viewport.z);
    float style = U.outfit.x;
    bool kit = style >= 3.5;
    kitLift = U.mechanics.x;
    float param = float(kit);
    float param_1 = U.pose.z;
    float param_2 = U.options.x;
    scKitPose(param, param_1, param_2, scKitOn, scKitRoll, scKitYawCS, U);
    float _11591;
    if (kit)
    {
        _11591 = liftLampGain(kitLift);
    }
    else
    {
        _11591 = 1.0;
    }
    float power = U.outfit.w * _11591;
    if (style < 0.5)
    {
        power = 0.0;
    }
    float2 param_3 = uv;
    float2 param_4 = float2(0.0);
    float3 param_5;
    float3 param_6;
    scCamera(param_3, param_4, param_5, param_6, U);
    float3 ro = param_5;
    float3 rd = param_6;
    float along = dot(ro, rd);
    float disc = ((along * along) - dot(ro, ro)) + 3.2400000095367431640625;
    float depth = 10000.0;
    float2 hit = float2(0.0);
    if ((U.receiver.w != 1.0) && (disc > 0.0))
    {
        float t = fast::max(0.0, (-along) - sqrt(disc));
        float end = (-along) + sqrt(disc);
        for (int i = 0; i < 112; i++)
        {
            float3 param_7 = ro + (rd * t);
            float param_8 = style;
            float2 probe = studySDF(param_7, param_8, scKitOn, scKitRoll, scKitYawCS, kitLift);
            if (probe.x < 0.000750000006519258022308349609375)
            {
                hit = probe;
                depth = t;
                break;
            }
            t += fast::max(0.0004199999966658651828765869140625, probe.x * 0.7400000095367431640625);
            if (t > end)
            {
                break;
            }
        }
    }
    float3 color = float3(0.0);
    float coverage = float(hit.y > 0.5);
    if (coverage > 0.0)
    {
        float3 p = ro + (rd * depth);
        float3 param_9 = p;
        float param_10 = style;
        float3 n = studyNormal(param_9, param_10, scKitOn, scKitRoll, scKitYawCS, kitLift);
        float3 v = -rd;
        bool _11720 = hit.y == 3.0;
        bool _11726;
        if (_11720)
        {
            _11726 = n.z > 0.939999997615814208984375;
        }
        else
        {
            _11726 = _11720;
        }
        if (_11726)
        {
            float param_11 = U.pose.z;
            float3 param_12 = p + (v * ((0.515999972820281982421875 - p.z) / v.z));
            float3 param_13 = v;
            float param_14 = scKitFaceMode(param_11);
            float param_15 = U.options.x;
            float2 param_16 = float2(0.0);
            color = scLCD(param_12, param_13, param_14, param_15, param_16, U);
        }
        else
        {
            if (hit.y >= 110.0)
            {
                float3 param_17 = p;
                float3 param_18 = n;
                float3 param_19 = v;
                float param_20 = hit.y;
                float param_21 = style;
                color = kitDisplaySurface(param_17, param_18, param_19, param_20, param_21, U);
                float3 param_22 = p;
                float3 param_23 = n;
                float param_24 = hit.y;
                float param_25 = style;
                if (kitDisplayLiveGlass(param_22, param_23, param_24, param_25))
                {
                    float3 param_26 = ro;
                    float3 param_27 = rd;
                    float param_28 = style;
                    color = kitDisplayGlassRay(param_26, param_27, param_28, U);
                }
            }
            else
            {
                if (hit.y >= 40.0)
                {
                    float3 param_29 = p;
                    float3 param_30 = n;
                    float3 param_31 = v;
                    float param_32 = hit.y;
                    float param_33 = power;
                    float3 param_34 = p;
                    float3 param_35 = n;
                    float3 param_36 = v;
                    float param_37 = hit.y;
                    float3 param_38 = liftLampSurface(param_29, param_30, param_31, param_32, param_33, kitLift, U);
                    float param_39 = U.outfit.y;
                    color = kitPaintFinish(param_34, param_35, param_36, param_37, param_38, param_39, scoutRoofHit, U);
                }
                else
                {
                    if (hit.y >= 19.5)
                    {
                        float3 param_40 = p;
                        float3 param_41 = n;
                        float3 param_42 = v;
                        float param_43 = hit.y;
                        float param_44 = style;
                        float param_45 = power;
                        color = headFinish(param_40, param_41, param_42, param_43, param_44, param_45, U);
                    }
                    else
                    {
                        float3 param_46 = p;
                        float3 param_47 = n;
                        float3 param_48 = v;
                        float param_49 = hit.y;
                        float3 _11852 = scHousing(param_46, param_47, param_48, param_49, scKitOn, scKitRoll, scKitYawCS, scoutRoofHit, U);
                        float3 param_50 = p;
                        float3 param_51 = n;
                        float3 param_52 = v;
                        float param_53 = hit.y;
                        float3 param_54 = _11852;
                        float param_55 = U.outfit.y;
                        float3 param_56 = p;
                        float3 param_57 = n;
                        float param_58 = style;
                        float param_59 = power;
                        color = kitPaintFinish(param_50, param_51, param_52, param_53, param_54, param_55, scoutRoofHit, U) + headBounce(param_56, param_57, param_58, param_59, kitLift);
                    }
                }
            }
        }
        float3 param_60 = ro;
        float3 param_61 = rd;
        float param_62 = depth;
        float param_63 = style;
        float param_64 = power;
        color += studyGlare(param_60, param_61, param_62, param_63, param_64, kitLift);
    }
    float c = cos(U.pose.x);
    float s = sin(U.pose.x);
    float2 floorPoint = float2((c * uv.x) - (s * uv.y), (s * uv.x) + (c * uv.y));
    float detail = fast::clamp(U.viewport.z / 55.0, 0.100000001490116119384765625, 1.0);
    float _11928;
    if (U.receiver.w > 0.0)
    {
        float2 param_65 = uv;
        float param_66 = style;
        _11928 = nativeShadow(param_65, param_66, scKitOn, scKitRoll, scKitYawCS, kitLift, U);
    }
    else
    {
        _11928 = 0.0;
    }
    float shade = _11928;
    float dust = 0.0;
    float floorAlpha = shade + ((1.0 - shade) * dust);
    float3 floorRGB = (float3(0.0030000000260770320892333984375, 0.004999999888241291046142578125, 0.008000000379979610443115234375) * shade) + ((float3(0.11900000274181365966796875, 0.112999998033046722412109375, 0.09399999678134918212890625) * dust) * (1.0 - shade));
    float3 param_67 = float3(uv.x, -0.767000019550323486328125, uv.y);
    float3 _11964 = scoutPoint(param_67, U);
    float3 floorLocal = _11964;
    float3 param_68 = float3(0.0, 1.0, 0.0);
    float3 _11967 = worldToScout(param_68, U);
    float3 floorNormal = _11967;
    float3 light = float3(0.0);
    if ((U.receiver.w > 0.0) && (power > 0.0))
    {
        float3 _12009;
        for (int k = 0; k < 2; k++)
        {
            float side = (k == 0) ? (-1.0) : 1.0;
            float param_69 = style;
            float param_70 = side;
            float3 d = floorLocal - studyLampOrigin(param_69, param_70, kitLift);
            float d2 = dot(d, d);
            float3 ray = d * rsqrt(fast::max(9.9999997473787516355514526367188e-05, d2));
            if (kit)
            {
                float3 param_71 = ray;
                _12009 = liftLampReferenceDirection(param_71, kitLift);
            }
            else
            {
                _12009 = ray;
            }
            float3 opticRay = _12009;
            float3 param_72 = opticRay;
            float param_73 = kit ? 2.0 : style;
            float param_74 = side;
            float e = (sfCandela(param_72, param_73, param_74) * fast::max(dot(-ray, floorNormal), 0.0)) / (d2 + 0.054999999701976776123046875);
            float param_75 = style;
            float3 _12043 = headTint(param_75);
            light += (((float3(0.24500000476837158203125, 0.25, 0.2579999864101409912109375) * e) * _12043) * power);
        }
    }
    float lightPeak = fast::max(light.x, fast::max(light.y, light.z));
    float lightAlpha = 0.180000007152557373046875 * (1.0 - exp((-lightPeak) * 0.5));
    floorRGB += ((light * 0.054999999701976776123046875) * (1.0 - floorAlpha));
    floorAlpha += (lightAlpha * (1.0 - floorAlpha));
    float fade = 1.0 - smoothstep(430.0, 490.0, length(pixel - U.receiver.xy));
    floorRGB *= fade;
    floorAlpha *= fade;
    float3 rgb = (color * coverage) + (floorRGB * (1.0 - coverage));
    float alpha = coverage + (floorAlpha * (1.0 - coverage));
    float peak = fast::max(rgb.x, fast::max(rgb.y, rgb.z));
    rgb *= fast::min(1.0, U.options.y / fast::max(peak, 9.9999997473787516355514526367188e-05));
    out.outputColor = float4(rgb, alpha);
    return out;
}


float scoutTreadLug(float across,float behind,float roll,float rear,float detail){
    // The wheel shader cuts its chevrons where cos(24*angle + 4.4*abs(x/.145))
    // is positive. Its front/rear mold coordinates mirror the wheel angle.
    float groove=4.4*abs(across/.145);
    float c=cos(24.*(roll-behind/.295)+mix(groove,-groove,rear));
    float raised=1.-smoothstep(.06,.59,c);
    // At a grazing angle the paired bands remain after individual lugs merge.
    float resolved=smoothstep(.065,.49,detail);
    return mix(.44,mix(.48-.40*c,raised,resolved),resolved);
}

fragment float4 scout_track_stamp(float4 position [[position]],constant float4& tile [[buffer(1)]]) {
 float across=(position.x/tile.x-.5)*.306;
 float behind=(position.y/tile.y-.5)*(6.2831853*.295/24.);
 float roll=0.,rear=tile.z,detail=1.;
 float ink=scoutTreadLug(across,behind,roll,rear,detail);
 float shoulder=1.-smoothstep(.102,.148,abs(across));
 float alpha=.30*ink*shoulder;
 return float4(float3(.119,.113,.094)*alpha,alpha);
}

vertex float4 scout_vertex(uint id [[vertex_id]]) {return float4(id==1?3.:-1.,id==2?3.:-1.,0.,1.);}
