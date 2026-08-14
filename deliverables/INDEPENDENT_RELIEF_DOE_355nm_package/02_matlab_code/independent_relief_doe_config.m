function cfg = independent_relief_doe_config()
%INDEPENDENT_RELIEF_DOE_CONFIG Manufacturable 355 nm relief-DOE inputs.
% All lengths are mm unless explicitly named otherwise.
cfg.matlabRequired = '2019b';
cfg.lambda = 355e-6;

% Measured laser source at z=0.  The source is treated as one deterministic
% continuous-wave complex field (fully coherent), not as an incoherent mode
% mixture.  Major/minor diameters are full 1/e^2 intensity diameters at the
% measured waist.  A nonzero ellipse rotation requires a 2-D model to retain
% the XY covariance; the present separable X/Y model uses the projected
% second-moment diameters below and reports that approximation explicitly.
cfg.laser.coherence = 'Fully coherent CW';
cfg.laser.spatialModel = ...
    'Gaussian waist (Sec. 7.1) plus measured-M2 q envelope (Sec. 7.3)';
cfg.laser.waistZ = 0;
cfg.laser.waistDiameterMajor = 1.1;
cfg.laser.waistDiameterMinor = 1.0;
cfg.laser.ellipseRotationDeg = 90;
cfg.laser.M2Major = 1.2;
cfg.laser.M2Minor = 1.2;
cfg.laser.decenterX = 0;
cfg.laser.decenterY = 0;
cfg.laser.tiltX = 0;
cfg.laser.tiltY = 0;

psi = cfg.laser.ellipseRotationDeg*pi/180;
cpsi = cos(psi); spsi = sin(psi);
cfg.laser.waistDiameterX = sqrt( ...
    (cfg.laser.waistDiameterMajor*cpsi)^2 + ...
    (cfg.laser.waistDiameterMinor*spsi)^2);
cfg.laser.waistDiameterY = sqrt( ...
    (cfg.laser.waistDiameterMajor*spsi)^2 + ...
    (cfg.laser.waistDiameterMinor*cpsi)^2);
cfg.laser.M2X = cfg.laser.M2Major*cpsi^2 + cfg.laser.M2Minor*spsi^2;
cfg.laser.M2Y = cfg.laser.M2Major*spsi^2 + cfg.laser.M2Minor*cpsi^2;
cfg.laser.ellipticity = cfg.laser.waistDiameterMajor/ ...
    cfg.laser.waistDiameterMinor;
cfg.laser.waistRadiusX = cfg.laser.waistDiameterX/2;
cfg.laser.waistRadiusY = cfg.laser.waistDiameterY/2;
cfg.laser.rayleighRangeX = pi*cfg.laser.waistRadiusX^2/ ...
    (cfg.laser.M2X*cfg.lambda);
cfg.laser.rayleighRangeY = pi*cfg.laser.waistRadiusY^2/ ...
    (cfg.laser.M2Y*cfg.lambda);
cfg.laser.divergenceHalfAngleX = cfg.laser.M2X*cfg.lambda/ ...
    (pi*cfg.laser.waistRadiusX);
cfg.laser.divergenceHalfAngleY = cfg.laser.M2Y*cfg.lambda/ ...
    (pi*cfg.laser.waistRadiusY);
cfg.laser.divergenceFullAngleX = 2*cfg.laser.divergenceHalfAngleX;
cfg.laser.divergenceFullAngleY = 2*cfg.laser.divergenceHalfAngleY;
% Backward-compatible scalar values and first spherical 6x expander.
cfg.M2 = cfg.laser.M2Y;
cfg.laserDiameter = sqrt(cfg.laser.waistDiameterX* ...
    cfg.laser.waistDiameterY);
% The first spherical, circularly symmetric expander is allowed to operate
% from 5x to 10x.  The optimized nominal point is kept deliberately small;
% larger values increase DOE steering angle and can violate the 10 um
% minimum lateral feature constraint.
cfg.beamExpanderMagnificationRange = [5.0 10.0];
cfg.beamExpanderMagnification = 5.0;
cfg.conditionedDiameterX = cfg.beamExpanderMagnification* ...
    cfg.laser.waistDiameterX;
cfg.conditionedDiameterY = cfg.beamExpanderMagnification* ...
    cfg.laser.waistDiameterY;
cfg.conditionedDiameter = cfg.conditionedDiameterX;
cfg.targetXWidth = 1.5;
cfg.targetYWidth = 1.0e-3;
cfg.finalYFocalLength = 100;
cfg.finalYBeamDiameter = 4*cfg.laser.M2Y*cfg.lambda*cfg.finalYFocalLength/ ...
    (pi*cfg.targetYWidth);
cfg.finalYLensClearAperture = 1.1*cfg.finalYBeamDiameter;

% Independent engineering acceptance limits.  No vendor proprietary phase
% file is used anywhere in this package.
cfg.acceptance.maxTilt = 10e-6;
cfg.acceptance.maxCurvatureSlope = 50e-6;
cfg.acceptance.maxXWidthError = 0.05;
cfg.acceptance.maxYWidthError = 0.01;
cfg.acceptance.uniformityFraction = 0.90;
cfg.acceptance.minUniformity = 0.90;
cfg.acceptance.propagationCheckDistance = 100;
cfg.acceptance.maxWidthChange = 0.01;
cfg.design.identity = 'Independent two-plane 32-level fused-silica relief DOE';
cfg.design.outputShape = '1-D X flat-top; Y unchanged by DOE';

% Independent manufacturable DOE surrogate.  The relief is invariant in Y
% and varies in X, consistent with the one-dimensional line shaper.  Fused
% silica index is calculated from the Malitson Sellmeier equation at 355 nm.
lambdaUm=1e3*cfg.lambda;
B1=0.6961663; B2=0.4079426; B3=0.8974794;
C1=0.0684043; C2=0.1162414; C3=9.896161;
nSquared=1+B1*lambdaUm^2/(lambdaUm^2-C1^2)+ ...
    B2*lambdaUm^2/(lambdaUm^2-C2^2)+ ...
    B3*lambdaUm^2/(lambdaUm^2-C3^2);
cfg.doe.material='Fused silica (Malitson Sellmeier model)';
cfg.doe.refractiveIndex=sqrt(nSquared);
cfg.doe.clearAperture=50;
cfg.doe.patternWidth=8.0; % central patterned width; outer aperture is unetched
cfg.doe.quantizationLevels=32;
cfg.doe.maskCount=log2(cfg.doe.quantizationLevels);
cfg.doe.minimumFeature=5e-3; % mm; user-confirmed lateral lithographic feature
% The two free-space-separated DOE surfaces directly transform the modestly
% expanded Gaussian X beam into the final 1.5 mm collimated flat-top.  The
% high-order target is required because uniformity is evaluated over the
% fixed central 90 percent (1.35 mm), not inferred from the 1/e^2 width.
% R2019b quantized-design sweep optimum for the frozen mechanical layout.
% The design width is slightly wider than the nominal acceptance width so
% that the fixed central 1.35 mm evaluation interval avoids the roll-off.
cfg.doe.targetDesignXWidth=1.54;
cfg.doe.targetSuperGaussianOrder=100;
cfg.doe.phaseIterations=200;
cfg.doe.quantizedRefinementIterations=120;
cfg.doe.jointQuantizedIterations=600;
cfg.doe.twoPiReliefDepth=cfg.lambda/(cfg.doe.refractiveIndex-1);
cfg.doe.heightStep=cfg.doe.twoPiReliefDepth/ ...
    cfg.doe.quantizationLevels;
cfg.doe.maximumReliefHeight=(cfg.doe.quantizationLevels-1)* ...
    cfg.doe.heightStep;
cfg.doe.maskEtchDepths=cfg.doe.heightStep* ...
    2.^(0:cfg.doe.maskCount-1);
cfg.doe.idealQuantizationEfficiency=(sin(pi/cfg.doe.quantizationLevels)/ ...
    (pi/cfg.doe.quantizationLevels))^2;
cfg.doe.useManufacturedPhase=true;

% Physical layout.
p.zLaser = cfg.laser.waistZ;
p.zSBE1 = 30; p.fSBE1 = -10;
p.fSBE2 = abs(p.fSBE1)*cfg.beamExpanderMagnification;
p.zSBE2 = p.zSBE1 + p.fSBE1 + p.fSBE2;
p.zDOE1 = 120;
p.zDOE2 = 220;
p.zYBE1 = 250; p.fYBE1 = -20;
p.mY = cfg.finalYBeamDiameter/cfg.conditionedDiameterY;
p.fYBE2 = abs(p.fYBE1)*p.mY;
p.zYBE2 = p.zYBE1 + p.fYBE1 + p.fYBE2;
% The unobstructed DOE pair is kept before the Y-only expansion.  This
% avoids clipping the 54.24 mm Y beam with the 50 mm maximum DOE diameter
% and retains sufficient free propagation for the quantized X shaper.
p.zYFL = 570; p.fYFL = cfg.finalYFocalLength;
p.zTarget = 670;
cfg.layout = p;

cfg.xTelescopeSeparation = 0;
cfg.xCompression = 1;
cfg.xAngularMagnification = 1;
cfg.xLastLensPower = 0;
cfg.xTargetGeometricWidth = cfg.targetXWidth;
end
