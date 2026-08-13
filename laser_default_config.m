function cfg = laser_default_config()
%LASER_DEFAULT_CONFIG Nominal inputs for the 355 nm line-focus design.
% MATLAB R2019b compatible. Lengths are millimetres unless noted.

cfg.lambda = 355e-6;              % 355 nm in mm
cfg.M2 = 1.2;
cfg.inputBeamDiameter = 1.0;      % full 1/e^2 irradiance diameter
cfg.ellipticity = 1.1;            % Dx / Dy
cfg.divergenceHalfAngleMax = 550e-6; % rad; recorded requirement limit

% Galilean expander: separation f2 + f1 = 90 mm, magnification 10x.
cfg.expander.z1 = 50;
cfg.expander.f1 = -10;
cfg.expander.z2 = 140;
cfg.expander.f2 = 100;

% Final shaping/focusing group.
cfg.shaper.z = 300;
cfg.shaper.clearAperture = 25.0;
cfg.shaper.topHatWidth = 1.5;
cfg.shaper.fX = 100;
cfg.shaper.decenter = 0;           % DOE lateral shift in X
cfg.target.z = cfg.shaper.z + cfg.shaper.fX;
cfg.target.yWidth = 0.8e-3;       % 0.8 um full 1/e^2 width in mm
cfg.target.defocus = 0;            % common target-plane displacement
cfg.inputBeamScale = 1;

% One-dimensional separable grids. A 2-D field is their outer product.
cfg.grid.N = 32768;               % power of two, modest memory in R2019b
cfg.grid.window = 160;            % source-plane span; resolves 0.8 um focus
cfg.uniformityFraction = 0.90;    % central useful fraction of Top-Hat
cfg.edgeThreshold = 0.50;         % width definition at half maximum

% Manufacturing/alignment feasibility scan.
cfg.tolerance.beamDiameterFraction = [-0.05, 0, 0.05];
cfg.tolerance.doeDecenter = [-0.25, 0, 0.25];
cfg.tolerance.targetDefocus = [-0.001, 0, 0.001]; % +/-1 um is significant
end
