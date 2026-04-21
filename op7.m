close all
clear all
clc

% Calculate speed function
function speed = calculateSpeed(positions, scaleFactor, fps)
    if size(positions, 1) < 2
        speed = 0;
    else
        diffs = diff(positions, 1, 1); % Differences between consecutive positions
        distances = sqrt(sum(diffs.^2, 2)); % Euclidean distance
        speed = mean(distances) * scaleFactor * fps; % Speed in cm/s
    end
end

% Classify motion function
function motionType = classifyMotion(positions, scaleFactor, fps)
    % Initialize default motion type
    motionType = 'Unknown';

    % Check if there are sufficient positions
    if size(positions, 1) < 2
        return;
    end

    % Calculate speed and direction
    diffs = diff(positions, 1, 1); % Differences between consecutive positions
    distances = sqrt(sum(diffs.^2, 2)); % Euclidean distance
    speeds = distances * 2 * fps; % Convert to cm/s using scale factor and frame rate
    avgSpeed = mean(speeds); % Average speed

    % Determine direction
    avgDirectionY = mean(diffs(:, 2)); % Average change in y-coordinate

    % Improved motion classification
    speedThreshold = 150; % Adjust threshold for milling vs running
    if avgSpeed <= speedThreshold
        if avgDirectionY > 0
            motionType = 'Milling Down';
        elseif avgDirectionY < 0
            motionType = 'Milling Up';
        end
    elseif avgSpeed > speedThreshold
        if avgDirectionY > 0
            motionType = 'Running Down';
        elseif avgDirectionY < 0
            motionType = 'Running Up';
        end
    end
end

% Initialize the video reader and background subtraction method
videoFile = 'harbour_seal.mp4'; % Specify your video file path
vidReader = VideoReader(videoFile);
bgSubtractor = vision.ForegroundDetector('NumGaussians', 3, 'NumTrainingFrames', 50, 'MinimumBackgroundRatio', 0.80);

MaxFrame = 800;
% Prepare to save data to an Excel file
outputFile = 'harbour_seal.xlsx';
fishData = {}; % Cell array to store fish data (ID, date, timestamp, frame number, motion, length, species, range)

fishID = 0; % Initial fish ID
frameCount = 0; % Frame count
trackedFish = []; % Struct array to store tracked fish

% Extracting date from file name
[~, fileName, ~] = fileparts(videoFile); % Get file name without extension
fileDate = regexp(fileName, '\d{4}-\d{2}-\d{2}', 'match', 'once'); % Match date pattern
if ~isempty(fileDate)
    formattedDate = datestr(datetime(fileDate, 'InputFormat', 'yyyy-MM-dd'), 'yyyy-mm-dd');
else
    formattedDate = 'Unknown Date';
end

disp(['Extracted Date: ', formattedDate]); % Display the extracted date

% Additional variables for calculations
fps = 5; % Frames per second
scaleFactor = 2; % Conversion factor from pixels to cm

maxLostFrames = 20; % Max frames a fish can be undetected before being removed

while hasFrame(vidReader) && frameCount < MaxFrame
    frameCount = frameCount + 1;
    frame = readFrame(vidReader);
    
    % Convert to grayscale for background subtraction
    grayFrame = rgb2gray(frame);
    
    % Apply foreground detection
    foregroundMask = step(bgSubtractor, grayFrame);
    foregroundMask = imopen(foregroundMask, strel('disk', 3)); % Remove noise
    
    % Find blobs (possible fishes)
    stats = regionprops(foregroundMask, 'BoundingBox', 'Area', 'Centroid');
    
    % Only consider objects with a minimum area (to avoid small noise blobs)
    minArea = 180; % Minimum area for a valid fish
    validFish = stats([stats.Area] > minArea);
    
    % Update tracking for detected fishes
    for k = 1:length(validFish)
        matched = false;
        for m = 1:length(trackedFish)
            % Matching threshold with maximum distance
            if norm(validFish(k).Centroid - trackedFish(m).centroid) < 150 && ...
               abs(validFish(k).Area - trackedFish(m).area) / trackedFish(m).area < 0.8
                trackedFish(m).centroid = validFish(k).Centroid;
                trackedFish(m).boundingBox = validFish(k).BoundingBox;
                trackedFish(m).area = validFish(k).Area;
                trackedFish(m).lastSeen = frameCount; % Update last seen frame
                trackedFish(m).finalFrame = frameCount; % Update final frame
                trackedFish(m).length = sqrt(validFish(k).BoundingBox(3)^2 + validFish(k).BoundingBox(4)^2); % Update fish length (diagonal length)
                trackedFish(m).positions = [trackedFish(m).positions; validFish(k).Centroid]; % Update positions
                matched = true;
                break;
            end
        end
        
        % If not matched, assign a new fish ID
        if ~matched
            fishID = fishID + 1;
            newFish = struct('id', fishID, ...
                             'centroid', validFish(k).Centroid, ...
                             'boundingBox', validFish(k).BoundingBox, ...
                             'area', validFish(k).Area, ...
                             'firstFrame', frameCount, ...
                             'finalFrame', frameCount, ...
                             'lastSeen', frameCount, ...
                             'length', sqrt(validFish(k).BoundingBox(3)^2 + validFish(k).BoundingBox(4)^2), ... % Diagonal length
                             'positions', validFish(k).Centroid); % Initialize positions
            trackedFish = [trackedFish; newFish]; % Append new fish to the struct array
        end
    end
    
    % Remove fishes that have been undetected for too long
    for m = length(trackedFish):-1:1
        if frameCount - trackedFish(m).lastSeen > maxLostFrames
            % Save fish data when it is no longer being tracked
            fishRange = -0.01812 * trackedFish(m).centroid(2) + 20.59; % Calculate range based on centroid position

            % Classify motion type
            motionType = classifyMotion(trackedFish(m).positions, scaleFactor, fps);
            
            % Skip saving if motion type is unknown
            if strcmp(motionType, 'Unknown')
                trackedFish(m) = [];
                continue;
            end
            
            % Estimate fish length in cm based on diagonal length of bounding box (use scale factor)
            fishLength = scaleFactor * trackedFish(m).length; % Diagonal length as fish length
            
            % Classify fish as Salmon or Trout based on length
            if fishLength > 50
                species = 'Salmon';
            else
                species = 'Trout';
            end
            
            % Calculate timestamp
            total_seconds = trackedFish(m).finalFrame / fps;
            hours = floor(total_seconds / 3600);
            minutes = floor(mod(total_seconds, 3600) / 60);
            seconds = floor(mod(total_seconds, 60));
            timestamp = sprintf('%02d:%02d:%02d', hours, minutes, seconds);
            
            % Store fish data
            fishData{end + 1, 1} = trackedFish(m).id;        % Fish ID
            fishData{end, 2} = formattedDate;                % Date
            fishData{end, 3} = timestamp;                    % Timestamp
            fishData{end, 4} = trackedFish(m).finalFrame;    % Frame number
            fishData{end, 5} = motionType;                   % Motion type
            fishData{end, 6} = fishLength;                   % Length (cm)
            fishData{end, 7} = species;                      % Species
            fishData{end, 8} = fishRange;                    % Range (m)
            
            % Remove fish from trackedFish array
            trackedFish(m) = [];
        end
    end
    
    % Display the tracked fishes
    for m = 1:length(trackedFish)
        % Draw bounding box around the fish and label it with the fish ID
        frame = insertShape(frame, 'Rectangle', trackedFish(m).boundingBox, 'Color', 'green', 'LineWidth', 2);
        frame = insertText(frame, trackedFish(m).centroid, num2str(trackedFish(m).id), 'TextColor', 'red', 'FontSize', 12);
        
        % Mark the centroid with a red dot
        frame = insertShape(frame, 'FilledCircle', [trackedFish(m).centroid, 5], 'Color', 'red');
        
        % Draw trajectory
        if size(trackedFish(m).positions, 1) > 1
            trajectoryPoints = trackedFish(m).positions;
            trajectoryPoints(:, 1) = trajectoryPoints(:, 1) + 0.5; % To correct visualization offset
            frame = insertShape(frame, 'Line', ...
                                reshape(trajectoryPoints', 1, []), 'Color', 'red', 'LineWidth', 2);
        end
        
        % Calculate speed
        speed = calculateSpeed(trackedFish(m).positions, scaleFactor, fps);
        
        % Display motion type and speed
        annotationText = sprintf('Type: %s\nSpeed: %.2f cm/s', classifyMotion(trackedFish(m).positions, scaleFactor, fps), speed);
        frame = insertText(frame, trackedFish(m).centroid, annotationText, ...
                           'FontSize', 12, 'TextColor', 'cyan', 'BoxColor', 'black');
    end
    
    % Show frame with tracking
    imshow(frame);
    title(['Frame: ', num2str(frameCount), ', Total Fish Count: ', num2str(fishID)]);
    pause(0.01);
end

% Save tracked data to Excel
fishDetailsTable = cell2table(fishData, ...
    'VariableNames', {'FishID', 'Date', 'Timestamp', 'FrameNumber', 'Motion', 'Length(cm)', 'Species', 'Range(m)'});
writetable(fishDetailsTable, outputFile);

disp('Fish tracking complete. Data saved to Excel.');