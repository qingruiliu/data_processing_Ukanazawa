%% re-arrange the output of suite2p into MATLAB table format for multiple imaging planes
% 
% This script processes suite2p output across multiple imaging planes:
% - Loads Fall.mat from each plane folder
% - Creates structured tables with ROI information
% - Generates cellReg-compatible binary masks
% - Saves spatial footprint visualization

% Last Modified: 2024.12.25

% select the main directory containing subfolders for each imaging plane
disp('Select the main directory containing subfolders for each imaging plane')
mainDir = uigetdir();
if mainDir == 0
    error('No directory selected. Exiting...');
end

% Get all items in the directory
allItems = dir(mainDir);
fprintf('Total items found in directory: %d\n', length(allItems));

% Filter to keep only directories, excluding '.' and '..'
isDirMask = [allItems.isdir];
notCurrentOrParent = ~ismember({allItems.name}, {'.', '..'});

% First pass: get all directories except '.' and '..'
allDirs = allItems(isDirMask & notCurrentOrParent);

if isempty(allDirs)
    error('No subdirectories found in %s', mainDir);
end

fprintf('Found %d subdirectories:\n', length(allDirs));
for i = 1:length(allDirs)
    hasfall = isfile(fullfile(mainDir, allDirs(i).name, 'Fall.mat'));
    if hasfall
        status = '(has Fall.mat)';
    else
        status = '(no Fall.mat)';
    end
    fprintf('  [%d] %s %s\n', i, allDirs(i).name, status);
end

% Filter out hidden folders (starting with '.')
notHidden = ~startsWith({allDirs.name}, '.');
subDirs = allDirs(notHidden);

if isempty(subDirs)
    fprintf('\nWARNING: All subdirectories are hidden (start with ".").\n');
    response = input('Do you want to process hidden folders too? (y/n): ', 's');
    if strcmpi(response, 'y')
        subDirs = allDirs;  % Include all directories
        fprintf('Processing all %d subdirectories (including hidden).\n', length(subDirs));
    else
        error('No valid subdirectories to process.');
    end
else
    fprintf('\n%d non-hidden subdirectories will be processed.\n', length(subDirs));
end

%%
wb = waitbar(0,'0/0','Name','Processing suite2p data...');
for k = 1:length(subDirs)
    waitbar(k/length(subDirs),wb,append('Processing suite2p data...',num2str(k),'/',num2str(length(subDirs))));
    planePath = fullfile(mainDir, subDirs(k).name);
    disp(['Processing folder: ', planePath]);
    
    % select the target Fall.mat file
    fileName = fullfile(planePath, 'Fall.mat');
    if ~isfile(fileName)
        disp(['Fall.mat not found in ', planePath]);
        continue;
    end
    load(fileName);
    fprintf('%s LOADED \n', planePath);
    
    % Validate required variables
    if ~exist('F', 'var') || ~exist('spks', 'var') || ~exist('stat', 'var') || ~exist('iscell', 'var')
        warning('Required variables missing in %s. Skipping...', planePath);
        continue;
    end
    
    % Get image dimensions from ops or stat
    if exist('ops', 'var') && isfield(ops, 'Ly') && isfield(ops, 'Lx')
        imgHeight = ops.Ly;
        imgWidth = ops.Lx;
    else
        % Fallback: infer from stat
        imgHeight = 512;
        imgWidth = 512;
        warning('Image dimensions not found in ops, using default 512x512');
    end

    %% create a empty table to save different variables

    tableTitle = {'ROIindexS2P','isCell','Prob','rawF','DeconvF','Stat','cellRegInputS2P'};
    tableTitleTypes = {'double','double','double','cell','cell','cell','cell'};

    %create the empty table
    suite2pTable = table('size',[length(iscell) length(tableTitle)],...
                            'VariableNames',tableTitle, ...
                            'VariableTypes',tableTitleTypes);

    %% build the suite2pTable

    suite2pTable.isCell(:) = iscell(:,1);
    suite2pTable.Prob(:) = iscell(:,2);

    for i = 1 : length(iscell)
        emptyImg = zeros(imgHeight, imgWidth);
        suite2pTable.ROIindexS2P(i) = i;
        suite2pTable.rawF(i) = {F(i,:)'};
        suite2pTable.DeconvF(i)= {spks(i,:)'};
        suite2pTable.Stat(i) = stat(i);
        tempX = double(stat{i}.xpix)' + 1;  % suite2p uses 0-indexed, MATLAB uses 1-indexed
        tempY = double(stat{i}.ypix)' + 1;
        tempLam = stat{i}.lam';

        %max-min normalize the pixel contribution of Lam
        lamRange = max(tempLam) - min(tempLam);
        if lamRange > eps  % Avoid division by zero
            tempLamNorm = (tempLam - min(tempLam)) / lamRange;
        else
            tempLamNorm = ones(size(tempLam));  % All values are the same
        end
        
        tempSoma = logical(stat{i}.soma_crop');
        
        % Validate coordinates are within bounds
        validX = tempX >= 1 & tempX <= imgWidth;
        validY = tempY >= 1 & tempY <= imgHeight;
        validCoords = validX & validY & tempSoma;
        
        if any(validCoords)
            linearIdx = sub2ind([imgHeight imgWidth], tempY(validCoords), tempX(validCoords));
            emptyImg(linearIdx) = tempLamNorm(validCoords);
        end
        suite2pTable.cellRegInputS2P(i) = {emptyImg};
    end

    % sort the rows based on the isCell and ROIindex
    suite2pTable = sortrows(suite2pTable,{'isCell','ROIindexS2P'},{'descend','ascend'});
    save(fullfile(planePath, 'suite2pTable.mat'),'suite2pTable');

    suite2pImage = zeros(imgHeight, imgWidth);
    for i = 1 : size(suite2pTable, 1)
        if suite2pTable.isCell(i) == 1  % only get the isCell spatial footprint
            suite2pImage = suite2pImage + suite2pTable.cellRegInputS2P{i,1};
        end
    end
    % Create or reuse figure window to avoid memory issues
    fig = figure('Name', ['Plane ' num2str(k)], 'NumberTitle', 'off'); 
    imshow(suite2pImage, []);
    title(['Spatial footprint of suite2p (isCell only): ', subDirs(k).name], 'FontSize', 16);
    
    % Save figure
    saveas(fig, fullfile(planePath, 'suite2p_spatial_footprint.png'));

    % save the suite2pImage as separate file
    imwrite(mat2gray(suite2pImage), fullfile(planePath, 'suite2p_spatial_footprint.tif'));
    
    close(fig);  % Close to avoid memory accumulation

    % get the iscell 3D matrix for cellReg input, save to cellRegInput.mat
    isCellNum = sum(suite2pTable.isCell);
    if isCellNum == 0
        warning('No cells detected in %s. Skipping cellReg input generation.', planePath);
        continue;
    end
    suite2pInput = zeros(imgHeight, imgWidth, isCellNum);

    for i = 1 : isCellNum
        suite2pInput(:,:,i) = suite2pTable.cellRegInputS2P{i};
    end

    cellRegInput = permute(suite2pInput,[3 2 1]);

    %use the binary mask to run the cellReg 24.10.31
    cellRegInput = double(cellRegInput ~= 0);

    saveStr = fullfile(planePath, 'cellRegInput.mat');
    save(saveStr,"cellRegInput");

    disp(['Processing completed for folder: ', planePath]);
end
close(wb)