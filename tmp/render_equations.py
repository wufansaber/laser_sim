from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

out=Path(r'D:\work\git_share\laser_sim\tmp\holoor_equations')
out.mkdir(parents=True,exist_ok=True)
eq={
'5_1':r'U_0(x,y)=A_0(x,y)\exp\!\left[i\phi_0(x,y)\right]',
'5_2':r't_{\mathrm{DOE}}(x,y)=\exp\!\left[i\phi_{\mathrm{DOE}}(x,y)\right]',
'5_3':r'U_0^{+}(x,y)=U_0(x,y)t_{\mathrm{DOE}}(x,y)',
'5_4':r'\phi_{\mathrm{DOE}}(x,y)=\frac{2\pi}{\lambda}\left[n(\lambda)-1\right]h(x,y)\ \mathrm{mod}\ 2\pi',
'5_5':r'U_f=\frac{e^{ikf}}{i\lambda f}e^{\frac{ik}{2f}(x_f^2+y_f^2)}\mathcal{F}\!\left\{U_0^{+}\right\}',
'5_6':r'U_1^{+}=U_{\mathrm{in}}e^{i\phi_1},\qquad U_2^{-}=\mathcal{P}_{L}\!\left\{U_1^{+}\right\}',
'5_7':r'\phi_2(x,y)=-\arg\!\left[U_2^{-}(x,y)\right]+\phi_{\mathrm{ref}}(x,y)',
'5_8':r'U_{\mathrm{out}}\approx A_{\mathrm{TH}}\exp\!\left[i\phi_{\mathrm{ref}}\right]',
'6_1':r'U_{\mathrm{in}}=U_0e^{-(x^2+y^2)/w^2},\quad I_{\mathrm{in}}=I_0e^{-2(x^2+y^2)/w^2}',
'6_2':r'\frac{\int_{-\infty}^{\xi}I_{\mathrm{in}}(s)ds}{\int_{-\infty}^{+\infty}I_{\mathrm{in}}(s)ds}=\frac{\int_{-D/2}^{T(\xi)}I_{\mathrm{TH}}(u)du}{\int_{-D/2}^{+D/2}I_{\mathrm{TH}}(u)du}',
'6_3':r'A_{\mathrm{TH}}(x)=A_0\exp\!\left[-\left|\frac{x}{D_{\mathrm{TH}}/2}\right|^m\right],\quad m=8',
'6_4':r'\frac{d\phi_1}{d\xi}\approx k\frac{T(\xi)-\xi}{L},\qquad k=\frac{2\pi}{\lambda}',
'6_5':r'U(x,y;z)=\mathcal{F}^{-1}\!\left\{\mathcal{F}[U(x,y;0)]H(f_x,f_y;z)\right\}',
'6_6':r'H=\exp\!\left[ikz\sqrt{1-\lambda^2f_x^2-\lambda^2f_y^2}\right]',
'6_7':r't_L(x)=\exp\!\left(-i\frac{kx^2}{2f_x}\right)',
'6_8':r'P(d)=[1\ \ d;\ 0\ \ 1],\qquad L(f)=[1\ \ 0;\ -1/f\ \ 1]',
'6_9':r'M_{\mathrm{CXC}}=L(-40)P(120)L(160)=[0.25\ \ 120;\ 0\ \ 4]',
'6_10':r'M_{X,\mathrm{total}}=P(150)I_{\mathrm{YFL},X}M_{\mathrm{CXC}},\qquad I_{\mathrm{YFL},X}=I',
'6_11':r'd_Y=\frac{4M^2\lambda f_Y}{\pi D_Y},\qquad D_Y=54.240\ \mathrm{mm}',
'6_12':r'\phi_{\mathrm{fit}}=a_2x^2+a_1x+a_0,\qquad \bar{\theta}_x=\frac{\lambda}{2\pi}a_1',
'6_13':r'R_x=\frac{\pi}{\lambda a_2},\qquad \sigma_{\phi}=\sqrt{\frac{1}{N}\sum_{n=1}^{N}\left[\phi(x_n)-(b_1x_n+b_0)\right]^2}',
'6_14':r'\theta_{\mathrm{edge}}=\frac{D_X/2}{|R_x|}',
}
for key,latex in eq.items():
    fig=plt.figure(figsize=(8.4,0.62),dpi=220); fig.patch.set_alpha(0)
    fig.text(0.5,0.52,'$'+latex+'$    ('+key.replace('_','-')+')',ha='center',va='center',fontsize=13)
    fig.savefig(out/(key+'.png'),transparent=True,bbox_inches='tight',pad_inches=0.04)
    plt.close(fig)
print(len(eq))
