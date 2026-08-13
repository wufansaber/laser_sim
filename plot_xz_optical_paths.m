function layoutTable = plot_xz_optical_paths(cfg,vendor,inhouse,outputDir)
%PLOT_XZ_OPTICAL_PATHS Annotated physical XZ paths with spherical expanders.
layouts={makeLayout(vendor,'Vendor'),makeLayout(inhouse,'In-house')};
drawSingle(layouts{1},'Vendor ST-426-I-Y-A - XZ optical layout', ...
    fullfile(outputDir,'vendor_xz_optical_path.png'));
drawSingle(layouts{2},'In-house two-DOE collimated mapper - XZ optical layout', ...
    fullfile(outputDir,'inhouse_xz_optical_path.png'));
fig=figure('Visible','off','Color','w','Position',[50 50 1550 900]);
subplot(2,1,1); drawAxes(layouts{1}); title('Vendor ST-426-I-Y-A - XZ plane')
subplot(2,1,2); drawAxes(layouts{2}); title('In-house two-DOE collimated mapper - XZ plane')
print(fig,fullfile(outputDir,'two_solution_xz_optical_paths.png'),'-dpng','-r180');
close(fig)
layoutTable=[layouts{1}.table;layouts{2}.table];
writetable(layoutTable,fullfile(outputDir,'xz_optical_layout.csv'));

    function L=makeLayout(solution,solutionName)
        p=cfg.layout;
        if isfield(solution,'collimated')
            zVerification=p.zTarget+50;
            z=[p.zLaser p.zExpander1L1 p.zExpander1L2 ...
                p.zExpander2L1 p.zExpander2L2 p.zInhouseDOE1 ...
                p.zFinalLens p.zTarget zVerification];
            ids={'LASER';'SBE1';'SBE2';'YBE1';'YBE2';'DOE1'; ...
                'YFL';'DOE2/OUT';'VERIFY'};
            axisPower={'-';'XY';'XY';'Y';'Y';'X phase';'Y';'X phase';'-'};
            focalX=[Inf p.fExpander1L1 p.fExpander1L2 Inf Inf Inf Inf Inf Inf];
            description={'355 nm laser';'First optic: spherical negative expander lens'; ...
                'Spherical positive expander lens'; ...
                'Y-only negative cylindrical expander lens'; ...
                'Y-only positive cylindrical expander lens'; ...
                'Inverse-designed X phase DOE'; ...
                'Y-only f=100 mm focusing cylinder'; ...
                'X phase corrector: flat-wavefront output plane'; ...
                '50 mm post-output diffraction verification plane'};
        else
            z=[p.zLaser p.zExpander1L1 p.zExpander1L2 p.zDOE ...
                p.zExpander2L1 p.zExpander2L2 p.zXCompressorL1 ...
                solution.xCompressorL2Z p.zXFinalLens p.zFinalLens p.zTarget];
            ids={'LASER';'SBE1';'SBE2';'DOE';'YBE1';'YBE2'; ...
                'CXC1';'CXC2';'XFL';'YFL';'TARGET'};
            axisPower={'-';'XY';'XY';'X phase';'Y';'Y';'X';'X';'X';'Y';'-'};
            focalX=[Inf p.fExpander1L1 p.fExpander1L2 Inf ...
                Inf Inf solution.relayF1 ...
                solution.relayF2 cfg.finalXFocalLength Inf Inf];
            description={'355 nm laser';'First optic: spherical negative expander lens'; ...
                'Spherical positive expander lens';'Line phase DOE'; ...
                'Y-only negative cylindrical expander lens'; ...
                'Y-only positive cylindrical expander lens'; ...
                'X-only positive angular compressor cylinder'; ...
                'X-only negative angular compressor cylinder'; ...
                'X-only Fourier cylinder, fX=110 mm'; ...
                'Last lens: Y-only cylinder, zero X optical power'; ...
                'Focal line target; phase unavailable'};
        end

        % Central-beam aperture envelope. The X cylinder telescope compresses
        % the expanded beam while increasing the DOE angular distribution.
        d0=cfg.laserDiameter; d1=cfg.doeBeamDiameter; d2=cfg.finalYBeamDiameter;
        zA=linspace(0,p.zExpander1L1,50); rA=d0/2*ones(size(zA));
        [zB,rB]=linearSegment(p.zExpander1L1,p.zExpander1L2,d0/2,d1/2);
        zC=linspace(p.zExpander1L2,p.zExpander2L1,100); rC=d1/2*ones(size(zC));
        [zD,rD]=linearSegment(p.zExpander2L1,p.zExpander2L2,d1/2,d1/2);
        if isfield(solution,'collimated')
            zE=linspace(p.zExpander2L2,p.zInhouseDOE1,60); rE=d1/2*ones(size(zE));
            zF=linspace(p.zInhouseDOE1,p.zTarget,150);
            rF=d1/2+(cfg.targetXWidth/2-d1/2)* ...
                (zF-p.zInhouseDOE1)/(p.zTarget-p.zInhouseDOE1);
            zG=linspace(p.zTarget,zVerification,80);
            rG=(cfg.targetXWidth/2)*ones(size(zG));
            rAfter=cfg.targetXWidth/2;
        else
            zE=linspace(p.zExpander2L2,p.zXCompressorL1,70); rE=d1/2*ones(size(zE));
            rAfter=(d1/2)/solution.xAngularGain;
            [zF,rF]=linearSegment(p.zXCompressorL1,solution.xCompressorL2Z,d1/2,rAfter);
            zG=linspace(solution.xCompressorL2Z,p.zXFinalLens,50); rG=rAfter*ones(size(zG));
        end
        if isfield(solution,'collimated')
            zH=[]; rH=[];
        else
            zH=linspace(p.zXFinalLens,p.zTarget,120);
            rH=rAfter+(cfg.targetXWidth/2-rAfter)*(zH-p.zXFinalLens)/cfg.finalXFocalLength;
        end
        L.z=[zA zB(2:end) zC(2:end) zD(2:end) zE(2:end) zF zG zH(2:end)];
        L.r=[rA rB(2:end) rC(2:end) rD(2:end) rE(2:end) rF rG rH(2:end)];
        L.zComponents=z; L.ids=ids; L.axisPower=axisPower;
        L.zTarget=p.zTarget; L.zPlotEnd=max(z); L.solution=solution;
        L.table=table(repmat({solutionName},numel(z),1),ids(:),z(:), ...
            axisPower,focalX(:),description, ...
            'VariableNames',{'solution','elementID','z_mm','powerAxis', ...
            'focalLengthX_mm','description'});
    end

    function drawSingle(L,titleText,fileName)
        fig=figure('Visible','off','Color','w','Position',[30 30 1700 760]);
        drawAxes(L); title(titleText)
        print(fig,fileName,'-dpng','-r180'); close(fig)
    end

    function drawAxes(L)
        fill([L.z fliplr(L.z)],[L.r -fliplr(L.r)],[1 0.88 0.78], ...
            'EdgeColor','none'); hold on
        plot(L.z,L.r,'r-','LineWidth',1.8); plot(L.z,-L.r,'r-','LineWidth',1.8)
        plot([0 L.zPlotEnd],[0 0],'k--','LineWidth',0.8)
        ymax=1.12*max(L.r);
        for ii=1:numel(L.zComponents)
            isYOnly=strcmp(L.axisPower{ii},'Y');
            style='k-'; if isYOnly; style='k:'; end
            lw=1; if strcmp(L.ids{ii},'TARGET'); lw=2.3; end
            plot([L.zComponents(ii) L.zComponents(ii)],[-ymax ymax],style,'LineWidth',lw)
            text(L.zComponents(ii),1.02*ymax,sprintf('%s\nZ=%.1f', ...
                L.ids{ii},L.zComponents(ii)),'Rotation',35,'FontSize',7.3)
        end
        s=L.solution;
        if isfield(s,'collimated')
            info=sprintf(['SBE1/SBE2 spherical 6x, equal X/Y power\n' ...
                'YBE1/YBE2 and YFL act only in Y; X stays near 6 mm\n' ...
                'DOE1/DOE2 form 1.5 mm X and cancel terminal X phase\n' ...
                'RMS terminal X angle <=10 urad']);
        else
            info=sprintf(['Only SBE1/SBE2 are spherical, equal X/Y power\n' ...
                'CXC1 f=%.2f mm, CXC2 f=%.2f mm, X angular gain=%.3fx\n' ...
                'XFL fX=110 mm at Z=590; last YFL has zero X power\n' ...
                'Vendor model supplies focal intensity only'], ...
                s.relayF1,s.relayF2,s.xAngularGain);
        end
        text(15,-0.90*ymax,info,'FontSize',7.8,'BackgroundColor','w', ...
            'EdgeColor',[0.5 0.5 0.5])
        if isfield(L.solution,'collimated')
            terminalText=sprintf('DOE2 exit: X=%.4f mm, flat wavefront; diffraction follows', ...
                L.solution.collimated.metricsAtTarget.widthE2);
        else
            terminalText='X=1.5 mm focal Top-Hat; phase not provided';
        end
        text(L.zPlotEnd,-0.14*ymax,terminalText, ...
            'HorizontalAlignment','right','FontWeight','bold')
        xlabel('Optical-axis position Z (mm)'); ylabel('X (mm)'); grid on
        xlim([0 1.025*L.zPlotEnd]); ylim([-1.32*ymax 1.32*ymax])
    end

    function [z,r]=linearSegment(z1,z2,r1,r2)
        z=linspace(z1,z2,120); r=r1+(r2-r1)*(z-z1)/(z2-z1);
    end
end
