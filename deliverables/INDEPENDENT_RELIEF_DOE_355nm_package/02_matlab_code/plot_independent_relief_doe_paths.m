function plot_independent_relief_doe_paths(cfg,outputDir)
%PLOT_INDEPENDENT_RELIEF_DOE_PATHS Draw XZ and YZ layouts.
p=cfg.layout;
ids={'LASER';'SBE1';'SBE2';'DOE1';'DOE2';'YBE1';'YBE2';'YFL';'TARGET'};
z=[p.zLaser;p.zSBE1;p.zSBE2;p.zDOE1;p.zDOE2;p.zYBE1;p.zYBE2; ...
    p.zYFL;p.zTarget];
axisPower={'-';'XY';'XY';'X phase';'X phase';'Y';'Y';'Y';'-'};
fX=[Inf;p.fSBE1;p.fSBE2;Inf;Inf;Inf;Inf;Inf;Inf];
fY=[Inf;p.fSBE1;p.fSBE2;Inf;Inf;p.fYBE1;p.fYBE2;p.fYFL;Inf];
description={sprintf(['355 nm fully coherent CW waist; Dx=%.4f mm, ' ...
    'Dy=%.4f mm, M2x=%.3f, M2y=%.3f'],cfg.laser.waistDiameterX, ...
    cfg.laser.waistDiameterY,cfg.laser.M2X,cfg.laser.M2Y); ...
    'First optic: spherical negative expander'; ...
    'Spherical positive expander';'Independent relief DOE 1: energy mapping'; ...
    'Independent relief DOE 2: phase flattening';'Y-only negative cylinder'; ...
    'Y-only positive cylinder'; ...
    'Last lens: Y-only fY=100 mm; zero X power'; ...
    'X approx. collimated 1.5 mm; Y focused 1.0 um'};
writetable(table(ids,z,axisPower,fX,fY,description), ...
    fullfile(outputDir,'independent_relief_doe_optical_layout.csv'));

% X envelope: measured-M2 Gaussian q propagation from the laser waist
% through the spherical expander, followed by the shaped-line envelope.
qx=1i*pi*cfg.laser.waistRadiusX^2/(cfg.laser.M2X*cfg.lambda);
[z1,r1,qx]=qSegment(qx,p.zLaser,p.zSBE1,cfg.laser.M2X);
qx=applyQLens(qx,p.fSBE1);
[z2,r2,qx]=qSegment(qx,p.zSBE1,p.zSBE2,cfg.laser.M2X);
qx=applyQLens(qx,p.fSBE2);
[z2b,r2b,qx]=qSegment(qx,p.zSBE2,p.zDOE1,cfg.laser.M2X);
[z3,r3]=linearSegment(p.zDOE1,p.zDOE2,r2b(end),cfg.targetXWidth/2);
[z4,r4]=constantSegment(p.zDOE2,p.zTarget,cfg.targetXWidth/2);
zx=[z1 z2(2:end) z2b(2:end) z3(2:end) z4(2:end)];
rx=[r1 r2(2:end) r2b(2:end) r3(2:end) r4(2:end)];
drawPath(zx,rx,'X',ids,z,axisPower, ...
    'Independent relief DOE line shaper - XZ optical layout', ...
    fullfile(outputDir,'independent_relief_doe_xz_optical_path.png'), ...
    sprintf(['First spherical expander: %.2fx (allowed 5-10x)\n' ...
    'DOE1-DOE2: %.1f mm free space; no intermediate optic\n' ...
    'All downstream lenses are Y-only; target X=1.5 mm, approximately collimated'], ...
    cfg.beamExpanderMagnification,p.zDOE2-p.zDOE1));

% Y measured-M2 Gaussian q envelope through every powered Y surface.
qy=1i*pi*cfg.laser.waistRadiusY^2/(cfg.laser.M2Y*cfg.lambda);
[y1,q1,qy]=qSegment(qy,p.zLaser,p.zSBE1,cfg.laser.M2Y);
qy=applyQLens(qy,p.fSBE1);
[y2,q2,qy]=qSegment(qy,p.zSBE1,p.zSBE2,cfg.laser.M2Y);
qy=applyQLens(qy,p.fSBE2);
[y3,q3,qy]=qSegment(qy,p.zSBE2,p.zYBE1,cfg.laser.M2Y);
qy=applyQLens(qy,p.fYBE1);
[y4,q4,qy]=qSegment(qy,p.zYBE1,p.zYBE2,cfg.laser.M2Y);
qy=applyQLens(qy,p.fYBE2);
[y5,q5,qy]=qSegment(qy,p.zYBE2,p.zYFL,cfg.laser.M2Y);
qy=applyQLens(qy,p.fYFL);
[y6,q6,qy]=qSegment(qy,p.zYFL,p.zTarget,cfg.laser.M2Y); %#ok<ASGLU>
zy=[y1 y2(2:end) y3(2:end) y4(2:end) y5(2:end) y6(2:end)];
ry=[q1 q2(2:end) q3(2:end) q4(2:end) q5(2:end) q6(2:end)];
drawPath(zy,ry,'Y',ids,z,axisPower, ...
    'Independent relief DOE line shaper - YZ optical layout', ...
    fullfile(outputDir,'independent_relief_doe_yz_optical_path.png'), ...
    sprintf(['YBE1/YBE2: fY=%.1f/%.1f mm, %.3fx expansion\n' ...
    'YFL: fY=100 mm, input D_Y=%.2f mm, suggested CA>=%.2f mm\n' ...
    'DOE surfaces have no Y optical power'],p.fYBE1,p.fYBE2,p.mY, ...
    cfg.finalYBeamDiameter,cfg.finalYLensClearAperture));

    function drawPath(zp,rp,plane,elementIds,elementZ,powerAxis,titleText,fileName,info)
        fig=figure('Visible','off','Color','w','Position',[30 30 1700 760]);
        if strcmp(plane,'X'); color=[1 0.88 0.78]; edge='r'; else; color=[0.82 0.91 1]; edge='b'; end
        fill([zp fliplr(zp)],[rp -fliplr(rp)],color,'EdgeColor','none'); hold on
        plot(zp,rp,[edge '-'],'LineWidth',1.8); plot(zp,-rp,[edge '-'],'LineWidth',1.8)
        plot([0 p.zTarget],[0 0],'k--','LineWidth',0.8)
        ymax=1.12*max(rp);
        for ii=1:numel(elementZ)
            noPower=(strcmp(plane,'X') && strcmp(powerAxis{ii},'Y')) || ...
                (strcmp(plane,'Y') && (strcmp(powerAxis{ii},'X') || strcmp(powerAxis{ii},'X phase')));
            style='k-'; if noPower; style='k:'; end
            lw=1; if strcmp(elementIds{ii},'TARGET'); lw=2.3; end
            plot([elementZ(ii) elementZ(ii)],[-ymax ymax],style,'LineWidth',lw)
            text(elementZ(ii),1.02*ymax,sprintf('%s\nZ=%.1f',elementIds{ii},elementZ(ii)), ...
                'Rotation',35,'FontSize',7.3)
        end
        text(15,-0.90*ymax,info,'FontSize',7.8,'BackgroundColor','w','EdgeColor',[0.5 0.5 0.5])
        if strcmp(plane,'X'); terminal='X=1.5 mm approximately collimated Top-Hat'; ...
        else; terminal='Y full 1/e^2 = 1.0 um focus'; end
        text(p.zTarget,-0.14*ymax,terminal,'HorizontalAlignment','right','FontWeight','bold')
        title(titleText); xlabel('Optical-axis position Z (mm)'); ylabel([plane ' (mm)']); grid on
        xlim([0 1.025*p.zTarget]); ylim([-1.32*ymax 1.32*ymax])
        print(fig,fileName,'-dpng','-r180'); close(fig)
    end
    function [zz,rr]=constantSegment(a,b,radius)
        zz=linspace(a,b,80); rr=radius*ones(size(zz));
    end
    function [zz,rr]=linearSegment(a,b,ra,rb)
        zz=linspace(a,b,120); rr=ra+(rb-ra)*(zz-a)/(b-a);
    end
    function [zz,rr,qEnd]=qSegment(qStart,a,b,m2)
        zz=linspace(a,b,160);
        qAlong=qStart+(zz-a);
        inverseQ=1./qAlong;
        rr=sqrt(-m2*cfg.lambda./(pi*imag(inverseQ)));
        qEnd=qStart+(b-a);
    end
    function qOut=applyQLens(qIn,f)
        qOut=1/(1/qIn-1/f);
    end
end
