# soft-crt
*浅色主题别用*
Windows Terminal 自定义 CRT 像素着色器。以官方 `Retro.hlsl` 效果为基底，叠加对「带背景色的色块」内容的可读性增强，以及一条随时间移动的扫描光束。
## 安装

1. 把 `soft-crt.hlsl` 放到任意固定位置（建议 Windows Terminal 的 `LocalState` 目录）。
2. 在 Windows Terminal `settings.json` 的某个 profile 或 `profiles.defaults` 里加入：

   ```json
   "experimental.pixelShaderPath": "C:\\Users\\你\\...\\soft-crt.hlsl",
   "experimental.retroTerminalEffect": false
   ```

3. 保存 `settings.json` 或新开一个标签页即可生效。设置界面打开时 Windows Terminal 不热重载外部改动，此时新开标签页可强制重载。

## 来源

泛光与方波扫描线基于 [microsoft/terminal](https://github.com/microsoft/terminal) 的官方示例 `samples/PixelShaders/Retro.hlsl`；动态扫描线参考同目录 `Animate_scan.hlsl`。
