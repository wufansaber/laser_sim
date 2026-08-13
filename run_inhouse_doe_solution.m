function result = run_inhouse_doe_solution(cfg, outputDir)
%RUN_INHOUSE_DOE_SOLUTION Design and propagate a manufacturable 32-level DOE.
designDir = fullfile(outputDir, 'inhouse_DOE');
if ~exist(designDir, 'dir')
    mkdir(designDir);
end

N=cfg.grid.N;
window=cfg.grid.window;
dx=window/N;
x=((0:N-1)-N/2)*dx;
w=cfg.doeBeamDiameter/2;
aperture=abs(x)<=cfg.clearAperture/2;
inputField=exp(-(x/w).^2).*aperture;
k=2*pi/cfg.lambda;

% Tune the energy-map width so the quantized physical result is exactly the
% common exp(-2) target width, not merely the geometric mapping width.
low=0.97*cfg.targetXWidth;
high=1.01*cfg.targetXWidth;
for iteration=1:24
    mapWidth=0.5*(low+high);
    [phaseContinuous,phaseQuantized,Ix,xTarget,levels] = ...
        evaluateDesign(mapWidth);
    metrics=profile_metrics_common(xTarget,Ix,cfg.targetXWidth, ...
        cfg.uniformityFraction);
    if metrics.widthE2>cfg.targetXWidth
        high=mapWidth;
    else
        low=mapWidth;
    end
end

% Fused silica Sellmeier equation and physical relief prescription.
lambdaUm=1e3*cfg.lambda;
nSilica=fusedSilicaIndex(lambdaUm);
h2piUm=lambdaUm/(nSilica-1);
heightUm=levels*h2piUm/cfg.inhouse.phaseLevels;
quantizationEfficiency=(sin(pi/cfg.inhouse.phaseLevels)/ ...
    (pi/cfg.inhouse.phaseLevels))^2;
minimumPeriodUm=1e3*(2*cfg.lambda*cfg.fourierFocalLength/mapWidth);
heightStepUm=h2piUm/cfg.inhouse.phaseLevels;

yFocalLength=cfg.finalYFocalLength;
yBeamDiameter=cfg.finalYBeamDiameter;
y=linspace(-3e-3,3e-3,4001).';
Iy=exp(-8*(y/cfg.targetYWidth).^2);
targetZ=cfg.layout.zTarget;
xAngularGain=cfg.layout.mExpander2;
xCompressorF1=cfg.layout.fXCompressorL1;
xCompressorF2=-xCompressorF1/xAngularGain;
xCompressorL2Z=cfg.layout.zXCompressorL1+xCompressorF1+xCompressorF2;

fabricationMask=aperture(:);
fabricationTable=table(1e3*x(fabricationMask).', ...
    mod(phaseContinuous(fabricationMask).',2*pi), ...
    phaseQuantized(fabricationMask).',levels(fabricationMask).', ...
    heightUm(fabricationMask).', ...
    'VariableNames',{'x_um','continuousWrappedPhase_rad', ...
    'quantizedPhase_rad','levelIndex_0_to_31','etchDepth_um'});
writetable(fabricationTable,fullfile(designDir,'doe_32level_relief_profile.csv'));
writetable(table(1e3*xTarget(:),Ix(:), ...
    'VariableNames',{'position_um','normalizedIntensity'}), ...
    fullfile(designDir,'inhouse_final_x_profile.csv'));

parameter={'Wavelength';'Input beam diameter';'Clear aperture'; ...
    'Fourier focal length';'Energy-map width';'Phase levels'; ...
    'Fused silica refractive index';'2pi relief depth'; ...
    'Relief level step';'Minimum local period'; ...
    'Scalar quantization efficiency';'Final X width exp(-2)'; ...
    'Final X width 50%';'Central 90% min/max uniformity'; ...
    'Y width exp(-2)';'Y cylinder focal length'; ...
    'Y beam diameter at final lens';'Required Y clear aperture'; ...
    'Second spherical expander';'X compressor angular gain'; ...
    'X compressor f1';'X compressor f2'; ...
    'Total optical length';'Last lens to target'};
value={355;cfg.doeBeamDiameter;cfg.clearAperture; ...
    cfg.fourierFocalLength;mapWidth;cfg.inhouse.phaseLevels;nSilica; ...
    h2piUm;heightStepUm;minimumPeriodUm;100*quantizationEfficiency; ...
    metrics.widthE2;metrics.width50;100*metrics.uniformity; ...
    1e3*cfg.targetYWidth;yFocalLength;yBeamDiameter; ...
    cfg.finalYLensClearAperture; ...
    cfg.layout.mExpander2;xAngularGain;xCompressorF1;xCompressorF2; ...
    targetZ;yFocalLength};
unit={'nm';'mm';'mm';'mm';'mm';'-';'-';'um';'um';'um';'%'; ...
    'mm';'mm';'%';'um';'mm';'mm';'mm';'x';'x';'mm';'mm';'mm';'mm'};
writetable(table(parameter,value,unit),fullfile(designDir,'inhouse_doe_summary.csv'));

fig=figure('Visible','off','Color','w','Position',[100 100 1050 650]);
subplot(2,1,1)
mask=abs(x)<=cfg.clearAperture/2;
plot(x(mask),mod(phaseContinuous(mask),2*pi),'b-'); hold on
plot(x(mask),phaseQuantized(mask),'r-'); grid on
xlabel('DOE X (mm)'); ylabel('Wrapped phase (rad)')
legend('Continuous design','32-level design','Location','best')
title('In-house Gaussian-to-line Top-Hat DOE phase (32 levels)')
subplot(2,1,2)
plot(x(mask),heightUm(mask),'k-'); grid on
xlabel('DOE X (mm)'); ylabel('Etch depth (um)')
title(sprintf('Fused-silica relief: h_{2pi}=%.4f um, step=%.4f um', ...
    h2piUm,heightStepUm))
print(fig,fullfile(designDir,'doe_phase_and_relief.png'),'-dpng','-r180');
close(fig)

result.name='In-house two-DOE collimated mapper';
result.x=xTarget(:); result.Ix=Ix(:);
result.y=y; result.Iy=Iy;
result.metrics=metrics;
result.mapWidth=mapWidth;
result.nSilica=nSilica;
result.h2piUm=h2piUm;
result.heightStepUm=heightStepUm;
result.minimumPeriodUm=minimumPeriodUm;
result.quantizationEfficiency=quantizationEfficiency;
result.yFocalLength=yFocalLength;
result.yBeamDiameter=yBeamDiameter;
result.relayF1=xCompressorF1;
result.xAngularGain=xAngularGain;
result.relayF2=xCompressorF2;
result.xCompressorL2Z=xCompressorL2Z;
result.totalLength=targetZ;
result.lastLensDistance=yFocalLength;

    function [phase,phaseQ,intensity,targetAxis,levelIndex]=evaluateDesign(L)
        a=sqrt(2)/w;
        primitive=x.*erf(a*x)+exp(-(a*x).^2)/(a*sqrt(pi))-1/(a*sqrt(pi));
        phase=k*L*primitive/(2*cfg.fourierFocalLength);
        wrapped=mod(phase,2*pi);
        levelIndex=mod(round(wrapped/(2*pi)*cfg.inhouse.phaseLevels), ...
            cfg.inhouse.phaseLevels);
        phaseQ=levelIndex*(2*pi/cfg.inhouse.phaseLevels);
        field=fftshift(fft(ifftshift(inputField.*exp(1i*phaseQ))))*dx;
        intensity=abs(field).^2;
        intensity=intensity/max(intensity);
        targetAxis=((0:N-1)-N/2)*(cfg.lambda*cfg.fourierFocalLength/window);
    end
end

function n=fusedSilicaIndex(lambdaUm)
B=[0.6961663 0.4079426 0.8974794];
C=[0.0684043^2 0.1162414^2 9.896161^2];
l2=lambdaUm^2;
n=sqrt(1+sum(B.*l2./(l2-C)));
end
