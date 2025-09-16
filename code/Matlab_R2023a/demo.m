% demo_run.m — minimal visual demo (no saving)
% Shows:
%   1) Butterfly (all channels) with ROI mean (RED)
%   2) Topomap panel at N45, P60, N100, P180
% Requires: EEGLAB (+ TESA/FieldTrip available), MATLAB R2023a+

close all; clc;

% =========================
% Fixed input .SET file
% =========================
data_dir  = 'F:\z_outputbackup\Paper_source_data\FigS1\';
data_file = 'HC01_F405_check.set';
fullpath  = fullfile(data_dir, data_file);

% =========================
% ROI & topo settings
% =========================
roi_labels     = {'AF4','F4','F2','F6','FC2','FC6','FC4'};   % edit as needed
latencies_ms   = [36 60 84 171];                             % N45, P60, N100, P180
tep_components = {'N45','P60','N100','P180'};

% =========================
% EEGLAB setup & load data
% =========================
if isempty(which('eeglab'))
    error('EEGLAB not found on MATLAB path. Add EEGLAB before running.');
end
eeglab nogui;

if ~exist(fullpath, 'file')
    error('Demo file not found:\n  %s\nCheck the path or file name.', fullpath);
end

EEG = pop_loadset('filename', data_file, 'filepath', data_dir);
fprintf('Loaded: %s\n', fullpath);

% =========================
% Butterfly plot + ROI mean
% =========================
figure('Color','w','Position',[100 100 900 520]);

% All-channel TEP butterfly
pop_tesa_plot(EEG, 'tepType','data', 'xlim',[-100 600], 'CI','off', 'plotPeak','off');
hold on;

% Compute ROI mean across trials and channels
all_labels = {EEG.chanlocs.labels};
roi_idx    = find(ismember(all_labels, roi_labels));

if isempty(roi_idx)
    warning('None of the ROI channels (%s) were found in EEG.chanlocs.', strjoin(roi_labels, ', '));
else
    EEG_avg_trials = mean(EEG.data, 3);                 % [channels x time]
    roi_mean       = mean(EEG_avg_trials(roi_idx,:),1);  % 1 x time
    time_ms        = EEG.times;

    % --- RED ROI mean line ---
    h = plot(time_ms, roi_mean, 'r', 'LineWidth', 2);

    % Clean legend (ROI only)
    legend(h, sprintf('ROI mean: %s', strjoin(roi_labels,',')), ...
        'Location','northeast','FontSize',9,'Box','off');
end

xlabel('Time (ms)','FontSize',12,'FontName','Arial');
ylabel('\muV','FontSize',12,'FontName','Arial');
xlim([-100 500]);
set(gca,'FontSize',12,'FontName','Arial');
hold off;

% =========================
% Topomap panel (1 x 4)
% =========================
% Mean over ±5 ms around each latency
allData = zeros(EEG.nbchan, numel(latencies_ms));
for j = 1:numel(latencies_ms)
    t   = latencies_ms(j);
    idx = EEG.times >= (t-5) & EEG.times <= (t+5);
    if ~any(idx)
        error('No EEG samples found around %d ms. Check EEG.times.', t);
    end
    allData(:,j) = mean(EEG.data(:, idx), 2);
end

figure('Color','w','Position',[100 100 1000 350]);
for j = 1:numel(latencies_ms)
    subplot(1, numel(latencies_ms), j);
    topoplot(allData(:,j), EEG.chanlocs, ...
        'maplimits', [-7 7], ...   % fixed scale for comparability
        'electrodes','off');
    title(tep_components{j}, 'FontSize',12, 'FontName','Arial');
    if j == numel(latencies_ms)
        cb = colorbar; ylabel(cb, '\muV','FontSize',12,'FontName','Arial');
    end
end

