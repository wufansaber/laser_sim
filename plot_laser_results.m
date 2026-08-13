function plot_laser_results(results, outputDir)
%PLOT_LASER_RESULTS Save MATLAB R2019b-compatible diagnostic figures.
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

visibleState = 'off';

fig = figure('Visible', visibleState, 'Color', 'w', 'Position', [100 100 1000 700]);
subplot(2,1,1)
maskX = abs(results.xTarget) <= 1.1;
plot(results.xTarget(maskX), results.Ix(maskX), 'b-', 'LineWidth', 1.5)
grid on
xlabel('X at target (mm)')
ylabel('Normalized irradiance')
title(sprintf('X line Top-Hat: width_{50%%}=%.4f mm, min/max=%.2f%%', ...
    results.xWidth50, 100*results.uniformity))
ylim([0 1.08])

subplot(2,1,2)
maskY = abs(results.yTarget) <= 0.003;
plot(1e3*results.yTarget(maskY), results.Iy(maskY), 'r-', 'LineWidth', 1.5)
hold on
plot(1e3*results.yTarget(maskY), exp(-2)*ones(1,sum(maskY)), 'k--')
grid on
xlabel('Y at target (um)')
ylabel('Normalized irradiance')
title(sprintf('Y Gaussian focus: full 1/e^2 width=%.4f um', ...
    1e3*results.yWidth1e2))
ylim([0 1.08])
print(fig, fullfile(outputDir, 'target_profiles.png'), '-dpng', '-r180')
close(fig)

% Compact 2-D visualization around the useful focal region.
xMask = abs(results.xTarget) <= 0.9;
yMask = abs(results.yTarget) <= 0.002;
I2D = results.Iy(yMask).' * results.Ix(xMask);
fig = figure('Visible', visibleState, 'Color', 'w', 'Position', [100 100 1100 420]);
imagesc(results.xTarget(xMask), 1e3*results.yTarget(yMask), I2D)
axis xy
xlabel('X (mm)')
ylabel('Y (um)')
title('Normalized coherent irradiance at target')
colormap(parula(256))
colorbar
print(fig, fullfile(outputDir, 'target_irradiance_2d.png'), '-dpng', '-r180')
close(fig)

fig = figure('Visible', visibleState, 'Color', 'w', 'Position', [100 100 1000 450]);
plot(results.sourceCoordinate, mod(results.doePhase,2*pi), 'LineWidth', 1.2)
xlim([-12.5 12.5])
grid on
xlabel('DOE X coordinate (mm)')
ylabel('Wrapped phase (rad)')
title('Nominal analytic line-shaper phase at 355 nm')
print(fig, fullfile(outputDir, 'doe_phase.png'), '-dpng', '-r180')
close(fig)
end
