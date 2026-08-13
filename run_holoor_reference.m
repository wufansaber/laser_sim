function run_holoor_reference()
%RUN_HOLOOR_REFERENCE Exercise the supplied encrypted Holo/Or black box.
% This opens the vendor plots. It is intentionally separate from the main
% model because TopHatSim.p does not return numeric field arrays.
rootDir = fileparts(mfilename('fullpath'));
addpath(fullfile(rootDir, 'references'));

cfg = laser_default_config();
referenceResult = simulate_laser_system(cfg);
nominalStruct.CA = cfg.shaper.clearAperture;
nominalStruct.beamDia = 2*mean(referenceResult.doeBeamRadius);
nominalStruct.f = cfg.shaper.fX;
nominalStruct.lambda = cfg.lambda;
nominalStruct.shape = 'line';
nominalStruct.THSize = cfg.shaper.topHatWidth;
toleranceStruct.tolvariable_string = '';
TopHatSim(nominalStruct, toleranceStruct);
end
