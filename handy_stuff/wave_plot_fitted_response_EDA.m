function wave_plot_fitted_response_EDA(in, varargin)

% Handle input
flag = '';
if nargin > 1
    flag = varargin{1};
end

% lme or betas
if strcmp(class(in), 'LinearMixedModel')
    betas = in.Coefficients.Estimate(2:end);
    if any(contains(in.CoefficientNames, 'diff'))
        flag = 'diffheat';
    end
else
    betas = in;
end

if numel(betas) == 7 % one trinary wm regressor
    M = wave_load_designmatrix(flag);
elseif numel(betas) == 11 % two binary wm regressors
    [~,M] = wave_load_designmatrix(flag);
end

fprintf("\nwave_plot_fitted_response_EDA([")
fprintf("%.1f ", betas);
fprintf("], '%s')\n", flag);

try 
    data = M*betas;
catch
    data = M*betas';
end

data = reshape(data,[],6);

% Plot fitted response
porder              = [1 1 2 2 3 4];
condition_names     = {'M21', 'M12','W21', 'W12','Monline','Wonline'};
do_ylims            = 0;

f =figure;
new = 1;


if new
    
    % Prepare wave
    load('parametric_contrats_60fir.mat','parametric_contrasts')
    m = M(1:60,1);
    w = M(121:180,1);
    wave_x = linspace(1,110,60);
    line_width          = 1;    
    
    % Set axis colors
    left_color = [0 0 0];
    right_color = [1 1 1];
    set(f,'defaultAxesColorOrder',[left_color; right_color]); 
    
    observed_data = [];
    for i = 1:6        
        subplot(2,2,porder(i)); hold on;
        
        % Plot data
        yyaxis left; % cla;
        line = waveplot(data(:,i), condition_names{i}, zeros(size(data,1),1),55);
        ylim([-1.5 1.5]);                       
        
        % Plot wave
        if ismember(i,[1 2 5])
            pwave=m;             
        else
            pwave=w;            
        end
        yyaxis right;  % cla;
        wave                = plot(wave_x, pwave, 'k--');
        wave.LineWidth      = line_width * .67;        
%         if i==4
%                 hold on;                
%                 online = plot(1,0.3, '-*', 'LineWidth', 4, 'Color', [0.1725 0.4824 0.7137]);
%                 blank = plot(1,0.1,'w-');
%                 lg =legend([line(1:3) online blank wave],{'...no task', '...1-back','...2-back','...online rating','','Heat stimulus'});
%                 lg.Position= [0.83 .45, 0.1 0.1];                            
%                 lg.Title.String = 'FIR estimates during...';
%                 lg.FontSize = 12;
%         end
%         
        % Customize figure
        grid on;
        title(condition_names{i}, 'FontSize', 14, 'Interpreter','none');
        ylim([-1.5 1.5]);
        if i > 4
            xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');            
        end
        [~,ticks] = getBinBarPos(110);
        ax = gca;
        Xachse = ax.XAxis;
        ax.YAxis(1).FontSize = 12;
        Xachse.FontSize = 12;
%         Xachse.TickValues = [ticks(2), ticks(4), ticks(6), 110];
        Xachse.TickValues = [];
        Xachse.TickLabelFormat = '%d';
        xlim([0 101.5]);
        ylim([-1.5 1.5]);

        
        % Save for later
%         observed_data = vertcat(observed_data, data{i}.contrast);        
    end
    
else
    % Still have to figure this out cause selecting the subplot clears
    % it...
    fprintf('...updating...     ');
    for i = 1:6        
        subplot(3,5,porder(i,:)); hold on;
        
       
        yyaxis left; cla;
        [line, legend_labels] = waveplot(data{i}.contrast, condition_names{i}, data{i}.standarderror,55);
        if do_ylims
            ylim([-do_ylims, do_ylims]);
        end
        xlim([0 110]);
    end        
end










