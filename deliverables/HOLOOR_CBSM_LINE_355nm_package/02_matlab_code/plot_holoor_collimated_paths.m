function plot_holoor_collimated_paths(cfg,outputDir)
%PLOT_HOLOOR_COLLIMATED_PATHS Draw XZ and YZ layouts for the selected train.
p=cfg.layout;
ids={'LASER';'SBE1';'SBE2';'CBSM1';'CBSM2';'YBE1';'YBE2'; ...
    'CXC1';'CXC2';'YFL';'TARGET'};
z=[p.zLaser;p.zSBE1;p.zSBE2;p.zCBSM1;p.zCBSM2;p.zYBE1;p.zYBE2; ...
    p.zCXC1;p.zCXC2;p.zYFL;p.zTarget];
axisPower={'-';'XY';'XY';'X phase';'X phase';'Y';'Y';'X';'X';'Y';'-'};
fX=[Inf;p.fSBE1;p.fSBE2;Inf;Inf;Inf;Inf;p.fXC1;p.fXC2;Inf;Inf];
fY=[Inf;p.fSBE1;p.fSBE2;Inf;Inf;p.fYBE1;p.fYBE2;Inf;Inf;p.fYFL;Inf];
description={'355 nm laser';'First optic: spherical negative expander'; ...
    'Spherical positive expander';'Custom HOLO/OR collimated-line module DOE 1'; ...
    'Custom module phase-flattening DOE 2';'Y-only negative cylinder'; ...
    'Y-only positive cylinder';'X-only positive compressor cylinder'; ...
    'X-only negative compressor cylinder'; ...
    'Last lens: Y-only fY=100 mm; zero X power'; ...
    'X approx. collimated 1.5 mm; Y focused 1.0 um'};
writetable(table(ids,z,axisPower,fX,fY,description), ...
    fullfile(outputDir,'holoor_collimated_optical_layout.csv'));

% X geometric envelope: 1 -> 6 mm, custom module maintains 6 mm,
% afocal CXC compresses 6 -> 1.5 mm, YFL leaves X unchanged.
[z1,r1]=constantSegment(0,p.zSBE1,cfg.laserDiameter/2);
[z2,r2]=linearSegment(p.zSBE1,p.zSBE2,cfg.laserDiameter/2,cfg.conditionedDiameter/2);
[z3,r3]=constantSegment(p.zSBE2,p.zCXC1,cfg.moduleOutputXWidth/2);
[z4,r4]=linearSegment(p.zCXC1,p.zCXC2,cfg.moduleOutputXWidth/2,cfg.targetXWidth/2);
[z5,r5]=constantSegment(p.zCXC2,p.zTarget,cfg.targetXWidth/2);
zx=[z1 z2(2:end) z3(2:end) z4(2:end) z5(2:end)];
rx=[r1 r2(2:end) r3(2:end) r4(2:end) r5(2:end)];
drawPath(zx,rx,'X',ids,z,axisPower, ...
    'HOLO/OR custom collimated line - XZ optical layout', ...
    fullfile(outputDir,'holoor_collimated_xz_optical_path.png'), ...
    sprintf(['CXC1/CXC2: fX=+160/-40 mm, separation=120 mm, afocal 4x compression\n' ...
    'YFL at Z=600 mm: Y-only, X optical power=0\n' ...
    'Target: X geometric width=1.5 mm, parallel marginal rays']));

% Y geometric envelope.
[y1,q1]=constantSegment(0,p.zSBE1,cfg.laserDiameter/2);
[y2,q2]=linearSegment(p.zSBE1,p.zSBE2,cfg.laserDiameter/2,cfg.conditionedDiameter/2);
[y3,q3]=constantSegment(p.zSBE2,p.zYBE1,cfg.conditionedDiameter/2);
[y4,q4]=linearSegment(p.zYBE1,p.zYBE2,cfg.conditionedDiameter/2,cfg.finalYBeamDiameter/2);
[y5,q5]=constantSegment(p.zYBE2,p.zYFL,cfg.finalYBeamDiameter/2);
y6=linspace(p.zYFL,p.zTarget,180);
q6=(cfg.finalYBeamDiameter/2)+(cfg.targetYWidth/2-cfg.finalYBeamDiameter/2)* ...
    (y6-p.zYFL)/(p.zTarget-p.zYFL);
zy=[y1 y2(2:end) y3(2:end) y4(2:end) y5(2:end) y6(2:end)];
ry=[q1 q2(2:end) q3(2:end) q4(2:end) q5(2:end) q6(2:end)];
drawPath(zy,ry,'Y',ids,z,axisPower, ...
    'HOLO/OR custom collimated line - YZ optical layout', ...
    fullfile(outputDir,'holoor_collimated_yz_optical_path.png'), ...
    sprintf(['YBE1/YBE2: fY=%.1f/%.1f mm, %.3fx expansion\n' ...
    'YFL: fY=100 mm, input D_Y=%.2f mm, suggested CA>=%.2f mm\n' ...
    'CBSM and CXC have no Y optical power'],p.fYBE1,p.fYBE2,p.mY, ...
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
end

