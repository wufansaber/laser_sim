function results = run_laser_sim()
%RUN_LASER_SIM Main entry point for the 355 nm laser-line feasibility model.
clc
cfg = laser_default_config();
results = simulate_laser_system(cfg);

outputDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
plot_laser_results(results, outputDir);
toleranceTable = run_tolerance_scan(cfg, outputDir);
results.toleranceTable = toleranceTable;
save(fullfile(outputDir, 'laser_sim_results.mat'), 'results', '-v7.3');

metric = {'X width at 50%'; 'Y full width at 1/e^2'; ...
    'X central-90% min/max uniformity'; 'X central-90% RMS uniformity'; ...
    'Optical length'; 'Last lens to target'; 'Y cylinder focal length'; ...
    'DOE beam diameter X'; 'DOE beam diameter Y'};
value = [results.xWidth50; 1e3*results.yWidth1e2; ...
    100*results.uniformity; 100*results.rmsUniformity; ...
    results.opticalLength; results.lastLensDistance; results.fY; ...
    2*results.doeBeamRadius(1); 2*results.doeBeamRadius(2)];
unit = {'mm'; 'um'; '%'; '%'; 'mm'; 'mm'; 'mm'; 'mm'; 'mm'};
summary = table(metric, value, unit);
writetable(summary, fullfile(outputDir, 'design_summary.csv'));

fprintf('\n355 nm coherent line-focus feasibility result\n');
fprintf('  X Top-Hat width (50%% edge) : %.6f mm\n', results.xWidth50);
fprintf('  Y width (full 1/e^2)       : %.6f um\n', 1e3*results.yWidth1e2);
fprintf('  X uniformity (min/max)     : %.3f %%\n', 100*results.uniformity);
fprintf('  Optical length             : %.3f mm\n', results.opticalLength);
fprintf('  Last lens to target        : %.3f mm\n', results.lastLensDistance);
fprintf('  Nominal constraints pass   : %d\n\n', results.requirementsPass);
end
