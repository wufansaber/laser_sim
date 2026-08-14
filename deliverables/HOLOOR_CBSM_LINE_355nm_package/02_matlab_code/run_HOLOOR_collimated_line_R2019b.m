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
laserReferenceVerification=verify_laser_model_against_reference(cfg,outputDir);
result=run_holoor_collimated_solution(cfg,outputDir);
result.laserReferenceVerification=laserReferenceVerification;
fid=fopen(fullfile(outputDir,'execution_manifest.txt'),'w');
fprintf(fid,'MATLAB version: %s\n',version);
fprintf(fid,'MATLAB release: %s\n',version('-release'));
fprintf(fid,'Execution date: %s\n',datestr(now,31));
fprintf(fid,'Vendor family: %s\n',cfg.vendor.family);
fprintf(fid,'Engineering ID: %s\n',cfg.vendor.engineeringID);
fprintf(fid,'Vendor PN status: %s\n',cfg.vendor.procurementStatus);
fprintf(fid,'Laser coherence: %s\n',cfg.laser.coherence);
fprintf(fid,'Laser waist location: %.6f mm\n',cfg.laser.waistZ);
fprintf(fid,'Laser waist X/Y full 1/e^2 diameters: %.6f / %.6f mm\n', ...
    cfg.laser.waistDiameterX,cfg.laser.waistDiameterY);
fprintf(fid,'Laser ellipticity / rotation: %.6f / %.6f deg\n', ...
    cfg.laser.ellipticity,cfg.laser.ellipseRotationDeg);
fprintf(fid,'Laser measured M2X/M2Y: %.6f / %.6f\n', ...
    cfg.laser.M2X,cfg.laser.M2Y);
fprintf(fid,'Laser full divergence X/Y: %.9g / %.9g rad\n', ...
    cfg.laser.divergenceFullAngleX,cfg.laser.divergenceFullAngleY);
fprintf(fid,'Gaussian reference-model verification pass: %d\n', ...
    all(laserReferenceVerification.pass));
fprintf(fid,'Last lens: Y-only fY=%.6f mm\n',cfg.layout.fYFL);
fprintf(fid,'Last lens X optical power: %.6g 1/mm\n',cfg.xLastLensPower);
fprintf(fid,'Target X geometric width: %.9f mm\n',result.xWidthAtTarget);
fprintf(fid,'Target X marginal-ray angle: %.6g rad\n',result.maxAbsAngleAtTarget);
fprintf(fid,'Target Y exp(-2) width: %.6f um\n',1e3*cfg.targetYWidth);
fprintf(fid,'Geometric ABCD verification pass: %d\n',result.geometricPass);
fprintf(fid,'Vendor phase data available: %d\n',result.phaseCheck.phaseDataAvailable);
fprintf(fid,'Vendor phase verification pass: %d\n',result.phaseCheck.phaseVerified);
fprintf(fid,'Independent phase-surrogate pass: %d\n',result.surrogate.pass);
fprintf(fid,'Y M2 propagation pass: %d\n',result.yModel.pass);
fprintf(fid,'Calculated target Y full 1/e^2 width: %.9f mm\n', ...
    result.yModel.targetDiameter);
fprintf(fid,'Design verification pass: %d\n',result.designPass);
fprintf(fid,'Vendor acceptance pass: %d\n',result.acceptancePass);
fclose(fid);
save(fullfile(outputDir,'holoor_collimated_result.mat'),'result','-v7.3');
end
