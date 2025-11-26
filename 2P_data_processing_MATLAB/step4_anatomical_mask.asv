%% Read Static 3D Volume Image (Anatomical Scan)
% This script reads an .nd2 file as a static 3D volume and visualizes it.
% It does not save individual planes to disk, but keeps the volume in memory.
% Based on step1_read_nd2.m

clear; clc;

%% 1. Select File
fprintf('Please select the .nd2 Galvano scan file...\n');
[file, path] = uigetfile('*.nd2', 'Select .nd2 Anatomical File');
if isequal(file, 0)
    disp('User canceled file selection');
    return;
end
cd(path);
fprintf('Selected: %s\n', fullfile(path, file));

%% 2. Initialize Bio-Formats Reader
% Ensure Bio-Formats is in the path
if ~exist('bfGetReader', 'file')
    error('Bio-Formats toolbox not found. Please install bfmatlab.');
end

reader = bfGetReader(file);
omeMeta = reader.getMetadataStore();

%% 3. Get Dimensions
reader.setSeries(0);
nZ = omeMeta.getPixelsSizeZ(0).getValue();
nT = omeMeta.getPixelsSizeT(0).getValue();
nC = omeMeta.getPixelsSizeC(0).getValue();
nX = omeMeta.getPixelsSizeX(0).getValue();
nY = omeMeta.getPixelsSizeY(0).getValue();

fprintf('\nDimensions:\n');
fprintf('X: %d, Y: %d, Z: %d\n', nX, nY, nZ);
fprintf('Channels: %d, Time points: %d\n', nC, nT);

if nT > 1
    fprintf('Warning: File contains %d time points. Only the first time point will be read.\n', nT);
end

%% 4. Read 3D Volume
% We will read the first time point (T=1) and first channel (C=1) by default.
% If you have multiple channels, you might want to modify this.

channel_idx = 1; % 1-based index
time_idx = 1;    % 1-based index

% Determine data type from the first plane
temp_plane = bfGetPlane(reader, 1);
data_class = class(temp_plane);

% Preallocate 3D matrix
volume_3d = zeros(nY, nX, nZ, data_class);

fprintf('\nReading Z-planes...\n');
wb = waitbar(0, 'Reading 3D Volume...');

for z = 1:nZ
    % Calculate index for specific Z, C, T
    % reader.getIndex(z, c, t) uses 0-based indexing
    % z: 0 to nZ-1
    % c: 0 to nC-1
    % t: 0 to nT-1
    
    % Note: getIndex returns 0-based index, bfGetPlane expects 1-based index
    try
        plane_idx = reader.getIndex(z-1, channel_idx-1, time_idx-1) + 1;
    catch
        % Fallback if getIndex fails or is not available (manual calculation)
        % Assuming XYCZT order which is common, but getIndex is safer
        plane_idx = (time_idx-1)*nZ*nC + (z-1)*nC + channel_idx;
    end
    
    volume_3d(:,:,z) = bfGetPlane(reader, plane_idx);
    
    if mod(z, 10) == 0
        waitbar(z/nZ, wb, sprintf('Reading Z plane %d/%d', z, nZ));
    end
end
close(wb);
reader.close();

fprintf('Done reading volume. Size: %s\n', mat2str(size(volume_3d)));

%% 5. Visualization
fprintf('\nVisualizing...\n');

% Check for available visualization tools
if exist('orthosliceViewer', 'file')
    % Best for 3D volumes (requires Image Processing Toolbox)
    orthosliceViewer(volume_3d, 'Parent', figure('Name', '3D Volume View'));
    fprintf('Opened orthosliceViewer.\n');    
else
    % Fallback: Simple slider viewer
    f = figure('Name', '3D Volume Slice Viewer');
    ax = axes('Parent', f, 'Position', [0.1 0.2 0.8 0.7]);
    
    % Show middle slice initially
    current_z = round(nZ/2);
    hImg = imshow(volume_3d(:,:,current_z), [], 'Parent', ax);
    title(ax, sprintf('Z Plane: %d / %d', current_z, nZ));
    
    % Add slider
    sld = uicontrol('Parent', f, 'Style', 'slider', ...
        'Position', [100 20 400 20], ...
        'Min', 1, 'Max', nZ, 'Value', current_z, ...
        'SliderStep', [1/(nZ-1) 10/(nZ-1)]);
        
    % Add listener (callback)
    % Note: In scripts, we can't use local functions as callbacks easily without
    % defining them at the end of the file.
    sld.Callback = @(src, event) update_slice_callback(src, hImg, ax, volume_3d, nZ);
    
    fprintf('Opened custom slice viewer.\n');
end

%% 6. Save to Workspace
assignin('base', 'anatomical_volume', volume_3d);
fprintf('\nVariable "anatomical_volume" has been saved to the workspace.\n');

%% 7. Deep Layer Segmentation (Crop Volume)
fprintf('\n=== Deep Layer Segmentation ===\n');
msg_handle = msgbox('Please examine the 3D volume viewer to determine the starting Z-plane for deep layer cells. Click OK when ready.', 'Ready to Segment');
uiwait(msg_handle);

prompt = {sprintf('Enter start Z-plane for deep layers (1-%d):\n(Keep data from this Z to end)', nZ)};
dlgtitle = 'Deep Layer Segmentation';
dims = [1 50];
definput = {num2str(round(nZ/2))};
answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer)
    fprintf('User canceled segmentation.\n');
else
    start_z = str2double(answer{1});
    
    if isnan(start_z) || start_z < 1 || start_z > nZ
        errordlg('Invalid Z-plane index.', 'Error');
    else
        % Create segmented volume (Deep layers only)
        % Assuming deep layers are from start_z to the end (nZ)
        deep_layer_volume = volume_3d(:, :, start_z:end);
        
        fprintf('Segmented Deep Layer Volume: Z %d to %d\n', start_z, nZ);
        fprintf('New Volume Size: %s\n', mat2str(size(deep_layer_volume)));
        
        % Visualize the result
        if exist('orthosliceViewer', 'file')
            orthosliceViewer(deep_layer_volume, 'Parent', figure('Name', 'Deep Layer Volume'));
        elseif exist('volshow', 'file')
            volshow(deep_layer_volume);
        else
            figure('Name', 'Deep Layer Volume - First Slice');
            imshow(deep_layer_volume(:,:,1), []);
            title(sprintf('Deep Layer Start (Original Z=%d)', start_z));
        end
        
        % Save to workspace
        assignin('base', 'deep_layer_volume', deep_layer_volume);
        assignin('base', 'deep_layer_start_z', start_z);
        fprintf('Saved "deep_layer_volume" to workspace.\n');
    end
end

%% 8. Save Deep Layer Volume to TIFF
if exist('deep_layer_volume', 'var')
    save_choice = questdlg('Do you want to save the segmented deep layer volume as a TIFF file?', ...
        'Save Output', 'Yes', 'No', 'Yes');
        
    if strcmp(save_choice, 'Yes')
        [file_name, save_path] = uiputfile('*.tif', 'Save Deep Layer Volume As', 'deep_layer_volume.tif');
        
        if isequal(file_name, 0)
            fprintf('Save canceled.\n');
        else
            full_save_path = fullfile(save_path, file_name);
            fprintf('Saving to %s...\n', full_save_path);
            
            % Get dimensions
            [h, w, d] = size(deep_layer_volume);
            
            % Save each slice
            wb_save = waitbar(0, 'Saving TIFF...');
            for k = 1:d
                if k == 1
                    imwrite(deep_layer_volume(:,:,k), full_save_path, 'tif', 'WriteMode', 'overwrite', 'Compression', 'none');
                else
                    imwrite(deep_layer_volume(:,:,k), full_save_path, 'tif', 'WriteMode', 'append', 'Compression', 'none');
                end
                if mod(k, 10) == 0
                    waitbar(k/d, wb_save, sprintf('Saving slice %d/%d', k, d));
                end
            end
            close(wb_save);
            fprintf('Saved successfully: %s\n', full_save_path);
        end
    end
end

%% Helper Function for Custom Viewer
function update_slice_callback(slider, img_handle, ax_handle, vol, max_z)
    z = round(slider.Value);
    % Ensure z is within bounds
    z = max(1, min(max_z, z));
    
    % Update image
    set(img_handle, 'CData', vol(:,:,z));
    title(ax_handle, sprintf('Z Plane: %d / %d', z, max_z));
end
