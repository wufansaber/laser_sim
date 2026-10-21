function result=run_final_hybrid_DOE_lens_R2019b()
%RUN_FINAL_HYBRID_DOE_LENS_R2019B Reproduce the frozen 355 nm design.
% Run in MATLAB R2019b:
%   cd('D:/work/git_share/laser_sim/deliverables/FINAL_HYBRID_DOE_LENS_355nm_package/02_matlab_code');
%   result=run_final_hybrid_DOE_lens_R2019b();

codeDir=fileparts(mfilename('fullpath'));
packageDir=fileparts(codeDir);
addpath(codeDir,'-begin');
outputDir=fullfile(packageDir,'04_simulation_results','matlab_R2019b');
result=simulate_final_hybrid_doe_lens(outputDir);
export_zemax_sequential_prescription();

fprintf('\nSeparated double-sided DOE + Y-cylinder result\n');
fprintf('  X full 1/e^2 width       : %.6f mm\n',result.xTargetWidth);
fprintf('  Y full 1/e^2 width       : %.6f um\n',1e3*result.yTargetDiameter);
fprintf('  X central-90%% uniformity : %.4f %%\n',100*result.xUniformity);
fprintf('  Total useful efficiency  : %.4f %%\n',100*result.totalUsefulEfficiency);
fprintf('  Working distance         : %.3f mm\n',result.targetDistance);
fprintf('  Physical DOE count       : %d\n',result.physicalDoeCount);
fprintf('  Overall acceptance       : %d\n\n',result.pass);
end
