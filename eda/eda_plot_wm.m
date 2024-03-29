function eda_plot_wm

% Plots online wm s_zt_scls for wavepain paper

SAMPLE          = 'behav'; % can be 'behav' or 'fMRI'
DONT_PLOT_OBSERVED_RESPONSE = 0;
XVAR            = 't';
DETREND_SCL     = 'no'; % can be 'yes' or 'no'
LEGEND_OFF      = 'legend_off'; % 'legend_off' turns it off else on

YVAR            = 's_zid_scl';
YVAR_ERROR      = strcat('sembj_',YVAR);
% YVAR_ERROR      = 'sembj_s_zt_scl';

ZVAR            = 'condition';
ZVAR_NAMES      = {'M21', 'M12','W21','W12'};
ZVAR_VALS       = [1 2 3 4];

HOST            = wave_ghost2(SAMPLE); %wave_gethost
NAME            = sprintf('%s_%s-vs-%s_%s',...
    SAMPLE, YVAR, XVAR, LEGEND_OFF);
FIG_DIR         = fullfile(HOST.results, '2022-07-06_scl-plots');
if ~exist(FIG_DIR, 'dir')
    mkdir(FIG_DIR)
end



% Figure
FIG_DIMS        = [8.8 5];

% LINE
LINEWIDTH       = 2;

% Colors
CB              = wave_load_colors;
ALPHA           = .5;

% Legend
L_FONTSIZE      = 8;

% Title
T_FONTSIZE      = 10;
T_FONTWEIGHT    = 'bold';

% XAxis
switch XVAR
    case 't'
        XL      = 'time [s]';
    case 'd'
        XL      = 'd prime';
end
XL_FONTSIZE     = 8;
XL_FONTWEIGHT   = 'bold';
XA_FONTSIZE     = 8;
XA_TICKS        = [0 5 55 105];
XLIMS           = [0 105];

% YAxis
YL = 'SCL [zscores]';
YA_TICKS = [0 30 60 100];

% HOUSEKEEPING
BASE_NAME = 'all_eda_sampled-at-half-a-hertz.csv';
% BASE_NAME = 'all_eda.csv';
[~,BLA,EXT] = fileparts(BASE_NAME);
NAMES = {BASE_NAME,...
    strcat(BLA,'_c',EXT),...
    strcat(BLA,'_cc',EXT)};

DATA_DIR     = fullfile(HOST.dir, 'eda');
FILES   = fullfile(DATA_DIR, NAMES);

% Grab data
data = cell(numel(NAMES),1);
i = 0;
for file = FILES
    i = i + 1;
    data{i} = readtable(FILES{i});
end

% PLOT SECOND LEVEL s_zt_scl TIME
if ~DONT_PLOT_OBSERVED_RESPONSE
    % Collect data
    d_raw      = data{3};
    for i = 1:numel(ZVAR_VALS)
        z = ZVAR_VALS(i);
        d{i}       = d_raw{d_raw{:,ZVAR} == z, YVAR};
        d_error{i} = d_raw{d_raw{:,ZVAR} == z, YVAR_ERROR};
        
        %      d{i}(isnan(d{i})) = [];
        %      d_error{i}(isnan(d_error{i})) = [];
        x{i} = linspace(0 ,110, numel(d{i}));
    end
    
    % driver code
    % create wave
    for i = 1:numel(ZVAR_VALS)
        z       = ZVAR_VALS(i);
        z_name  = ZVAR_NAMES{i};
        
        % Determine wave
        if ismember(z, [1,2,5])% then we have an M
            wave = waveit2(numel(d{i}));
        elseif ismember(z, [3,4,6]) % then its a W
            [~,wave] = waveit2(numel(d{i}));
        else
            error('unknown condition. aborting. better luck next time.');
        end
        
        % Whether to open a new figure
        if ismember(z, [1,3,5,6])
            fresh_figure = 1;
            figure('Color','white', 'Units', 'centimeters',...
                'Position', [10 10 FIG_DIMS]);
        else
            fresh_figure = 0;
        end
        
        % Plot s_zt_scls
        if strcmp('yes', DETREND_SCL)
            % have to take care of nans now
            nan_idx         = isnan(d{i});
            first_nan_idx       = find(nan_idx, 1);
            d{i}(nan_idx)   = d{1}(first_nan_idx-1);
            d{i} = detrend(d{i});
        end
        
        [hlines, hshades, legend_labels] = waveplot2(d{i},z_name, d_error{i});
        for j = 1:numel(hlines)
            hlines(j).LineWidth = LINEWIDTH;
        end        
        
        % Plot wave
        hold on;
        hwave = plot(x{i}, wave, 'k--');
        nothing = scatter(1,1,'w');
        
        % Legend
        if ~strcmp(LEGEND_OFF, 'legend_off')
            l =legend([hlines(1), hlines(2), hlines(3),...
                hshades(1), hshades(2), hshades(3)],...
                [strcat({'...'},legend_labels), strcat({'SEM '},legend_labels)],...
                'Location','best', 'NumColumns',2, 'Interpreter', 'none');
            l.Title.String = 'SCL during...';
            l.FontSize = L_FONTSIZE;
            %         l2 = legend(hwave, 'Heat stimulus', 'Location', 'best');
            %         l2.FontSize = L_FONTSIZE;
        end
        
        % Title
        
        
        if fresh_figure % then we construct the title from scratch
            if strcmp(SAMPLE, 'behav')
                T = 'Behavioural sample';
            elseif strcmp(SAMPLE, 'fmri') || strcmp(SAMPLE, 'fMRI')
                T = 'fMRI sample';
            else
                error("Sample not recognized, must be 'behav' or 'fmri'");
            end
            T = sprintf('%s: %s', T, ZVAR_NAMES{i});
        else % we just append current condition name
            T = sprintf('%s and %s', T, z_name);
        end
        fprintf('%s plotted\n',T);
        title(T, 'FontSize', T_FONTSIZE,'FontWeight',T_FONTWEIGHT);
        box off
        
        % XAxis
        ax = gca;
        xlim(XLIMS);
        xlabel(XL,'FontSize',XL_FONTSIZE, 'FontWeight', XL_FONTWEIGHT);
        ax.XAxis.FontSize = XA_FONTSIZE;
        ax.XAxis.TickValues = XA_TICKS;
        
        
        % YAxis
        ylabel(YL,'FontSize',XL_FONTSIZE, 'FontWeight', XL_FONTWEIGHT);
        ax.YAxis.TickValues = YA_TICKS;
        ax.YAxis.FontSize = XA_FONTSIZE;
        %     ylim([0 100])
        
        % Save
        grid on;
        xlim(XLIMS);
        fname = sprintf('%s_%s_%s-vs-%s_%s',...
            SAMPLE,ZVAR_NAMES{i}, YVAR, XVAR, LEGEND_OFF);
        fname = fullfile(FIG_DIR, fname);
        print(fname, '-dpng','-r300');
        fprintf('Printed %s\n\n',fname);
    end
end

% FIT LME
% Grab raw data
d = data{1};

% Append categorical variables
d.wm_c0 = categorical(d.wm, [0, -1, 1], {'notask','1back','2back'}); % no task is reference category
d.wm_c1 = categorical(d.wm, [-1, 0, 1], {'1back','notask','2back'}); % 1back is reference category
d.wm_c2 = categorical(d.wm, [1, 0, -1], {'2back','notask','1back'}); % 2back is reference category

LME_FORMULAS = {
    sprintf('%s~heat*wm_c0*slope+(1|id)', YVAR),...
    sprintf('%s~heat*wm_c1*slope+(1|id)', YVAR),...
    sprintf('%s~heat*wm_c2*slope+(1|id)', YVAR),...    
    sprintf('%s~heat*wm_c0*slope+(heat|id)+(wm_c0|id)+(slope|id)', YVAR),... % with correlated slope and intercept for each parameter and extra id intercept
    sprintf('%s~heat*wm_c2*slope+(heat|id)+(wm_c1|id)+(slope|id)', YVAR),...
    sprintf('%s~heat*wm_c2*slope+(heat|id)+(wm_c2|id)+(slope|id)', YVAR)};        

% Fitlmes
lmes = {};
for i = 1:numel(LME_FORMULAS)
    lmes{i} = fitlme(d, LME_FORMULAS{i}, 'FitMethod', 'REML', 'StartMethod', 'random');
    disp(lmes{i});
end


a = 10;

% PLOT OBSERVED RESPONSES
% fitted_res

% % Collect beta weights
% betas = fixedEffects(lme);
% betas = betas(2:end); % discard intercept
% 
% % Collect design matrix
% d2 = data{3}; % secondlevel means
% d2 = d2(:,{'heat','wm','slope',...
%     'heat_X_slope', 'heat_X_wm','wm_X_slope', 'heat_X_wm_X_slope'});
% d2.time = repmat(linspace(0,110,1101)',6,1); % construct time vector for easier plotting
% 
% if DISCARD_NO_TASK_FOR_LME
%     d2(d2.wm == 0,:) = [];
% end
% 
% % Now adjust wm encoding
% d2.wm(d2.wm == -1) = 0;
% 
% A = table2array(d2(:,1:end-1));
% fitted_responses = A(1:end-1)*betas;
% 
% % the question is how do I correctly weigh in --> NOPE fuck the non task
% % areas for now it should be enough to plot fitted responses for the task
% % regions only



