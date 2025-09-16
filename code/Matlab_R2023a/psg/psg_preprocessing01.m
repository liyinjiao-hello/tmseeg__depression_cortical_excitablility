%% adjust group = HC or MDD
group   = 'MDD';   
subject = 12;     
suffix  = 'before';   % savename in this step

subStr = sprintf('%02d', subject);  
%% 01
% import
if strcmpi(group,'HC')
    baseDir = 'F:\03_PSG\HC_staged\';
    edfFile = fullfile(baseDir, sprintf('HC%s_reduced.edf',      subStr));
    savename = sprintf('%s%s_%s', group, subStr, suffix); % e.g. 'HC01_psd'
    setName  = [ savename '.set' ];  
    txtFile = fullfile(baseDir, sprintf('HC%s.TXT',              subStr));
    twoCol  = fullfile(baseDir, sprintf('HC%s_twocolumns.TXT',   subStr));
    EEG = pop_biosig(edfFile,    'importevent','off');
elseif strcmpi(group,'MDD')
    baseDir = 'F:\03_PSG\MDD_staged\';
    edfFile = fullfile(baseDir, sprintf('MDD%s_reduced.edf',     subStr));
    savename = sprintf('%s%s_%s', group, subStr, suffix); % e.g. 'HC01_psd'
    setName  = [ savename '.set' ];   
    txtFile = fullfile(baseDir, sprintf('MDD%s.TXT',             subStr));
    twoCol  = fullfile(baseDir, sprintf('MDD%s_twocolumns.TXT',  subStr));
    EEG = pop_biosig(edfFile,    'importevent','off');
end
% filtering
EEG = pop_eegfiltnew(EEG, 'locutoff',0.5,'hicutoff',30,'plotfreqz',1);
% re-ref
EEG = pop_reref( EEG, [5 6] ,'keepref','on');



%% 02 event preparation
% Step 1: Load the .txt file, these event files are exported from staged
% PSG
if strcmpi(group,'HC')
    baseDir = 'F:\03_PSG\HC_staged\';
    edfFile = fullfile(baseDir, sprintf('HC%s_reduced.edf',      subStr));
    savename = sprintf('%s%s_%s', group, subStr, suffix); % e.g. 'HC01_psd'
    setName  = [ savename '.set' ];
    txtFile = fullfile(baseDir, sprintf('HC%s.TXT',              subStr));
    twoCol  = fullfile(baseDir, sprintf('HC%s_twocolumns.TXT',   subStr));

    stages = importdata(         txtFile);
    n_epochs = length(stages);
    epoch_duration = 30;
    latencies_sec = (0:n_epochs-1)' * epoch_duration;
    events = [stages, num2cell(latencies_sec)];
    writecell(events,            twoCol,     'Delimiter','tab');

elseif strcmpi(group,'MDD')
    baseDir = 'F:\03_PSG\MDD_staged\';
    edfFile = fullfile(baseDir, sprintf('MDD%s_reduced.edf',     subStr));
    savename = sprintf('%s%s_%s', group, subStr, suffix); % e.g. 'HC01_psd'
    setName  = [ savename '.set' ];
    txtFile = fullfile(baseDir, sprintf('MDD%s.TXT',             subStr));
    twoCol  = fullfile(baseDir, sprintf('MDD%s_twocolumns.TXT',  subStr));

    stages = importdata(         txtFile);
    n_epochs = length(stages);
    epoch_duration = 30;
    latencies_sec = (0:n_epochs-1)' * epoch_duration;
    events = [stages, num2cell(latencies_sec)];
    writecell(events,            twoCol,     'Delimiter','tab');
end



%% 03 adding sleep cycle manually according to staging data by clinical physician, because we just include first four sleep cycles


%% 04import event
if strcmpi(group,'HC')
    baseDir = 'F:\03_PSG\HC_staged\';
    edfFile = fullfile(baseDir, sprintf('HC%s_reduced.edf',      subStr));
    savename = sprintf('%s%s_%s', group, subStr, suffix); % e.g. 'HC01_psd'
    setName  = [ savename '.set' ];
    txtFile = fullfile(baseDir, sprintf('HC%s.TXT',              subStr));
    twoCol  = fullfile(baseDir, sprintf('HC%s_twocolumns.TXT',   subStr));

    EEG = pop_importevent( EEG,  'event',twoCol, 'fields',{'type','latency'},'timeunit',1);
    % epoch
    EEG = pop_epoch( EEG, {  }, [0  30], 'newname', 'EDF file epochs', 'epochinfo', 'yes');
    EEG = pop_saveset( EEG,     'filename',setName, 'filepath',baseDir);
elseif strcmpi(group,'MDD')
    baseDir = 'F:\03_PSG\MDD_staged\';
    edfFile = fullfile(baseDir, sprintf('MDD%s_reduced.edf',     subStr));
    savename = sprintf('%s%s_%s', group, subStr, suffix); % e.g. 'HC01_psd'
    setName  = [ savename '.set' ];
    txtFile = fullfile(baseDir, sprintf('MDD%s.TXT',             subStr));
    twoCol  = fullfile(baseDir, sprintf('MDD%s_twocolumns.TXT',  subStr));

    EEG = pop_importevent( EEG,  'event',twoCol, 'fields',{'type','latency'},'timeunit',1);
    % epoch
    EEG = pop_epoch( EEG, {  }, [0  30], 'newname', 'EDF file epochs', 'epochinfo', 'yes');
    EEG = pop_saveset( EEG,     'filename',setName, 'filepath',baseDir);
end
disp(setName)



%% 05 select n2n3 manually
% first four cycles adjusted manually according to staging data by clinical physician
EEG = pop_select( EEG, 'trial',29:950 ); % adjusted the number for each PSG file
% select
EEG = pop_selectevent( EEG, 'omittype',{'N1','R','W'},'deleteevents','off','deleteepochs','on','invertepochs','off');


%% 06 remove bad epoch manually!
pop_eegplot( EEG, 1, 1, 1);

% realign
nEpochs = EEG.trials;           % number of remaining epochs
nEvents = length(EEG.event);    % number of remaining events
if nEvents~=nEpochs
    error('You must have exactly one event per epoch for this script to work.')
end
for ev = 1:nEvents   
    EEG.event(ev).epoch      = ev;
    EEG.event(ev).Init_index = ev;   
end
EEG = eeg_checkset(EEG, 'eventconsistency');

% save as .set
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





