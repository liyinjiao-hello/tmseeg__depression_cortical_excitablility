%% Setup -------------------------
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;  % Initialize EEGLAB

% ==== MANUAL INPUT ====
group_name = 'MDD';  % Change to 'MDD' or 'HC' as needed
base_dir = fullfile('F:\TEP_MDD_preprocessed', filesep);  % Root folder for MDD or HC data
latency_file = 'D:\Project\Data_analysis\Output\Python_output\recheck\TEP_latenciesBroader_recheck.xlsx';  % Latency data

% Output path per group
if strcmp(group_name, 'HC')
    output_file = 'D:\Project\Data_analysis\Output\Python_output\recheck\TEP_hcPeak_recheck.xlsx';
    subject_offset = 0;  % HC subject IDs stay 1–12
else
    output_file = 'D:\Project\Data_analysis\Output\Python_output\recheck\TEP_mddPeak_recheck.xlsx';
    subject_offset = 12; % MDD IDs start from 13–24
end

% Define TEP components and electrodes
tep_components = {'N45', 'P60', 'N100', 'P180'}; 
selected_electrodes = {'AF4', 'F4', 'F2', 'F6', 'FC2', 'FC6', 'FC4'};

% Load latency data
latency_data = readtable(latency_file);

% Preallocate results table for efficiency
results = table();

%% Loop through subjects -------------------------
for subj_idx = 1:12
    subj_number_str = sprintf('%02d', subj_idx);  % e.g., '01'
    full_subject_id = subj_idx + subject_offset;  % e.g., 13 if MDD01

    subj_folder = fullfile(base_dir, [group_name subj_number_str], 'TMS');
    
    fprintf('\n▶ Processing %s Subject %02d (%s)\n', group_name, subj_idx, subj_folder);

    %% Loop through timepoints -------------------------
    for t = 1:7
        set_filename = sprintf('F4%02d_check.set', t);  % e.g., F401_check.set
        set_path = fullfile(subj_folder, set_filename);

        if ~exist(set_path, 'file')
            fprintf('  File not found: %s\n', set_path);
            continue;
        end

        EEG = pop_loadset('filename', set_path);

        % Get ROI electrode indices
        electrode_labels = {EEG.chanlocs.labels};
        electrode_indices = find(ismember(electrode_labels, selected_electrodes));

        % Compute ROI mean signal
        EEG_avg_trials = mean(EEG.data, 3);  % [channels x time]
        ROI_mean_signal = mean(EEG_avg_trials(electrode_indices, :), 1);

        %% Loop through TEP components -------------------------
        for j = 1:length(tep_components)
           
            tep_name = tep_components{j};

            % Get latency for this subject/timepoint/TEP
            latencies = latency_data.Value(latency_data.id == full_subject_id & ...
                strcmp(latency_data.TEP, tep_name) & ...
                latency_data.TimePoint == t);

            if isempty(latencies) || isnan(latencies)
                fprintf('   Missing latency: %s at T%d\n', tep_name, t);
                continue;
            end

            % Ensure latencies is scalar
            latency_ms = latencies(1);  
            disp(latency_ms)

            time_vector = EEG.times;
            center_idx = find(time_vector >= latency_ms, 1);

            if isempty(center_idx)
                fprintf('   Latency %g ms out of bounds.\n', latency_ms);
                continue;
            end

            % Get ±5 ms window
            start_idx = find(time_vector >= latency_ms - 5, 1);
            end_idx = find(time_vector >= latency_ms + 5, 1);
            time_window = ROI_mean_signal(start_idx:end_idx);
            average_amplitude = mean(time_window);

            % Save result in table
            new_row = table(full_subject_id, t, string(tep_components{j}), latency_ms, average_amplitude, ...
                'VariableNames', {'id', 'TimePoint', 'TEP', 'Latency', 'Value'});
            results = [results; new_row];  % Append result
        end
    end
end

%% Save results -------------------------
writetable(results, output_file, 'WriteMode', 'append', 'Sheet', 1);
disp('All subjects processed and results saved.');
