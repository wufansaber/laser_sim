function result = simulate_holoor_phase_surrogate(cfg, outputDir)
%SIMULATE_HOLOOR_PHASE_SURROGATE Independent two-element phase surrogate.
% This is not a HOLO/OR proprietary model.  Element 1 maps a collimated
% Gaussian into a line-like flat-top; element 2 cancels the mapped phase.
% The resulting complex field is propagated through the actual downstream
% X telescope.  The final Y-only lens is identity in X.
if ~exist(outputDir,'dir'); mkdir(outputDir); end

lambda=cfg.lambda;
k=2*pi/lambda;
N=32768;
window=80;
dx=window/N;
x=((0:N-1)-N/2)*dx;
clearAperture=15;
inputWidth=cfg.vendor.inputBeamDiameter;
outputWidth=cfg.vendor.outputXWidth;
mapperDistance=cfg.layout.zCBSM2-cfg.layout.zCBSM1;
aperture=abs(x)<=clearAperture/2;
w=inputWidth/2;
Ein=exp(-(x/w).^2).*aperture;

% Energy-conserving 1-D Gaussian-to-uniform coordinate map.
a=sqrt(2)/w;
cdfEdge=erf(a*clearAperture/2);
xMapped=(outputWidth/2)*erf(a*x)/cdfEdge;
xMapped=max(-outputWidth/2,min(outputWidth/2,xMapped));
delta=xMapped-x;
theta=atan2(delta,mapperDistance);
phi1=cumtrapz(x,k*sin(theta));
phi1=phi1-phi1(N/2+1);

Ebefore2=propagate(Ein.*exp(1i*phi1),mapperDistance);
phi2=-unwrap(angleComplex(Ebefore2));
% Ideal lossless two-surface remapper reference: the first surface performs
% the energy map and the second surface removes phase.  A smooth order-8
% super-Gaussian is used so finite-aperture diffraction is represented
% without pretending that a discontinuous hard edge is manufacturable.
superGaussianOrder=8;
Eafter2=exp(-(abs(x)/(outputWidth/2)).^superGaussianOrder);

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
result.model='Independent two-element complex-field phase surrogate';
result.isVendorModel=false;
result.exitWave=exitWave;
result.targetWave=targetWave;
result.targetMeasuredWidth=targetMeasuredWidth;
result.widthError=widthError;
result.targetEdgeSlope=targetEdgeSlope;

parameter={'Model identity';'Vendor proprietary phase';'Wavelength'; ...
    'Element separation';'Module exit width';'Super-Gaussian order'; ...
    'Target measured width';'Target width error'; ...
    'Exit phase RMS';'Target phase RMS'; ...
    'Exit mean wavefront tilt';'Target mean wavefront tilt'; ...
    'Exit RMS local diffraction angle';'Target RMS local diffraction angle'; ...
    'Target fitted wavefront radius';'Target curvature edge slope'; ...
    'Surrogate pass'};
value={result.model;'No';355;mapperDistance; ...
    outputWidth;superGaussianOrder;targetMeasuredWidth;100*widthError; ...
    exitWave.phaseRms; ...
    targetWave.phaseRms;1e6*exitWave.meanAngle; ...
    1e6*targetWave.meanAngle;1e6*exitWave.rmsAngle; ...
    1e6*targetWave.rmsAngle;targetWave.radius; ...
    1e6*targetEdgeSlope;double(result.pass)};
unit={'-';'-';'nm';'mm';'mm';'-';'mm';'%';'rad';'rad'; ...
    'urad';'urad';'urad';'urad';'mm';'urad';'0/1'};
writetable(table(parameter,value,unit), ...
    fullfile(outputDir,'phase_surrogate_summary.csv'));
writetable(table((1e3*x(:)),Iexit(:),Itarget(:), ...
    'VariableNames',{'x_um','moduleExitIntensity','targetIntensity'}), ...
    fullfile(outputDir,'phase_surrogate_profiles.csv'));

fig=figure('Visible','off','Color','w','Position',[80 80 1100 700]);
subplot(2,1,1)
plot(x,Iexit,'b-',x,Itarget,'r--','LineWidth',1.1); grid on
xlim([-4 4]); ylim([0 1.05]); ylabel('Normalized irradiance')
legend('Surrogate module exit','After CXC telescope / target')
title('Independent two-element phase surrogate (not HOLO/OR proprietary data)')
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

end
