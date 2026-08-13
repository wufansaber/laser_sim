"""Independent numerical check of the MATLAB nominal diffraction model.

This helper is for repository CI/development where MATLAB is unavailable. The
deliverable model remains the MATLAB R2019b implementation.
"""
import math
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.special import erf


def crossing_width(axis, intensity, level):
    center = len(intensity) // 2
    left = np.where(intensity[:center] < level)[0][-1]
    right = center + np.where(intensity[center:] < level)[0][0]
    xl = np.interp(level, intensity[left:left + 2], axis[left:left + 2])
    xr = np.interp(level, intensity[right - 1:right + 1][::-1],
                   axis[right - 1:right + 1][::-1])
    return xr - xl


def q_train(q, z1=50.0, f1=-10.0, z2=140.0, f2=100.0):
    q += z1
    q = 1.0 / (1.0 / q - 1.0 / f1)
    q += z2 - z1
    return 1.0 / (1.0 / q - 1.0 / f2)


def q_beam(q, wavelength_eff):
    inverse = 1.0 / q
    return math.sqrt(-wavelength_eff / (math.pi * inverse.imag))


def main():
    wavelength_eff = 1.2 * 0.000355
    ellipticity = 1.1
    radii0 = [0.5 * math.sqrt(ellipticity), 0.5 / math.sqrt(ellipticity)]
    q_doe = []
    for radius in radii0:
        q0 = 1j * math.pi * radius**2 / wavelength_eff
        q_doe.append(q_train(q0) + 160.0)
    wx, wy = [q_beam(q, wavelength_eff) for q in q_doe]

    target_z, doe_z = 400.0, 300.0
    fy = 0.0008 * math.pi * wy / (2*wavelength_eff)
    for _ in range(5):
        wy_lens = q_beam(q_doe[1] + (target_z-fy-doe_z), wavelength_eff)
        fy = 0.0008 * math.pi * wy_lens / (2*wavelength_eff)

    n, window = 32768, 160.0
    dx = window/n
    source = (np.arange(n)-n/2)*dx
    aperture = np.abs(source) <= 12.5
    ex = np.exp(-(source/wx)**2)*aperture
    a = math.sqrt(2)/wx
    primitive = (source*erf(a*source) + np.exp(-(a*source)**2) /
                 (a*math.sqrt(math.pi)) - 1/(a*math.sqrt(math.pi)))
    phase = 2*math.pi/wavelength_eff * 1.5/(2*100.0)*primitive
    ux = np.fft.fftshift(np.fft.fft(np.fft.ifftshift(ex*np.exp(1j*phase))))*dx
    x_target = (np.arange(n)-n/2)*wavelength_eff*100.0/window
    ix = np.abs(ux)**2
    ix /= ix.max()

    ey = np.exp(-(source/wy_lens)**2)*aperture
    uy = np.fft.fftshift(np.fft.fft(np.fft.ifftshift(ey)))*dx
    y_target = (np.arange(n)-n/2)*wavelength_eff*fy/window
    iy = np.abs(uy)**2
    iy /= iy.max()

    x_width = crossing_width(x_target, ix, 0.5)
    y_width = crossing_width(y_target, iy, math.exp(-2))
    useful = np.abs(x_target) <= 0.9*1.5/2
    uniformity = ix[useful].min()/ix[useful].max()

    print(f"DOE diameters: {2*wx:.6f} x {2*wy:.6f} mm")
    print(f"Y focal length: {fy:.6f} mm")
    print(f"X width50: {x_width:.6f} mm")
    print(f"Y width1/e2: {1000*y_width:.6f} um")
    print(f"Uniformity min/max: {100*uniformity:.6f} %")
    assert abs(x_width-1.5) <= 0.015
    assert abs(y_width-0.0008) <= 0.00004
    assert uniformity >= 0.90
    assert target_z <= 2000 and fy <= 300

    output = Path("results")
    output.mkdir(exist_ok=True)
    rows = [
        ("DOE beam diameter X", 2*wx, "mm"),
        ("DOE beam diameter Y", 2*wy, "mm"),
        ("Y cylinder focal length", fy, "mm"),
        ("X width at 50 percent", x_width, "mm"),
        ("Y full width at 1/e2", 1000*y_width, "um"),
        ("X central-90 percent min/max uniformity", 100*uniformity, "%"),
        ("Optical length", target_z, "mm"),
        ("Last lens distance", fy, "mm"),
    ]
    with (output/"independent_verification.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["metric", "value", "unit"])
        writer.writerows(rows)

    fig, axes = plt.subplots(2, 1, figsize=(9, 6), constrained_layout=True)
    select_x = np.abs(x_target) <= 1.1
    axes[0].plot(x_target[select_x], ix[select_x], lw=1.4)
    axes[0].set(xlabel="X at target (mm)", ylabel="Normalized irradiance",
                title=f"X line Top-Hat: width50={x_width:.4f} mm, uniformity={100*uniformity:.2f}%")
    axes[0].grid(True, alpha=.3)
    select_y = np.abs(y_target) <= .003
    axes[1].plot(1000*y_target[select_y], iy[select_y], color="tab:red", lw=1.4)
    axes[1].axhline(math.exp(-2), color="black", ls="--", lw=1)
    axes[1].set(xlabel="Y at target (um)", ylabel="Normalized irradiance",
                title=f"Y focus: full 1/e2 width={1000*y_width:.4f} um")
    axes[1].grid(True, alpha=.3)
    fig.savefig(output/"independent_target_profiles.png", dpi=180)
    plt.close(fig)


if __name__ == "__main__":
    main()
