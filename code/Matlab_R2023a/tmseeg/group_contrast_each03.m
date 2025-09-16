clc; clear;

% 1) Initialize EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% 2) Define groups and their base paths
groups = {'HC', 'MDD'};
basePaths = {'F:\TEP_HC_preprocessed', 'F:\TEP_MDD_preprocessed'};

% 3) Time point file (adjust as needed)
timePointFile = 'F404_check.set';  

% 4) Define the ROI electrodes
roi_electrodes = {'AF4', 'F4', 'F2', 'F6', 'FC2', 'FC6', 'FC4'};

% 5) Prepare structure for storing results
group_results = struct();

% 6) List of files to skip (because of different epoch durations)
%    Adjust paths/timepoint file names to match *exactly* how they appear on dis
skipList = {
    fullfile('F:\TEP_MDD_preprocessed','MDD02','TMS','F407_check.set'), ...
    fullfile('F:\TEP_HC_preprocessed','HC01','TMS','F406_check.set'),  ...
    fullfile('F:\TEP_HC_preprocessed','HC07','TMS','F403_check.set')
};

%% ------------------------------------------------------------
% 7) Process each group
for i = 1:length(groups)
    group = groups{i};
    basePath = basePaths{i};

    all_data = [];      % will hold [subject x timepoints]
    time_vector = [];   % store the EEG.times from the first valid file

    % Loop over 12 subjects in this group
    for s = 1:12
        % Compose the file path, e.g. "F:\TEP_HC_preprocessed\HC01\TMS\F401_check.set"
        subject_folder = fullfile(basePath, sprintf('%s%02d', group, s), 'TMS');
        filePath = fullfile(subject_folder, timePointFile);

        % Skip if it's in the skipList
        if ismember(filePath, skipList)
            warning('Skipping file (different epoch duration): %s', filePath);
            continue;
        end

        % If the file doesn't exist, skip with a warning
        if ~exist(filePath, 'file')
            warning('File not found: %s', filePath);
            continue;
        end

        % Load EEG data
        EEG = pop_loadset('filename', filePath);

        % Store the time vector once from the first valid subject
        if isempty(time_vector)
            time_vector = EEG.times;
        end

        % Identify ROI channels
        roi_indices = find(ismember({EEG.chanlocs.labels}, roi_electrodes));
        if isempty(roi_indices)
            warning('No ROI channels found in file: %s', filePath);
            continue;
        end

        % Average over trials (3rd dim) => [ROIchannels x timepoints]
        roi_avg = squeeze(mean(EEG.data(roi_indices, :, :), 3));

        % Then average across ROI channels => [1 x timepoints]
        subject_avg = mean(roi_avg, 1);

        % Accumulate this subject's data in rows => [subjects x timepoints]
        all_data = [all_data; subject_avg]; %#ok<AGROW>
    end

    % If no valid data for this group, skip
    if isempty(all_data)
        warning('No valid data found for group: %s (all files skipped?)', group);
        group_results.(group) = struct('avg', [], 'ci', [], 'time_vector', []);
        continue;
    end

    % Compute group-level average and CI
    avg = mean(all_data, 1); 
    ci = std(all_data, 0, 1) / sqrt(size(all_data, 1));

    % Store results in the group_results structure
    group_results.(group).avg = avg;
    group_results.(group).ci = ci;
    group_results.(group).time_vector = time_vector;
end

%% ------------------------------------------------------------
% 8) Plotting results (only if both groups have valid data)
if ~isempty(group_results.HC.avg) && ~isempty(group_results.MDD.avg)
    figure;
    hold on;

    % Define line colors
    hc_color = [0, 114, 189] / 255;  
    mdd_color = [217, 83, 25] / 255;

    % Define CI fill colors
    hc_ci_color = [127, 184, 222] / 255; 
    mdd_ci_color = [241, 190, 169] / 255;

    % -- Plot HC --
    hc = group_results.HC;
    hc_line = plot(hc.time_vector, hc.avg, 'Color', hc_color, 'LineWidth', 1.5);
    fill([hc.time_vector, fliplr(hc.time_vector)], ...
         [hc.avg + hc.ci, fliplr(hc.avg - hc.ci)], ...
         hc_ci_color, 'FaceAlpha', 0.2, 'EdgeColor', 'none');

    % -- Plot MDD --
    mdd = group_results.MDD;
    mdd_line = plot(mdd.time_vector, mdd.avg, 'Color', mdd_color, 'LineWidth', 1.5);
    fill([mdd.time_vector, fliplr(mdd.time_vector)], ...
         [mdd.avg + mdd.ci, fliplr(mdd.avg - mdd.ci)], ...
         mdd_ci_color, 'FaceAlpha', 0.2, 'EdgeColor', 'none');

    % Legend and labels
    legend([hc_line, mdd_line], {'HC', 'MDD'}, 'TextColor', 'k', ...
           'Location', 'NorthEast', 'FontSize', 10);
    xlabel('Time (ms)', 'FontSize', 12);
    ylabel('Amplitude (\muV)', 'FontSize', 12);

    % Title: extract the time point number from the file name (e.g., 'F401_check.set')
    timePointNumber = regexp(timePointFile, 'F40(\d+)', 'tokens', 'once');
    if ~isempty(timePointNumber)
        timePointNumber = timePointNumber{1};
    else
        timePointNumber = '??';  % fallback
    end
    title(sprintf('TEP of Time Point %s Between HC and MDD', timePointNumber));

    % Axes settings
    ylim([-3.5 3.5]);
    xlim([-100 500]);
    grid on;
    hold off;
else
    warning('Either HC or MDD had no valid data. No plot generated.');
end
