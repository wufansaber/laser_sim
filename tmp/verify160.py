"""Independent numerical check of the MATLAB nominal diffraction model.

This helper is for repository CI/development where MATLAB is unavailable. The
deliverable model remains the MATLAB R2019b implementation.
"""
import math
from pathlib import Path

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


if __name__ == "__main__":
    main()

