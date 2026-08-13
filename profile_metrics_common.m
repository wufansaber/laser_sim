function metrics = profile_metrics_common(x, intensity, targetWidth, usefulFraction)
%PROFILE_METRICS_COMMON Apply one definition to all plotted line profiles.
x = x(:);
intensity = real(intensity(:));
intensity = intensity/max(intensity);
metrics.widthE2 = crossingWidth(x, intensity, exp(-2));
metrics.width50 = crossingWidth(x, intensity, 0.5);
useful = abs(x) <= usefulFraction*targetWidth/2;
metrics.uniformity = min(intensity(useful))/max(intensity(useful));
metrics.rmsUniformity = 1-std(intensity(useful))/mean(intensity(useful));
end

function width = crossingWidth(x, intensity, level)
[~, center] = min(abs(x));
left = find(intensity(1:center) < level, 1, 'last');
rightRelative = find(intensity(center:end) < level, 1, 'first');
if isempty(left) || isempty(rightRelative)
    width = NaN;
    return
end
right = center+rightRelative-1;
xl = cross(x(left),x(left+1),intensity(left),intensity(left+1),level);
xr = cross(x(right-1),x(right),intensity(right-1),intensity(right),level);
width = xr-xl;
end

function value = cross(x1,x2,y1,y2,target)
value = x1+(target-y1)*(x2-x1)/(y2-y1);
end
