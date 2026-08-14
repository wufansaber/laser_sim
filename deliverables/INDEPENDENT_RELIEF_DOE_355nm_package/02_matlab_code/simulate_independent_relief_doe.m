function result = simulate_independent_relief_doe(cfg, outputDir)
%SIMULATE_INDEPENDENT_RELIEF_DOE Independent two-element relief DOE.
% This package does not use any vendor proprietary model. A measured-M2,
% fully coherent
% waist field is propagated through the first spherical beam expander.
% DOE1 and DOE2 are separated only by free space.  Together they map the
% modestly expanded Gaussian directly into the final 1.5 mm flat-top and
% flatten the target-plane X wavefront.  Every downstream powered surface
% is Y-only and therefore has zero X optical power.
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
outputWidth=cfg.doe.targetDesignXWidth;
mapperDistance=cfg.layout.zDOE2-cfg.layout.zDOE1;
targetDistance=cfg.layout.zTarget-cfg.layout.zDOE2;
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
qModule=qSBE2After+(cfg.layout.zDOE1-cfg.layout.zSBE2);
qValues=[q0;qSBE1Before;qSBE1After;qSBE2Before;qSBE2After;qModule];
qStages={'LASER waist';'SBE1 before';'SBE1 after';'SBE2 before'; ...
    'SBE2 after';'DOE1 input'};
qZ=[cfg.layout.zLaser;cfg.layout.zSBE1;cfg.layout.zSBE1; ...
    cfg.layout.zSBE2;cfg.layout.zSBE2;cfg.layout.zDOE1];
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

% The target is specified at the final plane, not at DOE2.  Back-propagating
% the desired flat-phase field supplies the amplitude and phase that DOE2
% must receive.  A high-order super-Gaussian leaves the fixed central 90%%
% region flat while retaining a finite, manufacturable edge transition.
superGaussianOrder=cfg.doe.targetSuperGaussianOrder;
targetAmplitudeFinal=exp(-(abs(x)/(outputWidth/2)).^superGaussianOrder).*aperture;
targetAmplitudeFinal=targetAmplitudeFinal*sqrt(trapz(x,abs(Ein).^2)/ ...
    trapz(x,targetAmplitudeFinal.^2));
EtargetDesired=targetAmplitudeFinal;
E2Desired=propagate(EtargetDesired,-targetDistance);
targetAmplitude=abs(E2Desired);
targetAmplitude=targetAmplitude*sqrt(trapz(x,abs(Ein).^2)/ ...
    trapz(x,targetAmplitude.^2));
inputCdf=cumtrapz(x,abs(Ein).^2); inputCdf=inputCdf/inputCdf(end);
targetCdf=cumtrapz(x,targetAmplitude.^2); targetCdf=targetCdf/targetCdf(end);
[targetCdfUnique,uniqueIndex]=unique(targetCdf);
xMapped=interp1(targetCdfUnique,x(uniqueIndex),inputCdf,'linear','extrap');
delta=xMapped-x;
theta=atan2(delta,mapperDistance);
phiMap=cumtrapz(x,k*sin(theta));
phiMap=phiMap-phiMap(N/2+1);

% Two-plane coherent phase optimization.  Alternating propagation makes
% DOE1 deliver the back-propagated target amplitude to DOE2.  DOE2 then
% supplies the phase difference between the actual field and the exact
% back-propagated target field.  No lens is present between the two DOEs.
phaseTotal1=angleComplex(Ein)+phiMap;
phaseIterations=cfg.doe.phaseIterations;
for iteration=1:phaseIterations
    trial2=propagate(abs(Ein).*exp(1i*phaseTotal1),mapperDistance);
    constrained2=targetAmplitude.*exp(1i*angleComplex(trial2));
    trial1=propagate(constrained2,-mapperDistance);
    phaseTotal1=angleComplex(trial1);
end
phi1Continuous=angle(exp(1i*(phaseTotal1-angleComplex(Ein))));
[EtargetContinuous,continuousWidth,continuousUniformity]= ...
    evaluateContinuousDesign(phi1Continuous);
% Refine DOE1 while enforcing the actual lateral cell hold and 32 phase
% levels on every iteration.  This prevents the final one-time sampling
% operation from destroying the continuous-design flat-top.
phi1=constrainDoePhaseOnly(phi1Continuous);
for iteration=1:cfg.doe.quantizedRefinementIterations
    trial2=propagate(abs(Ein).*exp(1i*(angleComplex(Ein)+phi1)), ...
        mapperDistance);
    constrained2=targetAmplitude.*exp(1i*angleComplex(trial2));
    trial1=propagate(constrained2,-mapperDistance);
    phi1=constrainDoePhaseOnly(angle(exp(1i*(angleComplex(trial1)- ...
        angleComplex(Ein)))));
end
Ebefore2=propagate(Ein.*exp(1i*phi1),mapperDistance);
phi2Continuous=angle(exp(1i*(angleComplex(E2Desired)-angleComplex(Ebefore2))));
phi2=constrainDoePhaseOnly(phi2Continuous);

% Joint manufactured-plane refinement.  The target amplitude is enforced
% after the complete DOE1 -> free space -> DOE2 -> free space propagation.
% At the same time the fitted target tilt and curvature are removed from
% the phase constraint, so the algorithm cannot trade collimation for a
% superficially flatter intensity profile.
fitUse=abs(x)<=cfg.acceptance.uniformityFraction*cfg.targetXWidth/2;
targetWeight=ones(size(x));
% The alternating projection is not monotonic after phase quantization.
% Retain the best actually manufacturable phase pair encountered instead
% of assuming that the last iteration is the best one.
bestUniformity=-inf;
bestJointIteration=0;
bestPhi1=phi1;
bestPhi2=phi2;
for iteration=1:cfg.doe.jointQuantizedIterations
    Ebefore2=propagate(Ein.*exp(1i*phi1),mapperDistance);
    targetTrial=propagate(Ebefore2.*exp(1i*phi2),targetDistance);
    trialIntensity=abs(targetTrial).^2;
    trialIntensity=trialIntensity/max(trialIntensity);
    trialWidth=thresholdWidth(x,trialIntensity,exp(-2));
    trialWidthError=abs(trialWidth-cfg.targetXWidth)/cfg.targetXWidth;
    trialUniformity=min(trialIntensity(fitUse))/ ...
        max(trialIntensity(fitUse));
    if trialWidthError<=cfg.acceptance.maxXWidthError && ...
            trialUniformity>bestUniformity
        trialWave=wavefrontMetrics(targetTrial,trialIntensity, ...
            cfg.targetXWidth);
        trialEdgeSlope=(cfg.targetXWidth/2)/abs(trialWave.radius);
        if abs(trialWave.meanAngle)<=cfg.acceptance.maxTilt && ...
                trialEdgeSlope<=cfg.acceptance.maxCurvatureSlope
            bestUniformity=trialUniformity;
            bestJointIteration=iteration;
            bestPhi1=phi1;
            bestPhi2=phi2;
        end
    end
    if mod(iteration,12)==0
        actualAmplitude=abs(targetTrial);
        actualAmplitude=actualAmplitude/max(actualAmplitude(fitUse));
        nominalAmplitude=targetAmplitudeFinal/ ...
            max(targetAmplitudeFinal(fitUse));
        correction=nominalAmplitude(fitUse)./ ...
            max(actualAmplitude(fitUse),0.50);
        correction=max(0.85,min(1.18,correction));
        targetWeight(fitUse)=targetWeight(fitUse).*correction.^0.45;
        targetWeight=max(0.55,min(1.80,targetWeight));
        targetWeight=conv(targetWeight,ones(1,25)/25,'same');
    end
    targetPhase=unwrap(angleComplex(targetTrial));
    targetFit=polyfit(x(fitUse),targetPhase(fitUse),2);
    targetPhase=targetPhase-targetFit(1)*x.^2-targetFit(2)*x;
    workingTargetAmplitude=targetAmplitudeFinal.*targetWeight;
    workingTargetAmplitude=workingTargetAmplitude* ...
        sqrt(trapz(x,abs(Ein).^2)/trapz(x,workingTargetAmplitude.^2));
    constrainedTarget=workingTargetAmplitude.*exp(1i*targetPhase);
    desiredAfter2=propagate(constrainedTarget,-targetDistance);
    phi2Continuous=angle(exp(1i*(angleComplex(desiredAfter2)- ...
        angleComplex(Ebefore2))));
    phi2=constrainDoePhaseOnly(phi2Continuous);

    desiredAmplitude2=abs(desiredAfter2);
    desiredAmplitude2=desiredAmplitude2*sqrt(trapz(x,abs(Ein).^2)/ ...
        trapz(x,desiredAmplitude2.^2));
    constrainedBefore2=desiredAmplitude2.*exp(1i*angleComplex(Ebefore2));
    desiredAt1=propagate(constrainedBefore2,-mapperDistance);
    phi1=constrainDoePhaseOnly(angle(exp(1i*(angleComplex(desiredAt1)- ...
        angleComplex(Ein)))));
end
if bestJointIteration>0
    phi1=bestPhi1;
    phi2=bestPhi2;
end
[phi1,level1,height1,maskBits1]=fabricateDoePhase(phi1);
[phi2,level2,height2,maskBits2]=fabricateDoePhase(phi2);
Ebefore2=propagate(Ein.*exp(1i*phi1),mapperDistance);
Eafter2=Ebefore2.*exp(1i*phi2);

% DOE2-to-target propagation contains only free space in X.  The Y-only
% expander and final Y focusing cylinder are identity operators in X.
Etarget=propagate(Eafter2,targetDistance);

Iexit=abs(Eafter2).^2; Iexit=Iexit/max(Iexit);
Itarget=abs(Etarget).^2; Itarget=Itarget/max(Itarget);
exitWave=wavefrontMetrics(Eafter2,Iexit,outputWidth);
targetWave=wavefrontMetrics(Etarget,Itarget,cfg.targetXWidth);
targetMeasuredWidth=thresholdWidth(x,Itarget,exp(-2));
targetWidth50=thresholdWidth(x,Itarget,0.5);
widthError=abs(targetMeasuredWidth-cfg.targetXWidth)/cfg.targetXWidth;
targetEdgeSlope=(cfg.targetXWidth/2)/abs(targetWave.radius);
uniformityUse=abs(x)<=cfg.acceptance.uniformityFraction*cfg.targetXWidth/2;
targetUniformity=min(Itarget(uniformityUse))/max(Itarget(uniformityUse));
EtargetCheck=propagate(Etarget,cfg.acceptance.propagationCheckDistance);
ItargetCheck=abs(EtargetCheck).^2; ItargetCheck=ItargetCheck/max(ItargetCheck);
targetCheckWidth=thresholdWidth(x,ItargetCheck,exp(-2));
targetWidthChange=abs(targetCheckWidth-targetMeasuredWidth)/targetMeasuredWidth;
result.pass=widthError<=0.05 && ...
    targetUniformity>=cfg.acceptance.minUniformity && ...
    abs(targetWave.meanAngle)<=cfg.acceptance.maxTilt && ...
    targetEdgeSlope<=cfg.acceptance.maxCurvatureSlope;
result.model=['Independent two-element quantized fused-silica relief ' ...
    'phase surrogate'];
result.isVendorModel=false;
result.source=sourceMeta;
result.inputWidthAtModule=inputWidthMeasured;
result.phaseIterations=phaseIterations;
result.bestJointIteration=bestJointIteration;
result.continuousTargetWidth=continuousWidth;
result.continuousTargetUniformity=continuousUniformity;
result.doe.material=cfg.doe.material;
result.doe.refractiveIndex=cfg.doe.refractiveIndex;
result.doe.quantizationLevels=cfg.doe.quantizationLevels;
result.doe.maskCount=cfg.doe.maskCount;
result.doe.minimumFeature=cfg.doe.minimumFeature;
result.doe.actualFeature=actualFeature;
result.doe.patternWidth=cfg.doe.patternWidth;
result.doe.designOutputXWidth=cfg.doe.targetDesignXWidth;
result.doe.twoPiReliefDepth=cfg.doe.twoPiReliefDepth;
result.doe.heightStep=cfg.doe.heightStep;
result.doe.maximumReliefHeight=cfg.doe.maximumReliefHeight;
result.doe.maskEtchDepths=cfg.doe.maskEtchDepths;
result.doe.idealQuantizationEfficiency= ...
    cfg.doe.idealQuantizationEfficiency;
result.exitWave=exitWave;
result.targetWave=targetWave;
result.targetMeasuredWidth=targetMeasuredWidth;
result.targetWidth50=targetWidth50;
result.widthError=widthError;
result.targetUniformity=targetUniformity;
result.targetEdgeSlope=targetEdgeSlope;
result.targetCheckWidth=targetCheckWidth;
result.targetWidthChange=targetWidthChange;

parameter={'Model identity';'Vendor proprietary phase';'Coherence'; ...
    'Laser waist location';'Laser waist X diameter';'Laser X M2'; ...
    'Laser X full divergence';'Laser X Rayleigh range'; ...
    'Laser ellipticity';'Laser ellipse rotation'; ...
    'First spherical expander magnification'; ...
    'SBE output / DOE1 input width';'Wavelength'; ...
    'DOE1 to DOE2 free-space separation';'DOE2 to target distance'; ...
    'Target design X width';'Super-Gaussian order'; ...
    'Phase-optimization iterations';'DOE substrate index'; ...
    'DOE phase levels';'DOE binary masks';'DOE requested minimum feature'; ...
    'DOE actual cell pitch';'DOE patterned X width'; ...
    'DOE 2pi relief depth';'DOE relief height step'; ...
    'Ideal phase-quantization efficiency'; ...
    'Target measured 1/e2 width';'Target measured FWHM'; ...
    'Target width error';'Central 90 percent min/max uniformity'; ...
    'Minimum accepted uniformity';'Target mean wavefront tilt'; ...
    'Target fitted wavefront radius';'Target curvature edge slope'; ...
    'Forward propagation check distance';'Forward-check 1/e2 width'; ...
    'Forward-check width change';'Maximum accepted width change'; ...
    'Target phase RMS diagnostic only'; ...
    'Surrogate pass'};
value={result.model;'No';cfg.laser.coherence;cfg.laser.waistZ; ...
    cfg.laser.waistDiameterX;cfg.laser.M2X; ...
    1e3*cfg.laser.divergenceFullAngleX;cfg.laser.rayleighRangeX; ...
    cfg.laser.ellipticity;cfg.laser.ellipseRotationDeg; ...
    cfg.beamExpanderMagnification;inputWidthMeasured;355;mapperDistance; ...
    targetDistance; ...
    outputWidth;superGaussianOrder;phaseIterations; ...
    cfg.doe.refractiveIndex;cfg.doe.quantizationLevels; ...
    cfg.doe.maskCount;1e3*cfg.doe.minimumFeature;1e3*actualFeature; ...
    cfg.doe.patternWidth; ...
    1e3*cfg.doe.twoPiReliefDepth;1e3*cfg.doe.heightStep; ...
    100*cfg.doe.idealQuantizationEfficiency; ...
    targetMeasuredWidth;targetWidth50;100*widthError; ...
    100*targetUniformity;100*cfg.acceptance.minUniformity; ...
    1e6*targetWave.meanAngle;targetWave.radius;1e6*targetEdgeSlope; ...
    cfg.acceptance.propagationCheckDistance;targetCheckWidth; ...
    100*targetWidthChange;100*cfg.acceptance.maxWidthChange; ...
    targetWave.phaseRms;double(result.pass)};
unit={'-';'-';'-';'mm';'mm';'-';'mrad full angle';'mm';'-';'deg'; ...
    'x';'mm';'nm';'mm';'mm';'mm';'-';'-';'-';'-';'-';'um';'um';'mm'; ...
    'um';'um';'%';'mm';'mm';'%';'%';'%';'urad';'mm';'urad'; ...
    'mm';'mm';'%';'%';'rad';'0/1'};
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
    'Maximum remaining relief height';'Designed target X width'; ...
    'Mask 1 etch depth';'Mask 2 etch depth';'Mask 3 etch depth'; ...
    'Mask 4 etch depth';'Mask 5 etch depth'; ...
    'Ideal quantization efficiency';'Final X 1/e2 width'; ...
    'Final X FWHM';'Central 90 percent uniformity'; ...
    'Uniformity acceptance limit';'Final mean X tilt'; ...
    'Final curvature edge slope';'100 mm width change';'DOE design pass'};
doeValue={cfg.doe.material;cfg.doe.refractiveIndex; ...
    cfg.doe.clearAperture;cfg.doe.quantizationLevels;cfg.doe.maskCount; ...
    1e3*cfg.doe.minimumFeature;1e3*actualFeature;cfg.doe.patternWidth; ...
    1e3*cfg.doe.twoPiReliefDepth; ...
    1e3*cfg.doe.heightStep;1e3*cfg.doe.maximumReliefHeight; ...
    cfg.doe.targetDesignXWidth; ...
    1e3*cfg.doe.maskEtchDepths(1);1e3*cfg.doe.maskEtchDepths(2); ...
    1e3*cfg.doe.maskEtchDepths(3); ...
    1e3*cfg.doe.maskEtchDepths(4);1e3*cfg.doe.maskEtchDepths(5); ...
    100*cfg.doe.idealQuantizationEfficiency;targetMeasuredWidth; ...
    targetWidth50;100*targetUniformity;100*cfg.acceptance.minUniformity; ...
    1e6*targetWave.meanAngle;1e6*targetEdgeSlope; ...
    100*targetWidthChange;double(result.pass)};
doeUnit={'-';'-';'mm';'-';'-';'um';'um';'mm';'um';'um';'um';'mm';'um'; ...
    'um';'um';'um';'um';'%';'mm';'mm';'%';'%';'urad';'urad';'%';'0/1'};
writetable(table(doeParameter,doeValue,doeUnit), ...
    fullfile(outputDir,'doe_fabrication_summary.csv'));

fidDoe=fopen(fullfile(outputDir,'doe_fabrication_instructions.txt'),'w');
fprintf(fidDoe,'INDEPENDENT DOE RELIEF FABRICATION DEFINITION\n');
fprintf(fidDoe,'This is an independent engineering design; no proprietary phase data are used.\n\n');
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
% separable: X is the coherent two-DOE result above, while Y is the M2
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
    sprintf(['Full 1/e^2: X=%.3f mm, Y=%.3f um; ' ...
    'central-90%% U=%.2f%%'],targetMeasuredWidth, ...
    1e3*cfg.targetYWidth,100*targetUniformity), ...
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
legend('DOE2 exit','Free-space target')
title('Coherent measured-M2 source and fabricated two-relief DOE surrogate')
subplot(2,1,2)
plot(x,1e6*localAngle(Eafter2),'b-',x,1e6*localAngle(Etarget),'r--'); grid on
xlim([-1 1]); xlabel('X (mm)'); ylabel('Local X angle (urad)')
legend('DOE2 exit','Target','Location','best')
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

    function [targetField,targetWidth,targetUniformity]= ...
            evaluateContinuousDesign(firstPhase)
        beforeSecond=propagate(Ein.*exp(1i*firstPhase),mapperDistance);
        secondPhase=angle(exp(1i*(angleComplex(E2Desired)- ...
            angleComplex(beforeSecond))));
        targetField=propagate(beforeSecond.*exp(1i*secondPhase), ...
            targetDistance);
        targetIntensity=abs(targetField).^2;
        targetIntensity=targetIntensity/max(targetIntensity);
        targetWidth=thresholdWidth(x,targetIntensity,exp(-2));
        use=abs(x)<=cfg.acceptance.uniformityFraction*cfg.targetXWidth/2;
        targetUniformity=min(targetIntensity(use))/max(targetIntensity(use));
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
        [~,center]=min(abs(xAxis));
        left=find(intensity(1:center)<level,1,'last');
        rightRelative=find(intensity(center:end)<level,1,'first');
        if isempty(left) || isempty(rightRelative)
            width=NaN;
            return
        end
        right=center+rightRelative-1;
        xl=crossing(xAxis(left),xAxis(left+1), ...
            intensity(left),intensity(left+1),level);
        xr=crossing(xAxis(right-1),xAxis(right), ...
            intensity(right-1),intensity(right),level);
        width=xr-xl;
    end

    function value=crossing(x1,x2,y1,y2,target)
        value=x1+(target-y1)*(x2-x1)/(y2-y1);
    end

    function [phaseFabricated,levelIndex,height,maskBits]= ...
            fabricateDoePhase(phaseContinuous)
        phaseFabricated=constrainDoePhaseOnly(phaseContinuous);
        phaseStep=2*pi/cfg.doe.quantizationLevels;
        levelIndex=mod(round(phaseFabricated/phaseStep), ...
            cfg.doe.quantizationLevels);
        height=levelIndex*cfg.doe.heightStep;
        maskBits=false(N,cfg.doe.maskCount);
        integerLevel=uint16(levelIndex(:));
        for bitIndex=1:cfg.doe.maskCount
            maskBits(:,bitIndex)=logical(bitget(integerLevel,bitIndex));
        end
    end

    function phaseFabricated=constrainDoePhaseOnly(phaseContinuous)
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
