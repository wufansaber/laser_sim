function result = run_HOLOOR_collimated_line_R2019b()
%RUN_HOLOOR_COLLIMATED_LINE_R2019B Main program for selected HOLO/OR train.
rootDir=fileparts(mfilename('fullpath'));
packageDir=fileparts(rootDir);
if exist(fullfile(packageDir,'03_simulation_results'),'dir')
    outputDir=fullfile(packageDir,'03_simulation_results','collimated_line_R2019b');
else
    outputDir=fullfile(rootDir,'results','holoor_collimated_line_R2019b');
end
if ~exist(outputDir,'dir'); mkdir(outputDir); end
cfg=common_holoor_collimated_config();
if ~strcmp(version('-release'),cfg.matlabRequired)
    error('laser_sim:WrongMATLAB','Required %s, running %s.', ...
        cfg.matlabRequired,version('-release'));
end
result=run_holoor_collimated_solution(cfg,outputDir);
fid=fopen(fullfile(outputDir,'execution_manifest.txt'),'w');
fprintf(fid,'MATLAB version: %s\n',version);
fprintf(fid,'MATLAB release: %s\n',version('-release'));
fprintf(fid,'Execution date: %s\n',datestr(now,31));
fprintf(fid,'Vendor family: %s\n',cfg.vendor.family);
fprintf(fid,'Engineering ID: %s\n',cfg.vendor.engineeringID);
fprintf(fid,'Vendor PN status: %s\n',cfg.vendor.procurementStatus);
fprintf(fid,'Last lens: Y-only fY=%.6f mm\n',cfg.layout.fYFL);
fprintf(fid,'Last lens X optical power: %.6g 1/mm\n',cfg.xLastLensPower);
fprintf(fid,'Target X geometric width: %.9f mm\n',result.xWidthAtTarget);
fprintf(fid,'Target X marginal-ray angle: %.6g rad\n',result.maxAbsAngleAtTarget);
fprintf(fid,'Target Y exp(-2) width: %.6f um\n',1e3*cfg.targetYWidth);
fprintf(fid,'Geometric ABCD verification pass: %d\n',result.geometricPass);
fprintf(fid,'Vendor phase data available: %d\n',result.phaseCheck.phaseDataAvailable);
fprintf(fid,'Vendor phase verification pass: %d\n',result.phaseCheck.phaseVerified);
fprintf(fid,'Independent phase-surrogate pass: %d\n',result.surrogate.pass);
fprintf(fid,'Design verification pass: %d\n',result.designPass);
fprintf(fid,'Vendor acceptance pass: %d\n',result.acceptancePass);
fclose(fid);
end
