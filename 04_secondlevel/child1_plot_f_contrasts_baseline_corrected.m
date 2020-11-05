function child1_plot_f_contrasts_baseline_corrected

% Settings
do_save = 1;
voxels_to_plot = 1;

xG.def              = 'Contrast estimates and 90% C.I.';
% M21_vs_Monline, M12 vs Monline, M21 vs M12, w21_vs_wonline, w12 vs wonline, w21 vs w12,   
contrasts_to_plot   = [375 376 374 377 378 382]; % contrasts we want to plot %ftl
line_width          = 4;


% Grab variables from base workspace
global st;
SPM             = evalin('base', 'SPM');
results_table   = evalin('base', 'TabDat.dat');
xSPM            = evalin('base', 'xSPM');
cd(SPM.swd);

% Housekeeping
xA                      = spm_atlas('load', 'Neuromorphometrics');
contrast_names          = {};

for i = 1:numel(contrasts_to_plot)
    contrast_names{i}   = SPM.xCon(contrasts_to_plot(i)).name;
end
base_dir                = '/home/hipp/projects/WavePain/results/spm/';
contrast_dir            = strjoin(contrast_names, '_and_');
save_dir                = fullfile(base_dir, contrast_dir);
fir_order               = 60;
if ~exist(save_dir, 'dir')
    mkdir(save_dir)
end

% Plotting action
% [m, w]          = waveit2(fir_order-5);
% wave_x          = linspace(0,110,numel(m));


%     if ~isempty(results_table{i,3}) % black voxel in results table, we care about those

% We get this from st.centre now
% Get coordinates and label
        xyz_rd      = st.centre; % mm space
        xyz         = mm2voxel(xyz_rd, xSPM);  % voxel space
        region      = spm_atlas('query', xA, xyz_rd);                

% Now loop through our contrasts
if ishandle(1997)
    fig = figure(1997);
else
    fig = figure('Name', 'template', 'Position', [0 0 1920 1080], 'Color', [1, 1, 1]);
    fig.Number = 1997;
end
x = linspace(0,120,numel(data.contrast));


for j = 1:size(contrasts_to_plot,2)
    xG.spec.Ic              = contrasts_to_plot(j);
    [~, ~, ~, ~, data]      = spm_graph(SPM, xyz, xG);
    
    subplot(3,2,j);
    
    % Plot data
    line = boundedline(x, data.contrast, data.standarderror, 'r-', 'alpha');            % ftl add errorline function
    line.LineWidth = line_width;
    
    % Plot wave
    if j < 4;   wave = m;
    else;       wave = w; end
    wave = plot(wave_x, wave, 'k--');
    wave.LineWidth = line_width * .67;
end

% Customize figure
legend(char(contrast_names), 'FontSize', 20)
title(sprintf('Voxel coordinates: x=%1.1f y=%1.1f z=%1.1f aka %s',xyz_rd, region), 'FontSize', 20)
ylim([-0.5 0.5]);
 
% Save figure
if do_save
    fname = sprintf('x_%03.1__y_%03.1f__z_%03.1f_%02d_export_%s',xyz_rd, vi,matlab.lang.makeValidName(region));
    print(fullfile(save_dir, fname),'-dpng','-r300') ;
end


