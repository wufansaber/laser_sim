function cfg = common_two_solution_config()
%COMMON_TWO_SOLUTION_CONFIG Inputs shared by vendor and in-house solutions.
% All lengths are mm unless explicitly named otherwise.
cfg.matlabRequired = '2019b';
cfg.lambda = 355e-6;
cfg.M2 = 1.2;
cfg.laserDiameter = 1.0;
cfg.laserEllipticity = 1.1;
cfg.doeBeamDiameter = 6.0;       % circular, collimated, full 1/e^2
cfg.clearAperture = 15.0;
cfg.targetXWidth = 1.5;          % full width at I=exp(-2)*Imax
cfg.targetYWidth = 1.0e-3;       % full width at I=exp(-2)*Imax
cfg.finalYFocalLength = 100;     % user-required final working distance
cfg.finalYBeamDiameter = 4*cfg.M2*cfg.lambda*cfg.finalYFocalLength/ ...
    (pi*cfg.targetYWidth);
cfg.finalYLensClearAperture = 1.1*cfg.finalYBeamDiameter;
cfg.uniformityFraction = 0.90;
cfg.commonConditionerLength = 150;
cfg.fourierFocalLength = 100;
cfg.grid.N = 32768;
cfg.grid.window = 40;

% Holo/Or standard product selected from the official product family table.
cfg.vendor.partNumber = 'ST-426-I-Y-A';
cfg.vendor.family = 'Angular Top-Hat / Stable Top-Hat line beam shaper';
cfg.vendor.optimizedWavelengthNm = 355;
cfg.vendor.beamDiameter = 6.0;
cfg.vendor.clearAperture = 15.0;
cfg.vendor.elementDiameter = 25.4;
cfg.vendor.thickness = 3.0;
cfg.vendor.material = 'Fused Silica';
cfg.vendor.coating = 'AR/AR';
cfg.vendor.fullAngleMrad = 4.5257;
cfg.vendor.transferRegionMrad = 0.14;
cfg.vendor.catalogOutputAt100mm = 2*cfg.fourierFocalLength* ...
    tan(0.5*cfg.vendor.fullAngleMrad*1e-3);

% In-house manufacturable phase design.
cfg.inhouse.phaseLevels = 32;

% Physical common train used in the XZ/YZ diagrams and system length.
cfg.layout.zLaser = 0;
cfg.layout.zExpander1L1 = 30;
cfg.layout.fExpander1L1 = -10;
cfg.layout.fExpander1L2 = 60;
cfg.layout.zExpander1L2 = cfg.layout.zExpander1L1 + ...
    cfg.layout.fExpander1L1 + cfg.layout.fExpander1L2;
cfg.layout.zDOE = cfg.commonConditionerLength;
cfg.layout.zInhouseDOE1 = 400;
cfg.layout.mExpander2 = cfg.finalYBeamDiameter/cfg.doeBeamDiameter;
cfg.layout.fExpander2L1 = -20;
cfg.layout.fExpander2L2 = abs(cfg.layout.fExpander2L1)*cfg.layout.mExpander2;
cfg.layout.zExpander2L1 = 180;
cfg.layout.zExpander2L2 = cfg.layout.zExpander2L1 + ...
    cfg.layout.fExpander2L1 + cfg.layout.fExpander2L2;
cfg.layout.zXCompressorL1 = 420;
cfg.layout.fXCompressorL1 = 150;
cfg.layout.zFinalLens = 600;
cfg.layout.zTarget = cfg.layout.zFinalLens + cfg.finalYFocalLength;
cfg.layout.zTerminalDOE = cfg.layout.zTarget;
cfg.inhouse.substrate = 'UV-grade fused silica';
cfg.inhouse.elementDiameter = 25.4;
cfg.inhouse.thickness = 3.0;
end
