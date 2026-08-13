function comparison = compare_holoor_model()
%COMPARE_HOLOOR_MODEL Compare captured vendor X profile with our X profile.
rootDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(rootDir, 'results', 'holoor');
curveFile = fullfile(outputDir, 'holoor_curve.csv');
if ~exist(curveFile, 'file')
    run_holoor_capture();
end

vendor = readtable(curveFile);
model = simulate_laser_system(laser_default_config());
vendorXmm = vendor.position_um/1000;
vendorI = vendor.normalizedIntensity/max(vendor.normalizedIntensity);

vendorWidth50 = profileWidth(vendorXmm, vendorI, 0.5);
vendorUseful = abs(vendorXmm) <= 0.9*1.5/2;
vendorUniformity = min(vendorI(vendorUseful))/max(vendorI(vendorUseful));

comparison = table( ...
    {'Holo/Or TopHatSim.p'; 'Independent coherent model'}, ...
    [vendorWidth50; model.xWidth50], ...
    [100*vendorUniformity; 100*model.uniformity], ...
    'VariableNames', {'model','width50_mm','central90_minmax_percent'});
writetable(comparison, fullfile(outputDir, 'model_comparison.csv'));

fig = figure('Visible','off','Color','w','Position',[100 100 1000 520]);
plot(vendorXmm, vendorI, 'b-', 'LineWidth', 1.3)
hold on
plot(model.xTarget, model.Ix, 'r--', 'LineWidth', 1.3)
xlim([-0.82 0.82])
ylim([0 1.03])
grid on
xlabel('X at target (mm)')
ylabel('Normalized irradiance')
title('Line Top-Hat comparison at 355 nm')
legend('Holo/Or TopHatSim.p', 'Independent coherent model', ...
    'Location', 'south')
print(fig, fullfile(outputDir, 'model_comparison.png'), '-dpng', '-r180')
close(fig)

disp(comparison)
end

function width = profileWidth(x, intensity, level)
[~, center] = min(abs(x));
left = find(intensity(1:center) < level, 1, 'last');
rightRelative = find(intensity(center:end) < level, 1, 'first');
right = center+rightRelative-1;
xl = crossing(x(left),x(left+1),intensity(left),intensity(left+1),level);
xr = crossing(x(right-1),x(right),intensity(right-1),intensity(right),level);
width = xr-xl;
end

function value = crossing(x1,x2,y1,y2,target)
value = x1+(target-y1)*(x2-x1)/(y2-y1);
end
