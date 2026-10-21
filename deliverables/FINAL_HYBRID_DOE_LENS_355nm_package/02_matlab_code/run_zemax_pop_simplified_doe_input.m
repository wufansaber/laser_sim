function result=run_zemax_pop_simplified_doe_input()
%RUN_ZEMAX_POP_SIMPLIFIED_DOE_INPUT Flat-wavefront Gaussian at DOE-A.
codeDir=fileparts(mfilename('fullpath')); packageDir=fileparts(codeDir);
zemaxDir=fullfile(packageDir,'06_zemax_sequential');
outputDir=fullfile(packageDir,'04_simulation_results', ...
    'zemax_POP_simplified_DOE_input');
if ~exist(outputDir,'dir'); mkdir(outputDir); end
cfg=final_hybrid_doe_lens_config();
nx=8192; ny=1024; xWidth=12; yWidth=128;
dx=xWidth/nx; dy=yWidth/ny;
x=((0:nx-1)-nx/2)*dx; y=((0:ny-1)-ny/2)*dy;
[X,Y]=meshgrid(x,y);
wx=cfg.doeInput.fullDiameterX/2; wy=cfg.doeInput.fullDiameterY/2;
field=exp(-(X/wx).^2-(Y/wy).^2);
field=field/sqrt(sum(abs(field(:)).^2)*dx*dy);
zbfName='DOE_INPUT_FLAT_PHASE_GAUSSIAN.ZBF';
zbfPackage=fullfile(zemaxDir,zbfName);
writeZbf(zbfPackage,field,dx,dy,cfg.lambda,wx,wy);

installDir='C:\Program Files\Ansys Zemax OpticStudio 2022 R2.02';
zemaxData='C:\Users\wufan\Documents\Zemax';
beamDir=fullfile(zemaxData,'POP','BEAMFILES');
if ~exist(beamDir,'dir'); mkdir(beamDir); end
copyfile(zbfPackage,fullfile(beamDir,zbfName),'f');
NET.addAssembly(fullfile(zemaxData,'ZOS-API','Libraries','ZOSAPI_NetHelper.dll'));
if ZOSAPI_NetHelper.ZOSAPI_Initializer.Initialize(installDir)~=1
    error('OpticStudio initialization failed.');
end
NET.addAssembly(fullfile(installDir,'ZOSAPI_Interfaces.dll'));
NET.addAssembly(fullfile(installDir,'ZOSAPI.dll'));
connection=ZOSAPI.ZOSAPI_Connection(); application=connection.CreateNewApplication();
cleanup=onCleanup(@() closeApplication(application)); %#ok<NASGU>
system=application.PrimarySystem;
system.LoadFile(fullfile(zemaxDir, ...
    'final_hybrid_355nm_SEQ_OpticStudio2022R2_validated.ZMX'),false);

pop=system.Analyses.New_Analysis_SettingsFirst( ...
    ZOSAPI.Analysis.AnalysisIDM.PhysicalOpticsPropagation);
popCleanup=onCleanup(@() closeAnalysis(pop)); %#ok<NASGU>
s=pop.GetSettings();
s.Wavelength.SetWavelengthNumber(1); s.Field.SetFieldNumber(1);
s.StartSurface.SetSurfaceNumber(13); s.EndSurface.SetSurfaceNumber(19);
s.SurfaceToBeam=0; s.UsePolarization=false; s.SeparateXY=true;
s.UseDiskStorage=true; s.BeamType=ZOSAPI.Analysis.PhysicalOptics.POPBeamTypes.File;
s.BeamTypeFilename=zbfName;
s.XSampling=ZOSAPI.Analysis.SampleSizes.S_8192x8192;
s.YSampling=ZOSAPI.Analysis.SampleSizes.S_1024x1024;
s.XWidth=xWidth; s.YWidth=yWidth; s.UseTotalPower=true; s.TotalPower=1;
s.DataType=ZOSAPI.Analysis.PhysicalOptics.POPDataTypes.Irradiance;
s.SaveTo(fullfile(outputDir,'POP_flat_Gaussian_DOE_to_target.CFG'));
pop.ApplyAndWaitForCompletion(); r=pop.GetResults(); g=r.GetDataGrid(0);
v=double(g.Values); nxOut=double(g.Nx); nyOut=double(g.Ny);
if isequal(size(v),[nxOut nyOut]); v=v.'; end
result.x=double(g.MinX)+(0:nxOut-1)*double(g.Dx);
result.y=double(g.MinY)+(0:nyOut-1)*double(g.Dy);
result.irradiance=max(v,0); result.power=sum(v(:))*double(g.Dx)*double(g.Dy);
result.norm=result.irradiance/max(result.irradiance(:));
[~,iy]=min(abs(result.y)); [~,ix]=min(abs(result.x));
result.xLine=result.norm(iy,:); result.xLine=result.xLine/max(result.xLine);
result.yLine=result.norm(:,ix).'; result.yLine=result.yLine/max(result.yLine);
result.fullWidthX=thresholdWidth(result.x,result.xLine,exp(-2));
result.fullWidthY=thresholdWidth(result.y,result.yLine,exp(-2));
use=abs(result.x)<=0.675;
result.uniformity=min(result.xLine(use))/max(result.xLine(use));
detectorWidth=0.050;
detectorSamples=max(1,round(detectorWidth/mean(diff(result.x))));
result.xLine50um=conv(result.xLine,ones(1,detectorSamples)/detectorSamples,'same');
result.uniformity50um=min(result.xLine50um(use))/max(result.xLine50um(use));
result.detectorAveragingWidth=detectorSamples*mean(diff(result.x));
xWindow=abs(result.x)<=0.75;
result.xWindowPower=sum(sum(result.irradiance(:,xWindow)))* ...
    double(g.Dx)*double(g.Dy);
result.sourceFullDiameterX=2*wx; result.sourceFullDiameterY=2*wy;
result.sourcePhaseRms=0; result.quantizationLevels=cfg.doe.quantizationLevels;
save(fullfile(outputDir,'simplified_DOE_input_POP_result.mat'),'result','-v7.3');
metric={'X full 1/e^2 width';'Y full 1/e^2 width'; ...
    'X uniformity at 50 um detector resolution'; ...
    'Raw coherent point-sampled X uniformity';'Propagated power'; ...
    'Power in X +/-0.75 mm'};
requirement={'1.500 mm +/-5%';'1.000 um +/-1%';'>=80%'; ...
    'reported, not acceptance';'>=85%';'>=85%'};
value=[result.fullWidthX;1e3*result.fullWidthY; ...
    100*result.uniformity50um;100*result.uniformity; ...
    100*result.power;100*result.xWindowPower];
pass=[abs(value(1)/1.5-1)<=0.05;abs(value(2)-1)<=0.01; ...
    value(3)>=80;true;value(5)>=85;value(6)>=85];
writetable(table(metric,requirement,value,pass), ...
    fullfile(outputDir,'simplified_DOE_input_acceptance.csv'));
fid=fopen(fullfile(outputDir,'simplified_DOE_input_POP_manifest.txt'),'w');
fprintf(fid,['source=coherent flat-phase Gaussian at DOE-A\n' ...
    'sourceFullDiameterX=%.12g\nsourceFullDiameterY=%.12g\n' ...
    'sourcePhaseRms=0\nquantizationLevels=%d\n' ...
    'targetFullWidthX=%.12g\ntargetFullWidthY=%.12g\n' ...
    'targetXUniformityRaw=%.12g\ntargetXUniformity50um=%.12g\n' ...
    'detectorAveragingWidth=%.12g\ntargetPower=%.12g\n' ...
    'targetXWindowPower=%.12g\n'],2*wx,2*wy,cfg.doe.quantizationLevels, ...
    result.fullWidthX,result.fullWidthY,result.uniformity, ...
    result.uniformity50um,result.detectorAveragingWidth,result.power, ...
    result.xWindowPower); fclose(fid);
fig=figure('Visible','off','Color','w','Position',[80 80 1320 620]);
imagesc(result.x,1e3*result.y,result.norm); axis xy; colormap(parula); colorbar
xlim([-1.2 1.2]); ylim([-5 5]); xlabel('X (mm)'); ylabel('Y (um)');
title('OpticStudio POP: flat-phase coherent Gaussian input at DOE');
print(fig,fullfile(outputDir,'simplified_DOE_input_target_2D.png'),'-dpng','-r180');
close(fig);
writetable(table(result.x(:),result.xLine(:),result.xLine50um(:), ...
    'VariableNames',{'X_mm','Raw_normalized_irradiance', ...
    'Averaged_50um_normalized_irradiance'}), ...
    fullfile(outputDir,'simplified_DOE_input_X_lineout.csv'));
fig=figure('Visible','off','Color','w','Position',[80 80 1200 560]);
plot(result.x,result.xLine,'Color',[0.65 0.75 0.95],'LineWidth',0.8); hold on
plot(result.x,result.xLine50um,'b-','LineWidth',1.8);
xline(-0.675,'k--'); xline(0.675,'k--'); grid on
xlim([-0.9 0.9]); ylim([0 1.08]); xlabel('X (mm)');
ylabel('Normalized irradiance');
legend('Raw coherent POP','50 um detector average','Acceptance boundary', ...
    'Location','south');
title(sprintf('X lineout: raw U=%.2f%%, 50 um U=%.2f%%', ...
    100*result.uniformity,100*result.uniformity50um));
print(fig,fullfile(outputDir,'simplified_DOE_input_X_uniformity.png'), ...
    '-dpng','-r180'); close(fig); disp(result)
end

function writeZbf(fileName,field,dx,dy,lambda,wx,wy)
[ny,nx]=size(field); fid=fopen(fileName,'w','ieee-le');
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid,int32([1 nx ny 0 0 0 0 0 0]),'int32');
fwrite(fid,[dx dy 0 pi*wx^2/lambda wx 0 pi*wy^2/lambda wy ...
    lambda 1 0 0 zeros(1,8)],'double');
ordered=field.'; ordered=ordered(:);
fwrite(fid,[real(ordered).';imag(ordered).'],'double');
end
function width=thresholdWidth(x,intensity,level)
[~,center]=min(abs(x)); left=find(intensity(1:center)<level,1,'last');
rr=find(intensity(center:end)<level,1,'first');
if isempty(left)||isempty(rr); width=NaN; return; end
right=center+rr-1;
xl=x(left)+(level-intensity(left))*(x(left+1)-x(left))/ ...
    (intensity(left+1)-intensity(left));
xr=x(right-1)+(level-intensity(right-1))*(x(right)-x(right-1))/ ...
    (intensity(right)-intensity(right-1)); width=xr-xl;
end
function closeAnalysis(a)
try; if ~isempty(a); a.Close(); end; catch; end
end
function closeApplication(a)
try; if ~isempty(a); a.CloseApplication(); end; catch; end
end
