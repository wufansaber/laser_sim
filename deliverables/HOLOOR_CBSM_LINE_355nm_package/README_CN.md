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

## 相位数据与验收

最终厂商相位验收需要把 `HOLOOR_CBSM_LINE_355_exit_complex_field.mat` 放入 `01_vendor_model`。文件缺失时，主程序运行独立双元件复场替代模型，但 `Vendor acceptance pass` 保持 0。替代模型用于检查实际后级光路对准直出口的影响，不代表 HOLO/OR 专有微结构。

## 目录

- `01_vendor_model`：HOLO/OR 出口复场数据格式说明；
- `02_matlab_code`：最终准直方案 R2019b 主程序、配置、求解器、替代模型和光路图代码；
- `03_simulation_results/collimated_line_R2019b`：最终几何与复场结果；
- `04_official_references`：与准直模块、DOE 原理和采购核对有关的官方资料链接；
- `HOLOOR_355nm准直线光技术说明.docx`：最终技术说明。
