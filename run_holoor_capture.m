function capturedFiles = run_holoor_capture()
%RUN_HOLOOR_CAPTURE Run the supplied black box and save every generated plot.
% The p-code has no numeric output, so figure capture is the only non-invasive
% way to retain its nominal response for comparison.
rootDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(rootDir, 'results', 'holoor');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

close all force
set(0, 'DefaultFigureVisible', 'off');
run_holoor_reference();
drawnow;

figures = findall(0, 'Type', 'figure');
if isempty(figures)
    error('laser_sim:HoloOrNoFigures', ...
        'TopHatSim completed but did not create any figure.');
end

numbers = arrayfun(@(h) get(h,'Number'), figures);
[~, order] = sort(numbers);
figures = figures(order);
capturedFiles = cell(numel(figures),1);
curveFigure = [];
curveAxes = [];
curveX = [];
curveY = [];
for index = 1:numel(figures)
    capturedFiles{index} = fullfile(outputDir, ...
        sprintf('holoor_figure_%02d.png', index));
    print(figures(index), capturedFiles{index}, '-dpng', '-r180');

    axesHandles = findall(figures(index), 'Type', 'axes');
    for axesIndex = 1:numel(axesHandles)
        lineHandles = findall(axesHandles(axesIndex), 'Type', 'line');
        for lineIndex = 1:numel(lineHandles)
            candidateX = get(lineHandles(lineIndex), 'XData');
            candidateY = get(lineHandles(lineIndex), 'YData');
            if isnumeric(candidateX) && isnumeric(candidateY) && ...
                    numel(candidateX) > numel(curveX)
                curveFigure = index;
                curveAxes = axesIndex;
                curveX = candidateX(:);
                curveY = candidateY(:);
            end
        end
    end
end
if ~isempty(curveX)
    curveTable = table(curveX, curveY, ...
        'VariableNames', {'position_um','normalizedIntensity'});
    writetable(curveTable, fullfile(outputDir, 'holoor_curve.csv'));
    save(fullfile(outputDir, 'holoor_curve.mat'), 'curveX', 'curveY', ...
        'curveFigure', 'curveAxes');
end
savefig(figures, fullfile(outputDir, 'holoor_figures.fig'));
close(figures)
set(0, 'DefaultFigureVisible', 'on');

fprintf('Captured %d Holo/Or figure(s) in %s\n', ...
    numel(capturedFiles), outputDir);
end
