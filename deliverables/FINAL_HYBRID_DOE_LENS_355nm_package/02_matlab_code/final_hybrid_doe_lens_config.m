function cfg = final_hybrid_doe_lens_config()
%FINAL_HYBRID_DOE_LENS_CONFIG Frozen 355 nm hybrid-element inputs.
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
cfg.finalYFocalLength = 80;
% Formal simplified DOE-plane POP model: a deterministic coherent field
% with Gaussian irradiance and exactly flat phase at DOE-A.  A true flat-
% phase Gaussian realization has M^2=1 at this reference plane.
cfg.model.flatGaussianAtDoe=true;
cfg.model.useSimplifiedFeedback=false;
cfg.doeInput.M2X=1;
cfg.doeInput.M2Y=1;
cfg.doeInput.fullDiameterX=3.25;
% Calibrated by the simplified OpticStudio POP so the physical fY=80 mm
% thick cylindrical lens produces a 1.00 um full 1/e^2 target width.
cfg.doeInput.fullDiameterY=45.16;
cfg.finalYBeamDiameter = 4*cfg.laser.M2Y*cfg.lambda*cfg.finalYFocalLength/ ...
    (pi*cfg.targetYWidth);
cfg.finalYLensClearAperture = 50;

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
cfg.design.identity = ['One plane-parallel double-sided fused-silica DOE ' ...
    'followed by one independent HPFS 7980 Y cylindrical lens'];
cfg.design.physicalDoeCount = 1;
cfg.design.phaseSurfaceCount = 2;
cfg.design.routing = ['DOE surface A -> 12 mm plane-parallel DOE -> ' ...
    'DOE surface B -> 20 mm air -> independent 20 mm HPFS 7980 ' ...
    'Y cylinder -> 80 mm air working distance'];
cfg.design.outputShape = ['X flat-top focal-plane intensity; ' ...
    'Y 1 um Gaussian focus'];

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
cfg.doe.substrateThickness=12;
hpfsA=[0.68374049400 0.42032361300 0.58502748000];
hpfsB=[0.00460352869 0.01339688560 64.49327320000];
cfg.glass.hpfs7980RefractiveIndex355=sqrt(1+sum( ...
    hpfsA.*lambdaUm^2./(lambdaUm^2-hpfsB)));
cfg.doe.zoneCenterX=[-10 10];
cfg.doe.zoneClearWidth=[10 10];
cfg.doe.clearAperture=50;
cfg.doe.patternWidth=12.0; % central patterned width; outer aperture is unetched
cfg.doe.quantizationLevels=16;
cfg.doe.maskCount=log2(cfg.doe.quantizationLevels);
cfg.doe.minimumFeature=5e-3; % mm; user-confirmed lateral lithographic feature
% OpticStudio Grid Phase datum: intentional +2.5 um pattern shift used by
% the frozen 88.68% POP configuration.  It is common to both DOE faces.
cfg.doe.zemaxGridDecenterX=2.5e-3; % mm
% The two free-space-separated DOE surfaces directly transform the modestly
% expanded Gaussian X beam into the final 1.5 mm collimated flat-top.  The
% high-order target is required because uniformity is evaluated over the
% fixed central 90 percent (1.35 mm), not inferred from the 1/e^2 width.
% R2019b quantized-design sweep optimum for the frozen mechanical layout.
% The design width is slightly wider than the nominal acceptance width so
% that the fixed central 1.35 mm evaluation interval avoids the roll-off.
cfg.doe.targetDesignXWidth=1.54;
cfg.doe.targetSuperGaussianOrder=60;
cfg.doe.phaseIterations=360;
cfg.doe.quantizedRefinementIterations=1600;
cfg.doe.jointQuantizedIterations=1600;
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

% Physical layout.  The first group is circularly symmetric.  The compact
% X-only relay reduces the 5 mm conditioned X beam to about 3 mm without
% affecting Y.  The Y-only Galilean telescope supplies the 43.392 mm beam
% needed by the independent fY=80 mm HPFS 7980 cylindrical lens.
p.zLaser = cfg.laser.waistZ;
p.zSBE1 = 30; p.fSBE1 = -10;
p.fSBE2 = abs(p.fSBE1)*cfg.beamExpanderMagnification;
p.zSBE2 = p.zSBE1 + p.fSBE1 + p.fSBE2;
p.zXRelay1=100; p.fXRelay1=100;
p.xRelayMagnification=0.65;
p.fXRelay2=-p.fXRelay1*p.xRelayMagnification;
p.zXRelay2=p.zXRelay1+p.fXRelay1+p.fXRelay2;
p.zYBE1 = 220; p.fYBE1 = -20;
p.mY = cfg.finalYBeamDiameter/cfg.conditionedDiameterY;
p.fYBE2 = abs(p.fYBE1)*p.mY;
p.zYBE2 = p.zYBE1 + p.fYBE1 + p.fYBE2;
p.zHybrid=480;
p.zHybridBack=p.zHybrid+cfg.doe.substrateThickness;
p.zFinalYFront=p.zHybridBack+20;
p.zFinalYBack=p.zFinalYFront+20;
p.fFinalY=cfg.finalYFocalLength;
p.zTarget=p.zFinalYBack+cfg.finalYFocalLength;
cfg.layout = p;

% Mechanical center thicknesses do not change any frozen focal length.
% The two large-aperture elements are deliberately thickened so their
% powered cylindrical edges retain robust positive material thickness.
cfg.mechanical.ybe2CenterThickness=12;
cfg.mechanical.doeCenterThickness=cfg.doe.substrateThickness;
cfg.mechanical.doeToFinalYLensAirGap=20;
cfg.mechanical.finalYLensCenterThickness=20;
% Aplanatic cylindrical conic for collimated HPFS7980-to-air focusing.
% For an object at infinity in index n and a focus in air, K=-n^2 keeps
% the optical path from the plane input wavefront to the focus constant.
cfg.mechanical.finalYLensConic=-cfg.glass.hpfs7980RefractiveIndex355^2;

cfg.xTelescopeSeparation = p.zXRelay2-p.zXRelay1;
cfg.xCompression = p.xRelayMagnification;
cfg.xAngularMagnification = 1/p.xRelayMagnification;
cfg.xLastLensPower = 1/p.fXRelay2;
cfg.xTargetGeometricWidth = cfg.targetXWidth;
end
