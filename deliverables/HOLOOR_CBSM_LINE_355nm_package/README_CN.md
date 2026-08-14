# HOLO/OR 355 nm 准直线光最终资料包

## MATLAB R2019b 主程序

```matlab
cd('D:/work/git_share/laser_sim/deliverables/HOLOOR_CBSM_LINE_355nm_package/02_matlab_code');
result = run_HOLOOR_collimated_line_R2019b();
```

方案采用 HOLO/OR `Collimated Beam Shaper Module` 定制线形架构。工程占位型号为 `CBSM-LINE-355-6MM-CUSTOM`，正式 PN、效率、口径和出口复场数据待 RFQ 确认。

## 最终结构

- 激光后的第一元件是圆对称扩束负透镜；只有 SBE1/SBE2 为圆对称扩束组。
- X 向由双元件准直模块整形，再由 `+160/-40 mm`、间距 `120 mm` 的无焦柱面组从 6 mm 缩为 1.5 mm。
- z=600 mm 的末级镜是 `YFL`，只对 Y 聚焦，`fY=100 mm`；X 光焦度为 0。
- Y 向目标为 1.0 µm 全 1/e² 宽度，末级工作距离 100 mm。

## 激光源模型

- 激光为 355 nm、连续、完全相干的确定性复电场，激光出口 `z=0` 为束腰面。
- 束腰振幅严格使用高斯分布 `exp[-(x/w0)^2]`，束腰波前曲率为无穷大；不人为加入随机相位或未测得的高阶相位。
- 实测 `M2X=M2Y=1.2` 通过广义高斯 `q` 参数进入瑞利长度、发散角、光束半径和曲率计算。
- 默认束腰全 1/e² 直径为 `Dx=Dy=1.0 mm`、椭圆度 1、旋转角 0；主配置支持主/次轴尺寸、旋转角、偏心、倾角以及 X/Y 独立 M²。
- 当前计算得到 X/Y 半发散角 `0.2712 mrad`，全发散角 `0.5424 mrad`，瑞利长度 `1843.66 mm`。
- `laser_model_reference_verification.csv` 按参考资料第 7.1、7.3 节逐式验证束腰振幅、强度、曲率、瑞利长度、发散角、Gouy 相位和复参数定义。

## 相位数据与验收

最终厂商相位验收需要把 `HOLOOR_CBSM_LINE_355_exit_complex_field.mat` 放入 `01_vendor_model`。文件缺失时，主程序运行独立双元件复场替代模型，但 `Vendor acceptance pass` 保持 0。替代模型用于检查实际后级光路对准直出口的影响，不代表 HOLO/OR 专有微结构。

## 独立浮雕 DOE 加工数据

- 独立对比 DOE 采用熔融石英、355 nm 折射率 1.47607188、32 级浮雕和 5 张二进制光刻掩模；结构仅沿 X 变化、沿 Y 等高延伸。
- 通光口径 15 mm，中心有效浮雕宽度 8 mm，外侧为未刻蚀平面；请求最小特征 10 µm，本次数值网格输出的实际单元节距为 10.986328 µm。
- (2\pi) 理论深度为 0.745685714 µm；32 级高度步长为 0.023302679 µm，最大保留浮雕高度为 0.722383035 µm。
- 5 次刻蚀深度依次为 0.023302679、0.046605357、0.093210714、0.186421428、0.372842857 µm。
- `doe1_relief_cells.csv`、`doe2_relief_cells.csv` 给出可合并加工区间、保留高度和从原始表面向下的总刻蚀深度。
- `doe_binary_lithography_masks.csv` 中 `1=开窗并刻蚀`、`0=保护`；加工前仍应由工艺方确认胶层极性、掩模正负片定义、刻蚀选择比和工艺偏差。
- 量化浮雕已直接进入相干传播，不是把连续理想相位用于最终结果。相位 RMS 验收上限按确认值取 0.12 rad（0.1116 rad 亦可接受）；当前 MATLAB R2019b 最终结果为 X 全 1/e² 宽度 1.499023 mm、相位 RMS 0.061100 rad、曲率边缘斜率 30.589 µrad，独立 DOE 验证通过。

## 目录

- `01_vendor_model`：HOLO/OR 出口复场数据格式说明；
- `02_matlab_code`：最终准直方案 R2019b 主程序、配置、求解器、替代模型和光路图代码；
- `03_simulation_results/collimated_line_R2019b`：最终几何与复场结果；
- `03_simulation_results/collimated_line_R2019b/phase_surrogate/target_plane_2d_intensity.png`：最终平面二维归一化强度分布；同目录的 MAT 文件保存二维数值，两个 lineout CSV 保存 X/Y 截线；
- `03_simulation_results/collimated_line_R2019b/phase_surrogate/doe_fabrication_instructions.txt`：浮雕基准、掩模极性及逐层刻蚀说明；
- `03_simulation_results/collimated_line_R2019b/phase_surrogate/doe_relief_and_lithography_design.png` 和 `doe_binary_lithography_mask_preview.png`：两片 DOE 的浮雕与掩模预览；
- `04_official_references`：与准直模块、DOE 原理和采购核对有关的官方资料链接；
- `HOLOOR_355nm准直线光技术说明.docx`：最终技术说明。
