function lmes=eda_lmes
% fit lmes to aggregated second level

% Housekeeping
[~,~,~,EDA_DIR] = wave_ghost();
EDA_NAME_IN     = 'all_eda_clean_downsampled10.csv';
EDA_FILE_IN     = fullfile(EDA_DIR, EDA_NAME_IN);
SHIFT_NAME      = 'eda_bestshifts.csv';
SHIFT_FILE      = fullfile(EDA_DIR, SHIFT_NAME);
F               = 10; % sampling freq of our data

% Read in data
data = readtable(EDA_FILE_IN);
SHIFTS = readtable(SHIFT_FILE);

% Get rid of conditions we dont want
data(data.condition > 4,:) = [];

% Cast to categorical
% data.wm = categorical(data.wm);

dvs = {'scl'};
shift = SHIFTS.fmri_wms;
lmes = {};

for i = 1:numel(dvs)
    dv = dvs{i};
    data{:,dv} = nanshift(data{:,dv}, shift*F);
    lme_form = sprintf('%s ~ heat*wm*slope + (1|ID)', dv);
    
    lme= fitlme(data, lme_form, 'FitMethod', 'REML')
    lmes{i} = lme;
    [~,~,stats] = fixedEffects(lme);
    
    eda_plot_betas(stats, lme_form); % 2:end as we exclude intercept        
end

function eda_plot_betas(stats, tit)

betas = stats.Estimate(2:end);
sem = stats.SE(2:end);

figure('Color','white');
y_label = 'LME Estimate +- SE';

pmod_names          = {'Heat', 'WM', 'Slope',...
    'Heat X WM', 'Heat X Slope','WM X Slope',...
    'Heat X WM X Slope'};

% pmod_names          = {'Heat', 'Slope',...
%     'Heat X Slope'};


x = 1:numel(pmod_names);

b   = bar(x, betas);
b.FaceColor = [1 1 1];
b.LineWidth = 2;
hold on;
er  = errorbar(x, betas, sem);
er.Color = [0 0 0];
er.LineStyle = 'none';
er.LineWidth = 2;

xticklabels(pmod_names);
xticks(x);
ax = gca;
ax.FontSize = 14;
ax.XAxis.TickLabelInterpreter = 'none';
xtickangle(90);
xlabel('Beta', 'FontWeight', 'bold');
ylabel(y_label, 'FontWeight', 'bold');

 sgtitle(tit,'FontWeight', 'bold', 'FontSize',16, 'Interpreter', 'none');