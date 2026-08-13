function cfg = common_holoor_collimated_config()
%COMMON_HOLOOR_COLLIMATED_CONFIG HOLO/OR collimated-line system inputs.
% All lengths are mm unless explicitly named otherwise.
cfg.matlabRequired = '2019b';
cfg.lambda = 355e-6;
cfg.M2 = 1.2;
cfg.laserDiameter = 1.0;
cfg.conditionedDiameter = 6.0;
cfg.moduleOutputXWidth = 6.0;
cfg.targetXWidth = 1.5;
cfg.targetYWidth = 1.0e-3;
cfg.finalYFocalLength = 100;
cfg.finalYBeamDiameter = 4*cfg.M2*cfg.lambda*cfg.finalYFocalLength/ ...
    (pi*cfg.targetYWidth);
cfg.finalYLensClearAperture = 1.1*cfg.finalYBeamDiameter;

% Vendor family is official; the engineering ID below is not an official PN.
cfg.vendor.family = 'HOLO/OR Collimated Beam Shaper Module';
cfg.vendor.engineeringID = 'CBSM-LINE-355-6MM-CUSTOM';
cfg.vendor.procurementStatus = 'Custom RFQ; final HOLO/OR PN pending';
cfg.vendor.inputWavelengthNm = 355;
cfg.vendor.inputBeamDiameter = 6.0;
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
cfg.vendor.maxPhaseRms = 0.10;      % rad; provisional until vendor contract
cfg.vendor.maxTilt = 10e-6;        % rad; user-allowed microradian scale
cfg.vendor.maxCurvatureSlope = 50e-6; % rad at X half-width, provisional

% Physical layout.
p.zLaser = 0;
p.zSBE1 = 30; p.fSBE1 = -10;
p.zSBE2 = 80; p.fSBE2 = 60;
p.zCBSM1 = 150;
p.zCBSM2 = 220;
p.zYBE1 = 250; p.fYBE1 = -20;
p.mY = cfg.finalYBeamDiameter/cfg.conditionedDiameter;
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
