function toleranceTable = run_tolerance_scan(cfg, outputDir)
%RUN_TOLERANCE_SCAN Scan beam size, DOE decenter, and common-plane defocus.
caseType = {};
caseValue = [];
xWidthMm = [];
yWidthUm = [];
uniformityPercent = [];
pass = [];

for value = cfg.tolerance.beamDiameterFraction
    localCfg = cfg;
    localCfg.inputBeamScale = 1+value;
    appendCase('beamDiameterChange', 100*value, localCfg);
end
for value = cfg.tolerance.doeDecenter
    localCfg = cfg;
    localCfg.shaper.decenter = value;
    appendCase('doeDecenter', value, localCfg);
end
for value = cfg.tolerance.targetDefocus
    localCfg = cfg;
    localCfg.target.defocus = value;
    appendCase('targetDefocus', 1e3*value, localCfg);
end

toleranceTable = table(caseType, caseValue, xWidthMm, yWidthUm, ...
    uniformityPercent, pass);
writetable(toleranceTable, fullfile(outputDir, 'tolerance_summary.csv'));

    function appendCase(name, value, localCfg)
        scanResult = simulate_laser_system(localCfg);
        caseType{end+1,1} = name; %#ok<AGROW>
        caseValue(end+1,1) = value; %#ok<AGROW>
        xWidthMm(end+1,1) = scanResult.xWidth50; %#ok<AGROW>
        yWidthUm(end+1,1) = 1e3*scanResult.yWidth1e2; %#ok<AGROW>
        uniformityPercent(end+1,1) = 100*scanResult.uniformity; %#ok<AGROW>
        pass(end+1,1) = scanResult.requirementsPass; %#ok<AGROW>
    end
end
