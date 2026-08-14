function run_doe_optimization_candidate(name,designWidth,sgOrder,jointIterations)
%RUN_DOE_OPTIMIZATION_CANDIDATE Parameter-screening helper for R2019b.
rootDir='D:/work/git_share/laser_sim';
codeDir=fullfile(rootDir,'deliverables', ...
    'INDEPENDENT_RELIEF_DOE_355nm_package','02_matlab_code');
addpath(codeDir);
cfg=independent_relief_doe_config();
cfg.doe.targetDesignXWidth=designWidth;
cfg.doe.targetSuperGaussianOrder=sgOrder;
cfg.doe.jointQuantizedIterations=jointIterations;
outputDir=fullfile(rootDir,'tmp','doe_main_config_optimization',name);
if ~exist(outputDir,'dir'); mkdir(outputDir); end
r=simulate_independent_relief_doe(cfg,outputDir);
save(fullfile(outputDir,'candidate_result.mat'),'cfg','r','-v7.3');
fid=fopen(fullfile(outputDir,'candidate_result.txt'),'w');
fprintf(fid,'name=%s\n',name);
fprintf(fid,'designWidth_mm=%.9f\n',designWidth);
fprintf(fid,'superGaussianOrder=%d\n',sgOrder);
fprintf(fid,'jointIterations=%d\n',jointIterations);
fprintf(fid,'measuredWidth_mm=%.12f\n',r.targetMeasuredWidth);
fprintf(fid,'uniformity_percent=%.12f\n',100*r.targetUniformity);
fprintf(fid,'meanTilt_urad=%.12f\n',1e6*r.targetWave.meanAngle);
fprintf(fid,'curvatureEdgeSlope_urad=%.12f\n',1e6*r.targetEdgeSlope);
fprintf(fid,'widthChange100mm_percent=%.12f\n',100*r.targetWidthChange);
fprintf(fid,'pass=%d\n',r.pass);
fclose(fid);
end
