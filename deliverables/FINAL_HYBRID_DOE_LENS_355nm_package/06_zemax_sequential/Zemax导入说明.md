# Zemax OpticStudio Sequential 导入说明

## 已完成的本机验证

已使用 `C:\Program Files\Ansys Zemax OpticStudio 2022 R2.02` 通过 ZOS-API 实际导入 DOE-A/DOE-B、保存并重新打开，结果为 PASS。优先打开：

- `final_hybrid_355nm_SEQ_OpticStudio2022R2_validated.ZMX`；
- 同目录配套数据文件 `final_hybrid_355nm_SEQ_OpticStudio2022R2_validated.ZDA`。

两者必须保持在同一文件夹。该版本已经嵌入 S14、S15、S16 三组完整计算网格相位数据，不需要再手工导入 DAT。验证记录见 `OpticStudio_2022R2_validation.txt`。

## 文件用途

- `component_prescription_355nm.csv`：逐片玻璃的口径、前后顶点位置、中心厚度及 X/Y 曲率半径。
- `surface_prescription_355nm.csv`：与 Zemax Lens Data Editor 对应的逐面处方。
- `final_hybrid_355nm_SEQ_starting_point.ZMX`：OpticStudio 22 格式的 Sequential 起始系统。
- `final_hybrid_355nm_SEQ_OpticStudio2022R2_validated.ZMX/.ZDA`：由本机 OpticStudio 2022 R2.02 实际导入、保存并重开的正式文件对。
- `LASER355_CUSTOM.AGF`：自定义玻璃库，包含 `HPFS7980` 和 DOE 使用的 `UVFS_DOE`。
- `DOE_surface_A_grid_phase.DAT`：物理 DOE-A 合成相位的审计/制造伴随数据。
- `DOE_surface_A_X_grid_phase.DAT`、`DOE_surface_A_Y_grid_phase.DAT`：Zemax 中共面表示 DOE-A 的 X/Y 数学分量；当前 Y 分量为零相位。
- `DOE_surface_B_grid_phase.DAT`：同一片双面 DOE 的背面 X 相位数据。
- `DOE_INPUT_FLAT_PHASE_GAUSSIAN.ZBF`：由 `run_zemax_pop_simplified_doe_input.m` 按需生成的 128 MB POP 输入缓存，不提交 GitHub。

## 导入步骤

以下步骤仅用于从起始文件重新构建。正常使用时直接打开上面的 validated ZMX/ZDA 文件对即可。

1. 把 `LASER355_CUSTOM.AGF` 复制到当前 Zemax 数据目录的 `Glasscat` 文件夹，在 Material Catalog 中刷新或重新加载 `LASER355_CUSTOM`。
2. 打开 `final_hybrid_355nm_SEQ_OpticStudio2022R2_validated.ZMX`，确认系统处于 Sequential Mode、单位为 mm、波长为 0.355 µm。正式文件已嵌入完整 Grid Phase 数组，正常复算不需要手工导入 DAT。
3. 如需从起始文件重建，运行 `validate_zemax_2022R2.m`；它会复制玻璃库和伴随 DAT、让 OpticStudio 打开并另存，然后重新打开检查面型、材料和嵌入数组。
4. 三个 Grid Phase 计算面均采用 Diffraction order `+1`、Shear distance `0`、Interpolation `2 = Pixelated`。S14/S15 是同一物理 DOE-A 面的共面数学分量，S16 是同一片基片的 DOE-B 背面。
5. 使用 Physical Optics Propagation 验证相干强度；仅用几何 Spot Diagram 不能复现平顶衍射强度。正式对照运行 `run_zemax_pop_simplified_doe_input.m`，由程序生成统一的平坦相位高斯 ZBF。

## 本机自动导入验证

关闭其他 OpticStudio 实例后，在 MATLAB R2019b 运行：

```matlab
cd('D:/work/git_share/laser_sim/deliverables/FINAL_HYBRID_DOE_LENS_355nm_package/02_matlab_code');
report = validate_zemax_2022R2();
```

脚本通过 ZOS-API 打开已嵌入完整 `2400×3` 数组的起始 ZMX，由 OpticStudio 2022 R2.02 自身保存并重新打开；不再调用可能静默保留默认 `3×3` 零网格的 `ImportDataFile`。如果验证通过，会生成：

- `final_hybrid_355nm_SEQ_OpticStudio2022R2_validated.ZMX`；
- `final_hybrid_355nm_SEQ_OpticStudio2022R2_validated.ZDA`；
- `OpticStudio_2022R2_validation.txt`。

ZOS-API Standalone 模式需要独占一个可用许可证；已有普通 OpticStudio 窗口占用许可证时，应先保存并关闭该窗口。

## DOE 与最终柱透镜的独立实体表示

DOE 与柱透镜在顺序模式和机械结构中都保持分离，不再采用同面叠加或零间隔计算分解：

- 第 13 面：DOE-A 前的零厚度 POP 参考面；
- 第 14/15 面：同一物理 DOE-A 面的共面 X/Y `GRID_PHA` 数学分量，轴向间距为零；当前 Y 相位为零；
- 第 16 面：同一片 12 mm DOE 基片的 DOE-B `GRID_PHA` 背面，面后为空气 20 mm；
- 第 17 面：独立 Y 柱透镜的平面前表面，材料 `HPFS7980`，中心厚度 20 mm；
- 第 18 面：独立 Y 柱透镜的 `TOROIDAL` 后表面，`RY=-38.087111 mm`、`RX=Inf`、Y 向圆锥常数 `K=-2.178838403`，名义 `fY=80 mm`，面后空气工作距离 80 mm；
- 第 19 面：目标面。

物理结构是一片双面 DOE 加一片独立 Y 柱透镜；DOE 数量仍为一片。DOE-A/DOE-B 只包含 X 相位，柱透镜只提供 Y 光焦度。

## 处方边界

- Zemax 曲率符号按光从左向右：半径为正表示曲率中心位于表面右侧，`Inf` 表示平面。
- 非 DOE 镜片统一采用 Corning HPFS 7980；按 Corning 22 °C Sellmeier 数据计算得到 `n(355 nm)=1.476088887172`。
- 最终 Y 柱透镜采用保持同一曲率半径的非球面柱面：`K=-n^2` 用于消除准直入射在单折射面聚焦时的几何球差。当前共同场 POP 已复核；正式加工前仍应加入实际面形、偏心倾斜和材料熔次公差。

## 当前正式 POP 结果

- 输入：DOE-A 前完全相干、平坦相位、二维高斯复振幅；X/Y 全 `1/e²` 直径分别为 3.25 mm 和 45.16 mm。
- X 全 `1/e²` 宽度：1.535711 mm。
- Y 全 `1/e²` 宽度：1.005721 µm。
- X 中央 1.35 mm 区域原始相干点采样均匀性：70.2531%。
- 同一区域经约 50 µm 矩形探测器空间平均后的均匀性：91.5321%。
- X ±0.75 mm 目标窗功率：94.6062%；总传播功率：95.9206%。
- 运行脚本：`run_zemax_pop_simplified_doe_input.m`；结果目录：`04_simulation_results/zemax_POP_simplified_DOE_input`。
- 结果不包含镀膜、实际刻蚀侧壁、粗糙度、散射、偏心倾斜和熔次折射率偏差。

## 数据依据

- Corning HPFS 7980 色散数据：<https://www.corning.com/content/dam/corning/media/worldwide/csm/documents/HPFS_Product_Brochure_All_Grades_2022_6.pdf>
- Ansys Grid Phase：<https://ansyshelp.ansys.com/public/Views/Secured/Zemax/v252/en/OpticStudio_User_Guide/OpticStudio_Help/topics/Grid_Phase.html>
- Ansys Grid Sag/Grid Phase DAT 格式：<https://ansyshelp.ansys.com/public/Views/Secured/Zemax/v242/en/OpticStudio_User_Guide/OpticStudio_Help/topics/Grid_Sag.html>
