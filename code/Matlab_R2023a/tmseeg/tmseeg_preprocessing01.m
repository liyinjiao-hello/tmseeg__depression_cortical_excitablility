
close all; clc;
eeglab;
%% -------------------- CONFIG --------------------
group          = 'HC';      % 'HC' or 'MDD'
F40X_number    = 1;         % 1,2,3,4... -> F401, F402, ...
subject_number = 12;        % 1..N       -> HC01 / MDD01
baseDir        = 'G:\';     % base directory that contains TEP_*_preprocessed
epochEvent     = 'TMS';     % event name to epoch around
epochWin       = [-0.7 0.7];% seconds

% Build paths & filenames
F40X_base       = sprintf('F40%d', F40X_number);
subject_folder  = sprintf('%s%02d', upper(group), subject_number);

if strcmpi(group,'MDD')
    dataDir = fullfile(baseDir, 'TEP_MDD_preprocessed', subject_folder, 'TMS');
elseif strcmpi(group,'HC')
    dataDir = fullfile(baseDir, 'TEP_HC_preprocessed', subject_folder, 'TMS');
else
    error('Unknown group: %s (use "HC" or "MDD").', group);
end
if ~exist(dataDir,'dir'), mkdir(dataDir); end

inFile  = sprintf('%s_removed.set',   F40X_base);   % expected input
out1    = sprintf('%s_firstica.set',  F40X_base);   % after 1st ICA + interp
out2    = sprintf('%s_secondica.set', F40X_base);   % after 2nd ICA + interp + reref

fprintf('--- TMS-EEG preprocessing ---\n');
fprintf('Group: %s | Subject: %s | Dataset: %s\n', upper(group), subject_folder, F40X_base);
fprintf('Data dir: %s\n', dataDir);
fprintf('Input file: %s\n\n', inFile);

%% -------------------- LOAD --------------------
assert(exist(fullfile(dataDir,inFile),'file')==2, ...
    'Input file not found: %s', fullfile(dataDir,inFile));

EEG = pop_loadset('filename', inFile, 'filepath', dataDir);
EEG.setname = sprintf('%s_removed', F40X_base);
EEG = eeg_checkset(EEG);

%% -------------------- EPOCH AROUND TMS --------------------
evNames = unique(string({EEG.event.type}));
if ~ismember(string(epochEvent), evNames)
    error('Event "%s" not found. Available events: %s', epochEvent, strjoin(evNames,', '));
end

EEG = pop_epoch(EEG, {epochEvent}, epochWin, 'epochinfo','yes');
EEG.setname = sprintf('%s_epoched', F40X_base);
EEG = eeg_checkset(EEG);

%% -------------------- REMOVE TMS PULSE WINDOW (TESA) --------------------
% Units are milliseconds for tesa_removedata
EEG = pop_tesa_removedata(EEG, [-2 15]);
EEG.setname = sprintf('%s_epoched_pulserem', F40X_base);
EEG = eeg_checkset(EEG);

%% -------------------- 1st ICA --------------------
EEG = pop_tesa_fastica(EEG, 'approach','symm','g','tanh','stabilization','off');
EEG.setname = sprintf('%s_firstICA_unpruned', F40X_base);
EEG = eeg_checkset(EEG);

% Component selection (Round 1) — keep your thresholds, non-interactive
EEG = pop_tesa_compselect(EEG, ...
    'compCheck','off', 'remove','on', 'saveWeights','off', 'figSize','large', ...
    'plotTimeX',[-100 500], 'plotFreqX',[1 100], 'freqScale','log', ...
    'tmsMuscle','on', 'tmsMuscleThresh',8, 'tmsMuscleWin',[11 30], 'tmsMuscleFeedback','off', ...
    'blink','off', 'blinkThresh',2.5, 'blinkElecs',{'Fp1','Fp2'}, 'blinkFeedback','off', ...
    'move','off', 'moveThresh',2, 'moveElecs',{'F7','F8'}, 'moveFeedback','off', ...
    'muscle','off', 'muscleThresh',-0.31, 'muscleFreqIn',[7 70], 'muscleFreqEx',[48 52], 'muscleFeedback','off', ...
    'elecNoise','off', 'elecNoiseThresh',4, 'elecNoiseFeedback','off');
EEG.setname = sprintf('%s_firstICA_pruned', F40X_base);
EEG = eeg_checkset(EEG);

%% -------------------- INTERPOLATE PULSE-SUPPRESSED SAMPLES --------------------
EEG = pop_tesa_interpdata(EEG, 'linear');
EEG.setname = sprintf('%s_firstICA_interp', F40X_base);
EEG = eeg_checkset(EEG);

%% -------------------- SAVE AFTER 1st ICA --------------------
EEG = pop_saveset(EEG, 'filename', out1, 'filepath', dataDir);
fprintf('Saved 1st-ICA dataset: %s\n', fullfile(dataDir,out1));

%% -------------------- FILTERS --------------------
% Bandpass 1–45 Hz and notch at 48–52 Hz and 60–64 Hz (adjust if needed)
EEG = pop_tesa_filtbutter(EEG, 1, 45, 4, 'bandpass');
EEG = pop_tesa_filtbutter(EEG, 48, 52, 4, 'bandstop');
EEG = pop_tesa_filtbutter(EEG, 60, 64, 4, 'bandstop');
EEG.setname = sprintf('%s_bp_notch', F40X_base);
EEG = eeg_checkset(EEG);

%% -------------------- DROP NON-EEG CHANNELS IF PRESENT --------------------
toDrop = intersect({'M1','M2','TRIGGER'}, string({EEG.chanlocs.labels}));
if ~isempty(toDrop)
    EEG = pop_select(EEG, 'rmchannel', cellstr(toDrop));
    fprintf('Dropped non-EEG channels: %s\n', strjoin(cellstr(toDrop),', '));
end
EEG = eeg_checkset(EEG);

%% -------------------- 2nd ICA --------------------
EEG = pop_tesa_fastica(EEG, 'approach','symm','g','tanh','stabilization','off');
EEG.setname = sprintf('%s_secondICA_unpruned', F40X_base);
EEG = eeg_checkset(EEG);

% Component selection (Round 2) — enable all detections as you set
EEG = pop_tesa_compselect(EEG, ...
    'compCheck','off', 'remove','on', 'saveWeights','off', 'figSize','large', ...
    'plotTimeX',[-150 450], 'plotFreqX',[1 100], 'freqScale','log', ...
    'tmsMuscle','on', 'tmsMuscleThresh',8, 'tmsMuscleWin',[11 30], 'tmsMuscleFeedback','off', ...
    'blink','on', 'blinkThresh',2.5, 'blinkElecs',{'Fp1','Fp2'}, 'blinkFeedback','off', ...
    'move','on', 'moveThresh',2, 'moveElecs',{'F7','F8'}, 'moveFeedback','off', ...
    'muscle','on', 'muscleThresh',-0.31, 'muscleFreqIn',[7 70], 'muscleFreqEx',[48 52], 'muscleFeedback','off', ...
    'elecNoise','on', 'elecNoiseThresh',4, 'elecNoiseFeedback','off');
EEG.setname = sprintf('%s_secondICA_pruned', F40X_base);
EEG = eeg_checkset(EEG);

%% -------------------- INTERPOLATE MISSING CHANNELS BACK (SPHERICAL) --------------------
removedChans = EEG.chaninfo.removedchans;
if ~isempty(removedChans)
    skip = ismember(string({removedChans.labels}), {'TRIGGER','M1','M2'}); % never restore these
    toInterp = removedChans(~skip);
    if ~isempty(toInterp)
        EEG = pop_interp(EEG, toInterp, 'spherical');
        fprintf('Interpolated channels: %s\n', strjoin({toInterp.labels},', '));
    end
end
EEG = eeg_checkset(EEG);

%% -------------------- RE-REFERENCE (COMMON AVERAGE) --------------------
EEG = pop_reref(EEG, []);
EEG.setname = sprintf('%s_secondICA_final', F40X_base);
EEG = eeg_checkset(EEG);

%% -------------------- SAVE FINAL --------------------
EEG = pop_saveset(EEG, 'filename', out2, 'filepath', dataDir);
fprintf('Saved FINAL dataset: %s\n', fullfile(dataDir,out2));
fprintf('Done.\n');
