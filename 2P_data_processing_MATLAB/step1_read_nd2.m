%% Read .nd2 file in MATLAB, get timestamp information and images of each scan
msb = msgbox('Please select the .nd2 **resonant** volume calcium imaging file','select file');
waitfor(msb); % Wait for user to close message box
[file,path] = uigetfile('.nd2','Please select the .nd2 volume calcium imaging file','MultiSelect','off');
cd(path)
reader = bfGetReader(file);
omeMeta = reader.getMetadataStore();

% Get image dimension information
nSeries = reader.getSeriesCount();
reader.setSeries(0); % Set to first series

% Get z-axis plane count and other dimension information
nPlanes = reader.getImageCount();
nZ = omeMeta.getPixelsSizeZ(0).getValue(); % Number of z-axis planes
nT = omeMeta.getPixelsSizeT(0).getValue(); % Number of time points
nC = omeMeta.getPixelsSizeC(0).getValue(); % Number of channels
nX = omeMeta.getPixelsSizeX(0).getValue(); % Image width
nY = omeMeta.getPixelsSizeY(0).getValue(); % Image height

fprintf('Image dimension information:\n');
fprintf('Number of Z planes: %d\n', nZ);
fprintf('Number of time points: %d\n', nT);
fprintf('Number of channels: %d\n', nC);
fprintf('Image size: %d x %d\n', nX, nY);
fprintf('Total images: %d\n', nPlanes);

% Get timestamps
timestamps = cell(nPlanes,1);
for i = 1:nPlanes
    tObj = omeMeta.getPlaneDeltaT(0, i-1);  % Returns Java object
    timestamps{i} = tObj;  % Store Java object in cell array
end
timestamps = cellfun(@(t) t.value().doubleValue(), timestamps);

% Get all image data
fprintf('Reading image data...\n');
images = cell(nPlanes, 1);
for i = 1:nPlanes
    images{i} = bfGetPlane(reader, i);
    if mod(i, 500) == 0
        fprintf('Read %d/%d images\n', i, nPlanes);
    end
end

% Group image data by z-plane as time series, using Z1, Z2, Z3 naming
fprintf('Grouping images by z-plane...\n');
for z = 1:nZ
    plane_name = sprintf('Z%d', z);
    
    % Create time series for each z-plane
    plane_images = cell(nT, 1);
    plane_times = zeros(nT, 1);
    
    for t = 1:nT
        % Calculate image index for current z-plane and time point
        % Usually follows z-t-c order: index = (t-1)*nZ*nC + (z-1)*nC + c
        % Here assuming single channel (c=1), adjust if multiple channels exist
        img_index = (t-1)*nZ + z;
        
        if img_index <= nPlanes
            plane_images{t} = images{img_index};
            plane_times(t) = timestamps(img_index);
        end
    end
    
    % Dynamically create variable names
    eval(sprintf('%s_images = plane_images;', plane_name));
    eval(sprintf('%s_timestamps = plane_times;', plane_name));
end

fprintf('Data reading completed!\n');
fprintf('Images divided into %d z-plane time series\n', nZ);

%% Calculate imaging speed (volume/second)
fprintf('\n=== Imaging Speed Calculation ===\n');

% Get time intervals for complete volumes
% A complete volume contains all z-planes, so every nZ images form one volume
volume_timestamps = [];
for vol = 1:floor(nPlanes/nZ)
    % Timestamp of first image in each volume
    vol_start_idx = (vol-1)*nZ + 1;
    if vol_start_idx <= length(timestamps)
        volume_timestamps(end+1) = timestamps(vol_start_idx);
    end
end

if length(volume_timestamps) > 1
    % Calculate time intervals between adjacent volumes
    volume_intervals = diff(volume_timestamps);
    avg_volume_interval = mean(volume_intervals);
    imaging_speed = 1 / avg_volume_interval; % volume/second
    
    fprintf('Total number of volumes: %d\n', length(volume_timestamps));
    fprintf('Average volume interval: %.3f seconds\n', avg_volume_interval);
    fprintf('Imaging speed: %.3f volume/second\n', imaging_speed);
    fprintf('Imaging speed: %.1f volume/minute\n', imaging_speed * 60);
else
    fprintf('Warning: Insufficient data to calculate imaging speed\n');
    imaging_speed = NaN;
end

fprintf('Grouped by z-plane and created named variables\n');

%% Data validation and information display
fprintf('\n=== Data Validation ===\n');
for z = 1:nZ
    plane_name = sprintf('Z%d', z);
    eval(sprintf('current_images = %s_images;', plane_name));
    valid_images = sum(~cellfun(@isempty, current_images));
    fprintf('%s: %d valid images\n', plane_name, valid_images);
    
    % Also output variable names for user reference
    if z == 1
        fprintf('\nCreated variables:\n');
    end
    fprintf('- %s_images and %s_timestamps\n', plane_name, plane_name);
end

%% Optional: Display first image of first z-plane as example
if exist('Z1_images', 'var') && ~isempty(Z1_images{1})
    figure;
    imshow(Z1_images{1}, []);
    title(sprintf('Example image - Z1, Time point 1\nTimestamp: %.3f seconds', Z1_timestamps(1)));
    %colorbar;
end

%% Optional: Plot timestamps for each z-plane
if nZ <= 10  % Only plot when z-plane count is not too many
    figure;
    colors = lines(nZ);
    for z = 1:nZ
        plane_name = sprintf('Z%d', z);
        
        % Dynamically get timestamp data
        eval(sprintf('current_timestamps = %s_timestamps;', plane_name));
        valid_times = current_timestamps(current_timestamps > 0);
        
        if ~isempty(valid_times)
            plot(1:length(valid_times), valid_times, 'o-', 'Color', colors(z,:), ...
                'DisplayName', plane_name);
            hold on;
        end
    end
    xlabel('Time point index');
    ylabel('Timestamp (seconds)');
    title('Timestamps for each z-plane');
    legend('show');
    grid on;
end

%% Data structure description
fprintf('\n=== Data Structure Description ===\n');
fprintf('Main variables:\n');
fprintf('- images: Cell array containing all original images (%d x 1)\n', nPlanes);
fprintf('- timestamps: Array of all image timestamps (%d x 1)\n', nPlanes);
fprintf('- imaging_speed: Imaging speed (%.3f volume/second)\n', imaging_speed);
fprintf('\nVariables grouped by z-plane (%d z-planes total):\n', nZ);

for z = 1:nZ
    plane_name = sprintf('Z%d', z);
    fprintf('- %s_images: Image time series for %s plane (%d x 1 cell)\n', plane_name, plane_name, nT);
    fprintf('- %s_timestamps: Timestamp array for %s plane (%d x 1)\n', plane_name, plane_name, nT);
end

fprintf('\nUsage examples:\n');
fprintf('Access Z1 plane 5th time point image: Z1_images{5}\n');
fprintf('Access all timestamps for Z2 plane: Z2_timestamps\n');
fprintf('Get number of images in Z3 plane: length(Z3_images)\n');

%% Create summary information structure
summary = struct();
summary.nZ = nZ;
summary.nT = nT;
summary.nC = nC;
summary.imageSize = [nX, nY];
summary.totalPlanes = nPlanes;
summary.imagingSpeed = imaging_speed;
summary.avgVolumeInterval = avg_volume_interval;

fprintf('\nCreated summary structure containing all key information\n');

%% Create convenient data access functions
% Create a function for convenient access to specific z-plane data
eval('clear getZPlaneData'); % Clear any previously existing function

% Save all z-plane data to a structure for easy access
ZPlanes = struct();
for z = 1:nZ
    plane_name = sprintf('Z%d', z);
    eval(sprintf('ZPlanes.%s.images = %s_images;', plane_name, plane_name));
    eval(sprintf('ZPlanes.%s.timestamps = %s_timestamps;', plane_name, plane_name));
end

fprintf('\nCreated ZPlanes structure, access data as follows:\n');
fprintf('- ZPlanes.Z1.images{5} : Access Z1 plane 5th time point image\n');
fprintf('- ZPlanes.Z2.timestamps : Access all timestamps for Z2 plane\n');

%% Save data as TIFF series and timestamp files
fprintf('\n=== Save Data ===\n');

% Ask user whether to save data
save_choice = questdlg('Do you want to save TIFF series and timestamp files?', ...
                      'Save Options', 'Yes', 'No', 'Select specific planes', 'Yes');

if strcmp(save_choice, 'No')
    fprintf('User chose not to save data\n');
else
    % Select z-planes to save
    if strcmp(save_choice, 'Select specific planes')
        plane_options = {};
        for z = 1:nZ
            plane_options{end+1} = sprintf('Z%d', z);
        end
        [selected_indices, ok] = listdlg('PromptString', 'Please select z-planes to save:', ...
                                        'SelectionMode', 'multiple', ...
                                        'ListString', plane_options);
        if ~ok || isempty(selected_indices)
            fprintf('No planes selected, skipping save step\n');
            return;
        end
        planes_to_save = selected_indices;
    else
        planes_to_save = 1:nZ; % Save all planes
    end
    
    % Select target folder
    output_folder = uigetdir(pwd, 'Please select folder to save TIFF series and timestamp files');
    if output_folder == 0
        fprintf('No folder selected, skipping save step\n');
    else
        fprintf('Saving to folder: %s\n', output_folder);
        fprintf('Will save %d z-planes\n', length(planes_to_save));
    
        % Save data for selected z-planes
        for i = 1:length(planes_to_save)
            z = planes_to_save(i);
            plane_name = sprintf('Z%d', z);
            fprintf('Processing %s (%d/%d)...\n', plane_name, i, length(planes_to_save));
        
        % Create z-plane specific subfolder
        plane_folder = fullfile(output_folder, plane_name);
        if ~exist(plane_folder, 'dir')
            mkdir(plane_folder);
        end
        
        % Get current z-plane data
        eval(sprintf('current_images = %s_images;', plane_name));
        eval(sprintf('current_timestamps = %s_timestamps;', plane_name));
        
        % Save timestamp file
        timestamp_file = fullfile(plane_folder, sprintf('%s_timestamps.txt', plane_name));
        valid_timestamps = current_timestamps(current_timestamps > 0);
        if ~isempty(valid_timestamps)
            fid = fopen(timestamp_file, 'w');
            fprintf(fid, '%% %s timestamp file\n', plane_name);
            fprintf(fid, '%% Generated: %s\n', datestr(now));
            fprintf(fid, '%% Imaging speed: %.3f volume/second\n', imaging_speed);
            fprintf(fid, '%% Total time points: %d\n', length(valid_timestamps));
            fprintf(fid, '%% Format: One timestamp per line (seconds)\n');
            fprintf(fid, '%%\n');
            for t = 1:length(valid_timestamps)
                fprintf(fid, '%.6f\n', valid_timestamps(t));
            end
            fclose(fid);
            fprintf('  Saved timestamp file: %s\n', timestamp_file);
        end
        
        % Save TIFF series (8-bit)
        valid_images = current_images(~cellfun(@isempty, current_images));
        if ~isempty(valid_images)
            % Get image data range for 8-bit conversion
            all_pixel_values = [];
            sample_size = min(10, length(valid_images)); % Sample first 10 images to estimate dynamic range
            for i = 1:sample_size
                img = valid_images{i};
                % Handle other data types
                all_pixel_values = [all_pixel_values; double(img(:))];
                
            end
            
            % Calculate dynamic range (use percentiles to avoid extreme values)
            min_val = prctile(all_pixel_values, 0.1);  % 0.1 percentile
            max_val = prctile(all_pixel_values, 99.9); % 99.9 percentile
            
            fprintf('  Image dynamic range: [%.2f, %.2f] (using 0.1-99.9 percentiles)\n', min_val, max_val);
            
            % Save as single multi-frame TIFF file (time series)
            tiff_filename = fullfile(plane_folder, sprintf('%s_timeseries.tif', plane_name));
            
            fprintf('  Creating time series TIFF file...\n');
            
            for t = 1:length(valid_images)
                img = valid_images{t};
                
                % Convert to 8-bit (0-255)
                if max_val > min_val
                    img_normalized = (double(img) - min_val) / (max_val - min_val);
                else
                    img_normalized = double(img) / max(double(img(:)));
                end
                img_8bit = uint8(img_normalized * 255);
                
                % Save as multi-frame TIFF
                if t == 1
                    % First frame: create new file
                    imwrite(img_8bit, tiff_filename, 'tif', ...
                           'Compression', 'none', 'WriteMode', 'overwrite');
                else
                    % Subsequent frames: append to existing file
                    imwrite(img_8bit, tiff_filename, 'tif', ...
                           'Compression', 'none', 'WriteMode', 'append');
                end
                
                % Show progress
                if mod(t, 500) == 0 || t == length(valid_images)
                    fprintf('  Processed %d/%d frames\n', t, length(valid_images));
                end
            end
            
            fprintf('  Saved time series TIFF file (%d frames): %s\n', length(valid_images), tiff_filename);
        end
        
        fprintf('  %s processing completed\n\n', plane_name);
    end
    
        % Create overall information file
        info_file = fullfile(output_folder, 'dataset_info.txt');
        fid = fopen(info_file, 'w');
        fprintf(fid, '%% ND2 Dataset Information File\n');
        fprintf(fid, '%% Generated: %s\n', datestr(now));
        fprintf(fid, '%% Original file: %s\n', file);
        fprintf(fid, '%%\n');
        fprintf(fid, '%% === Image Parameters ===\n');
        fprintf(fid, 'Number of Z planes: %d\n', nZ);
        fprintf(fid, 'Number of time points: %d\n', nT);
        fprintf(fid, 'Number of channels: %d\n', nC);
        fprintf(fid, 'Image size: %d x %d pixels\n', nX, nY);
        fprintf(fid, 'Total images: %d\n', nPlanes);
        fprintf(fid, 'Imaging speed: %.3f volume/second\n', imaging_speed);
        fprintf(fid, 'Average volume interval: %.3f seconds\n', avg_volume_interval);
        fprintf(fid, '%%\n');
        fprintf(fid, '%% === Saved Z Planes ===\n');
        for i = 1:length(planes_to_save)
            z = planes_to_save(i);
            fprintf(fid, 'Z%d/: Z%d plane time series TIFF and timestamps\n', z, z);
        end
        fprintf(fid, '%%\n');
        fprintf(fid, '%% === Data Format Description ===\n');
        fprintf(fid, '1. Each Z plane saved as single time series TIFF file\n');
        fprintf(fid, '2. TIFF files converted to 8-bit format for easy processing\n');
        fprintf(fid, '3. Timestamp files for time-related analysis\n');
        fprintf(fid, '4. Each Z plane contains complete time series data\n');
        fprintf(fid, '5. File naming format: Z[plane]_timeseries.tif (multi-frame time series)\n');
        fprintf(fid, '6. Compatible with various image analysis software and custom GUI processing\n');
        fclose(fid);
        
        fprintf('Created dataset information file: %s\n', info_file);
        
        fprintf('\n=== Save Completed ===\n');
        fprintf('Saved %d z-plane data to: %s\n', length(planes_to_save), output_folder);
        fprintf('Each z-plane contains:\n');
        fprintf('- Multi-frame time series TIFF file (8-bit format)\n');
        fprintf('- Timestamp file (.txt format)\n');
        fprintf('\nGenerated auxiliary files:\n');
        fprintf('- Dataset information file: %s\n', info_file);
        fprintf('\nData is ready for manual ROI processing in **suite2p** GUI!\n');
    end
end

% Clean up reader object
reader.close();

% Clear workspace
clear all;