# 355 nm 双方案线聚焦仿真

本项目在同一个 MATLAB R2019b 进程中计算并比较两套方案：

1. HOLO/OR 厂商模型，选用 `ST-426-I-Y-A` 355 nm 线形 Top-Hat 标准件。
2. 自研 32 级熔石英相位 DOE，采用高斯到线形平顶的能量映射设计。

共同目标为 X 向 `1.5 mm`、Y 向 `1.0 um` 的全 `1/e^2` 光斑宽度。最终聚焦镜为 X/Y 同光焦度的球面镜，焦距和镜后工作距离均为 `100 mm`。

## 主程序

在 MATLAB R2019b 中切换到本文件夹并执行：

```matlab
comparison = run_two_matlab_solutions;
```

也可从 PowerShell 直接运行：

```powershell
& 'D:\Program Files\Polyspace\R2019b\bin\matlab.exe' -batch "cd('D:/work/git_share/laser_sim'); comparison=run_two_matlab_solutions();"
```

结果写入 `results/two_solutions_R2019b/`。

## 当前光路

| z (mm) | 元件 | 作用 |
|---:|---|---|
| 0 | LASER | 355 nm，TEM00，M2=1.2 |
| 30 | SBE1 | 第一光学元件；球面对称负扩束镜，f=-10 mm |
| 80 | SBE2 | 球面对称正扩束镜，f=+60 mm；第一组名义 6x |
| 150 | DOE | 厂商或自研线相位 DOE |
| 180 | YBE1 | 仅 Y 方向负柱面扩束镜，fY=-20 mm |
| 340.8 | YBE2 | 仅 Y 方向正柱面扩束镜，fY=+180.8 mm；Y 向 9.04x |
| 400 | DOE1（自研） | X 向相位映射；X 入射束仍约 6 mm |
| 600 | YFL | 仅 Y 方向聚焦，fY=100 mm、fX=Inf |
| 700 | DOE2/Target（自研） | 1.5 mm 平行 X 输出及 1.0 um Y 焦点 |

只有第一组 SBE1/SBE2 是圆形对称、X/Y 光焦度相同的扩束镜。后续 YBE1/YBE2 和 YFL 都是仅作用于 Y 的柱面镜，因此 X 不会先扩到约 54 mm 再缩回；它从第一组扩束后保持约 6 mm，最后由 DOE1/DOE2 映射成 1.5 mm 平行平顶输出。

## 1 um 厚度对应的口径

按 M2 修正的高斯束关系：

```text
D_Y = 4 M2 lambda f / (pi d_Y)
```

`lambda=355 nm`、`M2=1.2`、`f=100 mm`、`d_Y=1.0 um` 时，最终镜前需要 `D_Y=54.24 mm` 的全 `1/e^2` 光束直径。程序采用 10% 裕量，建议最终镜有效通光口径不小于 `59.66 mm`。由于第二级扩束镜为球面对称元件，SBE4 和其后的第一片柱面镜也必须容纳同等级口径。

## 已验证结果

MATLAB 9.7.0 R2019b 实算结果：

| 方案 | X 全 1/e2 宽度 | Y 全 1/e2 宽度 | 中央 90% 均匀度 | 总长 | 工作距离 |
|---|---:|---:|---:|---:|---:|
| HOLO/OR ST-426-I-Y-A | 1.500000 mm | 1.000 um | 99.478% | 700 mm | 100 mm |
| 自研 32 级 DOE | 1.500000 mm | 1.000 um | 93.011% | 700 mm | 100 mm |

本次 1 um 版本的 DOE 加工参数见 `DOE_DESIGN_SPEC_1UM_CN.md`，逐点浮雕处方见 `results/two_solutions_R2019b/inhouse_DOE/doe_32level_relief_profile.csv`。

## 假设与边界

- 薄透镜、无像差、空气折射率为 1，使用标量傅里叶衍射。
- Y 向以 `lambda_eff=M2*lambda` 做工程修正；这不是非理想激光的完整模态分解。
- 主计算采用名义圆形 1 mm 入射束。若实测椭圆率确为 1.1，纯球面对称扩束镜会保持该椭圆率，不能自行圆化；需要另加圆化器或把 6 mm 厂商输入条件按实际 X/Y 束径重新做容差验证。
- 实际选型仍需校核 355 nm 镀膜、损伤阈值、像差、面形、偏心与装调公差。
