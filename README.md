# soft-crt

Windows Terminal 自定义 CRT 像素着色器。以官方 `Retro.hlsl` 效果为基底，叠加对「带背景色的色块」内容的可读性增强，以及一条随时间移动的扫描光束。

## 效果

- **全屏基础**：官方风格 CRT——高斯泛光（`10x10` 采样）+ 方波扫描线（周期跟随 `scale`）。
- **色块区**（有非黑背景填色的单元格，用邻域「非黑覆盖率」判定，边界渐变羽化）：
  - 压暗并降饱和块底色本身（块底是视觉干扰项）；
  - 放大块内文字相对底色的对比，让灰底白字、蓝底黑字这类内容凸显、清晰可读；
  - 亮到暗的单向泛光修补边界。
- **动态扫描光束**（随时间下扫，纯时间解析计算、零额外纹理采样）：
  - 一根 `1px` 全不透明红色基准线，全屏扫描；
  - 一条宽光带，仅在色块区显色；
  - 红线后方 `SWEEP_TRAIL_PX` 像素内，泛光核直径与强度同时 `lerp` 放大，形成「扫过点亮」的脉冲。

## 安装

1. 把 `soft-crt.hlsl` 放到任意固定位置（建议 Windows Terminal 的 `LocalState` 目录）。
2. 在 Windows Terminal `settings.json` 的某个 profile 或 `profiles.defaults` 里加入：

   ```json
   "experimental.pixelShaderPath": "C:\\Users\\你\\...\\soft-crt.hlsl",
   "experimental.retroTerminalEffect": false
   ```

3. 保存 `settings.json` 或新开一个标签页即可生效。设置界面打开时 Windows Terminal 不热重载外部改动，此时新开标签页可强制重载。

## 可调参数

着色器顶部一排 `#define`，标识符英文、注释中文，每条一行说明默认值与调向：

- `GLOW_WEIGHT` 与 `GLOW_PX_MIN`：常态泛光强度与核直径。
- `SCAN_FACTOR` 与 `SCAN_PERIOD_MUL`：扫描线压暗量与周期。
- `BLK_DIM`、`BLK_DESAT`、`BLK_CONTRAST`：色块底压暗、降饱和、块内文字对比放大。
- `COVER_LO`、`COVER_HI`、`COVER_SPACING_PX`、`COVER_EPS`：色块判定的覆盖率阈值与边界渐变宽度。
- `GLOW_PX_MAX`、`SWEEP_GLOW_BOOST`、`SWEEP_TRAIL_PX`、`BEAM_SECONDS`：扫描光束的泛光涨幅、亮度倍数、带宽、速度。
- `BEAM_RED_HALF` 与 `BEAM_WIDE_PX`：红基准线宽度与宽光带厚度。

## 契约

Windows Terminal 像素着色器契约固定：入口函数 `main`、`Texture2D shaderTexture`、`SamplerState samplerState`、`cbuffer PixelShaderSettings` 字段顺序 `float time / float scale / float2 resolution / float4 background`。目标 `ps_5_0`，`fxc` 标准与 `/WX /Ges` 严格模式均零错误零警告。

## 来源

泛光与方波扫描线基于 [microsoft/terminal](https://github.com/microsoft/terminal) 的官方示例 `samples/PixelShaders/Retro.hlsl`；动态扫描线参考同目录 `Animate_scan.hlsl`。
