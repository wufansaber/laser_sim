function result=simulate_final_hybrid_doe_lens(outputDir)
%SIMULATE_FINAL_HYBRID_DOE_LENS Frozen MATLAB R2019b wave-optics model.
% MATLAB R2019b feasibility optimizer for a separated final assembly:
%   DOE: two X-only relief phase surfaces on one plane-parallel plate;
%   final lens: an independent HPFS 7980 Y cylindrical lens;
%   target: one Y focal length after the independent cylinder (>50 mm).
% The DOE phase is invariant in Y.  No amplitude mask or spatial filter is
% used.  All dimensions are mm.

codeDir=fileparts(mfilename('fullpath'));
packageDir=fileparts(codeDir);
if nargin<1 || isempty(outputDir)
    outputDir=fullfile(packageDir,'04_simulation_results','matlab_R2019b');
end
if ~exist(outputDir,'dir'); mkdir(outputDir); end
cfg=final_hybrid_doe_lens_config();
name=sprintf('final_hybrid_DOE_lens_%dlevel',cfg.doe.quantizationLevels);
designWidth=cfg.doe.targetDesignXWidth;
sgOrder=cfg.doe.targetSuperGaussianOrder;
gridN=65536;
focalLengthY=cfg.finalYFocalLength;
xRelayMagnification=cfg.layout.xRelayMagnification;
phaseLevels=cfg.doe.quantizationLevels;

lambda=cfg.lambda; k=2*pi/lambda;
N=gridN; window=65.536; dx=window/N;
x=((0:N-1)-N/2)*dx;
fx=((0:N-1)-N/2)/window;
workingDistance=focalLengthY;
hybridClearAperture=cfg.doe.clearAperture;
hybridRadius=hybridClearAperture/2;
levels=phaseLevels;
samplesPerCell=ceil(cfg.doe.minimumFeature/dx);
cellPitch=samplesPerCell*dx;
patternWidth=cfg.doe.patternWidth;
patternUse=x>=-patternWidth/2 & x<patternWidth/2;
apertureX=abs(x)<=hybridRadius;
plateThickness=cfg.doe.substrateThickness;
effectiveGlassSeparation=plateThickness/cfg.doe.refractiveIndex;
doeToFinalYLensAirGap=cfg.mechanical.doeToFinalYLensAirGap;
finalYLensThickness=cfg.mechanical.finalYLensCenterThickness;
nFinalYLens=cfg.glass.hpfs7980RefractiveIndex355;
% In X the independent Y cylinder is a plane-parallel HPFS plate.  Its
% exact paraxial effect is therefore a reduced propagation t/n, not power.
xPropagationAfterDoe=doeToFinalYLensAirGap+ ...
    finalYLensThickness/nFinalYLens+workingDistance;

% Recalculate the Y-only telescope for this focal length and 1 um target.
requiredYDiameter=4*cfg.laser.M2Y*lambda*focalLengthY/ ...
    (pi*cfg.targetYWidth);
conditionedYDiameter=cfg.beamExpanderMagnification* ...
    cfg.laser.waistDiameterY;
fYBE1=-20;
yMagnification=requiredYDiameter/conditionedYDiameter;
fYBE2=abs(fYBE1)*yMagnification;
zYBE1=cfg.layout.zYBE1;
zYBE2=zYBE1+fYBE1+fYBE2;
zHybrid=cfg.layout.zHybrid;

% X-only afocal Galilean relay.  It deliberately reduces the conditioned
% 5 mm X beam before the final DOE, so the required DOE phase gradient stays
% compatible with the 5 um manufacturing feature.  Y is unaffected.
fXRelay1=cfg.layout.fXRelay1;
fXRelay2=-fXRelay1*xRelayMagnification;
zXRelay1=cfg.layout.zXRelay1;
zXRelay2=zXRelay1+fXRelay1+fXRelay2;

% Coherent measured-M2 X field at the plane-parallel double-sided DOE.
qX=1i*pi*cfg.laser.waistRadiusX^2/(cfg.laser.M2X*lambda);
qX=qX+(cfg.layout.zSBE1-cfg.layout.zLaser);
qX=1/(1/qX-1/cfg.layout.fSBE1);
qX=qX+(cfg.layout.zSBE2-cfg.layout.zSBE1);
qX=1/(1/qX-1/cfg.layout.fSBE2);
qX=qX+(zXRelay1-cfg.layout.zSBE2);
qX=1/(1/qX-1/fXRelay1);
qX=qX+(zXRelay2-zXRelay1);
qX=1/(1/qX-1/fXRelay2);
qX=qX+(zHybrid-zXRelay2);
invQX=1/qX;
xRadius=sqrt(-cfg.laser.M2X*lambda/(pi*imag(invQX)));
xCurvature=1/real(invQX);
xInputPhase=zeros(size(x));
if isfinite(xCurvature)
    xInputPhase=k*x.^2/(2*xCurvature);
end
EinUnnormalized=exp(-(x/xRadius).^2).*exp(1i*xInputPhase);
% When the full-source OpticStudio POP has been run, use its pre-DOE
% complex field as the authoritative X input.  This retains the measured
% source model, all upstream lenses, diffraction and wavefront curvature;
% the q-model above remains only a bootstrap fallback.
sourceZbf=fullfile(packageDir,'06_zemax_sequential', ...
    'FULL_SOURCE_AT_DOE_A_RESAMPLED.ZBF');
if cfg.model.flatGaussianAtDoe
    xRadius=cfg.doeInput.fullDiameterX/2;
    xInputPhase=zeros(size(x));
    EinUnnormalized=exp(-(x/xRadius).^2);
elseif exist(sourceZbf,'file')
    [sourceField,sourceHeader]=readZbf(sourceZbf);
    sourceX=((0:sourceHeader.nx-1)-sourceHeader.nx/2)*sourceHeader.dx;
    sourceLine=sourceField(floor(sourceHeader.ny/2)+1,:);
    % Sequential Grid Phase and POP use the conjugate sign convention
    % relative to the positive-k MATLAB propagator below.  Conjugating the
    % imported field gives the exact equivalent optimization problem:
    % P_-(E exp(-i phi)) = conj(P_+(conj(E) exp(+i phi))).
    EinUnnormalized=conj(interp1(sourceX,sourceLine,x,'linear',0));
    sourceIntensity=abs(EinUnnormalized).^2;
    sourceIntensity=sourceIntensity/max(sourceIntensity);
    xRadius=thresholdWidth(sourceIntensity,exp(-2))/2;
end
xIncidentPower=trapz(x,abs(EinUnnormalized).^2);
Ein=EinUnnormalized.*apertureX;
xApertureTransmission=trapz(x,abs(Ein).^2)/xIncidentPower;
Ein=Ein/sqrt(trapz(x,abs(Ein).^2));
inputPower=trapz(x,abs(Ein).^2);

% Y beam at the same element.  It is focused by the conventional cylinder,
% not by a sampled DOE phase, so the 5 um relief limit applies only in X.
qY=1i*pi*cfg.laser.waistRadiusY^2/(cfg.laser.M2Y*lambda);
qY=qY+(cfg.layout.zSBE1-cfg.layout.zLaser);
qY=1/(1/qY-1/cfg.layout.fSBE1);
qY=qY+(cfg.layout.zSBE2-cfg.layout.zSBE1);
qY=1/(1/qY-1/cfg.layout.fSBE2);
qY=qY+(zYBE1-cfg.layout.zSBE2);
qY=1/(1/qY-1/fYBE1);
qY=qY+(zYBE2-zYBE1);
qY=1/(1/qY-1/fYBE2);
qY=qY+(zHybrid-zYBE2);
invQY=1/qY;
yRadius=sqrt(-cfg.laser.M2Y*lambda/(pi*imag(invQY)));
yInputDiameter=2*yRadius;
if cfg.model.flatGaussianAtDoe
    yInputDiameter=cfg.doeInput.fullDiameterY;
    yRadius=yInputDiameter/2;
end
% Exact circular-aperture transmission for the separable elliptical input.
yFractionAtX=zeros(size(x));
inside=abs(x)<hybridRadius;
yHalf=sqrt(max(0,hybridRadius^2-x(inside).^2));
yFractionAtX(inside)=erf(sqrt(2)*yHalf/yRadius);
xWeight=abs(EinUnnormalized).^2;
hybridApertureTransmission=trapz(x,xWeight.*yFractionAtX)/ ...
    trapz(x,xWeight);
qYBack=qY+effectiveGlassSeparation+doeToFinalYLensAirGap+ ...
    finalYLensThickness/nFinalYLens;
qYAfter=1/(1/qYBack-1/focalLengthY);
qYTarget=qYAfter+workingDistance;
invQYTarget=1/qYTarget;
if cfg.model.flatGaussianAtDoe
    yTargetDiameter=4*cfg.doeInput.M2Y*lambda*focalLengthY/ ...
        (pi*yInputDiameter);
else
    yTargetDiameter=2*sqrt(-cfg.laser.M2Y*lambda/ ...
        (pi*imag(invQYTarget)));
end

targetAmplitude=exp(-(abs(x)/(designWidth/2)).^sgOrder);
useClosedLoopTarget=false;
if cfg.model.flatGaussianAtDoe && cfg.model.useSimplifiedFeedback
    simplifiedResult=fullfile(packageDir,'04_simulation_results', ...
        'zemax_POP_simplified_DOE_input', ...
        'simplified_DOE_input_POP_result.mat');
    if exist(simplifiedResult,'file')
        measured=load(simplifiedResult,'result');
        measuredAmplitude=sqrt(max(interp1(measured.result.x, ...
            measured.result.xLine,x,'linear',0),0));
        correction=ones(size(x)); correctionUse=abs(x)<=0.675;
        measuredAmplitude=measuredAmplitude/max(measuredAmplitude(correctionUse));
        correction(correctionUse)=max(measuredAmplitude(correctionUse),0.60).^0.70;
        correction=max(0.60,min(1.30,correction));
        correction=conv(correction,ones(1,61)/61,'same');
        targetAmplitude=targetAmplitude.*correction;
        useClosedLoopTarget=true;
    end
end
targetAmplitude=targetAmplitude*sqrt(inputPower/ ...
    trapz(x,targetAmplitude.^2));
uniformityUse=abs(x)<=0.90*cfg.targetXWidth/2;
targetWindow=abs(x)<=cfg.targetXWidth/2;

% Initial phase from energy-conserving ray mapping.
inputCdf=cumtrapz(x,abs(Ein).^2); inputCdf=inputCdf/inputCdf(end);
targetCdf=cumtrapz(x,targetAmplitude.^2); targetCdf=targetCdf/targetCdf(end);
[targetCdfUnique,uniqueIndex]=unique(targetCdf);
xMapped=interp1(targetCdfUnique,x(uniqueIndex),inputCdf,'linear','extrap');
theta=atan2(xMapped-x,xPropagationAfterDoe);
phiMap=cumtrapz(x,k*sin(theta));
phiMap=phiMap-phiMap(N/2+1);
phiFront=zeros(size(x));
phiBack=angle(exp(1i*phiMap));

% Continuous two-phase-plane alternating projection.  Both X reliefs are
% on one plane-parallel DOE.  The independent downstream Y cylinder has no
% X power and enters the X model only through its reduced glass thickness.
for iteration=1:360
    EbeforeBack=propagate(Ein.*exp(1i*phiFront), ...
        effectiveGlassSeparation);
    Etarget=propagate(EbeforeBack.*exp(1i*phiBack),xPropagationAfterDoe);
    constrainedTarget=targetAmplitude.*exp(1i*angleComplex(Etarget));
    desiredAfterBack=propagate(constrainedTarget,-xPropagationAfterDoe);
    phiBack=angle(exp(1i*(angleComplex(desiredAfterBack)- ...
        angleComplex(EbeforeBack))));
    constrainedBeforeBack=abs(desiredAfterBack).* ...
        exp(1i*angleComplex(EbeforeBack));
    desiredFront=propagate(constrainedBeforeBack, ...
        -effectiveGlassSeparation);
    phiFront=angle(exp(1i*(angleComplex(desiredFront)- ...
        angleComplex(Ein))));
end

% Manufactured quantized/held-cell refinement with best-iteration retention.
phiFront=constrainPhase(phiFront);
phiBack=constrainPhase(phiBack);
targetWeight=ones(size(x));
bestScore=-inf; bestIteration=0;
bestPhiFront=phiFront; bestPhiBack=phiBack;
bestMetrics=[];
for iteration=1:1600
    EbeforeBack=propagate(Ein.*exp(1i*phiFront), ...
        effectiveGlassSeparation);
    Etarget=propagate(EbeforeBack.*exp(1i*phiBack),xPropagationAfterDoe);
    metrics=evaluate(Etarget);
    widthError=abs(metrics.width-cfg.targetXWidth)/cfg.targetXWidth;
    if widthError<=0.05 && metrics.efficiency>=0.85/ ...
            hybridApertureTransmission
        if useClosedLoopTarget
            modelAmplitude=abs(Etarget); modelAmplitude=modelAmplitude/max(modelAmplitude);
            desiredShape=targetAmplitude/max(targetAmplitude);
            score=-mean((modelAmplitude(targetWindow)- ...
                desiredShape(targetWindow)).^2)-0.02*widthError;
        else
            score=metrics.uniformity-0.10*widthError+ ...
                0.02*metrics.efficiency;
        end
        if score>bestScore
            bestScore=score; bestIteration=iteration;
            bestPhiFront=phiFront; bestPhiBack=phiBack;
            bestMetrics=metrics;
        end
    end
    if mod(iteration,10)==0 && ~useClosedLoopTarget
        actual=abs(Etarget); actual=actual/max(actual(uniformityUse));
        nominal=targetAmplitude/max(targetAmplitude(uniformityUse));
        correction=nominal(uniformityUse)./max(actual(uniformityUse),0.45);
        correction=max(0.82,min(1.22,correction));
        targetWeight(uniformityUse)=targetWeight(uniformityUse).* ...
            correction.^0.42;
        targetWeight=max(0.45,min(2.2,targetWeight));
        targetWeight=conv(targetWeight,ones(1,21)/21,'same');
    end
    workingTarget=targetAmplitude.*targetWeight;
    workingTarget=workingTarget*sqrt(inputPower/ ...
        trapz(x,workingTarget.^2));
    constrainedTarget=workingTarget.*exp(1i*angleComplex(Etarget));
    desiredAfterBack=propagate(constrainedTarget,-xPropagationAfterDoe);
    phiBack=constrainPhase(angle(exp(1i*(angleComplex(desiredAfterBack)- ...
        angleComplex(EbeforeBack)))));
    constrainedBeforeBack=abs(desiredAfterBack).* ...
        exp(1i*angleComplex(EbeforeBack));
    desiredFront=propagate(constrainedBeforeBack, ...
        -effectiveGlassSeparation);
    phiFront=constrainPhase(angle(exp(1i*(angleComplex(desiredFront)- ...
        angleComplex(Ein)))));
end
if bestIteration>0
    phiFront=bestPhiFront; phiBack=bestPhiBack; metrics=bestMetrics;
end
EbeforeBack=propagate(Ein.*exp(1i*phiFront), ...
    effectiveGlassSeparation);
Etarget=propagate(EbeforeBack.*exp(1i*phiBack),xPropagationAfterDoe);
metrics=evaluate(Etarget);
Itarget=abs(Etarget).^2; Itarget=Itarget/max(Itarget);

result.name=name;
result.model=['Plane-parallel double-sided X-relief DOE followed by ' ...
    'an independent HPFS 7980 refractive Y cylinder'];
result.physicalDoeCount=1;
result.xPhaseSurfaceCount=2;
result.plateThickness=plateThickness;
result.effectiveGlassSeparation=effectiveGlassSeparation;
result.designWidth=designWidth;
result.superGaussianOrder=sgOrder;
result.gridN=N;
result.cellPitch=cellPitch;
result.quantizationLevels=levels;
result.minimumRequestedFeature=cfg.doe.minimumFeature;
result.hybridClearAperture=hybridClearAperture;
result.patternWidth=patternWidth;
result.targetDistance=workingDistance;
result.xEffectivePropagationAfterDoe=xPropagationAfterDoe;
result.doeToFinalYLensAirGap=doeToFinalYLensAirGap;
result.finalYLensThickness=finalYLensThickness;
result.xInputDiameter=2*xRadius;
result.yInputDiameter=yInputDiameter;
result.yRequiredDiameter=requiredYDiameter;
result.yTelescopeMagnification=yMagnification;
result.yExpanderFocalLength1=fYBE1;
result.yExpanderFocalLength2=fYBE2;
result.xRelayMagnification=xRelayMagnification;
result.xRelayFocalLength1=fXRelay1;
result.xRelayFocalLength2=fXRelay2;
result.zXRelay1=zXRelay1;
result.zXRelay2=zXRelay2;
result.zYBE1=zYBE1;
result.zYBE2=zYBE2;
result.zHybrid=zHybrid;
result.zFinalYFront=cfg.layout.zFinalYFront;
result.zFinalYBack=cfg.layout.zFinalYBack;
result.zTarget=cfg.layout.zTarget;
result.yFocalLength=focalLengthY;
result.yTargetDiameter=yTargetDiameter;
result.xTargetWidth=metrics.width;
result.xFwhm=metrics.fwhm;
result.xUniformity=metrics.uniformity;
result.xWindowEfficiency=metrics.efficiency;
result.hybridApertureTransmission=hybridApertureTransmission;
result.totalUsefulEfficiency=metrics.efficiency* ...
    hybridApertureTransmission;
result.bestIteration=bestIteration;
result.spatialFilterUsed=false;
result.amplitudeMaskUsed=false;
result.pass=abs(metrics.width-cfg.targetXWidth)/cfg.targetXWidth<=0.05 && ...
    metrics.uniformity>=0.90 && result.totalUsefulEfficiency>=0.85 && ...
    abs(yTargetDiameter-cfg.targetYWidth)/cfg.targetYWidth<=0.01;

save(fullfile(outputDir,'final_hybrid_doe_lens_result.mat'),'result','cfg','x', ...
    'Ein','Itarget','phiFront','phiBack','targetAmplitude','-v7.3');
fid=fopen(fullfile(outputDir,'execution_manifest.txt'),'w');
fields=fieldnames(result);
for fieldIndex=1:numel(fields)
    fieldName=fields{fieldIndex}; value=result.(fieldName);
    if ischar(value); fprintf(fid,'%s=%s\n',fieldName,value);
    else; fprintf(fid,'%s=%.12g\n',fieldName,value); end
end
fclose(fid);

fig=figure('Visible','off','Color','w','Position',[80 80 1250 680]);
plot(x,Itarget,'b-','LineWidth',1.1); grid on
xlim([-1.1 1.1]); ylim([0 1.08]);
xlabel('X (mm)'); ylabel('Normalized irradiance');
title(sprintf(['Separated DOE + Y cylinder: U=%.2f%%, X=%.4f mm, ' ...
    'useful efficiency=%.2f%%'],100*metrics.uniformity,metrics.width, ...
    100*result.totalUsefulEfficiency));
print(fig,fullfile(outputDir,'hybrid_target_x.png'),'-dpng','-r180');
close(fig)

% Numeric lineouts and compact separable 2-D target-plane irradiance.
writetable(table(x(:),Itarget(:),'VariableNames',{'X_mm','NormalizedIrradiance'}), ...
    fullfile(outputDir,'target_plane_x_lineout.csv'));
yDisplay=linspace(-0.002,0.002,801); % mm
yWaistRadius=cfg.targetYWidth/2;
Iy=exp(-2*(yDisplay/yWaistRadius).^2);
writetable(table(yDisplay(:),Iy(:),'VariableNames',{'Y_mm','NormalizedIrradiance'}), ...
    fullfile(outputDir,'target_plane_y_lineout.csv'));
xDisplay=linspace(-1.1,1.1,1601);
IxDisplay=interp1(x,Itarget,xDisplay,'linear',0);
I2D=Iy(:)*IxDisplay(:).'; I2D=I2D/max(I2D(:));
save(fullfile(outputDir,'target_plane_2d_intensity.mat'), ...
    'xDisplay','yDisplay','I2D');
fig=figure('Visible','off','Color','w','Position',[80 80 1320 620]);
imagesc(xDisplay,1e3*yDisplay,I2D); axis xy; colormap(parula); colorbar
xlabel('X (mm)'); ylabel('Y (um)');
title(sprintf(['Target plane Z=%.1f mm: X flat-top / Y Gaussian focus, ' ...
    'U=%.2f%%'],result.zTarget,100*result.xUniformity));
print(fig,fullfile(outputDir,'target_plane_2d_intensity.png'),'-dpng','-r180');
close(fig)

% Acceptance and efficiency budgets.
metricName={'X full 1/e^2 width';'Y full 1/e^2 width'; ...
    'X central-90% uniformity';'Total useful efficiency'; ...
    'Physical DOE count';'Working distance'};
requirement={'1.500 mm +/-5%';'1.000 um +/-1%';'>=90%';'>=85%'; ...
    '1';'>50 mm'};
value=[result.xTargetWidth;1e3*result.yTargetDiameter; ...
    100*result.xUniformity;100*result.totalUsefulEfficiency; ...
    result.physicalDoeCount;result.targetDistance];
passFlag=[abs(result.xTargetWidth/cfg.targetXWidth-1)<=0.05; ...
    abs(result.yTargetDiameter/cfg.targetYWidth-1)<=0.01; ...
    result.xUniformity>=0.90;result.totalUsefulEfficiency>=0.85; ...
    result.physicalDoeCount==1;result.targetDistance>50];
writetable(table(metricName,requirement,value,passFlag), ...
    fullfile(outputDir,'acceptance_summary.csv'));
lossItem={'Hybrid clear-aperture transmission'; ...
    'X energy inside 1.5 mm target window';'Total useful efficiency'; ...
    sprintf('Ideal %d-level phase quantization efficiency',levels)};
efficiency=[result.hybridApertureTransmission;result.xWindowEfficiency; ...
    result.totalUsefulEfficiency; ...
    (sin(pi/levels)/(pi/levels))^2];
writetable(table(lossItem,efficiency),fullfile(outputDir,'efficiency_budget.csv'));

% Mechanical layout and XZ/YZ path diagrams.
element={'LASER';'SBE1';'SBE2';'XRL1';'XRL2';'YBE1';'YBE2'; ...
    'DOE-A';'DOE-B';'YFL-front';'YFL-rear';'TARGET'};
zPosition=[0;cfg.layout.zSBE1;cfg.layout.zSBE2;zXRelay1;zXRelay2; ...
    zYBE1;zYBE2;zHybrid;zHybrid+plateThickness; ...
    cfg.layout.zFinalYFront;cfg.layout.zFinalYBack;result.zTarget];
xPower=[0;cfg.layout.fSBE1;cfg.layout.fSBE2;fXRelay1;fXRelay2; ...
    Inf;Inf;Inf;Inf;Inf;Inf;0];
yPower=[0;cfg.layout.fSBE1;cfg.layout.fSBE2;Inf;Inf;fYBE1;fYBE2; ...
    Inf;Inf;Inf;focalLengthY;0];
writetable(table(element,zPosition,xPower,yPower), ...
    fullfile(outputDir,'optical_layout.csv'));

segmentIndex=[ones(1,7) cfg.doe.refractiveIndex 1 nFinalYLens 1];
qXPath=1i*pi*cfg.laser.waistRadiusX^2/(cfg.laser.M2X*lambda);
xDiameterPath=zeros(size(zPosition)); xDiameterPath(1)=beamDiameter(qXPath,cfg.laser.M2X);
for nodeIndex=2:numel(zPosition)
    qXPath=qXPath+(zPosition(nodeIndex)-zPosition(nodeIndex-1))/ ...
        segmentIndex(nodeIndex-1);
    xDiameterPath(nodeIndex)=beamDiameter(qXPath,cfg.laser.M2X);
    if isfinite(xPower(nodeIndex)) && xPower(nodeIndex)~=0
        qXPath=1/(1/qXPath-1/xPower(nodeIndex));
    end
end
% Replace the post-DOE q-envelope with the DOE-shaped geometric envelope.
xAfterDoeEffective=[0 doeToFinalYLensAirGap ...
    doeToFinalYLensAirGap+finalYLensThickness/nFinalYLens ...
    xPropagationAfterDoe];
xDiameterPath(9:12)=xDiameterPath(9)+(result.xTargetWidth- ...
    xDiameterPath(9))*xAfterDoeEffective/xPropagationAfterDoe;
qYPath=1i*pi*cfg.laser.waistRadiusY^2/(cfg.laser.M2Y*lambda);
yDiameterPath=zeros(size(zPosition)); yDiameterPath(1)=beamDiameter(qYPath,cfg.laser.M2Y);
for nodeIndex=2:numel(zPosition)
    qYPath=qYPath+(zPosition(nodeIndex)-zPosition(nodeIndex-1))/ ...
        segmentIndex(nodeIndex-1);
    yDiameterPath(nodeIndex)=beamDiameter(qYPath,cfg.laser.M2Y);
    if isfinite(yPower(nodeIndex)) && yPower(nodeIndex)~=0
        qYPath=1/(1/qYPath-1/yPower(nodeIndex));
    end
end
yDiameterPath(end)=result.yTargetDiameter;
plotPath(zPosition,xDiameterPath,element,'XZ optical path', ...
    'X half-width (mm)',fullfile(outputDir,'final_hybrid_xz_optical_path.png'));
plotPath(zPosition,yDiameterPath,element,'YZ optical path', ...
    'Y half-width (mm)',fullfile(outputDir,'final_hybrid_yz_optical_path.png'));

% Quantized relief and binary lithography layers for both surfaces.
fabricationDir=fullfile(packageDir,'03_fabrication_data');
if ~exist(fabricationDir,'dir'); mkdir(fabricationDir); end
activeIndices=find(patternUse);
cellIndex=(activeIndices(1):samplesPerCell:activeIndices(end)).';
xCellStart=x(cellIndex).'+cfg.doe.zemaxGridDecenterX;
xCellEnd=xCellStart+cellPitch;
xCellCenter=(xCellStart+xCellEnd)/2;
levelA=mod(round(mod(phiFront(cellIndex),2*pi)/(2*pi)*levels),levels).';
levelB=mod(round(mod(phiBack(cellIndex),2*pi)/(2*pi)*levels),levels).';
heightStep=cfg.doe.twoPiReliefDepth/levels;
heightA_um=1e3*heightStep*levelA;
heightB_um=1e3*heightStep*levelB;
writetable(table(xCellStart,xCellEnd,xCellCenter,levelA,heightA_um), ...
    fullfile(fabricationDir,'surface_A_relief_cells.csv'));
writetable(table(xCellStart,xCellEnd,xCellCenter,levelB,heightB_um), ...
    fullfile(fabricationDir,'surface_B_relief_cells.csv'));
maskA=zeros(numel(levelA),log2(levels));
maskB=zeros(numel(levelB),log2(levels));
for maskIndex=1:log2(levels)
    maskA(:,maskIndex)=bitget(uint16(levelA),maskIndex);
    maskB(:,maskIndex)=bitget(uint16(levelB),maskIndex);
end
maskNames=arrayfun(@(v)sprintf('Mask_%d',v),1:log2(levels), ...
    'UniformOutput',false);
writetable(array2table([xCellStart xCellEnd xCellCenter maskA], ...
    'VariableNames',[{'X_start_mm','X_end_mm','X_center_mm'} maskNames]), ...
    fullfile(fabricationDir,'surface_A_binary_masks.csv'));
writetable(array2table([xCellStart xCellEnd xCellCenter maskB], ...
    'VariableNames',[{'X_start_mm','X_end_mm','X_center_mm'} maskNames]), ...
    fullfile(fabricationDir,'surface_B_binary_masks.csv'));
fid=fopen(fullfile(fabricationDir,'fabrication_instructions.txt'),'w');
fprintf(fid,'Material: %s\n',cfg.doe.material);
fprintf(fid,'Wavelength: 355 nm\nPhysical substrate count: 1\n');
fprintf(fid,'Substrate thickness: %.3f mm\nClear aperture: %.3f mm\n', ...
    plateThickness,hybridClearAperture);
fprintf(fid,'Pattern width per face: %.3f mm\nCell pitch: %.6f um\n', ...
    patternWidth,1e3*cellPitch);
fprintf(fid,'Common X pattern datum offset: %.6f um\n', ...
    1e3*cfg.doe.zemaxGridDecenterX);
fprintf(fid,'Relief levels: %d; binary masks per face: %d\n',levels,log2(levels));
fprintf(fid,'2pi relief depth: %.9f um\nHeight step: %.9f um\n', ...
    1e3*cfg.doe.twoPiReliefDepth,1e3*heightStep);
for maskIndex=1:log2(levels)
    fprintf(fid,'Mask %d etch contribution: %.9f um\n',maskIndex, ...
        1e3*heightStep*2^(maskIndex-1));
end
fprintf(fid,['DOE surface B carries X relief only.  The fY=%.3f mm ' ...
    'HPFS 7980 Y cylinder is a separate downstream element.\n'],focalLengthY);
fprintf(fid,['CSV mask convention: 1=open/expose/etch, 0=protect. ' ...
    'Confirm polarity and etch selectivity before release.\n']);
fclose(fid);

    function Eout=propagate(EinLocal,z)
        root=sqrt(complex(1-(lambda*fx).^2,0));
        H=exp(1i*k*z*root);
        Eout=fftshift(ifft(ifftshift(fftshift(fft(ifftshift(EinLocal))).*H)));
    end
    function p=angleComplex(E)
        p=atan2(imag(E),real(E));
    end
    function phaseOut=constrainPhase(phaseIn)
        phaseOut=zeros(size(phaseIn));
        firstActive=find(patternUse,1,'first');
        lastActive=find(patternUse,1,'last');
        numberOfBlocks=ceil((lastActive-firstActive+1)/samplesPerCell);
        for blockIndex=0:numberOfBlocks-1
            indices=firstActive+blockIndex*samplesPerCell+ ...
                (0:samplesPerCell-1);
            indices=indices(indices<=lastActive);
            if isempty(indices); continue; end
            phaseOut(indices)=angle(mean(exp(1i*phaseIn(indices))));
        end
        wrapped=mod(phaseOut,2*pi);
        level=mod(round(wrapped/(2*pi)*levels),levels);
        phaseOut=2*pi*level/levels;
    end
    function m=evaluate(E)
        I=abs(E).^2;
        In=I/max(I);
        m.width=thresholdWidth(In,exp(-2));
        m.fwhm=thresholdWidth(In,0.5);
        m.uniformity=min(In(uniformityUse))/max(In(uniformityUse));
        m.efficiency=trapz(x(targetWindow),I(targetWindow))/inputPower;
    end
    function width=thresholdWidth(In,level)
        [~,center]=min(abs(x));
        left=find(In(1:center)<level,1,'last');
        rightRelative=find(In(center:end)<level,1,'first');
        if isempty(left) || isempty(rightRelative); width=NaN; return; end
        right=center+rightRelative-1;
        xl=x(left)+(level-In(left))*(x(left+1)-x(left))/ ...
            (In(left+1)-In(left));
        xr=x(right-1)+(level-In(right-1))*(x(right)-x(right-1))/ ...
            (In(right)-In(right-1));
        width=xr-xl;
    end
    function [fieldOut,header]=readZbf(fileName)
        zbfFid=fopen(fileName,'r','ieee-le');
        if zbfFid<0; error('Cannot read source ZBF: %s',fileName); end
        zbfCleanup=onCleanup(@() fclose(zbfFid)); %#ok<NASGU>
        header.version=fread(zbfFid,1,'int32');
        dims=fread(zbfFid,8,'int32');
        values=fread(zbfFid,20,'double');
        header.nx=dims(1); header.ny=dims(2);
        header.dx=values(1); header.dy=values(2);
        pairs=fread(zbfFid,[2 header.nx*header.ny],'double');
        if size(pairs,2)~=header.nx*header.ny
            error('Incomplete source ZBF field data.');
        end
        ordered=complex(pairs(1,:),pairs(2,:));
        fieldOut=reshape(ordered,[header.nx header.ny]).';
    end
    function diameter=beamDiameter(qLocal,M2Local)
        invQLocal=1/qLocal;
        diameter=2*sqrt(-M2Local*lambda/(pi*imag(invQLocal)));
    end
    function plotPath(zNode,diameterNode,labelNode,pathTitle,yLabel,fileName)
        pathFig=figure('Visible','off','Color','w','Position',[80 80 1300 650]);
        halfWidth=diameterNode/2;
        fill([zNode;flipud(zNode)],[halfWidth;-flipud(halfWidth)], ...
            [1.0 0.86 0.72],'EdgeColor','none','FaceAlpha',0.72); hold on
        plot(zNode,halfWidth,'r-','LineWidth',1.6);
        plot(zNode,-halfWidth,'r-','LineWidth',1.6);
        plot([zNode(1) zNode(end)],[0 0],'k--','LineWidth',0.8);
        yExtent=max(halfWidth)*1.25;
        for labelIndex=1:numel(zNode)
            line([zNode(labelIndex) zNode(labelIndex)],[-yExtent yExtent], ...
                'Color',[0.15 0.15 0.15],'LineWidth',0.8);
            text(zNode(labelIndex)+2,0.92*yExtent,labelNode{labelIndex}, ...
                'Rotation',55,'FontSize',8,'Interpreter','none');
        end
        grid on; xlim([zNode(1) zNode(end)+10]); ylim([-yExtent yExtent]);
        xlabel('Optical-axis position Z (mm)'); ylabel(yLabel);
        title(sprintf('%s - separate double-sided DOE and Y cylinder',pathTitle));
        print(pathFig,fileName,'-dpng','-r180'); close(pathFig)
    end
end
