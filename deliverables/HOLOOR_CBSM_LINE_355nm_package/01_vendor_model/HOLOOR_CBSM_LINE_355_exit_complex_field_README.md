# HOLO/OR 定制准直线光模块复场数据接口

最终验收所需文件名：`HOLOOR_CBSM_LINE_355_exit_complex_field.mat`

文件必须由 HOLO/OR 针对最终定制料号提供，并注明参考面、坐标方向、采样间隔、单位、归一化方法及输入光束定义。MAT 文件须包含：

- `x_mm`：X 坐标列向量，单位 mm；
- `U_exit`：与 `x_mm` 等长的复振幅列向量；

或者使用以下等价字段：

- `amplitude`：实数非负振幅列向量；
- `phase_rad`：相位列向量，单位 rad。

推荐同时提供二维 `x_mm`、`y_mm`、`U_exit_xy` 数据及 Zemax/Code V 黑箱。当前 MATLAB 验收程序至少使用一维 X 截面计算有效光斑内的平均相位倾角、去 piston/tilt 后相位 RMS 和拟合波前曲率。

没有该文件时，程序只报告几何验证与独立双元件相位替代模型结果；`Vendor acceptance pass` 必须保持 0。
