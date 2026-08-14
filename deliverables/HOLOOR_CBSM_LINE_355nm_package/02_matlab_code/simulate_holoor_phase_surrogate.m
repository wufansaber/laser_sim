function result = simulate_holoor_phase_surrogate(cfg, outputDir)
%SIMULATE_HOLOOR_PHASE_SURROGATE Independent two-element phase surrogate.
% This is not a HOLO/OR proprietary model.  A measured-M2, fully coherent
% waist field is propagated through the first spherical beam expander.
% Element 1 then maps the resulting field into a line-like flat-top and
% element 2 cancels the mapped phase.
% The resulting complex field is propagated through the actual downstream
% X telescope.  The final Y-only lens is identity in X.
if ~exist(outputDir,'dir'); mkdir(outputDir); end

lambda=cfg.lambda;
k=2*pi/lambda;
N=65536;
window=80;
dx=window/N;
x=((0:N-1)-N/2)*dx;
samplesPerFeature=ceil(cfg.doe.minimumFeature/dx);
actualFeature=samplesPerFeature*dx;
clearAperture=cfg.doe.clearAperture;
outputWidth=cfg.doe.designOutputXWidth;
mapperDistance=cfg.layout.zCBSM2-cfg.layout.zCBSM1;
aperture=abs(x)<=clearAperture/2;
patternAperture=abs(x)<=cfg.doe.patternWidth/2;

% Laser exit is the measured waist: Sec. 7.1 Gaussian amplitude and flat
% wavefront.  The measured M2=1.2 is propagated to the module with the
% generalized q parameter of Sec. 7.3 (M2*lambda in the imaginary term).
[Elaser,sourceMeta]=build_coherent_laser_waist_1d(x,cfg,'X');
m2x=cfg.laser.M2X;
q0=1i*pi*cfg.laser.waistRadiusX^2/(m2x*lambda);
qSBE1Before=q0+(cfg.layout.zSBE1-cfg.layout.zLaser);
qSBE1After=1/(1/qSBE1Before-1/cfg.layout.fSBE1);
qSBE2Before=qSBE1After+(cfg.layout.zSBE2-cfg.layout.zSBE1);
qSBE2After=1/(1/qSBE2Before-1/cfg.layout.fSBE2);
qModule=qSBE2After+(cfg.layout.zCBSM1-cfg.layout.zSBE2);
qValues=[q0;qSBE1Before;qSBE1After;qSBE2Before;qSBE2After;qModule];
qStages={'LASER waist';'SBE1 before';'SBE1 after';'SBE2 before'; ...
    'SBE2 after';'CBSM1 input'};
qZ=[cfg.layout.zLaser;cfg.layout.zSBE1;cfg.layout.zSBE1; ...
    cfg.layout.zSBE2;cfg.layout.zSBE2;cfg.layout.zCBSM1];
qInverse=1./qValues;
qDiameters=2*sqrt(-m2x*lambda./(pi*imag(qInverse)));
qRadii=1./real(qInverse);
moduleRadius=qDiameters(end)/2;
moduleCurvature=qRadii(end);
xLocal=x-cfg.laser.decenterX;
modulePhase=k*cfg.laser.tiltX*xLocal;
if isfinite(moduleCurvature)
    % Positive sign matches the exp(+ikz) convention of propagate().
    modulePhase=modulePhase+k*xLocal.^2/(2*moduleCurvature);
end
Ein=exp(-(xLocal/moduleRadius).^2).*exp(1i*modulePhase).*aperture;
Ein=Ein/sqrt(trapz(x,abs(Ein).^2));
inputIntensity=abs(Ein).^2;
inputWidthMeasured=thresholdWidth(x,inputIntensity/max(inputIntensity),exp(-2));
writetable(table(qStages,qZ,qDiameters,qRadii, ...
    'VariableNames',{'stage','z_mm','full1e2Diameter_mm', ...
    'wavefrontRadius_mm'}),fullfile(outputDir,'laser_x_m2_path.csv'));
sourceMeta.moduleInputDiameter=inputWidthMeasured;
sourceMeta.moduleInputWavefrontRadius=moduleCurvature;

% Smooth target amplitude and numerical energy-conserving coordinate map.
superGaussianOrder=8;
targetAmplitude=exp(-(abs(x)/(outputWidth/2)).^superGaussianOrder).*aperture;
targetAmplitude=targetAmplitude*sqrt(trapz(x,abs(Ein).^2)/ ...
    trapz(x,targetAmplitude.^2));
inputCdf=cumtrapz(x,abs(Ein).^2); inputCdf=inputCdf/inputCdf(end);
targetCdf=cumtrapz(x,targetAmplitude.^2); targetCdf=targetCdf/targetCdf(end);
[targetCdfUnique,uniqueIndex]=unique(targetCdf);
xMapped=interp1(targetCdfUnique,x(uniqueIndex),inputCdf,'linear','extrap');
xMapped=max(-outputWidth/2,min(outputWidth/2,xMapped));
delta=xMapped-x;
theta=atan2(delta,mapperDistance);
phiMap=cumtrapz(x,k*sin(theta));
phiMap=phiMap-phiMap(N/2+1);

% Two-plane coherent phase optimization.  The first phase starts from the
% energy-map estimate.  Alternating propagation enforces the measured input
% amplitude at DOE1 and the smooth flat-top amplitude at DOE2.  DOE2 then
% removes the actual residual phase; no ideal output field is substituted.
phaseTotal1=angleComplex(Ein)+phiMap;
phaseIterations=100;
for iteration=1:phaseIterations
    trial2=propagate(abs(Ein).*exp(1i*phaseTotal1),mapperDistance);
    constrained2=targetAmplitude.*exp(1i*angleComplex(trial2));
    trial1=propagate(constrained2,-mapperDistance);
    phaseTotal1=angleComplex(trial1);
end
phi1Continuous=angle(exp(1i*(phaseTotal1-angleComplex(Ein))));
[phi1,level1,height1,maskBits1]=fabricateDoePhase(phi1Continuous);
Ebefore2=propagate(Ein.*exp(1i*phi1),mapperDistance);
phi2Continuous=-angleComplex(Ebefore2);
[phi2,level2,height2,maskBits2]=fabricateDoePhase(phi2Continuous);
Eafter2=Ebefore2.*exp(1i*phi2);

% Actual downstream X train: free space to CXC1, +160 mm lens,
% 120 mm free space, -40 mm lens, then 150 mm to target.  YFL adds no X
% phase and is therefore intentionally absent from this X propagation.
E=propagate(Eafter2,cfg.layout.zCXC1-cfg.layout.zCBSM2);
E=thinLens(E,cfg.layout.fXC1);
E=propagate(E,cfg.layout.zCXC2-cfg.layout.zCXC1);
E=thinLens(E,cfg.layout.fXC2);
Etarget=propagate(E,cfg.layout.zTarget-cfg.layout.zCXC2);

Iexit=abs(Eafter2).^2; Iexit=Iexit/max(Iexit);
Itarget=abs(Etarget).^2; Itarget=Itarget/max(Itarget);
exitWave=wavefrontMetrics(Eafter2,Iexit,outputWidth);
targetWave=wavefrontMetrics(Etarget,Itarget,cfg.targetXWidth);
targetMeasuredWidth=thresholdWidth(x,Itarget,exp(-2));
widthError=abs(targetMeasuredWidth-cfg.targetXWidth)/cfg.targetXWidth;
targetEdgeSlope=(cfg.targetXWidth/2)/abs(targetWave.radius);
result.pass=widthError<=0.05 && ...
    abs(targetWave.meanAngle)<=cfg.vendor.maxTilt && ...
    targetWave.phaseRms<=cfg.vendor.maxPhaseRms && ...
    targetEdgeSlope<=cfg.vendor.maxCurvatureSlope;
result.model=['Independent two-element quantized fused-silica relief ' ...
    'phase surrogate'];
result.isVendorModel=false;
result.source=sourceMeta;
result.inputWidthAtModule=inputWidthMeasured;
result.phaseIterations=phaseIterations;
result.doe.material=cfg.doe.material;
result.doe.refractiveIndex=cfg.doe.refractiveIndex;
result.doe.quantizationLevels=cfg.doe.quantizationLevels;
result.doe.maskCount=cfg.doe.maskCount;
result.doe.minimumFeature=cfg.doe.minimumFeature;
result.doe.actualFeature=actualFeature;
result.doe.patternWidth=cfg.doe.patternWidth;
result.doe.designOutputXWidth=cfg.doe.designOutputXWidth;
result.doe.twoPiReliefDepth=cfg.doe.twoPiReliefDepth;
result.doe.heightStep=cfg.doe.heightStep;
result.doe.maximumReliefHeight=cfg.doe.maximumReliefHeight;
result.doe.maskEtchDepths=cfg.doe.maskEtchDepths;
result.doe.idealQuantizationEfficiency= ...
    cfg.doe.idealQuantizationEfficiency;
result.exitWave=exitWave;
result.targetWave=targetWave;
result.targetMeasuredWidth=targetMeasuredWidth;
result.widthError=widthError;
result.targetEdgeSlope=targetEdgeSlope;

parameter={'Model identity';'Vendor proprietary phase';'Coherence'; ...
    'Laser waist location';'Laser waist X diameter';'Laser X M2'; ...
    'Laser X full divergence';'Laser X Rayleigh range'; ...
    'Laser ellipticity';'Laser ellipse rotation'; ...
    'SBE output / module input width';'Wavelength'; ...
    'Element separation';'Module exit width';'Super-Gaussian order'; ...
    'Phase-optimization iterations';'DOE substrate index'; ...
    'DOE phase levels';'DOE binary masks';'DOE requested minimum feature'; ...
    'DOE actual cell pitch';'DOE patterned X width'; ...
    'DOE design output X width'; ...
    'DOE 2pi relief depth';'DOE relief height step'; ...
    'Ideal phase-quantization efficiency'; ...
    'Target measured width';'Target width error'; ...
    'Exit phase RMS';'Target phase RMS';'Phase RMS acceptance limit'; ...
    'Exit mean wavefront tilt';'Target mean wavefront tilt'; ...
    'Exit RMS local diffraction angle';'Target RMS local diffraction angle'; ...
    'Target fitted wavefront radius';'Target curvature edge slope'; ...
    'Surrogate pass'};
value={result.model;'No';cfg.laser.coherence;cfg.laser.waistZ; ...
    cfg.laser.waistDiameterX;cfg.laser.M2X; ...
    1e3*cfg.laser.divergenceFullAngleX;cfg.laser.rayleighRangeX; ...
    cfg.laser.ellipticity;cfg.laser.ellipseRotationDeg; ...
    inputWidthMeasured;355;mapperDistance; ...
    outputWidth;superGaussianOrder;phaseIterations; ...
    cfg.doe.refractiveIndex;cfg.doe.quantizationLevels; ...
    cfg.doe.maskCount;1e3*cfg.doe.minimumFeature;1e3*actualFeature; ...
    cfg.doe.patternWidth; ...
    cfg.doe.designOutputXWidth; ...
    1e3*cfg.doe.twoPiReliefDepth;1e3*cfg.doe.heightStep; ...
    100*cfg.doe.idealQuantizationEfficiency; ...
    targetMeasuredWidth;100*widthError; ...
    exitWave.phaseRms; ...
    targetWave.phaseRms;cfg.vendor.maxPhaseRms;1e6*exitWave.meanAngle; ...
    1e6*targetWave.meanAngle;1e6*exitWave.rmsAngle; ...
    1e6*targetWave.rmsAngle;targetWave.radius; ...
    1e6*targetEdgeSlope;double(result.pass)};
unit={'-';'-';'-';'mm';'mm';'-';'mrad full angle';'mm';'-';'deg'; ...
    'mm';'nm';'mm';'mm';'-';'-';'-';'-';'-';'um';'um';'mm';'mm';'um';'um';'%'; ...
    'mm';'%';'rad';'rad';'rad'; ...
    'urad';'urad';'urad';'urad';'mm';'urad';'0/1'};
writetable(table(parameter,value,unit), ...
    fullfile(outputDir,'phase_surrogate_summary.csv'));
writetable(table((1e3*x(:)),Iexit(:),Itarget(:), ...
    'VariableNames',{'x_um','moduleExitIntensity','targetIntensity'}), ...
    fullfile(outputDir,'phase_surrogate_profiles.csv'));
writetable(table(x(:),abs(Elaser(:)).^2,angleComplex(Elaser(:)), ...
    abs(Ein(:)).^2,phi1Continuous(:),phi1(:),height1(:), ...
    abs(Ebefore2(:)).^2,phi2Continuous(:),phi2(:),height2(:), ...
    'VariableNames',{'x_mm','laserWaistIntensity','laserWaistPhase_rad', ...
    'moduleInputIntensity','doe1ContinuousPhase_rad', ...
    'doe1FabricatedPhase_rad','doe1ReliefHeight_mm', ...
    'doe2InputIntensity','doe2ContinuousPhase_rad', ...
    'doe2FabricatedPhase_rad','doe2ReliefHeight_mm'}), ...
    fullfile(outputDir,'source_and_doe_phase_profiles.csv'));

activeDoe=aperture(:);
writetable(table(x(activeDoe).',phi1Continuous(activeDoe).', ...
    phi1(activeDoe).',level1(activeDoe).',1e3*height1(activeDoe).', ...
    1e3*(cfg.doe.maximumReliefHeight-height1(activeDoe)).', ...
    'VariableNames',{'x_mm','continuousPhase_rad','fabricatedPhase_rad', ...
    'levelIndex','remainingReliefHeight_um','etchDepthFromOriginal_um'}), ...
    fullfile(outputDir,'doe1_relief_profile.csv'));
writetable(table(x(activeDoe).',phi2Continuous(activeDoe).', ...
    phi2(activeDoe).',level2(activeDoe).',1e3*height2(activeDoe).', ...
    1e3*(cfg.doe.maximumReliefHeight-height2(activeDoe)).', ...
    'VariableNames',{'x_mm','continuousPhase_rad','fabricatedPhase_rad', ...
    'levelIndex','remainingReliefHeight_um','etchDepthFromOriginal_um'}), ...
    fullfile(outputDir,'doe2_relief_profile.csv'));
writeReliefCells(level1,'doe1_relief_cells.csv');
writeReliefCells(level2,'doe2_relief_cells.csv');

maskMatrix=x(activeDoe).';
maskNames={'x_mm'};
for maskIndex=1:cfg.doe.maskCount
    % A value of 1 means that the corresponding stripe is exposed/opened
    % and etched down by this mask depth.  The complement is required
    % because optical phase is represented by glass remaining above the
    % deepest etched reference plane.
    maskMatrix=[maskMatrix double(~maskBits1(activeDoe,maskIndex)) ...
        double(~maskBits2(activeDoe,maskIndex))]; %#ok<AGROW>
    maskNames=[maskNames ... %#ok<AGROW>
        {sprintf('doe1_etch_mask_%d',maskIndex), ...
        sprintf('doe2_etch_mask_%d',maskIndex)}];
end
maskTable=array2table(maskMatrix,'VariableNames',maskNames);
writetable(maskTable,fullfile(outputDir,'doe_binary_lithography_masks.csv'));

doeParameter={'Material';'Refractive index at 355 nm'; ...
    'Clear aperture';'Quantization levels';'Binary mask count'; ...
    'Requested minimum lateral feature';'Actual X cell pitch'; ...
    'Patterned X width'; ...
    '2pi relief depth';'Relief height step'; ...
    'Maximum remaining relief height';'Designed module-exit X width'; ...
    'Mask 1 etch depth';'Mask 2 etch depth';'Mask 3 etch depth'; ...
    'Mask 4 etch depth';'Mask 5 etch depth'; ...
    'Ideal quantization efficiency';'Final X width'; ...
    'Final phase RMS';'Phase RMS acceptance limit'; ...
    'Final curvature edge slope';'DOE design pass'};
doeValue={cfg.doe.material;cfg.doe.refractiveIndex; ...
    cfg.doe.clearAperture;cfg.doe.quantizationLevels;cfg.doe.maskCount; ...
    1e3*cfg.doe.minimumFeature;1e3*actualFeature;cfg.doe.patternWidth; ...
    1e3*cfg.doe.twoPiReliefDepth; ...
    1e3*cfg.doe.heightStep;1e3*cfg.doe.maximumReliefHeight; ...
    cfg.doe.designOutputXWidth; ...
    1e3*cfg.doe.maskEtchDepths(1);1e3*cfg.doe.maskEtchDepths(2); ...
    1e3*cfg.doe.maskEtchDepths(3); ...
    1e3*cfg.doe.maskEtchDepths(4);1e3*cfg.doe.maskEtchDepths(5); ...
    100*cfg.doe.idealQuantizationEfficiency;targetMeasuredWidth; ...
    targetWave.phaseRms;cfg.vendor.maxPhaseRms; ...
    1e6*targetEdgeSlope;double(result.pass)};
doeUnit={'-';'-';'mm';'-';'-';'um';'um';'mm';'um';'um';'um';'mm';'um'; ...
    'um';'um';'um';'um';'%';'mm';'rad';'rad';'urad';'0/1'};
writetable(table(doeParameter,doeValue,doeUnit), ...
    fullfile(outputDir,'doe_fabrication_summary.csv'));

fidDoe=fopen(fullfile(outputDir,'doe_fabrication_instructions.txt'),'w');
fprintf(fidDoe,'INDEPENDENT DOE RELIEF FABRICATION DEFINITION\n');
fprintf(fidDoe,'This is an independently designed surrogate, not HOLO/OR proprietary phase data.\n\n');
fprintf(fidDoe,'Substrate: fused silica, n(355 nm)=%.12f\n',cfg.doe.refractiveIndex);
fprintf(fidDoe,'Pattern: one-dimensional in X and invariant/extruded in Y.\n');
fprintf(fidDoe,'Clear aperture: %.6f mm. Requested minimum X feature: %.6f um.\n', ...
    cfg.doe.clearAperture,1e3*cfg.doe.minimumFeature);
fprintf(fidDoe,'Central patterned X width: %.6f mm; outer clear aperture remains unetched.\n', ...
    cfg.doe.patternWidth);
fprintf(fidDoe,'Actual simulated/fabrication X cell pitch: %.9f um (never below requested minimum).\n', ...
    1e3*actualFeature);
fprintf(fidDoe,'Levels: %d; masks: %d; maximum remaining relief: %.9f um.\n', ...
    cfg.doe.quantizationLevels,cfg.doe.maskCount, ...
    1e3*cfg.doe.maximumReliefHeight);
fprintf(fidDoe,'The relief CSV defines glass height remaining above the deepest reference plane.\n');
fprintf(fidDoe,'etchDepthFromOriginal = maximumReliefHeight - remainingReliefHeight.\n');
fprintf(fidDoe,'In the mask CSV, 1 = open/expose and etch; 0 = protect.\n');
for maskIndex=1:cfg.doe.maskCount
    fprintf(fidDoe,'Mask %d etch depth: %.9f um.\n',maskIndex, ...
        1e3*cfg.doe.maskEtchDepths(maskIndex));
end
fprintf(fidDoe,'DOE1 patterned surface faces downstream in the scalar model; DOE2 uses the same convention.\n');
fprintf(fidDoe,'A constant thickness offset adds only global phase and does not change intensity.\n');
fprintf(fidDoe,'Confirm resist/process bias, etch selectivity, AR coating, damage threshold and metrology with the fabricator.\n');
fclose(fidDoe);

figDoe=figure('Visible','off','Color','w','Position',[80 80 1450 850]);
phi1ContinuousPlot=mod(phi1Continuous,2*pi);
phi2ContinuousPlot=mod(phi2Continuous,2*pi);
phi1ContinuousPlot(~patternAperture)=NaN;
phi2ContinuousPlot(~patternAperture)=NaN;
subplot(2,2,1)
plot(x,phi1ContinuousPlot,'k-',x,mod(phi1,2*pi),'r-', ...
    'LineWidth',0.8);
xlim([-cfg.doe.clearAperture/2 cfg.doe.clearAperture/2]); grid on
ylabel('DOE1 wrapped phase (rad)'); ylim([0 2*pi]);
legend('Continuous design','Fabricated levels')
title('Independent 1-D multilevel relief DOE design')
subplot(2,2,3)
stairs(x,1e3*height1,'b-','LineWidth',0.8); grid on
xlim([-cfg.doe.clearAperture/2 cfg.doe.clearAperture/2]);
xlabel('X (mm)'); ylabel('DOE1 relief height (um)')
subplot(2,2,2)
plot(x,phi2ContinuousPlot,'k-',x,mod(phi2,2*pi),'r-', ...
    'LineWidth',0.8); grid on
xlim([-cfg.doe.clearAperture/2 cfg.doe.clearAperture/2]); ylim([0 2*pi]);
ylabel('DOE2 wrapped phase (rad)');
legend('Continuous design','Fabricated levels')
title('DOE2 phase correction')
subplot(2,2,4)
stairs(x,1e3*height2,'b-','LineWidth',0.8); grid on
xlim([-cfg.doe.clearAperture/2 cfg.doe.clearAperture/2]);
xlabel('X (mm)'); ylabel('DOE2 relief height (um)')
print(figDoe,fullfile(outputDir,'doe_relief_and_lithography_design.png'), ...
    '-dpng','-r200');
close(figDoe)

figMask=figure('Visible','off','Color','w','Position',[100 100 1450 650]);
subplot(2,1,1)
imagesc(x(activeDoe),1:cfg.doe.maskCount, ...
    double((~maskBits1(activeDoe,:)).')); axis xy
ylabel('DOE1 mask number'); title('Binary etch masks: 1=open/etch, 0=protect')
subplot(2,1,2)
imagesc(x(activeDoe),1:cfg.doe.maskCount, ...
    double((~maskBits2(activeDoe,:)).')); axis xy
xlabel('X (mm), pattern invariant in Y'); ylabel('DOE2 mask number')
colormap(gray)
print(figMask,fullfile(outputDir,'doe_binary_lithography_mask_preview.png'), ...
    '-dpng','-r200');
close(figMask)

% Final-plane two-dimensional irradiance.  The current optical model is
% separable: X is the coherent DOE+CXC result above, while Y is the M2
% Gaussian waist verified independently at the same z=target plane.
xTargetMm=linspace(-1.5*cfg.targetXWidth/2,1.5*cfg.targetXWidth/2,1201);
yTargetUm=linspace(-4*cfg.targetYWidth/2,4*cfg.targetYWidth/2,801)*1e3;
ixTarget=interp1(x,Itarget,xTargetMm,'linear',0);
yTargetMm=yTargetUm/1e3;
wYTarget=cfg.targetYWidth/2;
iyTarget=exp(-2*(yTargetMm/wYTarget).^2);
intensityNormalized2D=iyTarget(:)*ixTarget(:).';
intensityNormalized2D=intensityNormalized2D/max(intensityNormalized2D(:));

fig2d=figure('Visible','off','Color','w','Position',[60 60 1450 780]);
imagesc(xTargetMm,yTargetUm,intensityNormalized2D); axis xy
colormap(parula); colorbar; caxis([0 1]);
xlabel('X (mm)'); ylabel('Y (um)');
title(sprintf(['Final-plane normalized irradiance at Z=%.1f mm ' ...
    '(separable X coherent / Y M2 model)'],cfg.layout.zTarget));
hold on
contour(xTargetMm,yTargetUm,intensityNormalized2D,[exp(-2) exp(-2)], ...
    'w--','LineWidth',1.2);
text(-0.70*cfg.targetXWidth,1.55*wYTarget*1e3, ...
    sprintf('Full 1/e^2 size: X=%.3f mm, Y=%.3f um', ...
    targetMeasuredWidth,1e3*cfg.targetYWidth), ...
    'Color','w','FontWeight','bold','BackgroundColor',[0 0 0]);
print(fig2d,fullfile(outputDir,'target_plane_2d_intensity.png'), ...
    '-dpng','-r220');
close(fig2d)

writetable(table(xTargetMm(:),ixTarget(:), ...
    'VariableNames',{'x_mm','normalizedIntensity'}), ...
    fullfile(outputDir,'target_plane_x_lineout.csv'));
writetable(table(yTargetUm(:),iyTarget(:), ...
    'VariableNames',{'y_um','normalizedIntensity'}), ...
    fullfile(outputDir,'target_plane_y_lineout.csv'));
save(fullfile(outputDir,'target_plane_2d_intensity.mat'), ...
    'xTargetMm','yTargetUm','intensityNormalized2D','-v7.3');
result.targetPlane2D.model= ...
    'Separable X coherent diffraction times Y M2 Gaussian irradiance';
result.targetPlane2D.imageFile=fullfile(outputDir, ...
    'target_plane_2d_intensity.png');
result.targetPlane2D.dataFile=fullfile(outputDir, ...
    'target_plane_2d_intensity.mat');

fig=figure('Visible','off','Color','w','Position',[80 80 1100 700]);
subplot(2,1,1)
plot(x,Iexit,'b-',x,Itarget,'r--','LineWidth',1.1); grid on
xlim([-4 4]); ylim([0 1.05]); ylabel('Normalized irradiance')
legend('Surrogate module exit','After CXC telescope / target')
title('Coherent measured-M2 source and fabricated two-relief DOE surrogate')
subplot(2,1,2)
plot(x,1e6*localAngle(Eafter2),'b-',x,1e6*localAngle(Etarget),'r--'); grid on
xlim([-1 1]); xlabel('X (mm)'); ylabel('Local X angle (urad)')
legend('Surrogate module exit','Target','Location','best')
print(fig,fullfile(outputDir,'phase_surrogate_intensity_angle.png'), ...
    '-dpng','-r180');
close(fig)
save(fullfile(outputDir,'phase_surrogate_result.mat'),'result','-v7.3');

    function Eout=propagate(Ein,z)
        fx=((0:N-1)-N/2)/window;
        root=sqrt(complex(1-(lambda*fx).^2,0));
        H=exp(1i*k*z*root);
        Eout=fftshift(ifft(ifftshift(fftshift(fft(ifftshift(Ein))).*H)));
    end

    function Eout=thinLens(Ein,f)
        Eout=Ein.*exp(-1i*k*x.^2/(2*f));
    end

    function p=angleComplex(Ein)
        p=atan2(imag(Ein),real(Ein));
    end

    function ang=localAngle(Ein)
        ph=unwrap(angleComplex(Ein));
        ang=(lambda/(2*pi))*gradient(ph,dx);
    end

    function metrics=wavefrontMetrics(Ein,Iin,width)
        use=abs(x)<=0.40*width & Iin>=0.35;
        ph=unwrap(angleComplex(Ein));
        coeff=polyfit(x(use),ph(use),2);
        linear=polyfit(x(use),ph(use),1);
        residual=ph(use)-polyval(linear,x(use));
        ang=localAngle(Ein);
        metrics.meanAngle=(lambda/(2*pi))*linear(1);
        metrics.rmsAngle=sqrt(mean((ang(use)-metrics.meanAngle).^2));
        metrics.phaseRms=sqrt(mean(residual.^2));
        if abs(coeff(1))<eps
            metrics.radius=Inf;
        else
            metrics.radius=pi/(lambda*coeff(1));
        end
    end

    function width=thresholdWidth(xAxis,intensity,level)
        use=find(intensity>=level);
        width=xAxis(use(end))-xAxis(use(1));
    end

    function [phaseFabricated,levelIndex,height,maskBits]= ...
            fabricateDoePhase(phaseContinuous)
        phaseWrapped=mod(phaseContinuous,2*pi);
        phaseHeld=zeros(size(phaseWrapped));
        for blockStart=1:samplesPerFeature:N
            blockEnd=min(N,blockStart+samplesPerFeature-1);
            indices=blockStart:blockEnd;
            circularMean=angle(mean(exp(1i*phaseWrapped(indices))));
            phaseHeld(indices)=mod(circularMean,2*pi);
        end
        phaseStep=2*pi/cfg.doe.quantizationLevels;
        levelIndex=mod(round(phaseHeld/phaseStep), ...
            cfg.doe.quantizationLevels);
        % Outside the useful patterned width select the highest level,
        % which is optically almost 2*pi and mechanically remains unetched.
        levelIndex(~patternAperture)=cfg.doe.quantizationLevels-1;
        phaseFabricated=levelIndex*phaseStep;
        height=levelIndex*cfg.doe.heightStep;
        maskBits=false(N,cfg.doe.maskCount);
        integerLevel=uint16(levelIndex(:));
        for bitIndex=1:cfg.doe.maskCount
            maskBits(:,bitIndex)=logical(bitget(integerLevel,bitIndex));
        end
    end

    function writeReliefCells(levelIndex,fileName)
        activeIndex=find(activeDoe);
        activeLevel=levelIndex(activeDoe);
        activeLevel=activeLevel(:).';
        change=[true diff(activeLevel)~=0];
        cellStart=find(change);
        cellEnd=[cellStart(2:end)-1 numel(activeIndex)];
        numberOfCells=numel(cellStart);
        xStart=zeros(numberOfCells,1); xEnd=xStart; cellLevel=xStart;
        for cellIndex=1:numberOfCells
            firstIndex=activeIndex(cellStart(cellIndex));
            lastIndex=activeIndex(cellEnd(cellIndex));
            xStart(cellIndex)=x(firstIndex)-dx/2;
            xEnd(cellIndex)=x(lastIndex)+dx/2;
            cellLevel(cellIndex)=levelIndex(firstIndex);
        end
        remainingHeight=cellLevel*cfg.doe.heightStep;
        etchDepth=cfg.doe.maximumReliefHeight-remainingHeight;
        writetable(table(xStart,xEnd,xEnd-xStart,cellLevel, ...
            1e3*remainingHeight,1e3*etchDepth, ...
            'VariableNames',{'xStart_mm','xEnd_mm','width_mm', ...
            'levelIndex','remainingReliefHeight_um', ...
            'etchDepthFromOriginal_um'}),fullfile(outputDir,fileName));
    end

end
