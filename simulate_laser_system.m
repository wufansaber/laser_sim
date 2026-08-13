function results = simulate_laser_system(cfg)
%SIMULATE_LASER_SYSTEM Coherent separable simulation of the laser train.
%
% The X field uses analytic Gaussian-to-uniform energy mapping followed by
% the Fourier focal transform of an ideal cylindrical lens. The Y field is
% the Fourier transform of the expanded Gaussian at its cylindrical focus.
% M2 is included through lambdaEff=M2*lambda, consistent with the corrected
% Gaussian waist relation in Chapter 7 of the supplied reference.

lambdaEff = cfg.M2 * cfg.lambda;
kEff = 2*pi/lambdaEff;

% Preserve the stated geometric-mean diameter while applying ellipticity.
d0x = cfg.inputBeamScale * cfg.inputBeamDiameter * sqrt(cfg.ellipticity);
d0y = cfg.inputBeamScale * cfg.inputBeamDiameter / sqrt(cfg.ellipticity);
q0x = 1i*pi*(d0x/2)^2/lambdaEff;
q0y = 1i*pi*(d0y/2)^2/lambdaEff;

qx = propagateTrain(q0x, cfg);
qy = propagateTrain(q0y, cfg);

% Propagate from expander L2 to the DOE/X lens.
qxDoe = qx + (cfg.shaper.z - cfg.expander.z2);
qyDoe = qy + (cfg.shaper.z - cfg.expander.z2);
[wxDoe, RxDoe] = qToBeam(qxDoe, lambdaEff);
[wyDoe, RyDoe] = qToBeam(qyDoe, lambdaEff);

% Solve the last Y-cylinder position using the local expanded beam radius.
% A refinement below accounts for the small propagation from DOE to Y lens.
fY = cfg.target.yWidth*pi*wyDoe/(2*lambdaEff);
for iter = 1:5
    zY = cfg.target.z - fY;
    qyAtLens = qyDoe + (zY - cfg.shaper.z);
    [wyAtLens, ~] = qToBeam(qyAtLens, lambdaEff);
    fY = cfg.target.yWidth*pi*wyAtLens/(2*lambdaEff);
end
zY = cfg.target.z - fY;
qyAtLens = qyDoe + (zY - cfg.shaper.z);
[wyAtLens, RyAtLens] = qToBeam(qyAtLens, lambdaEff);

N = cfg.grid.N;
window = cfg.grid.window;
dx = window/N;
x = ((0:N-1) - N/2)*dx;

% Complex Gaussian fields include residual wave-front curvature.
Ex = exp(-(x/wxDoe).^2);
if isfinite(RxDoe)
    Ex = Ex .* exp(-1i*kEff*x.^2/(2*RxDoe));
end
Ey = exp(-(x/wyAtLens).^2);
if isfinite(RyAtLens)
    Ey = Ey .* exp(-1i*kEff*x.^2/(2*RyAtLens));
end

% Apply finite clear apertures.
aperture = abs(x) <= cfg.shaper.clearAperture/2;
Ex = Ex .* aperture;
Ey = Ey .* aperture;

% Analytic 1-D energy mapping. Xmap(x) maps accumulated Gaussian energy to
% a uniform line in [-topHatWidth/2,+topHatWidth/2]. Integrating
% d(phi)/dx = k*Xmap/f gives the required phase-only DOE function.
a = sqrt(2)/wxDoe;
phaseCoordinate = x-cfg.shaper.decenter;
primitive = phaseCoordinate.*erf(a*phaseCoordinate) + ...
    exp(-(a*phaseCoordinate).^2)/(a*sqrt(pi));
primitive = primitive - 1/(a*sqrt(pi));
doePhase = kEff*cfg.shaper.topHatWidth*primitive/(2*cfg.shaper.fX);
% Equation (9.36) defocus term. Removing its constant phase leaves the
% numerically better-conditioned relative phase used here.
defocusPhaseX = -kEff*cfg.target.defocus * ...
    (sqrt(max(0,1-(x/cfg.shaper.fX).^2))-1);
defocusPhaseY = -kEff*cfg.target.defocus * ...
    (sqrt(max(0,1-(x/fY).^2))-1);
ExAfterDoe = Ex .* exp(1i*(doePhase+defocusPhaseX));
Ey = Ey .* exp(1i*defocusPhaseY);

% Fourier focal transforms. Common phase and scale factors cancel after
% normalization but dx is retained for physical consistency.
Ux = fftshift(fft(ifftshift(ExAfterDoe)))*dx;
Uy = fftshift(fft(ifftshift(Ey)))*dx;
xTarget = ((0:N-1) - N/2)*(lambdaEff*cfg.shaper.fX/window);
yTarget = ((0:N-1) - N/2)*(lambdaEff*fY/window);
Ix = abs(Ux).^2;
Iy = abs(Uy).^2;
Ix = Ix/max(Ix);
Iy = Iy/max(Iy);

% Metrics. The coherent 2-D result is separable: I2D=Ix*Iy.
xWidth50 = crossingWidth(xTarget, Ix, cfg.edgeThreshold);
yWidth1e2 = crossingWidth(yTarget, Iy, exp(-2));
useful = abs(xTarget) <= cfg.uniformityFraction*cfg.shaper.topHatWidth/2;
uniformity = min(Ix(useful))/max(Ix(useful));
rmsUniformity = 1 - std(Ix(useful))/mean(Ix(useful));

results.cfg = cfg;
results.lambdaEff = lambdaEff;
results.inputDiameter = [d0x, d0y];
results.doeBeamRadius = [wxDoe, wyDoe];
results.doeWavefrontRadius = [RxDoe, RyDoe];
results.yLensBeamRadius = wyAtLens;
results.yLensWavefrontRadius = RyAtLens;
results.fY = fY;
results.zY = zY;
results.opticalLength = cfg.target.z;
results.lastLensDistance = cfg.target.z-zY;
results.doePhase = doePhase;
results.sourceCoordinate = x;
results.xTarget = xTarget;
results.yTarget = yTarget;
results.Ix = Ix;
results.Iy = Iy;
results.xWidth50 = xWidth50;
results.yWidth1e2 = yWidth1e2;
results.uniformity = uniformity;
results.rmsUniformity = rmsUniformity;
results.requirementsPass = xWidth50 >= 0.99*cfg.shaper.topHatWidth && ...
    xWidth50 <= 1.01*cfg.shaper.topHatWidth && ...
    yWidth1e2 >= 0.95*cfg.target.yWidth && ...
    yWidth1e2 <= 1.05*cfg.target.yWidth && ...
    uniformity >= 0.90 && results.opticalLength <= 2000 && ...
    results.lastLensDistance <= 300;
end

function q = propagateTrain(q, cfg)
q = q + cfg.expander.z1;
q = 1/(1/q - 1/cfg.expander.f1);
q = q + (cfg.expander.z2-cfg.expander.z1);
q = 1/(1/q - 1/cfg.expander.f2);
end

function [w, R] = qToBeam(q, lambdaEff)
invq = 1/q;
w = sqrt(-lambdaEff/(pi*imag(invq)));
if abs(real(invq)) < 1e-14
    R = Inf;
else
    R = 1/real(invq);
end
end

function width = crossingWidth(axisValues, intensity, level)
center = floor(numel(intensity)/2)+1;
left = find(intensity(1:center) < level, 1, 'last');
rightRelative = find(intensity(center:end) < level, 1, 'first');
if isempty(left) || isempty(rightRelative)
    width = NaN;
    return
end
right = center + rightRelative - 1;
xl = linearCrossing(axisValues(left), axisValues(left+1), ...
    intensity(left), intensity(left+1), level);
xr = linearCrossing(axisValues(right-1), axisValues(right), ...
    intensity(right-1), intensity(right), level);
width = xr-xl;
end

function value = linearCrossing(x1, x2, y1, y2, target)
value = x1 + (target-y1)*(x2-x1)/(y2-y1);
end
