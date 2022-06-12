function firstlevel_canonical_pmod
% specify firstlevel pmod with parametrically modulated stick functions

[base_dir, n_proc, code_dir] = wave_ghost;
go_back = pwd; % go back to the directory we started in

% Subs
all_subs = [5:12 14:53]; 
% all_subs = [5:12];
% all_subs = [14:53];


% Settings
DEBUG_PLOT = 0;
                       
%-firstlevel
do_model            = 0;
do_cons             = 0;
do_warp             = 0;
do_smooth           = 0;

%-secondlevel
do_mask             = 0;
do_ttest            = 0;
do_nosub_anova_model= 0;
do_nosub_anova_cons = 1;

TR                  = 1.599;
heat_duration       = 110; % seconds. this is verified in C:\Users\hipp\projects\WavePain\code\matlab\fmri\fsubject\onsets.mat
skern               = [6 6 6]; % smoothing kernel
stick_resolution    = 10; % /seconds so many sticks we want per second
anadirname          = 'canonical_pmodV4'; 

% Each subject has two sessions. Sessions are also used to distinquish
% subjects --> conceputal distance between eg sub10 sess1 - sub10sess2 =
% conceptual distance sub10sess1 - sub53sess2. Each session is a seperate
% matlabbatch and evaluated seperately by run_matlab

% Specify paths and files
struc_templ         = '^sPRISMA.*\.nii';
epi_folders         = {'run001/mrt/', 'run002/mrt/'};
strip_str           = 's3skull_strip.nii';
flow_str            = '^u_rc.*\.nii';
realign_str         =  '^rp_afMR.*\.txt';

rfunc_file         = '^rafMRI.nii';
conditions          = {'M21', 'M12', 'W21', 'W12', 'M_Online', 'W_Online'};
pmod_names          = {'heat', 'wm', 'slope',...
    'heat_X_wm', 'heat_X_slope','wm_X_slope',...
    'heat_X_wm_X_slope', 'ramp_up', 'ramp_down'}; % regressor
mat_name          = which(mfilename);

to_warp             = 'con_%04.4d.nii';

n_sess            = size(epi_folders,2);
n_cond            = size(conditions,2);
contrasts         = [];

% Load temp file
temp_file = fullfile(code_dir, 'temps.mat');
load(temp_file, 'temps');

% Load onset file
onset_file = fullfile(base_dir, 'all_onsets.mat');
load(onset_file, 'all_RES');

% Prepare multiprocessing
if size(all_subs) < n_proc
    n_proc = size(all_subs,2);
end
subs              = splitvect(all_subs, n_proc);

for np = 1:size(subs,2) % core loop start
    matlabbatch = [];
    mbi = 0;
    
    
    for i = 1:size(subs{np},2) % subject loop start
        
        % Housekeeping
        name            = sprintf('sub%03d',subs{np}(i));
        st_dir          = fullfile(base_dir, name,'run000/mrt/');
        sub_res         = all_RES.(name); % condition onsets
        mepi_dir        = fullfile(st_dir, 'mean_epi');
        strip_file      = spm_select('FPList', mepi_dir, strip_str); 
        struc_file      = spm_select('FPList', st_dir, struc_templ);
        u_rc1_file      = spm_select('FPList', mepi_dir, flow_str);         
        sub_temps       = temps(temps.id == subs{np}(i),:);        
        a_dir = fullfile(base_dir, name, anadirname);
        if ~exist(a_dir, 'dir')
            mkdir(a_dir)
        end
        
        % First level model generics
        template = [];
        template.spm.stats.fmri_spec.timing.units   = 'scans';
        template.spm.stats.fmri_spec.timing.RT      = TR;
        template.spm.stats.fmri_spec.timing.fmri_t  = 16;
        template.spm.stats.fmri_spec.timing.fmri_t0 = 8;
        template.spm.stats.fmri_spec.fact           = struct('name', {}, 'levels', {});
        
        template.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];        
        template.spm.stats.fmri_spec.volt             = 1;
        template.spm.stats.fmri_spec.mthresh          = -Inf;
        template.spm.stats.fmri_spec.global           = 'None';
        template.spm.stats.fmri_spec.mask             = cellstr(strip_file);
        template.spm.stats.fmri_spec.cvi              = 'None';
        
        
        if DEBUG_PLOT
            porder = [1:2:27 2:2:28];
            pidx = 1;
            figure('Name', name);
            sgtitle(name);
        end
        
        
        for j = 1:n_sess % session loop start
            
%             if DEBUG_PLOT
%                 subplot(2,1,j);
%                 title(sprintf('session %d',j));                
%             end
            
            s_dir           = fullfile(base_dir, name, epi_folders{j});
            epi_files       = spm_select('ExtFPList', s_dir, rfunc_file);
            fm              = spm_select('FPList', s_dir, realign_str);
            movement        = normalize(load(fm));
            all_nuis{j}     = movement;
            n_nuis          = size(all_nuis{j},2);
            
            template.spm.stats.fmri_spec.sess(j).hpf = 360;
            template.spm.stats.fmri_spec.sess(j).scans = cellstr(epi_files);
            template.spm.stats.fmri_spec.sess(j).multi = {''};
            template.spm.stats.fmri_spec.sess(j).multi_reg = {''};
            
            % Collect onsets and create conditions
            RES     = sub_res{j};            
            
            % Assesmble onsets vector and pmods matrix for wm and online conditions respectively
            model_conds = {'wm','online'}; % model conditions           
            all_onsets = {[],[]}; % first entry for wm conditions, second for online
            all_pmods  = {[],[]}; % first entry for wm conditions, second for online                                                                        
            
            for conds = 1:numel(conditions) % condition loop start
                onset       = RES{conds}.onset; % seconds  
                cond_name   = RES{conds}.name;                
                [onsets, pmods] = wave_getpmods(onset, cond_name, stick_resolution, sub_temps); % onset and onsets still in seconds                
                
                idx = 1; % wm by default
                if ismember(cond_name, {'M_Online','W_Online'}) % where to append onsets and pmods
                    idx = 2;
                end
                all_onsets{idx} = vertcat(all_onsets{idx}, onsets);
                all_pmods{idx} = vertcat(all_pmods{idx}, pmods);
            end % condition loop end                        
            
            for model_cond = 1:numel(model_conds) % model condition start: handle wm conditions first, then online conditions
                template.spm.stats.fmri_spec.sess(j).cond(model_cond).name     = model_conds{model_cond};
                template.spm.stats.fmri_spec.sess(j).cond(model_cond).onset    = (all_onsets{model_cond} ./ TR) -1;                                                
                template.spm.stats.fmri_spec.sess(j).cond(model_cond).duration = 0;
                template.spm.stats.fmri_spec.sess(j).cond(model_cond).orth     = 0;
                template.spm.stats.fmri_spec.sess(j).cond(model_cond).tmod     = 0;                                
                
                idx = 1; % we need this to index as some iterators are going to be skipped for online conditions so we cannot use the iterator as an index anymore
                for pmod = 1:numel(pmod_names) % parametric modulator loop start
                    pmod_params = all_pmods{model_cond}(:,pmod);
                    if isempty(find(pmod_params, 1)) % only zeros in pmod --> wm related pmod for online --> skip
%                         fprintf('\n skipped %s for %s-condition', pmod_names{pmod}, model_conds{model_cond});
                        continue % dont do anything                        
                    end                        
                    template.spm.stats.fmri_spec.sess(j).cond(model_cond).pmod(idx).name = pmod_names{pmod};
                    template.spm.stats.fmri_spec.sess(j).cond(model_cond).pmod(idx).param = pmod_params;                                                            
                    template.spm.stats.fmri_spec.sess(j).cond(model_cond).pmod(idx).poly = 1;
                    idx = idx+1; 
                    
                    if DEBUG_PLOT
                        subplot(14,2,porder(pidx));                        
                        x = (all_onsets{model_cond} ./ TR) -1;
                        plot(x,pmod_params,'.');                                                
                        title(sprintf('%02d %s session %02d',...
                            pidx ,pmod_names{pmod}, j),...
                            'Interpreter', 'none');
                        xlim([0 1100]);
                        pidx = pidx + 1;                        
                    end                    
                    
                end % parametric modulator loop end                
            end % model condition loop end                                      
            
            % Movement parameters black box
            movement        = normalize(load(fm));
            all_nuis{j}     = movement;
            n_nuis          = size(all_nuis{j},2);
            for nuis = 1:n_nuis % movement parameters loop start
                template.spm.stats.fmri_spec.sess(j).regress(nuis) = struct('name', cellstr(num2str(nuis)), 'val', all_nuis{j}(:,nuis));
            end % movement parameter loop end            
        end % session loop end        
        
        if do_model
            mbi = mbi + 1;
            matlabbatch{mbi} = template;                        
            copyfile(which(mfilename),a_dir);
            matlabbatch{mbi}.spm.stats.fmri_spec.dir = {a_dir};
            
            mbi = mbi + 1;
            matlabbatch{mbi}.spm.stats.fmri_est.spmmat           = {[a_dir filesep 'SPM.mat']};
            matlabbatch{mbi}.spm.stats.fmri_est.method.Classical = 1;
        end
        
        %------------------------------------------------------------------
        % CONTRAST DEFINITION START (sessions collapse here)
        %------------------------------------------------------------------
        % Prepare template              
        template            = [];        
        if isempty(contrasts)                              
            con_names       = strcat('wm_',pmod_names); % wm cons           
            con_names       = [con_names,...
                'online_heat','online_slope','online_heat_X_slope',...
                'online_ramp_up','online_ramp_down'];
            contrasts(1,:)  = repmat([0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_heat
            contrasts(2,:)  = repmat([0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_wm
            contrasts(3,:)  = repmat([0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_slope
            contrasts(4,:)  = repmat([0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_heat_X_wm
            contrasts(5,:)  = repmat([0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_heat_X_slope
            contrasts(6,:)  = repmat([0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_wm_X_slope
            contrasts(7,:)  = repmat([0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_heat_X_wm_X_slope                                               
            contrasts(8,:)  = repmat([0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_ramp_up
            contrasts(9,:)  = repmat([0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 zeros(1,6)],1,n_sess); % wm_ramp_down
            contrasts(10,:) = repmat([0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 zeros(1,6)],1,n_sess); % online_heat
            contrasts(11,:) = repmat([0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 zeros(1,6)],1,n_sess); % online_slope
            contrasts(12,:) = repmat([0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 zeros(1,6)],1,n_sess); % online_heat_X_slope
            contrasts(13,:) = repmat([0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 zeros(1,6)],1,n_sess); % online_ramp_up
            contrasts(14,:) = repmat([0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 zeros(1,6)],1,n_sess); % online_ramp_down
        end        
        
%         % Make negative contrasts
%         contrasts = vertcat(contrasts, -contrasts);
%         con_names = [con_names, strcat('-',con_names)];
        
        template.spm.stats.con.spmmat   = {[a_dir filesep 'SPM.mat']};
        template.spm.stats.con.delete   = 1;        
        for k = 1:numel(con_names) % contrast loop start
                template.spm.stats.con.consess{k}.tcon.name     = con_names{k};
                template.spm.stats.con.consess{k}.tcon.convec   = contrasts(k,:);
                template.spm.stats.con.consess{k}.tcon.sessrep  = 'none';
        end % contrast loop end        
        %------------------------------------------------------------------
        % CONTRAST DEFINITION END
        %------------------------------------------------------------------        
        
        if do_cons % Pass con template to batch
            mbi = mbi + 1;
            matlabbatch{mbi} = template; 
        end                        
        
        %------------------------------------------------------------------
        % WARP SPECIFICATION START (go from native to MNI space using mepi flow field)
        %------------------------------------------------------------------
        template            = [];
        con_files           = '';
        
        for j = 1:numel(con_names) % collect con_files
            con_files(j,:) = [a_dir filesep sprintf(to_warp,j)];
        end
        
        % Prepare con file names here for later reference
        dartel_prefix       = 'w_mepi';
        wcon_files             = ins_letter(con_files,'w');
        wcon_dartel_files      = ins_letter(con_files, dartel_prefix); % delete 
        wcon_files             = chng_path(wcon_files, mepi_dir);    % delete
        wcon_dartel_files      = chng_path(wcon_dartel_files, mepi_dir); % delete
        wcon_dartel_files2     = chng_path(wcon_dartel_files, a_dir);  % keep those
        
        template.spm.tools.dartel.crt_warped.flowfields = cellstr(repmat(u_rc1_file, size(con_files,1),1)); % either use u_rcl from t1 or from epis
        template.spm.tools.dartel.crt_warped.images = {cellstr(char(con_files))};
        template.spm.tools.dartel.crt_warped.jactransf = 0;
        template.spm.tools.dartel.crt_warped.K = 6;
        template.spm.tools.dartel.crt_warped.interp = 1;        
        %------------------------------------------------------------------
        % WARP SPECIFICATION END
        %------------------------------------------------------------------                    
        
         if do_warp % pass warp template to batch             
            mbi = mbi + 1;
            matlabbatch{mbi} = template; 
            
            mbi = mbi + 1;
            matlabbatch{mbi}.cfg_basicio.file_dir.file_ops.file_move.files = cellstr(wcon_files);
            matlabbatch{mbi}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.moveto = cellstr(a_dir);
            matlabbatch{mbi}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.patrep.pattern = 'w';
            matlabbatch{mbi}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.patrep.repl    = dartel_prefix;
            matlabbatch{mbi}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.unique         = false;            
         end   
         
         
        %------------------------------------------------------------------
        % SMOOTH SPECIFICATION START
        %------------------------------------------------------------------            
         template   = [];
         template.spm.spatial.smooth.data = cellstr(wcon_dartel_files2);
         template.spm.spatial.smooth.fwhm = skern;
         template.spm.spatial.smooth.prefix = ['s' num2str(skern(1))];
        %------------------------------------------------------------------
        % SMOOTH SPECIFICATION END
        %------------------------------------------------------------------            
        
        if do_smooth % pass smooth template to batch
            mbi = mbi+1;
            matlabbatch{mbi} = template; 
        end                        
    end % subject loop end
    
    % PASS BATCH TO CORE    
    if ~isempty(matlabbatch)
        check = 0;
        run_matlab(np, matlabbatch, check);
    end    
end % core loop end

%--------------------------------------------------------------------------
% SECOND LEVEL create overall mask.nii START (binary imaging with ones
% representing common voxels of ALL con images across participants and
% sessions
%--------------------------------------------------------------------------

matlabbatch = [];
all_cons    = [];
con_string  = sprintf('^s%d%scon', skern(1), dartel_prefix);
mask_name   = 'mask_all_canonical_pmod';

for i = 1:numel(all_subs)
    name        = sprintf('sub%03d',all_subs(i));
    a_dir       = fullfile(base_dir, name, anadirname);
    sub_cons    = spm_select('FPList', a_dir, con_string);
    all_cons    = char(all_cons, sub_cons);
end
matlabbatch{1}.spm.util.imcalc.input = cellstr(all_cons);
matlabbatch{1}.spm.util.imcalc.output = mask_name;
matlabbatch{1}.spm.util.imcalc.outdir = {fullfile(base_dir, 'second_Level')};
matlabbatch{1}.spm.util.imcalc.expression = 'all(X)';
matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
matlabbatch{1}.spm.util.imcalc.options.dmtx = 1;
matlabbatch{1}.spm.util.imcalc.options.mask = 0;
matlabbatch{1}.spm.util.imcalc.options.interp = 1;
matlabbatch{1}.spm.util.imcalc.options.dtype = 4;

if do_mask
    spm_jobman('run',matlabbatch);
end
%--------------------------------------------------------------------------
% SECOND LEVEL create overall mask.nii END
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
% SECOND LEVEL t-Test START (one 2nd level per contrast --> 14 ttests)% 
%--------------------------------------------------------------------------
anadirname2          = strcat('second_level_ttest', anadirname);
for i = 1:numel(con_names) % contrast loop start
    
    % House keeping
    con_folder      = sprintf('%02d_%s_contrast%02d', i, con_names{i}, skern(1));
    out_dir         = fullfile(base_dir, 'second_Level', anadirname2, con_folder);        
    matlabbatch     = [];    
    
    for j = 1:numel(all_subs) % 2nd level subject loop start
        name        = sprintf('sub%03d',all_subs(j));
        a_dir       = fullfile(base_dir, name, anadirname);
        swcon_templ = sprintf('s%d%scon_%04d.nii',skern(1), dartel_prefix, i);
        
        swcon_file  = spm_select('FPList', a_dir, swcon_templ);
        if j == 1; all_scans = swcon_file; else
            all_scans   = char(all_scans, swcon_file);        
        end
    end % 2nd level subject loop end
   
    %----------------------- MODEL SPECIFICATION --------------------------
    matlabbatch{1}.spm.stats.factorial_design.dir = {out_dir};
    matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = cellstr(all_scans);    
    matlabbatch{1}.spm.stats.factorial_design.des.pt.gmsca  = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.pt.ancova = 0;

    
    matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;    
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {fullfile(base_dir, 'second_Level', [mask_name '.nii'])};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;
    
    %----------------------- MODEL ESTIMATION -----------------------------    
    matlabbatch{2}.spm.stats.fmri_est.spmmat = {fullfile(out_dir, 'SPM.mat')};
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
    
    %---------------------- CONTRASTS -------------------------------------
    matlabbatch{3}.spm.stats.con.spmmat = {fullfile(out_dir, 'SPM.mat')};
    matlabbatch{3}.spm.stats.con.delete = 1;    
    co = 1;
    
    matlabbatch{3}.spm.stats.con.consess{co}.tcon.name    = 'pos';
    matlabbatch{3}.spm.stats.con.consess{co}.tcon.convec  = [1];
    matlabbatch{3}.spm.stats.con.consess{co}.tcon.sessrep = 'none';
    co = co + 1; %increment by 1     
    matlabbatch{3}.spm.stats.con.consess{co}.tcon.name    = 'neg';
    matlabbatch{3}.spm.stats.con.consess{co}.tcon.convec  = [-1];
    matlabbatch{3}.spm.stats.con.consess{co}.tcon.sessrep = 'none';
    co = co + 1; %increment by 1    
    
    if do_ttest
        spm_jobman('initcfg');
        spm('defaults', 'FMRI');
        spm_jobman('run',matlabbatch);
        copyfile(which(mfilename),out_dir);
    end
end % contrast loop end
%--------------------------------------------------------------------------
% SECOND LEVEL t-Test END
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
% SECOND LEVEL no subject ANOVA START
%--------------------------------------------------------------------------
% Housekeeping
anadirname2     = strcat('second_level_anova', anadirname);
out_dir         = fullfile(base_dir, 'second_Level', anadirname2);

if ~exist(out_dir)
    mkdir(out_dir)
end

%-------------------------MODEL SPECIFICATION------------------------------
matlabbatch                 = [];
template                    = [];
g                           = 1;

template.spm.stats.factorial_design.dir   = {out_dir};
for i = 1:numel(con_names) % contrast loop start            
    all_scans       = [];    
    for j = 1:numel(all_subs) % 2nd level subject loop start
        name        = sprintf('sub%03d',all_subs(j));
        a_dir       = fullfile(base_dir, name, anadirname);
        swcon_templ = sprintf('s%d%scon_%04d.nii',skern(1), dartel_prefix, i); % already exists because 2nd level ttests designed above        
        swcon_file  = spm_select('FPList', a_dir, swcon_templ);                                
        all_scans   = strvcat(all_scans, swcon_file);        
    end % 2nd level subject loop end
    
    % Pass images to cell
    template.spm.stats.factorial_design.des.anova.icell(i).scans = cellstr(all_scans);    
    
end % contrast loop end
    template.spm.stats.factorial_design.des.anova.dept = 1;
    template.spm.stats.factorial_design.des.anova.variance = 1;
    template.spm.stats.factorial_design.des.anova.gmsca = 0;
    template.spm.stats.factorial_design.des.anova.ancova = 0;
    
    template.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    template.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
    template.spm.stats.factorial_design.masking.tm.tm_none = 1;
    template.spm.stats.factorial_design.masking.im = 1;
    template.spm.stats.factorial_design.masking.em = {fullfile(base_dir, 'second_Level', [mask_name '.nii'])};
    template.spm.stats.factorial_design.globalc.g_omit = 1;
    template.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
    template.spm.stats.factorial_design.globalm.glonorm = 1;    

if do_nosub_anova_model
    matlabbatch{g} = template;
    g = g+1;
end

%-------------------------MODEL ESTIMATION---------------------------------
template = [];
template.spm.stats.fmri_est.spmmat = {fullfile(out_dir, 'SPM.mat')};
template.spm.stats.fmri_est.method.Classical = 1;

if do_nosub_anova_model
    matlabbatch{g} = template;
    g = g+1;
end

%-------------------------CONTRAST SPECIFICATION---------------------------
contrast_names                      = con_names; % condition names
tcons                               = eye(numel(contrast_names));
template                            = [];
ci                                  = 1;
template.spm.stats.con.delete       = 1;
template.spm.stats.con.spmmat       = {fullfile(out_dir, 'SPM.mat')};

template.spm.stats.con.consess{ci}.fcon.name     = 'eoi';
template.spm.stats.con.consess{ci}.fcon.convec   = eye(numel(con_names));
ci = ci+1;

template.spm.stats.con.consess{ci}.fcon.name     = 'eoi_without_ramps';
template.spm.stats.con.consess{ci}.fcon.convec   = [vertcat(eye(7), zeros(3,7)) zeros(10,2) vertcat(zeros(7,3),eye(3))];
ci = ci+1;

% Prepare flipped tcons
contrast_names = [contrast_names, strcat('-',contrast_names)];
tcons = vertcat(tcons, -tcons); 

for i = 1:numel(contrast_names)
    template.spm.stats.con.consess{ci}.tcon.name    = contrast_names{i};
    template.spm.stats.con.consess{ci}.tcon.convec  = tcons(i,:);
    template.spm.stats.con.consess{ci}.tcon.sessrep = 'none';
    ci = ci+1;
end

if do_nosub_anova_cons
    matlabbatch{g} = template;
    g = g+1;
end

if ~isempty(matlabbatch)
    spm_jobman('initcfg');
    spm('defaults', 'FMRI');
    spm_jobman('run',matlabbatch);
    copyfile(which(mfilename),out_dir);
end
%--------------------------------------------------------------------------
% SECOND LEVEL no subject ANOVA END
%--------------------------------------------------------------------------

cd(go_back); % so we don't end up in results folder

%==========================================================================
% FUNCTION chuckCell = splitvect(v, n)
%==========================================================================
function chuckCell = splitvect(v, n)
% Splits a vector into number of n chunks of  the same size (if possible).
% In not possible the chunks are almost of equal size.
%
% based on http://code.activestate.com/recipes/425044/

chuckCell = {};

vectLength = numel(v);


splitsize = 1/n*vectLength;

for i = 1:n
    %newVector(end + 1) =
    idxs = [floor(round((i-1)*splitsize)):floor(round((i)*splitsize))-1]+1;
    chuckCell{end + 1} = v(idxs);
end

%==========================================================================
% FUNCTION out = ins_letter(pscan,letter)
%==========================================================================
function out = ins_letter(pscan,letter)
for a=1:size(pscan,1)
    [p , f, e] = fileparts(pscan(a,:));
    out(a,:) = [p filesep letter f e];
end

%==========================================================================
% FUNCTION out = chng_path(pscan,pa)
%==========================================================================
function out = chng_path(pscan,pa)
for a=1:size(pscan,1)
    [p , f, e] = fileparts(pscan(a,:));
    out(a,:) = [pa filesep f e];
end

%==========================================================================
% FUNCTION run_matlab(np, matlabbatch, check)
%==========================================================================
function run_matlab(np, matlabbatch, check)

spm_path          = fileparts(which('spm')); %get spm path
mat_name          = which(mfilename);
[~,mat_name,~]    = fileparts(mat_name);


fname = [mat_name '_'  num2str(np) '.mat'];

save(fname,'matlabbatch');
lo_cmd  = ['clear matlabbatch;load(''' fname ''');'];
ex_cmd  = ['addpath(''' spm_path ''');spm(''defaults'',''FMRI'');spm_jobman(''initcfg'');spm_jobman(''run'',matlabbatch);'];
end_cmd = ['delete(''' fname ''');'];

% Because matlab from bash can only execute one statement upon startup we
% have to detour via a function
if isunix    
    str                 = strcat(lo_cmd, ex_cmd, end_cmd, 'exit');
    [~, name_stem]      = fileparts(fname); 
    function_name       = strcat(name_stem, '.m');  
    log_name            = strcat(name_stem, '.log');
    fh                  = fopen(function_name, 'w');
                      fprintf(fh, 'function %s\n', name_stem); % write header                        
    nbytes              = fprintf(fh, '%s', str); % write commands
    if ~nbytes
        warning('Nothing written to %s', function_name)
    else
        fprintf('\n%d bytes written to %s \n', function_name);
    end
    fclose(fh);
    cmd = sprintf('matlab -nodesktop -nosplash  -logfile %s -r "%s" &', log_name, name_stem); 
end

if ispc
    cmd = ['start matlab.exe -nodesktop -nosplash  -logfile ' num2str(np) '_' mat_name '.log -r "' lo_cmd ex_cmd ';exit"'];
end

if ~check    
    system(cmd);
end
