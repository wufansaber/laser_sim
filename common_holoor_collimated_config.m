function cfg = common_holoor_collimated_config()
%COMMON_HOLOOR_COLLIMATED_CONFIG HOLO/OR collimated-line system inputs.
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
cfg.laser.waistDiameterMajor = 1.0;
cfg.laser.waistDiameterMinor = 1.0;
cfg.laser.ellipseRotationDeg = 0;
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
cfg.beamExpanderMagnification = 6.0;
cfg.conditionedDiameterX = cfg.beamExpanderMagnification* ...
    cfg.laser.waistDiameterX;
cfg.conditionedDiameterY = cfg.beamExpanderMagnification* ...
    cfg.laser.waistDiameterY;
cfg.conditionedDiameter = cfg.conditionedDiameterX;
cfg.moduleOutputXWidth = 6.0;
cfg.targetXWidth = 1.5;
cfg.targetYWidth = 1.0e-3;
cfg.finalYFocalLength = 100;
cfg.finalYBeamDiameter = 4*cfg.laser.M2Y*cfg.lambda*cfg.finalYFocalLength/ ...
    (pi*cfg.targetYWidth);
cfg.finalYLensClearAperture = 1.1*cfg.finalYBeamDiameter;

% Vendor family is official; the engineering ID below is not an official PN.
cfg.vendor.family = 'HOLO/OR Collimated Beam Shaper Module';
cfg.vendor.engineeringID = 'CBSM-LINE-355-6MM-CUSTOM';
cfg.vendor.procurementStatus = 'Custom RFQ; final HOLO/OR PN pending';
cfg.vendor.inputWavelengthNm = 355;
cfg.vendor.inputBeamDiameter = cfg.conditionedDiameterX;
cfg.vendor.inputBeamDiameterY = cfg.conditionedDiameterY;
cfg.vendor.outputShape = '1-D line, X flat-top; Y unchanged';
cfg.vendor.outputXWidth = 6.0;
cfg.vendor.requiredExitPhase = 'Flat X phase / collimated X output';
codeDir = fileparts(mfilename('fullpath'));
packageDir = fileparts(codeDir);
if exist(fullfile(packageDir,'01_vendor_model'),'dir')
    cfg.vendor.phaseFile = fullfile(packageDir,'01_vendor_model', ...
        'HOLOOR_CBSM_LINE_355_exit_complex_field.mat');
else
    cfg.vendor.phaseFile = fullfile(codeDir,'references', ...
        'HOLOOR_CBSM_LINE_355_exit_complex_field.mat');
end
cfg.vendor.maxPhaseRms = 0.12;      % rad; user-accepted engineering limit
cfg.vendor.maxTilt = 10e-6;        % rad; user-allowed microradian scale
cfg.vendor.maxCurvatureSlope = 50e-6; % rad at X half-width, provisional

% Independent manufacturable DOE surrogate.  The relief is invariant in Y
% and varies in X, consistent with the one-dimensional line shaper.  Fused
% silica index is calculated from the Malitson Sellmeier equation at 355 nm.
lambdaUm=1e3*cfg.lambda;
B1=0.6961663; B2=0.4079426; B3=0.8974794;
C1=0.0684043; C2=0.1162414; C3=9.896161;
nSquared=1+B1*lambdaUm^2/(lambdaUm^2-C1^2)+ ...
    B2*lambdaUm^2/(lambdaUm^2-C2^2)+ ...
    B3*lambdaUm^2/(lambdaUm^2-C3^2);
cfg.doe.material='Fused silica (Sellmeier model)';
cfg.doe.refractiveIndex=sqrt(nSquared);
cfg.doe.clearAperture=15;
cfg.doe.patternWidth=8.0; % central patterned width; outer aperture is unetched
cfg.doe.quantizationLevels=32;
cfg.doe.maskCount=log2(cfg.doe.quantizationLevels);
cfg.doe.minimumFeature=10e-3; % mm; lateral lithographic cell pitch
% The independent relief is pre-compensated slightly above the nominal
% 6 mm geometrical line width so that its coherent 1/e^2 width is 1.5 mm
% after the 4:1 X telescope.  This does not change the vendor requirement.
cfg.doe.designOutputXWidth=6.20;
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
p.zSBE2 = 80; p.fSBE2 = 60;
p.zCBSM1 = 150;
p.zCBSM2 = 220;
p.zYBE1 = 250; p.fYBE1 = -20;
p.mY = cfg.finalYBeamDiameter/cfg.conditionedDiameterY;
p.fYBE2 = abs(p.fYBE1)*p.mY;
p.zYBE2 = p.zYBE1 + p.fYBE1 + p.fYBE2;
p.zCXC1 = 430; p.fXC1 = 160;
p.zCXC2 = 550; p.fXC2 = -40;
p.zYFL = 600; p.fYFL = cfg.finalYFocalLength;
p.zTarget = 700;
cfg.layout = p;

cfg.xTelescopeSeparation = p.zCXC2-p.zCXC1;
cfg.xCompression = abs(p.fXC2/p.fXC1);
cfg.xAngularMagnification = abs(p.fXC1/p.fXC2);
cfg.xLastLensPower = 0;
cfg.xTargetGeometricWidth = cfg.moduleOutputXWidth*cfg.xCompression;
end
