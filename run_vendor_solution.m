function result = run_vendor_solution(cfg, outputDir)
%RUN_VENDOR_SOLUTION Run ST-426-I-Y-A parameters in Holo/Or TopHatSim.p.
vendorDir = fullfile(outputDir, 'vendor_ST-426-I-Y-A');
if ~exist(vendorDir, 'dir')
    mkdir(vendorDir);
end
addpath(fullfile(fileparts(mfilename('fullpath')), 'references'));

nominalStruct.CA = cfg.vendor.clearAperture;
nominalStruct.beamDia = cfg.vendor.beamDiameter;
nominalStruct.f = cfg.fourierFocalLength;
nominalStruct.lambda = cfg.lambda;
nominalStruct.shape = 'line';
nominalStruct.THSize = cfg.vendor.catalogOutputAt100mm;
toleranceStruct.tolvariable_string = '';

close all force
set(0, 'DefaultFigureVisible', 'off');
TopHatSim(nominalStruct, toleranceStruct);
drawnow
figures = findall(0, 'Type', 'figure');
if isempty(figures)
    error('laser_sim:VendorNoFigure','Holo/Or model created no figure.');
end

[nativeXum,nativeI] = longestPlottedLine(figures);
nativeX = nativeXum/1000;
nativeI = nativeI/max(nativeI);
nativeMetrics = profile_metrics_common(nativeX,nativeI, ...
    cfg.vendor.catalogOutputAt100mm,cfg.uniformityFraction);

% Use the vendor-model exp(-2) output to set the X-only relay exactly.
relayMagnification = cfg.targetXWidth/nativeMetrics.widthE2;
xFinal = nativeX*relayMagnification;
finalMetrics = profile_metrics_common(xFinal,nativeI, ...
    cfg.targetXWidth,cfg.uniformityFraction);

% Only the first expander is rotationally symmetric. The later 9.04x
% expander acts in Y only, so X needs only the catalog-to-target gain.
xAngularGain = relayMagnification;
xCompressorF1 = cfg.layout.fXCompressorL1;
xCompressorF2 = -xCompressorF1/xAngularGain;
xCompressorL2Z = cfg.layout.zXCompressorL1 + ...
    xCompressorF1 + xCompressorF2;

% Common M2-corrected Y focusing stage.
yFocalLength = cfg.finalYFocalLength;
yBeamDiameter = cfg.finalYBeamDiameter;
y = linspace(-3e-3,3e-3,4001).';
Iy = exp(-8*(y/cfg.targetYWidth).^2);

% Physical common train ends at the f=100 mm focusing stage.
targetZ = cfg.layout.zTarget;
lastLensDistance = yFocalLength;

profileTable = table(1e3*xFinal,nativeI, ...
    'VariableNames',{'position_um','normalizedIntensity'});
writetable(profileTable,fullfile(vendorDir,'vendor_final_x_profile.csv'));
parameter = {'Part number';'Design wavelength';'Input beam diameter'; ...
    'Clear aperture';'Catalog full angle';'Catalog transfer region'; ...
    'Native Holo/Or width exp(-2)';'Catalog-to-target angular scale'; ...
    'Y-only second expander';'X compressor angular gain'; ...
    'X compressor f1';'X compressor f2';'Final X width exp(-2)'; ...
    'Final X width 50%';'Central 90% min/max uniformity'; ...
    'Y width exp(-2)';'Y cylinder focal length'; ...
    'Y beam diameter at final lens';'Required Y clear aperture'; ...
    'Total optical length'; ...
    'Last lens to target'};
value = {cfg.vendor.partNumber;cfg.vendor.optimizedWavelengthNm; ...
    cfg.vendor.beamDiameter;cfg.vendor.clearAperture; ...
    cfg.vendor.fullAngleMrad;cfg.vendor.transferRegionMrad; ...
    nativeMetrics.widthE2;relayMagnification;cfg.layout.mExpander2; ...
    xAngularGain;xCompressorF1;xCompressorF2; ...
    finalMetrics.widthE2;finalMetrics.width50;100*finalMetrics.uniformity; ...
    1e3*cfg.targetYWidth;yFocalLength;yBeamDiameter; ...
    cfg.finalYLensClearAperture; ...
    targetZ;lastLensDistance};
unit = {'-';'nm';'mm';'mm';'mrad';'mrad';'mm';'x';'x';'x';'mm';'mm'; ...
    'mm';'mm';'%';'um';'mm';'mm';'mm';'mm';'mm'};
writetable(table(parameter,value,unit),fullfile(vendorDir,'vendor_summary.csv'));

for index=1:numel(figures)
    print(figures(index),fullfile(vendorDir,sprintf('vendor_native_%02d.png',index)), ...
        '-dpng','-r180');
end
savefig(figures,fullfile(vendorDir,'vendor_native.fig'));
close(figures)
set(0, 'DefaultFigureVisible', 'on');

result.name = ['Vendor ' cfg.vendor.partNumber];
result.partNumber = cfg.vendor.partNumber;
result.x = xFinal;
result.Ix = nativeI;
result.y = y;
result.Iy = Iy;
result.metrics = finalMetrics;
result.nativeMetrics = nativeMetrics;
result.relayMagnification = relayMagnification;
result.relayF1 = xCompressorF1;
result.relayF2 = xCompressorF2;
result.xAngularGain = xAngularGain;
result.xCompressorAngularGain = xAngularGain;
result.xCompressorF1 = xCompressorF1;
result.xCompressorF2 = xCompressorF2;
result.xCompressorL2Z = xCompressorL2Z;
result.yFocalLength = yFocalLength;
result.yBeamDiameter = yBeamDiameter;
result.totalLength = targetZ;
result.lastLensDistance = lastLensDistance;
end

function [bestX,bestY] = longestPlottedLine(figures)
bestX=[]; bestY=[];
for figureIndex=1:numel(figures)
    lines=findall(figures(figureIndex),'Type','line');
    for lineIndex=1:numel(lines)
        x=get(lines(lineIndex),'XData');
        y=get(lines(lineIndex),'YData');
        if isnumeric(x) && isnumeric(y) && numel(x)>numel(bestX)
            bestX=x(:); bestY=y(:);
        end
    end
end
if isempty(bestX)
    error('laser_sim:VendorNoCurve','No numeric curve in vendor figure.');
end
end
