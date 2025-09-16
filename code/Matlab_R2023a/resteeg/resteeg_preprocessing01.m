%%%  to convert them as .set 
%%%  to preprocess them using RELAX
%%%  to check automatically preprocessed files

clear; clc; close all;
eeglab;

% Main folder path
mainDir = 'G:\resteeg';

% Define the folder categories (HC and MDD)
%folders = {'HC', 'MDD'};
folders = {'HC'};
% Loop through each folder category (HC or MDD)
for f = 1:length(folders)
    foldDir = fullfile(mainDir, folders{f});  % Path to HC or MDD folder
    
    % Get list of subfolders (e.g., HC01, HC02, ..., HC12 or MDD01, MDD02, ..., MDD12)
    subfolders = dir(foldDir);
    subfolders = subfolders([subfolders.isdir] & ~ismember({subfolders.name}, {'.', '..'}));  % Filter folders
    
    % Loop through each subfolder (e.g., HC01, MDD03)  
    for s = 1:length(subfolders)
        subDir = fullfile(foldDir, subfolders(s).name);  % Path to the current subfolder
        
        % Get all .dap files in the subfolder
        dapFiles = dir(fullfile(subDir, '*.dap'));
        
        % Create 'eeglab' subfolder if it doesn't exist
        eeglabDir = fullfile(subDir, 'eeglab');
        if ~exist(eeglabDir, 'dir')
            mkdir(eeglabDir);
        end
        
        % Loop through each .dap file
        for j = 1:length(dapFiles)
            filePath = fullfile(subDir, dapFiles(j).name);
            
            % Load EEG data
            disp(['Loading file: ', dapFiles(j).name]);
            EEG = loadcurry(filePath, 'KeepTriggerChannel', 'True', 'CurryLocations', 'False');
            
            channelsToRemove = {'M1', 'M2', 'TRIGGER'};
            EEG = pop_select(EEG, 'rmchannel', channelsToRemove);
            disp(['Number of channels in the EEG data: ', num2str(EEG.nbchan)]);
            
            % Extract the last two digits of the filename (e.g., 'preEC01' → '01')
            [~, name, ~] = fileparts(dapFiles(j).name);  % Get base filename without extension
            suffixNum = name(end-1:end);  % Extract the last two digits
            
            % Define the new file name
            newFileName = ['preclose', suffixNum, '.set'];  % New name like preclose01.set
            saveFilePath = fullfile(eeglabDir, newFileName);  % Path to save the new file
            
            % Save the processed EEG data to the new file
            pop_saveset(EEG, 'filename', saveFilePath);
            disp(['Saved new file to: ', saveFilePath]);
        end
    end
end
disp('ALL DONE!')

%% Next, using RELAX toolbox to preprocessing it automatically
%% check the results again maunally
