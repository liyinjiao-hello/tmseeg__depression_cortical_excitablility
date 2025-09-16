%%% adjust 1) groups
clear; clc; close all;

eeglab;

%% 1) Define Parameters
groups = {'HC'};  % Both groups: 'HC' and 'MDD'
mainDir = 'G:\resteeg\ALL_REST_EEG_RELAX\RELAXProcessed\Cleaned_Data';  
roiChannels = {'FZ', 'FCZ', 'CZ', 'FC1', 'FC2'};  % Frontal ROI electrodes
fs = 250;  % Sampling rate
nfft = 512;  % FFT points
window = hamming(512);  % Hamming window for pwelch

% Frequency range for PSD plot
fmin = 1; 
fmax = 45;

%% 2) Loop Over Groups (HC and MDD)
for g = 1:numel(groups)
    group = groups{g};
    subjects = arrayfun(@(x) sprintf('%s%02d', group, x), 1:12, 'UniformOutput', false);  % 'HC01' to 'HC12'
    
    % Initialize matrix to store group-level data (7 time points, frequency bins)
    group_psd = zeros(7, nfft/2+1);  % 7 time points, frequency bins (averaging across 5 electrodes)
    valid_subjects = zeros(7, 1);  % To track valid subjects for each time point
    
    %% 3) Loop Over Subjects
    for s = 1:numel(subjects)
        subjID = subjects{s};
        subjDir = mainDir;  % Files are directly under Cleaned_Data, no subfolders
        
        % Loop Over Time Points (preclose01 to preclose07)
        for tp = 1:7
            fileName = sprintf('%s_preclose%02d_RELAX.set', subjID, tp);
            filePath = fullfile(subjDir, fileName);
            
            if ~exist(filePath, 'file')
                continue;  % Skip missing files
            end
            if strcmp(group, 'MDD') && (s == 1 || s == 5 || s == 6 || s == 12) && tp == 6
                continue;  % Skip this iteration of the loop
            end
            if strcmp(group, 'HC') && (s == 11) && tp == 3
                continue;  % Skip this iteration of the loop
            end
            if strcmp(group, 'HC') && (s == 1) && (tp == 1 || tp == 4)
                continue;  % Skip this iteration of the loop
            end

            %% Load EEGLAB Data
            EEG = pop_loadset('filename', filePath);
            
            % Ensure ROI channels are present in the EEG data
            channelIdx = find(ismember({EEG.chanlocs.labels}, roiChannels));
            
            if isempty(channelIdx)
                warning('ROI channels not found in the data for %s - Time %d', subjID, tp);
                continue;
            end
            
            % Extract data for the ROI channels
            data = EEG.data(channelIdx, :);  % Only select ROI channels
            
            % Initialize PSD container for this subject and time point
            psd_all = zeros(length(channelIdx), nfft/2+1);  % Pre-allocate PSD storage
            
            % Compute PSD for each ROI channel using pwelch
            for ch = 1:length(channelIdx)
                [pxx, f] = pwelch(data(ch,:), window, [], nfft, fs, 'power'); % unit: uv^2/hz
                psd_all(ch, :) = pxx;  % Store PSD for each channel
            end
            
            % Average PSD across the 5 channels (ROI)
            avg_psd = mean(psd_all, 1);  % Average over channels
            
            % Accumulate the average PSD for this time point
            group_psd(tp, :) = group_psd(tp, :) + avg_psd;
            
            % Increment valid subject count for this time point
            valid_subjects(tp) = valid_subjects(tp) + 1;
        end
    end
    
    %% 4) Plot Group-Level Data (7 time points, average across electrodes)
    figure('Name', sprintf('%s - Group PSD Plot', group), 'NumberTitle', 'off');
    
    % Compute the average PSD for each time point (divide by valid subjects)
    for tp = 1:7
        if valid_subjects(tp) > 0  % Only plot if there are valid subjects
            disp(['Timepoint: ', num2str(tp), ' has valid subjects.']);
            disp(valid_subjects)
            avg_psd = group_psd(tp, :) / valid_subjects(tp);  % Average by the number of valid subjects
            plot(f, 10*log10(avg_psd), 'LineWidth', 2);  % Plot each time point's average PSD
            hold on;
        else
            disp(['Skipping time point ', num2str(tp), ' for group ', group, ' due to no valid subjects.']);
        end
    end
    
    % Set plot properties
    xlabel('Frequency (Hz)');
    ylabel('Power (dB)');
    xlim([fmin fmax]);  % Limit x-axis between 0.5 Hz and 45 Hz
    ylim([-20 15]);  % Limit y-axis between -30 dB and 10 dB
    legend(arrayfun(@(x) sprintf('Time Point %d', x), 1:7, 'UniformOutput', false), 'Location', 'northeast');
    title([group, ' - Group Average PSD']);
    grid on;
    set(gcf, 'Position', [100, 100, 1200, 800]);  % Increase figure size
end

