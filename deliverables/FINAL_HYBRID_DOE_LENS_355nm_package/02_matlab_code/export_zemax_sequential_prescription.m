function export_zemax_sequential_prescription()
%EXPORT_ZEMAX_SEQUENTIAL_PRESCRIPTION Export OpticStudio SEQ starting files.
% The ZMX is an OpticStudio 22-compatible sequential prescription.  Both
% complete Grid Phase arrays are embedded in the ZMX; the DAT files are
% retained as human-readable manufacturing/audit companions.

codeDir=fileparts(mfilename('fullpath'));
packageDir=fileparts(codeDir);
zemaxDir=fullfile(packageDir,'06_zemax_sequential');
if ~exist(zemaxDir,'dir'); mkdir(zemaxDir); end

resultFile=fullfile(packageDir,'04_simulation_results','matlab_R2019b', ...
    'final_hybrid_doe_lens_result.mat');
load(resultFile,'result','cfg');
% Manufacturing release setting is taken from the live configuration, not
% from an older optimization MAT file.  This allows the frozen continuous
% phase solution to be requantized without silently retaining a prior level
% count.
releaseCfg=final_hybrid_doe_lens_config();
cfg.doe.quantizationLevels=releaseCfg.doe.quantizationLevels;
cfg.doe.maskCount=releaseCfg.doe.maskCount;
cfg.doe.heightStep=releaseCfg.doe.heightStep;
cfg.doe.maximumReliefHeight=releaseCfg.doe.maximumReliefHeight;
cfg.doe.maskEtchDepths=releaseCfg.doe.maskEtchDepths;
cfg.doe.idealQuantizationEfficiency=releaseCfg.doe.idealQuantizationEfficiency;
% Keep the sequential export convention explicit even when the stored
% optimization result predates this OpticStudio-only coordinate field.
if ~isfield(cfg.doe,'zemaxGridDecenterX')
    cfg.doe.zemaxGridDecenterX=2.5e-3;
end
surfaceA=readtable(fullfile(packageDir,'03_fabrication_data', ...
    'surface_A_relief_cells.csv'));
surfaceB=readtable(fullfile(packageDir,'03_fabrication_data', ...
    'surface_B_relief_cells.csv'));

% Corning HPFS 7980 Sellmeier data at 22 C (lambda in um).
sellA=[0.68374049400 0.42032361300 0.58502748000];
sellB=[0.00460352869 0.01339688560 64.49327320000];
lambdaUm=0.355;
n7980=sqrt(1+sum(sellA.*lambdaUm^2./(lambdaUm^2-sellB)));
nDoe=cfg.doe.refractiveIndex;
ybe2Thickness=cfg.mechanical.ybe2CenterThickness;
doeThickness=cfg.doe.substrateThickness;
zDoeFront=cfg.layout.zHybrid;
zDoeBack=cfg.layout.zHybridBack;
zTarget=cfg.layout.zTarget;

% Plano elements retain the frozen paraxial focal lengths.  Powered-surface
% orientation is selected so the curved face points toward the collimated
% side where practical.  Radius signs follow Zemax left-to-right convention.
R_SBE1=(n7980-1)*(-10);
R_SBE2=-(n7980-1)*(50);       % powered rear surface, glass -> air
R_XRL1=(n7980-1)*(100);       % X cylinder, powered front surface
R_XRL2=(n7980-1)*(65);        % X cylinder, powered rear; negative power
R_YBE1=(n7980-1)*(-20);       % Y cylinder, powered front surface
R_YBE2=-(n7980-1)*cfg.layout.fYBE2; % Y cylinder, powered rear
R_FINAL_Y=-(n7980-1)*cfg.finalYFocalLength; % rear HPFS -> air, Y power
K_FINAL_Y=-n7980^2; % aplanatic cylindrical conic, collimated glass -> air focus
K_YBE2=-(1/n7980)^2; % point in glass -> collimated air Cartesian conic

% Thick-element afocal spacing.  In the reduced ray coordinate [y,n*theta],
% propagation through glass contributes t/n.  These air gaps preserve the
% frozen thin-lens separations f1+f2 without changing any focal power.
gapSbeAir=(-10+50)-(3+4)/n7980;
gapXRelayAir=(100-65)-(4+3)/n7980;
gapYRelayAir=(-20+cfg.layout.fYBE2)-(3+ybe2Thickness)/n7980;
zSbe2Front=33+gapSbeAir; zSbe2Rear=zSbe2Front+4;
zXrl2Front=104+gapXRelayAir; zXrl2Rear=zXrl2Front+3;
zYbe2Front=223+gapYRelayAir; zYbe2Rear=zYbe2Front+ybe2Thickness;

% Surface vertices after converting thin-lens afocal separations to the
% corresponding thick-element reduced distances.
z=[0;30;33;zSbe2Front;zSbe2Rear;100;104;zXrl2Front;zXrl2Rear;220;223; ...
    zYbe2Front;zYbe2Rear; ...
    zDoeFront;zDoeFront;zDoeFront;zDoeBack;cfg.layout.zFinalYFront; ...
    cfg.layout.zFinalYBack;zTarget];
surf=(0:numel(z)-1).';
element={'OBJECT';'SBE1';'SBE1';'SBE2';'SBE2';'XRL1';'XRL1'; ...
    'XRL2';'XRL2';'YBE1';'YBE1';'YBE2';'YBE2';'DOE-IN'; ...
    'DOE-A-X';'DOE-A-Y';'DOE-B'; ...
    'YFL';'YFL';'TARGET'};
role={'Laser waist';'powered front';'plane rear';'plane front'; ...
    'powered rear';'powered front X';'plane rear';'plane front'; ...
    'powered rear X';'powered front Y';'plane rear';'plane front'; ...
    'powered rear Y';'POP reference before DOE'; ...
    'surface A X Grid Phase';'surface A Y Grid Phase (co-located)'; ...
    'surface B X Grid Phase'; ...
    'plane front';'powered rear Y';'target plane'};
type={'STANDARD';'STANDARD';'STANDARD';'STANDARD';'STANDARD'; ...
    'TOROIDAL';'STANDARD';'STANDARD';'TOROIDAL';'TOROIDAL'; ...
    'STANDARD';'STANDARD';'TOROIDAL';'STANDARD';'GRID_PHA';'GRID_PHA'; ...
    'GRID_PHA'; ...
    'STANDARD';'TOROIDAL';'STANDARD'};
radiusX=[Inf;R_SBE1;Inf;Inf;R_SBE2;R_XRL1;Inf;Inf;R_XRL2; ...
    Inf;Inf;Inf;Inf;Inf;Inf;Inf;Inf;Inf;Inf;Inf];
radiusY=[Inf;R_SBE1;Inf;Inf;R_SBE2;Inf;Inf;Inf;Inf;R_YBE1; ...
    Inf;Inf;R_YBE2;Inf;Inf;Inf;Inf;Inf;R_FINAL_Y;Inf];
conic=zeros(20,1);
conic(13)=K_YBE2; % surface 12, YBE2 powered rear
conic(19)=K_FINAL_Y;
clearDiameter=[1.1;4;4;8;8;10;10;10;10;10;10;50;50;50;50;50;50;50;50;3];
thicknessAfter=diff([z;z(end)]);
materialAfter={'AIR';'HPFS7980';'AIR';'HPFS7980';'AIR'; ...
    'HPFS7980';'AIR';'HPFS7980';'AIR';'HPFS7980';'AIR'; ...
    'HPFS7980';'AIR';'AIR';'AIR';'UVFS_DOE';'AIR'; ...
    'HPFS7980';'AIR';'AIR'};
prescription=table(surf,element,role,type,z,radiusX,radiusY,conic, ...
    clearDiameter,thicknessAfter,materialAfter, ...
    'VariableNames',{'Surface','Element','Role','SurfaceType', ...
    'VertexZ_mm','RadiusX_mm','RadiusY_mm','Conic','ClearDiameter_mm', ...
    'ThicknessAfter_mm','MaterialAfter'});
writetable(prescription,fullfile(zemaxDir,'surface_prescription_355nm.csv'));

% Component summary requested for manufacturing review.
component={'SBE1';'SBE2';'XRL1';'XRL2';'YBE1';'YBE2'; ...
    'DOE plate';'Final Y cylinder'};
componentType={'spherical plano-concave';'spherical plano-convex'; ...
    'X cylindrical plano-convex';'X cylindrical plano-concave'; ...
    'Y cylindrical plano-concave';'Y cylindrical plano-convex'; ...
    'plane-parallel double-sided phase plate'; ...
    'independent Y cylindrical plano-convex'};
frontZ=[30;zSbe2Front;100;zXrl2Front;220;zYbe2Front; ...
    zDoeFront;cfg.layout.zFinalYFront];
backZ=[33;zSbe2Rear;104;zXrl2Rear;223;zYbe2Rear;zDoeBack; ...
    cfg.layout.zFinalYBack];
centerThickness=[3;4;4;3;3;ybe2Thickness;doeThickness; ...
    cfg.mechanical.finalYLensCenterThickness];
frontRadiusX=[R_SBE1;Inf;R_XRL1;Inf;Inf;Inf;Inf;Inf];
frontRadiusY=[R_SBE1;Inf;Inf;Inf;R_YBE1;Inf;Inf;Inf];
backRadiusX=[Inf;R_SBE2;Inf;R_XRL2;Inf;Inf;Inf;Inf];
backRadiusY=[Inf;R_SBE2;Inf;Inf;Inf;R_YBE2;Inf;R_FINAL_Y];
backConicY=[0;0;0;0;0;K_YBE2;0;K_FINAL_Y];
diameter=[4;8;10;10;10;50;50;50];
airGapBefore=[30;gapSbeAir;100-zSbe2Rear;gapXRelayAir; ...
    220-zXrl2Rear;gapYRelayAir;zDoeFront-zYbe2Rear; ...
    cfg.mechanical.doeToFinalYLensAirGap];
nominalFocalX=[-10;50;100;-65;Inf;Inf;NaN;Inf];
nominalFocalY=[-10;50;Inf;Inf;-20;cfg.layout.fYBE2; ...
    Inf;cfg.finalYFocalLength];
% Minimum mechanical edge thickness.  For a cylindrical surface this is
% evaluated in the powered meridian at the clear semi-diameter.
sagSBE2=abs(R_SBE2)-sqrt(R_SBE2^2-(diameter(2)/2)^2);
sagXRL1=abs(R_XRL1)-sqrt(R_XRL1^2-(diameter(3)/2)^2);
sagYBE2=abs(R_YBE2)-sqrt(R_YBE2^2-(diameter(6)/2)^2);
cFinalY=1/R_FINAL_Y;
sagFinalY=abs(cFinalY*(diameter(8)/2)^2/(1+sqrt(1- ...
    (1+K_FINAL_Y)*cFinalY^2*(diameter(8)/2)^2)));
minimumEdgeThickness=[centerThickness(1); ...
    centerThickness(2)-sagSBE2; ...
    centerThickness(3)-sagXRL1; ...
    centerThickness(4);centerThickness(5); ...
    centerThickness(6)-sagYBE2;centerThickness(7); ...
    centerThickness(8)-sagFinalY];
material={'HPFS7980';'HPFS7980';'HPFS7980';'HPFS7980'; ...
    'HPFS7980';'HPFS7980';'UVFS_DOE';'HPFS7980'};
writetable(table(component,componentType,frontZ,backZ,centerThickness, ...
    airGapBefore,nominalFocalX,nominalFocalY,frontRadiusX,frontRadiusY, ...
    backRadiusX,backRadiusY,backConicY,diameter,minimumEdgeThickness,material), ...
    fullfile(zemaxDir,'component_prescription_355nm.csv'));

% Combine the existing X mapper with the source-derived Y wavefront
% correction on DOE-A, then quantize the physical combined relief to the
% configured release level count.  DOE-B remains X-only with three repeated
% Y rows.  Reconstruct the stored mapper phase from its own level basis
% before applying the current release quantization.
correctionFile=fullfile(packageDir,'04_simulation_results', ...
    'zemax_POP_from_laser_source','DOE_Y_wavefront_correction.csv');
yGridA=(-25:0.25:25).';
if cfg.model.flatGaussianAtDoe
    correctionY=zeros(size(yGridA));
elseif exist(correctionFile,'file')
    correctionTable=readtable(correctionFile);
    correctionY=interp1(correctionTable.Y_mm, ...
        correctionTable.ConjugatePhase_rad,yGridA,'linear',0);
else
    correctionY=zeros(size(yGridA));
end
levels=cfg.doe.quantizationLevels;
storedLevels=max([double(surfaceA.levelA(:));double(surfaceB.levelB(:))])+1;
xPhaseA=2*pi*double(surfaceA.levelA(:)).'/storedLevels;
xPhaseB=2*pi*double(surfaceB.levelB(:)).'/storedLevels;
% The ZBF proof multiplies the field by exp(+i*correctionY), whereas the
% positive-order Sequential Grid Phase surface uses the opposite optical
% phase sign in the propagated complex field.  Subtraction here makes the
% embedded relief reproduce the verified complex-field conjugation.
phaseAX=repmat(xPhaseA,3,1);
phaseAYVector=2*pi*mod(round(mod(-correctionY,2*pi)/(2*pi)*levels), ...
    levels)/levels;
phaseAY=repmat(phaseAYVector,1,3);
phaseACombined=mod(repmat(xPhaseA,numel(yGridA),1)+ ...
    repmat(phaseAYVector,1,numel(xPhaseA)),2*pi);
phaseBCombined=repmat(xPhaseB,3,1);

% Authoritative fabrication table for the physical DOE-A face.  The X and
% Y computational phase operators are added modulo 16 here, producing one
% physical 2D relief with only the allowed 16 height levels.
combinedLevel=mod(round(phaseACombined/(2*pi)*levels),levels);
[combinedY,combinedX]=ndgrid(yGridA,double(surfaceA.xCellCenter(:)));
combinedHeightUm=1e3*cfg.doe.twoPiReliefDepth/levels*combinedLevel;
mask1=bitget(uint16(combinedLevel),1);
mask2=bitget(uint16(combinedLevel),2);
mask3=bitget(uint16(combinedLevel),3);
mask4=bitget(uint16(combinedLevel),4);
fabricationDir=fullfile(packageDir,'03_fabrication_data');
writetable(table(combinedX(:),combinedY(:),combinedLevel(:), ...
    combinedHeightUm(:),mask1(:),mask2(:),mask3(:),mask4(:), ...
    'VariableNames',{'X_center_mm','Y_center_mm','Level_0_to_15', ...
    'Relief_height_um','Mask_1','Mask_2','Mask_3','Mask_4'}), ...
    fullfile(fabricationDir,'surface_A_combined_2D_16level.csv'));

writeGridPhase(fullfile(zemaxDir,'DOE_surface_A_grid_phase.DAT'), ...
    phaseACombined,0.005,0.25,cfg.doe.zemaxGridDecenterX);
writeGridPhase(fullfile(zemaxDir,'DOE_surface_A_X_grid_phase.DAT'), ...
    phaseAX,0.005,25,cfg.doe.zemaxGridDecenterX);
writeGridPhase(fullfile(zemaxDir,'DOE_surface_A_Y_grid_phase.DAT'), ...
    phaseAY,25,0.25,0);
writeGridPhase(fullfile(zemaxDir,'DOE_surface_B_grid_phase.DAT'), ...
    phaseBCombined,0.005,25,cfg.doe.zemaxGridDecenterX);

% Custom Zemax AGF contains Corning HPFS 7980 and the DOE UVFS substrate.
fid=fopen(fullfile(zemaxDir,'LASER355_CUSTOM.AGF'),'w');
fprintf(fid,'CC 355 nm custom catalog: Corning HPFS 7980 plus DOE UVFS\n');
fprintf(fid,'NM HPFS7980 2 0 1.458461 67.8 0 1 1\n');
fprintf(fid,'GC Corning HPFS 7980 nominal Sellmeier, 22 C\n');
fprintf(fid,'ED 5.5E-1 0 2.20 0 0\n');
fprintf(fid,['CD %.12g %.12g %.12g %.12g %.12g %.12g ' ...
    '0 0 0 0\n'],sellA(1),sellB(1),sellA(2),sellB(2),sellA(3),sellB(3));
fprintf(fid,'LD 0.185 1.13\n');
fprintf(fid,'NM UVFS_DOE 2 0 1.458464 67.821433 0 3 1\n');
fprintf(fid,'GC DOE substrate: Malitson fused-silica model used by MATLAB\n');
fprintf(fid,'ED 5.1E-1 0 2.20 0 0\n');
fprintf(fid,['CD 0.6961663 0.004679148 0.4079426 0.013512063 ' ...
    '0.8974794 97.9340025 0 0 0 0\n']);
fprintf(fid,'LD 0.21 3.71\n');
fclose(fid);

% OpticStudio 22 sequential prescription with both Grid Phase arrays
% embedded directly in the text ZMX.
writeZmx(fullfile(zemaxDir,'final_hybrid_355nm_SEQ_starting_point.ZMX'), ...
    prescription);

% Compact scalar summary for independent checking.
fid=fopen(fullfile(zemaxDir,'index_and_power_check.txt'),'w');
fprintf(fid,'Wavelength = 0.355 um\n');
fprintf(fid,'n_HPFS7980(355 nm, 22 C) = %.12f\n',n7980);
fprintf(fid,'n_UVFS_DOE(355 nm) = %.12f\n',nDoe);
fprintf(fid,'DOE physical thickness = %.6f mm\n',result.plateThickness);
fprintf(fid,'DOE effective propagation thickness t/n = %.12f mm\n', ...
    result.effectiveGlassSeparation);
fprintf(fid,'Final HPFS Y-cylinder radius = %.9f mm; clear semi-diameter = %.6f mm\n', ...
    R_FINAL_Y,cfg.finalYLensClearAperture/2);
cFinalY=1/R_FINAL_Y;
sag=abs(cFinalY*(cfg.finalYLensClearAperture/2)^2/(1+sqrt(1- ...
    (1+K_FINAL_Y)*cFinalY^2*(cfg.finalYLensClearAperture/2)^2)));
fprintf(fid,['Final Y-cylinder edge sag = %.9f mm; ' ...
    'minimum edge thickness = %.9f mm\n'],sag, ...
    cfg.mechanical.finalYLensCenterThickness-sag);
fprintf(fid,'DOE-to-final-cylinder air gap = %.6f mm\n', ...
    cfg.mechanical.doeToFinalYLensAirGap);
fprintf(fid,['Target Z = %.6f mm; air working distance after final ' ...
    'Y cylinder = %.6f mm\n'], ...
    result.zTarget,result.targetDistance);
fclose(fid);

    function writeGridPhase(fileName,phase,deltaX,deltaY,xDecenter)
        [numberY,numberX]=size(phase);
        gridFid=fopen(fileName,'w');
        % OpticStudio 2022 R2.02 requires the numeric header to be the
        % first line; leading comment lines prevent the DAT being listed.
        fprintf(gridFid,'%d %d %.12g %.12g %.12g 0 0\n', ...
            numberX,numberY,deltaX,deltaY,xDecenter);
        for rowIndex=1:numberY
            for phaseIndex=1:numberX
                fprintf(gridFid,'%.12g 0 0 0 0\n', ...
                    phase(rowIndex,phaseIndex));
            end
        end
        fclose(gridFid);
    end

    function writeZmx(fileName,p)
        zmx=fopen(fileName,'w');
        fprintf(zmx,'VERS 221026 429 20120530 20120530\n');
        fprintf(zmx,'MODE SEQ\nNAME 355nm HYBRID DOE LINE BEAM STARTING POINT\n');
        fprintf(zmx,'AUTH OpenAI Codex - engineering starting prescription\n');
        fprintf(zmx,['NOTE 0 PRE-DOE REF=S13; PHYSICAL DOE-A IS ' ...
            'CO-LOCATED S14(X)+S15(Y); DOE-B=S16\n']);
        fprintf(zmx,'UNIT MM X W X CM MR CPMM\nENPD 1.1\n');
        fprintf(zmx,'GCAT LASER355_CUSTOM\n');
        fprintf(zmx,'FTYP 0 0 1 1 0 0 0 1\n');
        fprintf(zmx,'XFLN 0\nYFLN 0\nFWGN 1\nVDXN 0\nVDYN 0\n');
        fprintf(zmx,'VCXN 0\nVCYN 0\nVANN 0\nWAVM 1 0.355 1\nPWAV 1\n');
        fprintf(zmx,'POLS 1 0 1 0 0 1 0\n');
        for si=1:height(p)
            fprintf(zmx,'SURF %d\n  SSID %d\n  COMM %s - %s\n', ...
                p.Surface(si),p.Surface(si),p.Element{si},p.Role{si});
            fprintf(zmx,'  TYPE %s\n  FIMP \n\n',p.SurfaceType{si});
            if strcmp(p.SurfaceType{si},'TOROIDAL')
                if isfinite(p.RadiusY_mm(si))
                    fprintf(zmx,'  CURV %.16g 0 0 0 0 ""\n',1/p.RadiusY_mm(si));
                else
                    fprintf(zmx,'  CURV 0 0 0 0 0 ""\n');
                end
                if isfinite(p.RadiusX_mm(si))
                    fprintf(zmx,'  PARM 1 %.16g\n',p.RadiusX_mm(si));
                else
                    fprintf(zmx,'  PARM 1 0\n');
                end
                if p.Conic(si)~=0
                    fprintf(zmx,'  CONI %.16g\n',p.Conic(si));
                end
            else
                if isfinite(p.RadiusX_mm(si)) && ...
                        strcmp(p.SurfaceType{si},'STANDARD')
                    fprintf(zmx,'  CURV %.16g 0 0 0 0 ""\n',1/p.RadiusX_mm(si));
                else
                    fprintf(zmx,'  CURV 0 0 0 0 0 ""\n');
                end
            end
            if strcmp(p.SurfaceType{si},'GRID_PHA')
                fprintf(zmx,'  PARM 0 1\n  PARM 1 0\n  PARM 2 2\n');
                if p.Surface(si)==14
                    gridPhase=phaseAX; deltaX=0.005; deltaY=25;
                    xDecenter=cfg.doe.zemaxGridDecenterX;
                elseif p.Surface(si)==15
                    gridPhase=phaseAY; deltaX=25; deltaY=0.25;
                    xDecenter=0;
                else
                    gridPhase=phaseBCombined; deltaX=0.005; deltaY=25;
                    xDecenter=cfg.doe.zemaxGridDecenterX;
                end
                [numberY,numberX]=size(gridPhase);
                % Embed the complete phase grid directly.  OpticStudio
                % 2022 R2's ImportDataFile API can silently retain its
                % default 3x3 zero grid; explicit GDAT/GARR records avoid
                % that failure mode and remain editable in Sequential mode.
                fprintf(zmx,'  GDAT %d %d %.12g %.12g %.12g 0\n', ...
                    numberX,numberY,deltaX,deltaY,xDecenter);
                arrayIndex=0;
                for yRow=1:numberY
                    for phaseIndex=1:numberX
                        fprintf(zmx,'  GARR %d %.12g 0 0 0 0\n', ...
                            arrayIndex,gridPhase(yRow,phaseIndex));
                        arrayIndex=arrayIndex+1;
                    end
                end
            end
            fprintf(zmx,'  DISZ %.16g\n',p.ThicknessAfter_mm(si));
            if ~strcmp(p.MaterialAfter{si},'AIR')
                fprintf(zmx,'  GLAS %s 0 0 0 0 0 0 0 0 0 0\n', ...
                    p.MaterialAfter{si});
            end
            % The second DIAM field is 1 for a fixed user semi-diameter.
            % This prevents OpticStudio from auto-expanding the mechanical
            % drawing well beyond the specified clear aperture.
            fprintf(zmx,'  DIAM %.16g 1 0 0 1 ""\n',p.ClearDiameter_mm(si)/2);
            fprintf(zmx,'  MEMA %.16g 0 0 0 1 ""\n',p.ClearDiameter_mm(si)/2);
            fprintf(zmx,['  POPS 0 0 0 0 0 0 0 0 1 1 1 1 ' ...
                '0 0 0 0\n']);
        end
        fprintf(zmx,'DMFS 0 0 0 0 0 0 0 0 0 0\n');
        fprintf(zmx,'BLNK Surface 13 is the zero-thickness pre-DOE POP reference.\n');
        fprintf(zmx,'BLNK S14+S15 are one physical DOE-A relief, split only for POP.\n');
        fprintf(zmx,'BLNK Import DOE_surface_A_X_grid_phase.DAT on surface 14.\n');
        fprintf(zmx,'BLNK Import DOE_surface_A_Y_grid_phase.DAT on surface 15.\n');
        fprintf(zmx,'BLNK Import DOE_surface_B_grid_phase.DAT on surface 16.\n');
        fprintf(zmx,'BLNK Set Grid Phase interpolation to Pixelated and order +1.\n');
        fclose(zmx);
    end
end
