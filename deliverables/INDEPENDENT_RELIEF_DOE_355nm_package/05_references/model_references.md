# 模型与参考资料说明

1. `optical_design_using_excel.pdf` 第7.1节用于高斯束腰振幅、强度和复参数定义，第7.3节用于M²修正的工程传播模型。
2. 熔融石英折射率在355 nm处用Malitson型Sellmeier方程计算，代码系数位于 `02_matlab_code/independent_relief_doe_config.m`。
3. 双相位面设计使用累计能量映射作为初值，再进行100次双平面交替投影；DOE2补偿传播到第二面的实际残余相位。
4. 自由空间传播使用角谱传递函数，薄透镜使用二次相位；量化后的浮雕相位直接进入最终传播。
5. 本包不包含HOLO/OR或其他厂商的专有微结构、相位文件或仿真代码。

主要公式：

```latex
U(x,0)=A(x)\exp[i\phi(x)]
```

```latex
\phi_{DOE}(x)=\frac{2\pi}{\lambda}[n(\lambda)-1]h(x)\pmod{2\pi}
```

```latex
U(x,z)=\mathcal{F}^{-1}\{\mathcal{F}[U(x,0)]H(f_x,z)\}
```

```latex
H(f_x,z)=\exp\left[ikz\sqrt{1-\lambda^2f_x^2}\right]
```

```latex
\eta_N=\left[\frac{\sin(\pi/N)}{\pi/N}\right]^2
```
