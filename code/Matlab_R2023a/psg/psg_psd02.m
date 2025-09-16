
suffix  = 'psd';  % savename in this step 

%% convert to fieldtrip format
data_ft = eeglab2fieldtrip(EEG, 'preprocessing', 'none');
% parameter setting
cfg = [];
cfg.channel = {'F3', 'F4', 'Fz'}; % frontal swa activity
data_ft = ft_selectdata(cfg, data_ft);  % now data_ft only contains F3, F4, Fz------
cfg = [];
cfg.length = 5;        
cfg.overlap = 0;       
data_seg = ft_redefinetrial(cfg, data_ft); 
cfg = [];
cfg.method = 'mtmfft';
cfg.output = 'pow';
cfg.taper = 'hanning';
cfg.foilim = [0.5 30];     % frequency range of interest
cfg.pad = 'nextpow2';      % zero padding to next power of 2
cfg.keeptrials = 'yes';    % keep individual trials
% FFT 
freq = ft_freqanalysis(cfg, data_seg);  % freq.powspctrm: [segments x channels x freqs]


%save
if strcmpi(group,'HC')
    baseDir = 'F:\03_PSG\HC_staged\';
    edfFile = fullfile(baseDir, sprintf('HC%s_reduced.edf',      subStr));
    savename = sprintf('%s%s_%s', group, subStr, suffix);
    setName  = [ savename '.set' ];
    txtFile = fullfile(baseDir, sprintf('HC%s.TXT',              subStr));
    twoCol  = fullfile(baseDir, sprintf('HC%s_twocolumns.TXT',   subStr));

    EEG = pop_saveset( EEG,     'filename',setName, 'filepath',baseDir);
elseif strcmpi(group,'MDD')
    baseDir = 'F:\03_PSG\MDD_staged\';
    edfFile = fullfile(baseDir, sprintf('MDD%s_reduced.edf',     subStr));
    savename = sprintf('%s%s_%s', group, subStr, suffix); % 
    setName  = [ savename '.set' ];
    txtFile = fullfile(baseDir, sprintf('MDD%s.TXT',             subStr));
    twoCol  = fullfile(baseDir, sprintf('MDD%s_twocolumns.TXT',  subStr));

    EEG = pop_saveset( EEG,     'filename',setName, 'filepath',baseDir);
end
disp(setName)


