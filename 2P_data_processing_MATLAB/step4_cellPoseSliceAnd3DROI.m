%% step1 load the manually adjusted 3D ROI .tif file from cellPose
%the feature-added version of this program is used.
questdlg('Please select the 3D ROI .tif file from cellPose','3D ROI file selection','OK','OK');
[fileName,path] = uigetfile('*masks.tif');

% Validate file selection
if isequal(fileName,0) || isequal(path,0)
    error('User canceled file selection');
end

% Save original directory and change to file location
originalDir = pwd;
cd(path)

% Load and validate volume
try
    cellPoseVolume = double(tiffreadVolume(fileName));
    if isempty(cellPoseVolume)
        error('Loaded volume is empty');
    end
    fprintf('Successfully loaded volume: %d x %d x %d\n', size(cellPoseVolume,1), size(cellPoseVolume,2), size(cellPoseVolume,3));
catch ME
    cd(originalDir);
    error('Failed to load tif file: %s', ME.message);
end

% Get image dimensions dynamically
imgHeight = size(cellPoseVolume, 1);
imgWidth = size(cellPoseVolume, 2);
imgDepth = size(cellPoseVolume, 3);

%% step2(optional):如果cellpose中的mask不是填充好的情况下，需要将每一个区域进行填充，
%  并新建一个3D ROI footprint table

%get the number list of all of the ROIs 
roiLabels = unique(cellPoseVolume);
roiLabels(roiLabels == 0) = [];

if isempty(roiLabels)
    cd(originalDir);
    error('No ROIs found in the volume');
end

fprintf('Found %d ROIs in the volume\n', length(roiLabels));

%create a blank table of 3D ROIs


tableTitle = {'ROI3DIdx','FP_3D','S1_registered','S2_registered','S3_registered'};
tableTitleTypes = {'double','cell','struct','struct','struct'};
ROI3DWithTraceTable = table('size',[length(roiLabels) length(tableTitle)],...
                            'VariableTypes',tableTitleTypes,'VariableNames',tableTitle);
ROI3DWithTraceTable.ROI3DIdx(:) = 1 : length(roiLabels);
clearvars tableTitle tableTitleTypes

%% extract the 3D ROIs and save the filled ROIs to the table
fillWB = waitbar(0,'0/0','Name','filling the empty ROIs...');
filledVolume = zeros(size(cellPoseVolume));
overlapCount = 0;  % Track overlapping regions

for labelIdx = 1: length(roiLabels)
    wbstr = append(num2str(labelIdx),'/',num2str(length(roiLabels)));
    waitbar(labelIdx/length(roiLabels),fillWB,wbstr);

    roiMask = (cellPoseVolume == roiLabels(labelIdx));     % get the current ROI label
    filledROI = imfill(roiMask,'holes');                   % fill the current ROI
    
    % Check for overlaps before saving
    if any(filledVolume(filledROI) > 0)
        overlapCount = overlapCount + 1;
        warning('ROI %d overlaps with existing ROIs. Later ROI will overwrite.', roiLabels(labelIdx));
    end
    
    filledVolume(filledROI) = roiLabels(labelIdx);         % save the filled ROI to the filledVolume
    ROI3DWithTraceTable.FP_3D{labelIdx} = filledROI;       % save the filled ROI to the table
end

close(fillWB)

if overlapCount > 0
    fprintf('Warning: %d ROIs had overlapping regions\n', overlapCount);
end

% Preview the filled volume using orthogonal view
figure('Name', '3D ROI Orthogonal View', 'NumberTitle', 'off');
if exist('orthosliceViewer', 'file')
    % Use orthosliceViewer for interactive orthogonal slices (R2020b+)
    orthosliceViewer(filledVolume);
else
    % Fallback to manual orthogonal slice display
    midX = round(imgHeight/2);
    midY = round(imgWidth/2);
    midZ = round(imgDepth/2);
    
    subplot(2,2,1);
    imagesc(squeeze(filledVolume(:,:,midZ))); axis image; colormap(gca, 'jet'); colorbar;
    title(sprintf('XY plane (Z=%d)', midZ)); xlabel('X'); ylabel('Y');
    
    subplot(2,2,2);
    imagesc(squeeze(filledVolume(:,midY,:))); axis image; colormap(gca, 'jet'); colorbar;
    title(sprintf('XZ plane (Y=%d)', midY)); xlabel('X'); ylabel('Z');
    
    subplot(2,2,3);
    imagesc(squeeze(filledVolume(midX,:,:))); axis image; colormap(gca, 'jet'); colorbar;
    title(sprintf('YZ plane (X=%d)', midX)); xlabel('Y'); ylabel('Z');
    
    subplot(2,2,4);
    % Maximum intensity projection for reference
    mipXY = max(filledVolume, [], 3);
    imagesc(mipXY); axis image; colormap(gca, 'jet'); colorbar;
    title('Max Intensity Projection (XY)'); xlabel('X'); ylabel('Y');
end

%% 将每一层保存为用于cellReg的输入，并将每个其中每个3D ROI的序号填入table中

%create coordinate table
sliceN = size(cellPoseVolume,3);
tableTitle = {'index','planeN','ROINum','ROIIdxList','ROIfootprints','cellRegInput'};
tableTitleTypes = {'double','double','double','cell','cell','cell'};
coordinateTable = table('size',[sliceN length(tableTitle)],...
                  'VariableTypes',tableTitleTypes,'VariableNames',tableTitle);
coordinateTable.index(:) = 1:sliceN;
clearvars tableTitle tableTitleTypes  

[~,name,~] = fileparts(fileName);
%extract the slice number from the file name
startZ = str2double(regexp(name, '\d{1,3}', 'match', 'once'));  % extract the first 1-3 digit number

if isnan(startZ)
    warning('Could not extract start Z from filename. Using default startZ = 0');
    startZ = 0;
end

endZ = startZ + sliceN - 1;  % end Z plane number (corrected for 0-based indexing)
fprintf('Processing Z-planes from %d to %d\n', startZ, endZ);

wb1 = waitbar(0,'0/0','Name','saving the 3D ROI data...');
for i = 1 : sliceN
    waitbar(i/sliceN,wb1,append(num2str(i),'/',num2str(sliceN)));
    %Corrected: MATLAB index i corresponds to Python index i-1 (0-based)
    tempPlane = filledVolume(:,:,i);
    tempROIList = unique(tempPlane);
    tempROIList(tempROIList == 0) = [];            %exclude zero
    
    %write the values to the table elements
    %Fixed: use startZ+i-1 to correctly map to 0-based Python indexing
    coordinateTable.planeN(i) = startZ + i - 1;  
    coordinateTable.ROINum(i) = nnz(tempROIList);  %exclude zero
    coordinateTable.ROIIdxList(i) = {tempROIList'};
    
    %Fixed: use dynamic image dimensions instead of hardcoded 512x512
    tempCellRegInput = zeros(imgHeight, imgWidth, length(tempROIList));
    tempCell = cell(length(tempROIList),1);           %save the temp spatial footprint
    
    for j = 1 : length(tempROIList)
        ROILinearFP = find(tempPlane == tempROIList(j));  %the ROI equals to the j-TH ROI idx
        [x,y] = ind2sub([imgHeight, imgWidth], ROILinearFP);
        tempCell{j} = [x,y];
        tempCellRegInput(:,:,j) = double(tempPlane == tempROIList(j));
    end

    coordinateTable.ROIfootprints(i) = {tempCell};
    %Note: permute [3 2 1] converts from (height,width,roi) to (roi,width,height)
    %Verify this matches cellReg's expected input format
    coordinateTable.cellRegInput(i) = {permute(tempCellRegInput,[3 2 1])};
end

save('coordinateTable.mat','coordinateTable','-v7.3')
save('ROI3DWithTraceTable.mat','ROI3DWithTraceTable','-v7.3')
close(wb1)

%% save the individual cellReg input as individual .mat file
questdlg('Please select the folder to save the sliced cellPose ROI','cellReg input saving','OK','OK');
savePath = uigetdir(path, 'Select folder to save cellReg inputs');

if isequal(savePath, 0)
    warning('User canceled save directory selection. Files not saved.');
else
    fprintf('Saving %d cellReg input files to: %s\n', coordinateTable.index(end), savePath);
    
    for i = 1 : coordinateTable.index(end)
        cellRegInput = coordinateTable.cellRegInput{i};
        tempSaveStr = fullfile(savePath, sprintf('Z%d.mat', coordinateTable.planeN(i)));
        save(tempSaveStr, "cellRegInput");
    end
    
    fprintf('Successfully saved all cellReg input files\n');
end

% Return to original directory
cd(originalDir);
fprintf('Processing complete. Returned to original directory.\n');

clearvars -except *Table