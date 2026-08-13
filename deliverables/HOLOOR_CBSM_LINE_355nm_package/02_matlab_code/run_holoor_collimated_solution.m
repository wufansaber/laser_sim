function result = run_holoor_collimated_solution(cfg, outputDir)
%RUN_HOLOOR_COLLIMATED_SOLUTION Verify the X-collimated HOLO/OR train.
if ~exist(outputDir,'dir'); mkdir(outputDir); end
p=cfg.layout;

P=@(d)[1 d;0 1];
L=@(f)[1 0;-1/f 1];
Ix=eye(2); % The final Y cylinder is identity in the X plane.
MxTelescope=L(p.fXC2)*P(p.zCXC2-p.zCXC1)*L(p.fXC1);
MxToTarget=P(p.zTarget-p.zCXC2)*Ix*MxTelescope;

% Parallel marginal rays at the custom-module exit and CXC1 entrance.
xIn=[-cfg.moduleOutputXWidth/2;cfg.moduleOutputXWidth/2];
rayIn=[xIn.';0 0];
rayAfterCXC=MxTelescope*rayIn;
rayAtTarget=MxToTarget*rayIn;
xWidthAfterCXC=max(rayAfterCXC(1,:))-min(rayAfterCXC(1,:));
xWidthAtTarget=max(rayAtTarget(1,:))-min(rayAtTarget(1,:));
maxAbsAngleAtTarget=max(abs(rayAtTarget(2,:)));

tol=1e-12;
checks={'CXC telescope afocal (C=0)'; ...
    'Last lens X optical power'; ...
    'X width after CXC'; ...
    'X width at target'; ...
    'Geometric marginal-ray angle at target'};
value=[MxTelescope(2,1);cfg.xLastLensPower;xWidthAfterCXC; ...
    xWidthAtTarget;maxAbsAngleAtTarget];
limit=[tol;tol;cfg.targetXWidth;cfg.targetXWidth;tol];
pass=[abs(value(1))<=limit(1);abs(value(2))<=limit(2); ...
    abs(value(3)-limit(3))<=tol;abs(value(4)-limit(4))<=tol; ...
    abs(value(5))<=limit(5)];
unit={'1/mm';'1/mm';'mm';'mm';'rad'};
verification=table(checks,value,limit,unit,pass);
writetable(verification,fullfile(outputDir,'collimated_x_verification.csv'));

% Phase-aware verification. The standard TopHatSim.p returns intensity
% only, so it is not accepted as evidence of X collimation. A vendor file
% must contain x_mm and either U_exit (complex) or amplitude + phase_rad.
phaseAvailable=exist(cfg.vendor.phaseFile,'file')==2;
phaseVerified=false;
phaseRms=NaN; residualTilt=NaN; curvature=NaN;
phaseMessage='HOLO/OR complex-field/phase file missing: X collimation not verified.';
if phaseAvailable
    vendorField=load(cfg.vendor.phaseFile);
    if ~isfield(vendorField,'x_mm')
        error('laser_sim:VendorPhaseFormat','Vendor phase file must contain x_mm.');
    end
    xVendor=vendorField.x_mm(:);
    if isfield(vendorField,'U_exit')
        uVendor=vendorField.U_exit(:);
    elseif isfield(vendorField,'amplitude') && isfield(vendorField,'phase_rad')
        uVendor=vendorField.amplitude(:).*exp(1i*vendorField.phase_rad(:));
    else
        error('laser_sim:VendorPhaseFormat', ...
            'Vendor phase file needs U_exit or amplitude plus phase_rad.');
    end
    active=abs(uVendor)>=exp(-1)*max(abs(uVendor));
    xAct=xVendor(active); phi=unwrap(angle(uVendor(active)));
    fitCoef=polyfit(xAct,phi,2);
    linearCoef=polyfit(xAct,phi,1);
    % Remove piston and mean tilt only. Quadratic phase is retained in the
    % residual because wavefront curvature is part of collimation.
    phiResidual=phi-polyval(linearCoef,xAct);
    phaseRms=sqrt(mean(phiResidual.^2));
    residualTilt=linearCoef(1)*cfg.lambda/(2*pi);
    if abs(fitCoef(1))>eps
        curvature=pi/(cfg.lambda*fitCoef(1));
    else
        curvature=Inf;
    end
    phaseVerified=phaseRms<=cfg.vendor.maxPhaseRms && ...
        abs(residualTilt)<=cfg.vendor.maxTilt;
    phaseMessage='Verified from HOLO/OR exit complex-field data.';
end
phaseCheck=table(phaseAvailable,phaseVerified,phaseRms,residualTilt,curvature, ...
    {phaseMessage},'VariableNames',{'phaseDataAvailable','phaseVerified', ...
    'phaseRms_rad','residualTilt_rad','wavefrontRadius_mm','message'});
writetable(phaseCheck,fullfile(outputDir,'holoor_phase_verification.csv'));

% When official phase is unavailable, run an independently designed
% two-element complex-field surrogate.  It is design evidence only and is
% never labelled as HOLO/OR proprietary phase data.
surrogate=simulate_holoor_phase_surrogate(cfg, ...
    fullfile(outputDir,'phase_surrogate'));

matrixName={'CXC telescope';'CXC to target';'Last YFL in X'};
A=[MxTelescope(1,1);MxToTarget(1,1);Ix(1,1)];
B=[MxTelescope(1,2);MxToTarget(1,2);Ix(1,2)];
C=[MxTelescope(2,1);MxToTarget(2,1);Ix(2,1)];
D=[MxTelescope(2,2);MxToTarget(2,2);Ix(2,2)];
writetable(table(matrixName,A,B,C,D), ...
    fullfile(outputDir,'collimated_x_abcd.csv'));

parameter={'Vendor family';'Engineering ID';'Vendor PN status'; ...
    'Wavelength';'Module input beam';'Module X output width'; ...
    'Module exit X phase requirement';'CXC1 focal length'; ...
    'CXC2 focal length';'CXC separation';'X compression'; ...
    'Last lens axis';'Last lens Y focal length';'Last lens X optical power'; ...
    'Target X geometric width';'Target Y exp(-2) width'; ...
    'Target geometric X marginal-ray angle';'HOLO/OR phase data available'; ...
    'HOLO/OR phase verified';'Y beam diameter at YFL'; ...
    'Suggested YFL clear aperture';'Total length'};
valueText={cfg.vendor.family;cfg.vendor.engineeringID; ...
    cfg.vendor.procurementStatus;sprintf('%.0f',cfg.vendor.inputWavelengthNm); ...
    sprintf('%.6f',cfg.vendor.inputBeamDiameter); ...
    sprintf('%.6f',cfg.vendor.outputXWidth);cfg.vendor.requiredExitPhase; ...
    sprintf('%.6f',p.fXC1);sprintf('%.6f',p.fXC2); ...
    sprintf('%.6f',cfg.xTelescopeSeparation);sprintf('%.9f',cfg.xCompression); ...
    'Y only';sprintf('%.6f',p.fYFL);sprintf('%.6g',cfg.xLastLensPower); ...
    sprintf('%.9f',xWidthAtTarget);sprintf('%.6f',1e3*cfg.targetYWidth); ...
    sprintf('%.6g',maxAbsAngleAtTarget);sprintf('%d',phaseAvailable); ...
    sprintf('%d',phaseVerified);sprintf('%.6f',cfg.finalYBeamDiameter); ...
    sprintf('%.6f',cfg.finalYLensClearAperture);sprintf('%.6f',p.zTarget)};
unitText={'-';'-';'-';'nm';'mm';'mm';'-';'mm';'mm';'mm';'x';'-'; ...
    'mm';'1/mm';'mm';'um';'rad';'-';'-';'mm';'mm';'mm'};
writetable(table(parameter,valueText,unitText), ...
    fullfile(outputDir,'holoor_collimated_summary.csv'));

plot_holoor_collimated_paths(cfg,outputDir);
result.cfg=cfg;
result.MxTelescope=MxTelescope;
result.MxToTarget=MxToTarget;
result.verification=verification;
result.xWidthAtTarget=xWidthAtTarget;
result.maxAbsAngleAtTarget=maxAbsAngleAtTarget;
result.phaseCheck=phaseCheck;
result.geometricPass=all(pass);
result.surrogate=surrogate;
result.designPass=all(pass) && (phaseVerified || surrogate.pass);
result.acceptancePass=all(pass) && phaseVerified;
result.pass=result.designPass;
save(fullfile(outputDir,'holoor_collimated_result.mat'),'result','-v7.3');
disp(verification)
end
