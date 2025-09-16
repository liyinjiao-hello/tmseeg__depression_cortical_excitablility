%%
%Loops over all 12 subjects in each group, computes each subject.s 30-min–binned SWA, and stores it........

%Determines the maximum bin‐count (maxBins) across all subjects and pads each subject%s vector with NaN so you can build two [maxBins×12] matrices.

%Computes the group mean at each bin (ignoring NaN) and fits an exponential to those mean curves.

%Pools every subject%s individual bins into two long vectors and scatters them.

%Overlays the two fitted exponentials (dark blue for HC, dark red for MDD).

%% 0) Setup
groups        = {'HC','MDD'};
nSegPerEpoch  = 6;      % 6×5 s = 30 s epochs
binSize       = 60;     % 60 epochs × 30 s = 30 min

nSubjects     = 12;     % per group

% Pre-allocate storage
swa_raw.HC    = cell(nSubjects,1);
swa_raw.MDD   = cell(nSubjects,1);
all_nBins.HC  = zeros(nSubjects,1);
all_nBins.MDD = zeros(nSubjects,1);

%% 1) Loop over every subject in each group
for gi = 1:2
  group = groups{gi};
  
  for i = 1:nSubjects
    % — Load the EEGLAB .set —
    subStr = sprintf('%02d', i);
    if strcmpi(group,'HC')
      baseDir = 'F:\03_PSG\HC_staged\';
    else
      baseDir = 'F:\03_PSG\MDD_staged\';
    end
    fname = sprintf('%s%s_exp.set', group, subStr);
    EEG   = pop_loadset('filename',fname,'filepath',baseDir);

    % — Compute PSD with FieldTrip —
    data_ft = eeglab2fieldtrip(EEG,'preprocessing','none');
    cfg      = []; cfg.channel = {'F3','F4','Fz'};
    data_ft  = ft_selectdata(cfg, data_ft);
    cfg      = []; cfg.length=5; cfg.overlap=0;
    data_seg = ft_redefinetrial(cfg, data_ft);
    cfg      = []; 
    cfg.method     = 'mtmfft';
    cfg.output     = 'pow';
    cfg.taper      = 'hanning';
    cfg.foilim     = [0.5 30];
    cfg.pad        = 'nextpow2';
    cfg.keeptrials = 'yes';
    freq = ft_freqanalysis(cfg, data_seg);

    % — Extract SWA per 30 s epoch —
    nEpochs   = size(freq.powspctrm,1) / nSegPerEpoch;
    swa_epoch = nan(nEpochs,1);
    swa_idx   = freq.freq >= 0.5 & freq.freq <= 4;
    for ep = 1:nEpochs
      segs = (ep-1)*nSegPerEpoch + (1:nSegPerEpoch);
      P    = squeeze(sum(freq.powspctrm(segs,:,swa_idx),3));
      swa_epoch(ep) = mean(P(:));
    end

    % — Bin into 30 min windows —
    nBins      = floor(nEpochs/binSize);
    swa_binned = nan(nBins,1);
    for b = 1:nBins
      idx = (b-1)*binSize + (1:binSize);
      swa_binned(b) = mean(swa_epoch(idx));
    end

    % — Store per‐subject results —
    swa_raw.(group){i}   = swa_binned;
    all_nBins.(group)(i) = nBins;
  end
end

%% 2) Build padded matrices [maxBins×12]
maxBins     = max([all_nBins.HC; all_nBins.MDD]);
all_swa_HC  = nan(maxBins, nSubjects);
all_swa_MDD = nan(maxBins, nSubjects);

for i = 1:nSubjects
  nb = all_nBins.HC(i);
  all_swa_HC(1:nb,i)  = swa_raw.HC{i};
  nb = all_nBins.MDD(i);
  all_swa_MDD(1:nb,i) = swa_raw.MDD{i};
end

%% 3) Common time vector (30 min midpoints, in hours)
t = (((1:maxBins) - 0.5)*30) / 60;
% 3) Common time vector (30 min midpoints, in hours)
t = (((1:maxBins) - 0.5)*30) / 60;   % currently 1×maxBins
t = t(:);                            % force into [maxBins×1]


%% 4) Compute group‐mean curves
mean_HC  = nanmean(all_swa_HC, 2);
mean_MDD = nanmean(all_swa_MDD,2);

%% 5) Fit exponentials to the group‐mean
ft   = fittype('A*exp(-r*t)','independent','t','coefficients',{'A','r'});
opts = fitoptions(ft);
opts.Lower = [0 0];   % A≥0, r≥0

% HC fit
valid_HC   = ~isnan(mean_HC);
t_HC_fit   = t(valid_HC);
y_HC_fit   = mean_HC(valid_HC);
opts.StartPoint = [y_HC_fit(1), 0.5];
[cf_HC, ~] = fit(t_HC_fit, y_HC_fit, ft, opts);

% MDD fit
valid_MDD   = ~isnan(mean_MDD);
t_MDD_fit   = t(valid_MDD);
y_MDD_fit   = mean_MDD(valid_MDD);
opts.StartPoint = [y_MDD_fit(1), 0.5];
[cf_MDD, ~] = fit(t_MDD_fit, y_MDD_fit, ft, opts);

%% Extract parameters for HC
SWA0_HC = cf_HC.A;
r_HC    = cf_HC.r;

% Extract parameters for MDD
SWA0_MDD = cf_MDD.A;
r_MDD    = cf_MDD.r;

% Display them
fprintf('HC: SWA0 = %.2f, r = %.3f h^-1', SWA0_HC, r_HC);
fprintf('MDD: SWA0 = %.2f, r = %.3f h^-1, R^2 = %.2f\n', ...
        SWA0_MDD, r_MDD);


%% 7) Final plot: all dots + two fitted curves
figure; hold on;
% HC fit: dark blue line
hHC = plot(t_HC_fit, cf_HC(t_HC_fit), '-', ...
     'Color',[0 0 0.8], 'LineWidth',2);

% MDD fit: dark red line
hMDD = plot(t_MDD_fit, cf_MDD(t_MDD_fit), '-', ...
     'Color',darkRed, 'LineWidth',2);

ylabel('SWA (0.5–4 Hz)/µV²');

% Set x‐axis ticks every 100 min from 100 to 400
minTicks  = 100:100:400;          % in minutes
hourTicks = minTicks / 60;        % convert to hours
xticks(hourTicks);
xticklabels(string(minTicks));
xlabel('NREM time in minutes since sleep onset');
ylim([0, 1500]);  
% Legend for only the two curves
legend([hHC, hMDD], {'HC','MDD'}, 'Location','northeast');

hold off;
