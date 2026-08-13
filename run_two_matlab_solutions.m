function comparison = run_two_matlab_solutions()
%RUN_TWO_MATLAB_SOLUTIONS Generate both requested results in one R2019b run.
rootDir=fileparts(mfilename('fullpath'));
outputDir=fullfile(rootDir,'results','two_solutions_R2019b');
if ~exist(outputDir,'dir'); mkdir(outputDir); end
cfg=common_two_solution_config();

if ~strcmp(version('-release'),cfg.matlabRequired)
    error('laser_sim:WrongMATLAB','Required %s, running %s.', ...
        cfg.matlabRequired,version('-release'));
end

vendor=run_vendor_solution(cfg,outputDir);
cfg.commonXAngularGain=vendor.xAngularGain;
cfg.layout.fXCompressorL2=vendor.xCompressorF2;
cfg.layout.zXCompressorL2=vendor.xCompressorL2Z;
inhouse=run_inhouse_doe_solution(cfg,outputDir);
collimated=simulate_collimated_x_mapper(fullfile(outputDir,'inhouse_collimated_X'));
inhouse.collimated=collimated;
inhouse.focalDesignMetrics=inhouse.metrics;
inhouse.metrics=collimated.metricsAtTarget;
inhouse.x=collimated.x;
inhouse.Ix=collimated.IatTarget;
layoutTable=plot_yz_optical_paths(cfg,vendor,inhouse,outputDir);
xzLayoutTable=plot_xz_optical_paths(cfg,vendor,inhouse,outputDir);

model={vendor.name;inhouse.name};
xWidthE2_mm=[vendor.metrics.widthE2;inhouse.metrics.widthE2];
xWidth50_mm=[vendor.metrics.width50;inhouse.metrics.width50];
yWidthE2_um=[1e3*cfg.targetYWidth;1e3*cfg.targetYWidth];
uniformityPercent=[100*vendor.metrics.uniformity;100*inhouse.metrics.uniformity];
xWavefrontRms_urad=[NaN;1e6*collimated.wavefrontAtTarget.rmsAngle];
collimationVerified=[false;true];
totalLength_mm=[vendor.totalLength;inhouse.totalLength];
lastLensDistance_mm=[vendor.lastLensDistance;inhouse.lastLensDistance];
pass=xWidthE2_mm>=0.99*cfg.targetXWidth & ...
    xWidthE2_mm<=1.01*cfg.targetXWidth & ...
    abs(yWidthE2_um-1.0)<=0.01 & ...
    uniformityPercent>=90 & totalLength_mm<=2000 & ...
    abs(lastLensDistance_mm-100)<=1e-12 & ...
    collimationVerified & xWavefrontRms_urad<=10;
comparison=table(model,xWidthE2_mm,xWidth50_mm,yWidthE2_um, ...
    uniformityPercent,xWavefrontRms_urad,collimationVerified, ...
    totalLength_mm,lastLensDistance_mm,pass);
writetable(comparison,fullfile(outputDir,'two_solution_comparison.csv'));

fig=figure('Visible','off','Color','w','Position',[100 100 1100 700]);
subplot(2,1,1)
plot(vendor.x,vendor.Ix,'b-','LineWidth',1.2); hold on
plot(inhouse.x,inhouse.Ix,'r--','LineWidth',1.2)
xlim([-0.82 0.82]); ylim([0 1.03]); grid on
xlabel('X at target (mm)'); ylabel('Normalized irradiance')
title('Same MATLAB R2019b: final X line profiles')
legend(vendor.name,inhouse.name,'Location','south')
subplot(2,1,2)
plot(1e3*vendor.y,vendor.Iy,'k-','LineWidth',1.3); grid on
xlim([-2.5 2.5]); ylim([0 1.03])
xlabel('Y at target (um)'); ylabel('Normalized irradiance')
title(sprintf('Shared M^2-corrected Y focus (full 1/e^2 width = %.1f um)', ...
    1e3*cfg.targetYWidth))
print(fig,fullfile(outputDir,'two_solution_profiles.png'),'-dpng','-r180');
close(fig)

% Save compact separable 2-D maps for both systems.
plot2D(vendor,'vendor_final_2d.png');
plot2D(inhouse,'inhouse_final_2d.png');

manifestFile=fullfile(outputDir,'matlab_execution_manifest.txt');
fid=fopen(manifestFile,'w');
fprintf(fid,'MATLAB version: %s\n',version);
fprintf(fid,'MATLAB release: %s\n',version('-release'));
fprintf(fid,'Execution date: %s\n',datestr(now,31));
fprintf(fid,'Executable supplied by user: D:\\Program Files\\Polyspace\\R2019b\\bin\\matlab.exe\n');
fprintf(fid,'Vendor part: %s\n',cfg.vendor.partNumber);
fprintf(fid,'Common wavelength: %.0f nm\n',1e6*cfg.lambda);
fprintf(fid,'Common DOE beam diameter: %.4f mm\n',cfg.doeBeamDiameter);
fprintf(fid,'Common clear aperture: %.4f mm\n',cfg.clearAperture);
fprintf(fid,'Final Y full 1/e^2 width: %.4f um\n',1e3*cfg.targetYWidth);
fprintf(fid,'Final crossed-cylinder Y focal length: %.4f mm\n',cfg.finalYFocalLength);
fprintf(fid,'Beam diameter at final lens: %.4f mm\n',cfg.finalYBeamDiameter);
fprintf(fid,'Suggested final-lens clear aperture: %.4f mm\n',cfg.finalYLensClearAperture);
fclose(fid);
save(fullfile(outputDir,'two_solution_results.mat'), ...
    'cfg','vendor','inhouse','collimated','comparison','layoutTable', ...
    'xzLayoutTable','-v7.3');
disp(comparison)

    function plot2D(solution,fileName)
        xMask=abs(solution.x)<=0.85;
        yMask=abs(solution.y)<=2e-3;
        imageData=solution.Iy(yMask)*solution.Ix(xMask).';
        f=figure('Visible','off','Color','w','Position',[100 100 1000 380]);
        imagesc(solution.x(xMask),1e3*solution.y(yMask),imageData)
        axis xy; xlabel('X (mm)'); ylabel('Y (um)'); colorbar
        title([solution.name ' normalized target irradiance'])
        print(f,fullfile(outputDir,fileName),'-dpng','-r180'); close(f)
    end
end
