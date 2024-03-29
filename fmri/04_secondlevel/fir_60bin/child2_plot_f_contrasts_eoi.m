function child2_plot_f_contrasts_eoi

% Settings
do_save = 1;
colors = {'k', 'r','b'}; % replace with fancy seaborn palette later

xG.def              = 'Contrast estimates and 90% C.I.';
% M21_vs_Monline, M12 vs Monline, M21 vs M12, w21_vs_wonline, w12 vs wonline, w21 vs w12,   
contrasts_to_plot   = [1:6]; % contrasts we want to plot %ftl
condition_names      = {'M21', 'M12','W21', 'W12','Monline','Wonline'};
line_width          = 4;
y_amplitude         = 0.4;


% Grab variables from base workspace
global st;
global cb_fig;
SPM                     = evalin('base', 'SPM');
% results_table           = evalin('base', 'TabDat.dat');
xSPM                    = evalin('base', 'xSPM');
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
load('parametric_contrats_60fir.mat','parametric_contrasts')
m = parametric_contrasts.m;
w = parametric_contrasts.w;
wave_x = linspace(1,119,60);

% Get coordinates and label
xyz_rd      = st.centre; % mm space
xyz         = mm2voxel(xyz_rd, xSPM);  % voxel space
region      = spm_atlas('query', xA, xyz_rd);

% Make figure
if ishandle(cb_fig)
    figure(cb_fig); 
else
    cb_fig = figure('Name', 'template', 'Position', [0 0 108 192], 'Color', [1, 1, 1]);    
end
sgtitle(sprintf('Voxel coordinates: x=%1.1f y=%1.1f z=%1.1f aka %s',xyz_rd, region), 'FontSize', 24)

% Loop through contrasts
porder = [1,3,2,4,5,6];
for j = 1:size(contrasts_to_plot,2)
    xG.spec.Ic              = contrasts_to_plot(j);
    [~, ~, ~, ~, data]      = spm_graph(SPM, xyz, xG);        
    
    % Plot data    
    subplot(3,2,porder(j)); 
    hold on;
    yyaxis left; cla;
    [line, legend_labels] = waveplot(data.contrast, condition_names{j}, data.standarderror,55);        
    
    % Plot wave
    if ismember(j,[1 2 5]);   pwave=m;
    else;       pwave=w; end    
    yyaxis right; cla;
    wave                = plot(wave_x, pwave, 'k--');
    wave.LineWidth      = line_width * .67;
    
    % Customize figure
    grid on;
    title(contrast_names{j}, 'FontSize', 14, 'Interpreter','none')        
%     ylim([-y_amplitude y_amplitude]);
    xlabel('Time (s)', 'FontSize', 14);        
    [~,ticks] = getBinBarPos(110);
    ax = gca;
    Xachse = ax.XAxis;
    ax.YAxis(1).FontSize = 14;
    Xachse.FontSize = 14;
    Xachse.TickValues = [ticks(2), ticks(4), ticks(6), 110];
    Xachse.TickLabelFormat = '%d';        
    if numel(legend_labels) > 1
        legend([line(1), line(2), line(3)], legend_labels);
    else
        legend(line(1), legend_labels);
    end
end

 
% Save figure
if do_save
    fname = sprintf('x_%03.1__y_%03.1f__z_%03.1f_export_%s',xyz_rd, matlab.lang.makeValidName(region));
    print(fullfile(save_dir, fname),'-dpng','-r300') ;
end


