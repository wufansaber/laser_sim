function [field, meta] = build_coherent_laser_waist_1d(x, cfg, axisName)
%BUILD_COHERENT_LASER_WAIST_1D Gaussian waist from Sec. 7.1 of the reference.
% At z=0 the electric-field amplitude is exp[-(x/w0)^2], the irradiance is
% exp[-2(x/w0)^2], and the spherical-wavefront radius is infinite.  Thus no
% invented M2 phase is added at the waist.  The measured M2 is applied to
% divergence, W(z), R(z), and q propagation using the Sec. 7.3 equations.

if strcmpi(axisName,'X')
    diameter=cfg.laser.waistDiameterX;
    m2=cfg.laser.M2X;
    center=cfg.laser.decenterX;
    tilt=cfg.laser.tiltX;
elseif strcmpi(axisName,'Y')
    diameter=cfg.laser.waistDiameterY;
    m2=cfg.laser.M2Y;
    center=cfg.laser.decenterY;
    tilt=cfg.laser.tiltY;
else
    error('laser_sim:LaserAxis','axisName must be X or Y.');
end

w0=diameter/2;
u=(x-center)/w0;
amplitude=exp(-(u.^2));
k=2*pi/cfg.lambda;
phaseTilt=k*tilt*(x-center);
field=amplitude.*exp(1i*phaseTilt);
power=trapz(x,abs(field).^2);
field=field/sqrt(power);

meta.axis=upper(axisName);
meta.waistDiameter=diameter;
meta.waistRadius=w0;
meta.M2=m2;
meta.decenter=center;
meta.tilt=tilt;
meta.rayleighRange=pi*w0^2/(m2*cfg.lambda);
meta.divergenceHalfAngle=m2*cfg.lambda/(pi*w0);
meta.divergenceFullAngle=2*meta.divergenceHalfAngle;
meta.coherence=cfg.laser.coherence;
meta.phaseModel='Flat waist wavefront plus configured global tilt';
end
