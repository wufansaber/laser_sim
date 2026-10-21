# 355 nm DOE 面平坦相位高斯入射简化模型

本目录的正式验收模型从 DOE 入射面开始。入射光为完全相干标量场，波前严格平坦，强度为二维高斯分布；不再仿真激光器到 DOE 的前级扩束和传播。

## 正式主程序

```matlab
cd('D:/work/git_share/laser_sim/deliverables/FINAL_HYBRID_DOE_LENS_355nm_package/02_matlab_code');
result = run_simplified_doe_plane_workflow();
```

只复跑已导出的 Zemax 模型：

```matlab
result = run_zemax_pop_simplified_doe_input();
```

需要 MATLAB R2019b、OpticStudio 2022 R2.02 和有效 ZOS-API 许可。

## DOE 面入射场

波长为355 nm。DOE-A前参考面S13的复振幅定义为：

```text
E(x,y)=C exp[-(x/wx)^2-(y/wy)^2],
arg(E)=0,
2wx=3.250 mm,
2wy=45.160 mm.
```

因此入射相位RMS为0 rad，场完全相干，强度为高斯分布。运行主程序时会自动生成 `06_zemax_sequential/DOE_INPUT_FLAT_PHASE_GAUSSIAN.ZBF`。该文件约128 MB，属于可重建的POP输入缓存，不提交GitHub。

## DOE与后级透镜

- 物理DOE数量：1片，双面熔融石英平行平板，厚12 mm，口径50 mm。
- 相位量化：16级；最小横向单元5 µm；2π浮雕深度约0.745686 µm；高度步长约0.046605 µm；4张二进制刻蚀掩模。
- DOE-A/DOE-B负责X向平顶整形，不给Y方向增加普通光焦度。
- 后级柱透镜与DOE分开：DOE-B到柱透镜前表面20 mm空气。
- 柱透镜：HPFS 7980，中心厚20 mm，口径50 mm；`RX=Inf`，`RY=-38.087111 mm`，Y向圆锥常数`K=-2.178838403`，名义`fY=80 mm`；X向无光焦度。
- 目标面位于柱透镜后表面80 mm，工作距离80 mm。

Zemax中S14和S15是同一物理DOE-A面的共面X/Y数学分量，轴向间距为0；当前Y相位分量为0。S16是DOE-B。该表示不增加物理DOE。

## Zemax POP设置

- Start Surface：S13，DOE前零厚度参考面。
- End Surface：S19，目标面。
- 输入：File beam，`DOE_INPUT_FLAT_PHASE_GAUSSIAN.ZBF`。
- X/Y采样：8192×1024；输入窗口12×128 mm。
- Grid Phase：order `+1`，interpolation `2`（pixelated）。
- 传播场保持完整复振幅和相干相位；无振幅掩模、空间滤波和部分相干平均。

正式ZMX已经由本机OpticStudio 2022 R2.02实际打开、保存并重新打开，验证日志为PASS。

## 最终 Zemax 结果

- X全 `1/e²` 宽度：**1.535711 mm**，满足1.500 mm ±5%。
- Y全 `1/e²` 宽度：**1.005721 µm**，满足1.000 µm ±1%。
- X中央固定1.35 mm区域，50 µm探测器空间平均后的均匀性：**91.5321%**，满足至少80%。
- 同一区域未经空间平均的完全相干点采样均匀性：**70.2531%**。该值同时保留，不能与50 µm验收值混用。
- 目标面总传播功率：**95.9206%**。
- X ±0.75 mm窗口功率：**94.6062%**。

均匀性验收明确包含50 µm矩形探测器空间响应；实际探测器像元或狭缝若明显小于50 µm，应采用原始相干纹波值或按实际响应重新计算。

## 文件

- `02_matlab_code/run_simplified_doe_plane_workflow.m`：正式一键主程序。
- `02_matlab_code/run_zemax_pop_simplified_doe_input.m`：只运行简化Zemax POP。
- `04_simulation_results/zemax_POP_simplified_DOE_input`：二维强度图、结果MAT、POP CFG、数值清单和验收CSV。
- `03_fabrication_data`：16级浮雕与4层掩模数据。
- `06_zemax_sequential`：实体处方、Grid Phase DAT、玻璃库和验证后的ZMX/ZDA；平坦相位高斯ZBF由运行脚本按需生成。

数值权威文件：`04_simulation_results/zemax_POP_simplified_DOE_input/simplified_DOE_input_POP_manifest.txt`。
