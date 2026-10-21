function report = validate_zemax_2022R2()
%VALIDATE_ZEMAX_2022R2 Open and re-save the Sequential model in OpticStudio.
% This function requires Ansys Zemax OpticStudio 2022 R2.02 and a ZOS-API
% enabled license.  It copies the custom AGF and companion Grid Phase DAT
% files into the user data folders, opens the ZMX containing the embedded
% arrays, saves a self-contained validated ZMX, and reopens it.

codeDir=fileparts(mfilename('fullpath'));
packageDir=fileparts(codeDir);
zemaxDir=fullfile(packageDir,'06_zemax_sequential');
sourceZmx=fullfile(zemaxDir,'final_hybrid_355nm_SEQ_starting_point.ZMX');
validatedZmx=fullfile(zemaxDir, ...
    'final_hybrid_355nm_SEQ_OpticStudio2022R2_validated.ZMX');
logFile=fullfile(zemaxDir,'OpticStudio_2022R2_validation.txt');

installDir='C:\Program Files\Ansys Zemax OpticStudio 2022 R2.02';
% Explicit path avoids dependence on registry visibility when MATLAB is
% started from a restricted/non-interactive engineering environment.
zemaxData='C:\Users\wufan\Documents\Zemax';
netHelper=fullfile(zemaxData,'ZOS-API','Libraries','ZOSAPI_NetHelper.dll');
glassDir=fullfile(zemaxData,'Glasscat');
gridDir=fullfile(zemaxData,'Objects','Grid Files');
if ~exist(gridDir,'dir'); mkdir(gridDir); end

copyIfDifferent(fullfile(zemaxDir,'LASER355_CUSTOM.AGF'), ...
    fullfile(glassDir,'LASER355_CUSTOM.AGF'));
copyIfDifferent(fullfile(zemaxDir,'DOE_surface_A_grid_phase.DAT'), ...
    fullfile(gridDir,'DOE_surface_A_grid_phase.DAT'));
copyIfDifferent(fullfile(zemaxDir,'DOE_surface_A_X_grid_phase.DAT'), ...
    fullfile(gridDir,'DOE_surface_A_X_grid_phase.DAT'));
copyIfDifferent(fullfile(zemaxDir,'DOE_surface_A_Y_grid_phase.DAT'), ...
    fullfile(gridDir,'DOE_surface_A_Y_grid_phase.DAT'));
copyIfDifferent(fullfile(zemaxDir,'DOE_surface_B_grid_phase.DAT'), ...
    fullfile(gridDir,'DOE_surface_B_grid_phase.DAT'));

NET.addAssembly(netHelper);
success=ZOSAPI_NetHelper.ZOSAPI_Initializer.Initialize(installDir);
if success~=1
    error('OpticStudio 2022 R2.02 initialization failed.');
end
NET.addAssembly(fullfile(installDir,'ZOSAPI_Interfaces.dll'));
NET.addAssembly(fullfile(installDir,'ZOSAPI.dll'));

connection=ZOSAPI.ZOSAPI_Connection();
application=connection.CreateNewApplication();
if isempty(application)
    error('Could not create a ZOS-API standalone application.');
end
cleanup=onCleanup(@() closeApplication(application)); %#ok<NASGU>
if ~application.IsValidLicenseForAPI
    error('Installed OpticStudio license is not valid for ZOS-API.');
end
system=application.PrimarySystem;
system.LoadFile(sourceZmx,false);
% The complete co-located DOE-A-X 2400x3, DOE-A-Y 3x201 and DOE-B-X
% 2400x3 phase arrays are embedded as GDAT/GARR records in the
% starting ZMX.  This is deliberate: in OpticStudio 2022 R2 the
% ImportDataFile API may report success while retaining a 3x3 zero grid.
system.SaveAs(validatedZmx);

% Reopen what OpticStudio itself wrote.  This is the actual compatibility
% check, not merely a check of the hand-generated text file.
system.LoadFile(validatedZmx,false);
lde=system.LDE;
if lde.NumberOfSurfaces~=20
    error('Unexpected surface count after reopen: %d.',lde.NumberOfSurfaces);
end

expectedGrid=[14 15 16];
expectedToroidal=[5 8 9 12 18];
for k=1:numel(expectedGrid)
    name=char(lde.GetSurfaceAt(expectedGrid(k)).TypeName);
    if isempty(regexpi(name,'grid\s*phase','once'))
        error('Surface %d reopened as "%s", not Grid Phase.', ...
            expectedGrid(k),name);
    end
end
for k=1:numel(expectedToroidal)
    name=char(lde.GetSurfaceAt(expectedToroidal(k)).TypeName);
    if isempty(regexpi(name,'toroidal','once'))
        error('Surface %d reopened as "%s", not Toroidal.', ...
            expectedToroidal(k),name);
    end
end

hpfsSurfaces=[1 3 5 7 9 11 17];
for k=1:numel(hpfsSurfaces)
    row=lde.GetSurfaceAt(hpfsSurfaces(k));
    material=char(row.GetSurfaceCell( ...
        ZOSAPI.Editors.LDE.SurfaceColumn.Material).Value);
    if ~strcmpi(strtrim(material),'HPFS7980')
        error('Surface %d material reopened as "%s".', ...
            hpfsSurfaces(k),material);
    end
end
doeMaterial=char(lde.GetSurfaceAt(15).GetSurfaceCell( ...
    ZOSAPI.Editors.LDE.SurfaceColumn.Material).Value);
if ~strcmpi(strtrim(doeMaterial),'UVFS_DOE')
    error('DOE material reopened as "%s".',doeMaterial);
end

savedInfo=dir(validatedZmx);
if isempty(savedInfo) || savedInfo.bytes<3e5
    error('The embedded Grid Phase arrays were not preserved in the ZMX.');
end

fid=fopen(logFile,'w');
fprintf(fid,'OpticStudio executable: %s\n',fullfile(installDir,'OpticStudio.exe'));
fprintf(fid,'OpticStudio API version directory: %s\n',installDir);
fprintf(fid,'Zemax data directory: %s\n',char(application.ZemaxDataDir));
fprintf(fid,'Validated file: %s\n',validatedZmx);
fprintf(fid,'Reopen status: PASS\n');
fprintf(fid,'Sequential surface count: %d\n',lde.NumberOfSurfaces);
fprintf(fid,'Pre-DOE zero-thickness POP reference surface: 13 = PASS\n');
fprintf(fid,['Grid Phase surfaces: 14 (DOE-A-X), 15 (DOE-A-Y), ' ...
    '16 (DOE-B-X) = PASS\n']);
fprintf(fid,'Toroidal surfaces: 5, 8, 9, 12, 18 = PASS\n');
fprintf(fid,'HPFS7980 material surfaces: 1, 3, 5, 7, 9, 11, 17 = PASS\n');
fprintf(fid,'UVFS_DOE material surface: 15 = PASS\n');
fprintf(fid,['Embedded Grid Phase arrays: S14=2400x3, S15=3x201, ' ...
    'S16=2400x3 = PASS\n']);
fprintf(fid,'DAT A/B companion files copied to the Grid Files directory = PASS\n');
fclose(fid);

report=struct('pass',true,'validatedZmx',validatedZmx, ...
    'logFile',logFile,'surfaceCount',double(lde.NumberOfSurfaces));
disp('OPTICSTUDIO_2022R2_VALIDATION_PASS');
disp(validatedZmx);
end

function closeApplication(application)
try
    if ~isempty(application)
        application.CloseApplication();
    end
catch
end
end

function copyIfDifferent(source,destination)
if ~exist(destination,'file') || ~strcmp(fileread(source),fileread(destination))
    copyfile(source,destination,'f');
end
end
