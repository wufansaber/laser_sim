%   Top-Hat Beam shaping: nominal and post-tolerance simulation
%     TopHatSim(nominalStruct,toleranceStruct)
% 
%   The input variables include two structures:
%     nominalStruct - parameters for nominal simulation
%     toleranceStruct - parameters for tolerances
%     Fields of each structure:
%         nominalStruct.CA - clear aperture size in mm
%         nominalStruct.beamDia - Gaussian beam diameter at exp(-2) in mm
%         nominalStruct.f - Effective Focal Length (EFL) of the system in mm
%         nominalStruct.lambda – laser wavelength in mm (i.e, 500nm=5e-4)
%         nominalStruct.shape – shape string: 'square', 'round' or 'line'
%         nominalStruct.THSize - Top Hat size in mm
%         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%         toleranceStruct.tolvariable_string - variable for tolerances. Options: '', 'defocus', 'wavelength', 'beamSizeChange', 'decenter'
%         * defocus - distance from nominal plane
%         * wavelength - deviation from nominal wavelength in mm
%         * beamSizeChange - deviation from nominal beam size in mm
%         * decenter - misalignment between incident beam and Top Hat
%         element. Only positive values are possible in mm
%         toleranceStruct.tolvar_values - values for tolerances in mm. It is possible to run several tolerance values in each run using []
% 
%     Examples:
%       Copy and paste the following script into your command window and change the values accordingly.
%       Uncomment the tolerance you wish to simulate. 
% 
%             nominalStruct.CA = 23.6;
%             nominalStruct.beamDia = 5;
%             nominalStruct.f = 50;
%             nominalStruct.lambda = 0.532e-3;
%             nominalStruct.shape = 'square';
%             nominalStruct.THSize = 0.5;
%             toleranceStruct.tolvariable_string = 'defocus'; % options: 'defocus', 'wavelength', 'beamSizeChange', 'decenter'
%             toleranceStruct.tolvar_values = [-1 -0.5 0 0.5 1]; % enter values in mm
%             %toleranceStruct.tolvariable_string = 'wavelength'; % options: 'defocus', 'wavelength', 'beamSizeChange', 'decenter'
%             %toleranceStruct.tolvar_values = [-0.01 0.01]*1e-3; % enter values in mm
%             %toleranceStruct.tolvariable_string = 'beamSizeChange'; % options: 'defocus', 'wavelength', 'beamSizeChange', 'decenter'
%             %toleranceStruct.tolvar_values = [-1 -0.5 0.5 1]; % enter values in mm
%             %toleranceStruct.tolvariable_string = 'decenter'; % options: 'defocus', 'wavelength', 'beamSizeChange', 'decenter'
%             %toleranceStruct.tolvar_values = linspace(0.5,1.5,3); % enter values in mm
%             TopHatSim(nominalStruct,toleranceStruct);
% 
%     This algorithm uses an analytical model for Top-Hats.
%     Holo/Or also offers further optimization of simulation parameters.
% 
%     For more information see: <a href= "matlab: web http://www.holoor.co.il/Diffractive_optics_Applications/Application_Notes_BeamShapers.htm -browser">Top-Hat's application note on HOLOOR Website</a>
% 
% 
%
