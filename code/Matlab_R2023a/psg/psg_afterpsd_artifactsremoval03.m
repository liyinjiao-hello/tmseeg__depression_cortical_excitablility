%% 20-30HZ muscle artifacts removal---muscle artifacts
band = [20 30];  % Frequency range of interest (20-30 Hz)
band_idx = find(freq.freq >= band(1) & freq.freq <= band(2));  % Index for the frequency band
band_power= squeeze(sum(freq.powspctrm(:, :, band_idx), 3));  % Sum power across the frequency range for each segment
nSeg        = size(band_power,1);
all_outlier = false(nSeg,1);

for ch = 1:3
    % 1) compute scalar mean & std for this channel
    m = mean(band_power(:,ch));
    s = std( band_power(:,ch) );

    % 2) define the low/high thresholds (scalars)
    thr_low = m - 3*s;
    thr_up  = m + 3*s;

    % 3) find segments outside [thr_low, thr_up]
    outlier = band_power(:,ch) < thr_low ...
           | band_power(:,ch) > thr_up;

    % 4) accumulate
    all_outlier = all_outlier | outlier;

    % 5) display
    %fprintf('Channel %s: mean=%.2f, std=%.2f, thr=[%.2f, %.2f]\n', ...
          %  freq.label{ch}, m, s, thr_low, thr_up);
   % fprintf('  outlier epochs: %s\n\n', mat2str(find(outlier)'));
end
% finally, your master list (no duplicates, since it's logical)
outlier_seg = find(all_outlier);
% map each segment to its epoch
epoch_nums = ceil(outlier_seg / 6);
outlier_epoch = unique(epoch_nums);
n_outlier_epoch = numel(outlier_epoch);    
fprintf('20-30HZ： %d bad epochs\n', n_outlier_epoch);
fprintf('All outlier epochs (swa): %s\n', mat2str(outlier_epoch'));
artifacts_high = outlier_epoch(:)';   %If you want a space‑separated string: 
artifacts_high = sprintf('%d ', artifacts_high);  
artifacts_high= strtrim(artifacts_high);  


%% amp outlier removal > mean+-3sd
% Identify F3, F4, Fz channels
chan_labels = {'F3','F4','Fz'};
chan_idx    = find(ismember({EEG.chanlocs.labels}, chan_labels));
all_bad     = [];
figure;
for i = 1:numel(chan_idx)
    idx      = chan_idx(i);
    name     = chan_labels{i};
    
    % compute per-epoch max absolute amplitude
    max_amp  = squeeze(max(abs(EEG.data(idx,:,:)), [], 2));
    
    % threshold = mean ± 3*std
    mu       = mean(max_amp);
    sigma    = std(max_amp);
    thr_lo   = mu - 3*sigma;
    thr_hi   = mu + 3*sigma;
    
    % find bad epochs
    bad_epochs = find(max_amp < thr_lo | max_amp > thr_hi);
    all_bad    = union(all_bad, bad_epochs);
    
    % plot histogram
    subplot(1, numel(chan_idx), i);
    histogram(max_amp, 0:20:500);
    xlim([0 500]);
    title(name);
    xlabel('Max |Amplitude| (µV)');
    ylabel('Count');
    hold on;
    yL = ylim;
    plot([thr_lo thr_lo], yL, '--r');
    plot([thr_hi thr_hi], yL, '--r');
    hold off;
end
% report
n_bad = numel(all_bad);
fprintf('Amplitude outliers (mean±3σ): %d epochs\n', n_bad);
fprintf('Bad epochs: %s\n', mat2str(all_bad'));
artifacts_amp = all_bad(:)';   %If you want a space‑separated string: 
artifacts_amp = sprintf('%d ', artifacts_amp);  
artifacts_amp= strtrim(artifacts_amp

%% then manually remove these bad epoches using eeglab GUI( finally, <10% epoches are removed)







