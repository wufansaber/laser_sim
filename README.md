# 355 nm DOE 高斯光束整形与柱透镜聚焦

本仓库只保留最终正式方案：从 DOE 入射面开始，以完全相干、平坦波前、二维高斯强度分布作为输入，通过一片 16 级双面 DOE 完成 X 向平顶整形，再由独立 HPFS 7980 柱透镜完成 Y 向聚焦。

## 最终指标

| 指标 | Zemax POP 结果 |
|---|---:|
| 波长 | 355 nm |
| X 全 1/e² 宽度 | 1.535711 mm |
| Y 全 1/e² 宽度 | 1.005721 µm |
| X 均匀性，50 µm 探测器空间平均 | 91.5321% |
| X 原始相干点采样均匀性 | 70.2531% |
| 目标面总传播功率 | 95.9206% |
| X ±0.75 mm 窗口功率 | 94.6062% |

均匀性超过 80% 的验收结论明确采用约 50 µm 矩形探测器空间响应；未经空间平均的完全相干结果也同时保留，不能混用。

## 项目入口

完整交付位于 [`deliverables/FINAL_HYBRID_DOE_LENS_355nm_package`](deliverables/FINAL_HYBRID_DOE_LENS_355nm_package)。

MATLAB R2019b 一键主程序：

```matlab
cd('deliverables/FINAL_HYBRID_DOE_LENS_355nm_package/02_matlab_code');
result = run_simplified_doe_plane_workflow();
```

只重新运行 OpticStudio POP：

```matlab
result = run_zemax_pop_simplified_doe_input();
```

依赖：

- MATLAB R2019b；
- Ansys Zemax OpticStudio 2022 R2.02；
- 可用的 ZOS-API 许可证。

## 最终文件结构

- `02_matlab_code`：物理模型、DOE 计算、Zemax 导出、验证及 POP 自动化；
- `03_fabrication_data`：16 级浮雕、4 层二进制掩模和加工说明；
- `04_simulation_results`：MATLAB/Zemax 最终图表、数值和验收清单；
- `05_references`：模型依据与来源链接；
- `06_zemax_sequential`：处方、Grid Phase 数据、玻璃库及已验证 ZMX/ZDA；
- `利用AI 进行激光照明设计.docx`：项目设计过程说明。

128 MB 的 `DOE_INPUT_FLAT_PHASE_GAUSSIAN.ZBF` 是可重建运行缓存，未提交 GitHub。运行 `run_zemax_pop_simplified_doe_input` 时会根据正式输入参数自动生成并复制到 Zemax `POP/BEAMFILES` 目录。

数值权威文件：

`deliverables/FINAL_HYBRID_DOE_LENS_355nm_package/04_simulation_results/zemax_POP_simplified_DOE_input/simplified_DOE_input_POP_manifest.txt`
