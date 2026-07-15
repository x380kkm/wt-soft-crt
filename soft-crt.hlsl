// # soft-crt
Texture2D    shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float  time;
    float  scale;
    float2 resolution;
    float4 background;
};

// ---- 可调 ----
#define GLOW_WEIGHT      0.30   // 常态全屏泛光权重（官方 0.3）
#define GLOW_SAMPLES     10     // 泛光核采样边长（10x10=100 采样）
#define GLOW_PX_MIN      10.0   // 常态泛光核直径（像素）
#define GLOW_PX_MAX      20.0   // 扫过区泛光核直径（像素），向线渐增
#define SWEEP_GLOW_BOOST 2.5    // 扫过区泛光强度倍数（向线渐增）；1=不提亮
#define SCAN_FACTOR      0.50   // 全屏扫描线压暗（官方 0.5）
#define SCAN_PERIOD_MUL  1.0    // 扫描线周期 = scale*本值；1=官方 [1..6]
#define COVER_SPACING_PX 6.0    // 覆盖率/块底采样间距（像素）；越大块边界过渡越宽越渐变
#define COVER_EPS        0.12   // 判"非黑"的亮度阈值（高于 2% 壁纸底）
#define COVER_LO         0.40   // 覆盖率下界 -> blockness（下界低+区间宽=边界渐变）
#define COVER_HI         0.85   // 覆盖率上界 -> blockness
#define BLK_DIM          0.55   // 块底压暗系数（越小越暗）[0.3..1]
#define BLK_DESAT        0.55   // 块底降饱和（0=不降，1=灰）[0..1]
#define BLK_CONTRAST     1.60   // 块内内容相对底色的对比放大 [1..2.5]
#define DIR_GLOW_GAIN    0.35   // 块区 亮->暗 单向泛光 [0..0.8]
#define BEAM_SECONDS     4.0    // 光束扫完一屏秒数（越大越慢、停留越久）
#define BEAM_WIDE_PX     50.0   // 宽光带厚度（像素），仅色块区
#define BEAM_WIDE_GAIN   0.14   // 宽光带提亮
#define SWEEP_TRAIL_PX   75.0  // 扫过区（红线后方）长度（像素）：泛光核与强度在此内渐变
#define BEAM_RED_HALF    0.5    // 红基准线半宽（像素）；0.5=约 1px，全屏全不透明

static const float  M_PI     = 3.14159265f;
static const float3 LUMA     = float3(0.299, 0.587, 0.114);
static const float3 BEAM_RED = float3(1.0, 0.10, 0.10);

float luma(float3 c) { return dot(c, LUMA); }

float Gaussian2D(float x, float y, float sigma)
{
    return 1 / (sigma * sqrt(2 * M_PI)) * exp(-0.5 * (x * x + y * y) / sigma / sigma);
}

// 官方结构的高斯泛光核（GLOW_SAMPLES 边长）。bscale 缩放采样间距 -> 放大/缩小核直径；
float3 Blur(float2 tc, float bscale)
{
    float w, h;
    shaderTexture.GetDimensions(w, h);
    float tw = bscale / w;
    float th = bscale / h;
    float sigma = 2.0f * scale;
    float3 color = float3(0, 0, 0);
    float N = GLOW_SAMPLES;
    for (float x = 0; x < N; x++)
    {
        float sx = tc.x + (x - N / 2.0f) * tw;
        for (float y = 0; y < N; y++)
        {
            color += shaderTexture.Sample(samplerState, float2(sx, tc.y + (y - N / 2.0f) * th)).rgb * Gaussian2D(x - N / 2.0f, y - N / 2.0f, sigma);
        }
    }
    return color;
}

// 邻域 5x5：非黑覆盖率 coverage（判块）+ 非黑像素均值 bg（块底色估计，排除暗文字）
void Neighborhood(float2 tc, out float coverage, out float3 bg)
{
    float2 s = COVER_SPACING_PX / resolution;
    float  nonBlack = 0.0;
    float3 bgSum = float3(0, 0, 0);
    [unroll] for (int dy = -2; dy <= 2; dy++)
    {
        [unroll] for (int dx = -2; dx <= 2; dx++)
        {
            float3 p = shaderTexture.Sample(samplerState, tc + float2(dx, dy) * s).rgb;
            if (luma(p) > COVER_EPS) { nonBlack += 1.0; bgSum += p; }
        }
    }
    coverage = nonBlack / 25.0;
    bg = (nonBlack > 0.5) ? (bgSum / nonBlack) : float3(0, 0, 0);
}

// 官方方波扫描线，周期 = scale*SCAN_PERIOD_MUL（floor 整数行号，避免半像素抵消）
float SquareWave(float y)
{
    float period = scale * SCAN_PERIOD_MUL;
    return 1.0f - (floor(y / period) % 2.0f) * SCAN_FACTOR;
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float4 orig = shaderTexture.Sample(samplerState, tex);

    // 下扫时序（纯时间解析）：红线在 beamY；其后方（上方）SWEEP_TRAIL_PX 内为扫过区
    float beamY  = frac(time / BEAM_SECONDS);
    float trailY = (beamY - tex.y) * resolution.y;                      // >0 = 线上方（扫过区）
    float sweep  = (trailY >= 0.0f) ? saturate(1.0f - trailY / SWEEP_TRAIL_PX) : 0.0f;
    // 扫过区：泛光核直径与泛光强度双双 lerp 放大
    float  bscale = lerp(1.0f, GLOW_PX_MAX / GLOW_PX_MIN, sweep);
    float  glowW  = GLOW_WEIGHT * lerp(1.0f, SWEEP_GLOW_BOOST, sweep);
    float3 blur   = Blur(tex, bscale);

    float  coverage;
    float3 bg;
    Neighborhood(tex, coverage, bg);
    float blockness = smoothstep(COVER_LO, COVER_HI, coverage);   // 渐变羽化的块掩码

    // 第 1 层：官方风格 CRT（泛光 + 全屏扫描线）
    float3 baseRetro = (orig.rgb + blur * glowW) * SquareWave(pos.y);

    // 第 2 层：块区 —— 压暗+降饱和块底本身，放大块内文字对比，叠加单向泛光
    float  bgL    = luma(bg);
    float3 bgWeak = lerp(bg, float3(bgL, bgL, bgL), BLK_DESAT) * BLK_DIM;
    float3 blk    = bgWeak + (orig.rgb - bg) * BLK_CONTRAST;
    blk += saturate(blur - orig.rgb) * DIR_GLOW_GAIN;
    blk  = saturate(blk);

    float3 col = lerp(baseRetro, blk, blockness);

    // 第 3 层：下扫元素
    float dpx  = abs(tex.y - beamY) * resolution.y;
    // 宽光带：仅色块区显色（维持现状）
    float wide = saturate(1.0f - dpx / BEAM_WIDE_PX);
    col += wide * wide * BEAM_WIDE_GAIN * blockness;
    // 红基准线：1px、全不透明、全屏扫描
    float redLine = (dpx < BEAM_RED_HALF) ? 1.0f : 0.0f;
    col = lerp(col, BEAM_RED, redLine);

    return float4(saturate(col), orig.a);
}
