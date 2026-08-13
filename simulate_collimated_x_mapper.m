function result = simulate_collimated_x_mapper(outputDir)
%SIMULATE_COLLIMATED_X_MAPPER End-to-end two-DOE collimated line shaper.
% DOE1 and DOE2 act only in X. DOE2 lies in the output plane and removes
% the residual X phase, producing a flat X wavefront at that reference
% plane. Finite-aperture diffraction after that plane is reported separately.

if nargin<1
    outputDir=fullfile(fileparts(mfilename('fullpath')), ...
        'results','collimated_X_R2019b');
end
if ~exist(outputDir,'dir'); mkdir(outputDir); end

lambda=355e-6;                 % mm
k=2*pi/lambda;
inputDiameter=6.0;             % full 1/e^2 X diameter at DOE1, mm
clearAperture=15.0;            % mm
mapperDistance=300;            % DOE1 z=400 to DOE2/output z=700, mm
downstreamDistance=0;          % collimation reference at DOE2 exit surface
targetWidth=1.5;               % full 1/e^2 X width, mm
designWidth=1.482;             % calibrated phase-map width, mm
phaseLevels=Inf;               % continuous grayscale/freeform DOE surfaces
parallelTolerance=10e-6;       % rad RMS local X wavefront angle
N=32768;
window=80;                     % mm, contains the expanded 54.24 mm beam
dx=window/N;
x=((0:N-1)-N/2)*dx;
aperture=abs(x)<=clearAperture/2;
w=inputDiameter/2;
Ein=exp(-(x/w).^2).*aperture;

% Geometric mapping gives a stable initial phase for the iterative solver.
a=sqrt(2)/w;
cdfEdge=erf(a*clearAperture/2);
x2map=(designWidth/2)*erf(a*x)/cdfEdge;
x2map=max(-designWidth/2,min(designWidth/2,x2map));
delta=x2map-x;
sinTheta=delta./sqrt(mapperDistance^2+delta.^2);
dphi1dx=k*sinTheta;
phi1=cumtrapz(x,dphi1dx);
phi1=phi1-phi1(N/2+1);

inside=x(aperture);
mapped=x2map(aperture);
thetaMapped=sinTheta(aperture);
valid2=abs(x)<=designWidth/2;
thetaAt2=zeros(size(x));
thetaAt2(valid2)=interp1(mapped,thetaMapped,x(valid2),'pchip');
thetaAt2(x<-designWidth/2)=thetaMapped(1);
thetaAt2(x> designWidth/2)=thetaMapped(end);
dphi2dx=-k*thetaAt2;
phi2=cumtrapz(x,dphi2dx);
phi2=phi2-phi2(N/2+1);

% DOE1 maps the 6 mm Gaussian into the 1.5 mm line. DOE2 removes the
% resulting X phase slope at its exit reference plane.
signalRegion=abs(x)<=designWidth/2;
phase1=phi1;
for iteration=1:250
    forward=propagateASM(Ein.*exp(1i*phase1),mapperDistance);
    constrained=0.65*forward;
    constrained(signalRegion)=exp(1i*angleComplex(forward(signalRegion)));
    backward=propagateASM(constrained,-mapperDistance);
    phase1=unwrap(angleComplex(backward));
end
[phase1Q,level1]=quantizePhase(phase1,phaseLevels);
Ebefore2=propagateASM(Ein.*exp(1i*phase1Q),mapperDistance);

phi2=-unwrap(angleComplex(Ebefore2));
[phase2Q,level2]=quantizePhase(phi2,phaseLevels);
Eafter2=Ebefore2.*exp(1i*phase2Q);
Etarget=propagateASM(Eafter2,downstreamDistance);

I2=abs(Eafter2).^2; I2=I2/max(I2);
It=abs(Etarget).^2; It=It/max(It);
metrics2=profile_metrics_common(x(:),I2(:),targetWidth,0.90);
metricsTarget=profile_metrics_common(x(:),It(:),targetWidth,0.90);
wave2=wavefrontMetrics(Eafter2,I2);
waveTarget=wavefrontMetrics(Etarget,It);

% The final f=100 mm lens is spherical. DOE1 was inversely designed through
% it, and final-plane DOE2 removes its residual X convergence phase.
result.name='In-house two-DOE collimated X mapper';
result.x=x(:); result.IatDOE2=I2(:); result.IatTarget=It(:);
result.metricsAtDOE2=metrics2; result.metricsAtTarget=metricsTarget;
result.wavefrontAtDOE2=wave2; result.wavefrontAtTarget=waveTarget;
result.inputDiameter=inputDiameter; result.clearAperture=clearAperture;
result.mapperDistance=mapperDistance; result.downstreamDistance=downstreamDistance;
result.targetWidth=targetWidth; result.phaseLevels=phaseLevels;
result.parallelTolerance=parallelTolerance;
result.pass=abs(metricsTarget.widthE2-targetWidth)<=0.01*targetWidth && ...
    metricsTarget.uniformity>=0.90 && ...
    waveTarget.rmsAngle<=parallelTolerance;

nSilica=1.47607188038016;
h2piUm=0.355/(nSilica-1);
depth1Um=mod(phase1Q,2*pi)/(2*pi)*h2piUm;
depth2Um=mod(phase2Q,2*pi)/(2*pi)*h2piUm;

mask=aperture(:);
writetable(table(1e3*x(mask).',mod(phase1Q(mask).',2*pi),depth1Um(mask).', ...
    'VariableNames',{'x_um','wrappedPhase_rad','etchDepth_um'}), ...
    fullfile(outputDir,'doe1_phase.csv'));
mask2=abs(x(:))<=3;
writetable(table(1e3*x(mask2).',mod(phase2Q(mask2).',2*pi),depth2Um(mask2).', ...
    'VariableNames',{'x_um','wrappedPhase_rad','etchDepth_um'}), ...
    fullfile(outputDir,'doe2_phase.csv'));
writetable(table(1e3*x(:),I2(:),It(:), ...
    'VariableNames',{'x_um','intensityAfterDOE2','intensityAtTarget'}), ...
    fullfile(outputDir,'collimated_x_profiles.csv'));

parameter={'Wavelength';'Input X beam diameter';'Clear aperture'; ...
    'DOE1 to DOE2/final plane';'DOE2 to target';'Phase levels'; ...
    'X width after DOE2';'X width at target'; ...
    'Uniformity after DOE2';'Uniformity at target'; ...
    'Mean X angle after DOE2';'Mean X angle at target'; ...
    'RMS local X angle after DOE2';'RMS local X angle at target'; ...
    'Fitted X wavefront radius after DOE2'; ...
    'Fitted X wavefront radius at target'; ...
    'Final spherical lens fX';'Final spherical lens fY'; ...
    'Terminal X phase-corrector power';'Parallel tolerance RMS'; ...
    'Y full 1/e2 target width';'Overall pass'};
value={355;inputDiameter;clearAperture;mapperDistance;downstreamDistance; ...
    phaseLevels;metrics2.widthE2;metricsTarget.widthE2; ...
    100*metrics2.uniformity;100*metricsTarget.uniformity; ...
    1e3*wave2.meanAngle;1e3*waveTarget.meanAngle; ...
    1e3*wave2.rmsAngle;1e3*waveTarget.rmsAngle; ...
    wave2.radius;waveTarget.radius;100;100;Inf; ...
    1e6*parallelTolerance;1.0;double(result.pass)};
unit={'nm';'mm';'mm';'mm';'mm';'-';'mm';'mm';'%';'%'; ...
    'mrad';'mrad';'mrad';'mrad';'mm';'mm';'mm';'mm';'Y: none'; ...
    'urad';'um';'0/1'};
writetable(table(parameter,value,unit),fullfile(outputDir,'collimated_x_summary.csv'));

% A flat wavefront at DOE2 is not the same as zero diffraction over an
% unlimited distance. Quantify the actual field evolution behind DOE2.
verificationDistance_mm=[0;1;5;10;50];
verificationWidth_mm=zeros(size(verificationDistance_mm));
verificationUniformity_percent=zeros(size(verificationDistance_mm));
verificationRmsLocalAngle_urad=zeros(size(verificationDistance_mm));
for verificationIndex=1:numel(verificationDistance_mm)
    verificationField=propagateASM(Eafter2,verificationDistance_mm(verificationIndex));
    verificationIntensity=abs(verificationField).^2;
    verificationIntensity=verificationIntensity/max(verificationIntensity);
    verificationProfile=profile_metrics_common(x(:),verificationIntensity(:), ...
        targetWidth,0.90);
    verificationWave=wavefrontMetrics(verificationField,verificationIntensity);
    verificationWidth_mm(verificationIndex)=verificationProfile.widthE2;
    verificationUniformity_percent(verificationIndex)=100*verificationProfile.uniformity;
    verificationRmsLocalAngle_urad(verificationIndex)=1e6*verificationWave.rmsAngle;
end
verificationTable=table(verificationDistance_mm,verificationWidth_mm, ...
    verificationUniformity_percent,verificationRmsLocalAngle_urad);
writetable(verificationTable,fullfile(outputDir,'post_DOE2_diffraction_check.csv'));
result.postDOE2Verification=verificationTable;

fig=figure('Visible','off','Color','w','Position',[80 80 1100 700]);
subplot(2,1,1)
plot(x,I2,'b-',x,It,'r--','LineWidth',1.1); grid on
xlim([-1 1]); ylim([0 1.04]); ylabel('Normalized irradiance')
legend('Immediately after DOE2','Final plane','Location','south')
title('End-to-end complex-field propagation: collimated X line')
subplot(2,1,2)
plot(x,1e3*localAngle(Eafter2),'b-',x,1e3*localAngle(Etarget),'r--'); grid on
xlim([-0.68 0.68]); xlabel('X (mm)'); ylabel('Local wavefront angle (mrad)')
legend('Immediately after DOE2','Final plane','Location','best')
print(fig,fullfile(outputDir,'collimated_x_intensity_and_angle.png'),'-dpng','-r180');
close(fig)

save(fullfile(outputDir,'collimated_x_result.mat'),'result','-v7.3');
disp(table(metrics2.widthE2,metricsTarget.widthE2, ...
    100*metrics2.uniformity,100*metricsTarget.uniformity, ...
    1e3*wave2.rmsAngle,1e3*waveTarget.rmsAngle, ...
    'VariableNames',{'widthDOE2_mm','widthTarget_mm','uniformityDOE2_percent', ...
    'uniformityTarget_percent','rmsAngleDOE2_mrad','rmsAngleTarget_mrad'}))
assert(result.pass,'laser_sim:CollimatedXFailed', ...
    'Collimated X mapper did not meet width, uniformity, and angle limits.');

    function [phaseQ,level]=quantizePhase(phase,levels)
        if isinf(levels)
            phaseQ=phase;
            level=nan(size(phase));
            return
        end
        wrapped=mod(phase,2*pi);
        level=mod(round(wrapped/(2*pi)*levels),levels);
        phaseQ=level*(2*pi/levels);
    end

    function Eout=propagateASM(Ein,z)
        fx=((0:N-1)-N/2)/window;
        root=sqrt(complex(1-(lambda*fx).^2,0));
        H=exp(1i*k*z*root);
        Eout=fftshift(ifft(ifftshift(fftshift(fft(ifftshift(Ein))).*H)));
    end

    function angle=localAngle(E)
        phase=unwrap(angleComplex(E));
        angle=(lambda/(2*pi))*gradient(phase,dx);
    end

    function p=angleComplex(E)
        p=atan2(imag(E),real(E));
    end

    function metrics=wavefrontMetrics(E,I)
        use=abs(x)<=0.45*targetWidth & I>=0.5;
        phase=unwrap(angleComplex(E));
        coeff=polyfit(x(use),phase(use),2);
        fitted=polyval(coeff,x(use));
        local=(lambda/(2*pi))*gradient(phase,dx);
        metrics.meanAngle=(lambda/(2*pi))*coeff(2);
        metrics.rmsAngle=sqrt(mean((local(use)-metrics.meanAngle).^2));
        metrics.phaseFitRms=sqrt(mean((phase(use)-fitted).^2));
        if abs(coeff(1))<eps
            metrics.radius=Inf;
        else
            metrics.radius=k/(2*coeff(1));
        end
    end
end
