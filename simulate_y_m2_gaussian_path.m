function result = simulate_y_m2_gaussian_path(cfg, outputDir)
%SIMULATE_Y_M2_GAUSSIAN_PATH Second-moment M2 propagation in the Y plane.
% This complements the coherent X diffraction calculation.  The measured
% waist, M2Y and every powered Y optic are propagated with the generalized
% Gaussian q parameter.  It verifies rather than assumes the YFL waist
% position and 1/e^2 focus width.
if ~exist(outputDir,'dir'); mkdir(outputDir); end
p=cfg.layout;
lambda=cfg.lambda;
m2=cfg.laser.M2Y;
w0=cfg.laser.waistRadiusY;
q=1i*pi*w0^2/(m2*lambda);
z=p.zLaser;

stage={}; zRecord=[]; diameter=[]; radius=[];
record('LASER waist');
propagateTo(p.zSBE1); record('SBE1 before'); applyLens(p.fSBE1);
propagateTo(p.zSBE2); record('SBE2 before'); applyLens(p.fSBE2);
propagateTo(p.zCBSM1); record('CBSM1 input');
propagateTo(p.zYBE1); record('YBE1 before'); applyLens(p.fYBE1);
propagateTo(p.zYBE2); record('YBE2 before'); applyLens(p.fYBE2);
propagateTo(p.zYFL); record('YFL before');
qBeforeYFL=q;
applyLens(p.fYFL);
qAfterYFL=q;
propagateTo(p.zTarget); record('TARGET');

targetDiameter=diameter(end);
waistDistance=-real(qAfterYFL);
waistDiameter=2*sqrt(m2*lambda*imag(qAfterYFL)/pi);
widthError=abs(targetDiameter-cfg.targetYWidth)/cfg.targetYWidth;
distanceError=abs(waistDistance-(p.zTarget-p.zYFL));
result.pass=widthError<=0.01 && distanceError<=0.1;
result.targetDiameter=targetDiameter;
result.waistDiameter=waistDiameter;
result.waistDistanceFromYFL=waistDistance;
result.widthError=widthError;
result.distanceError=distanceError;
result.qBeforeYFL=qBeforeYFL;
result.qAfterYFL=qAfterYFL;

writetable(table(stage(:),zRecord(:),diameter(:),radius(:), ...
    'VariableNames',{'stage','z_mm','full1e2Diameter_mm', ...
    'wavefrontRadius_mm'}),fullfile(outputDir,'laser_y_m2_path.csv'));
parameter={'Coherence';'Waist Y diameter';'M2Y';'Y full divergence'; ...
    'Y Rayleigh range';'YFL incident diameter';'YFL wavefront radius'; ...
    'Calculated waist distance after YFL';'Calculated waist diameter'; ...
    'Target-plane diameter';'Target width error';'Waist distance error'; ...
    'Y model pass'};
value={cfg.laser.coherence;cfg.laser.waistDiameterY;m2; ...
    1e3*cfg.laser.divergenceFullAngleY;cfg.laser.rayleighRangeY; ...
    beamDiameter(qBeforeYFL);wavefrontRadius(qBeforeYFL); ...
    waistDistance;waistDiameter;targetDiameter;100*widthError; ...
    distanceError;double(result.pass)};
unit={'-';'mm';'-';'mrad full angle';'mm';'mm';'mm';'mm';'mm'; ...
    'mm';'%';'mm';'0/1'};
writetable(table(parameter,value,unit), ...
    fullfile(outputDir,'laser_y_m2_summary.csv'));

    function propagateTo(zNext)
        q=q+(zNext-z);
        z=zNext;
    end

    function applyLens(f)
        q=1/(1/q-1/f);
    end

    function record(name)
        stage{end+1,1}=name;
        zRecord(end+1,1)=z;
        diameter(end+1,1)=beamDiameter(q);
        radius(end+1,1)=wavefrontRadius(q);
    end

    function d=beamDiameter(qValue)
        inverseQ=1/qValue;
        d=2*sqrt(-m2*lambda/(pi*imag(inverseQ)));
    end

    function r=wavefrontRadius(qValue)
        inverseQ=1/qValue;
        if abs(real(inverseQ))<1e-15
            r=Inf;
        else
            r=1/real(inverseQ);
        end
    end
end
