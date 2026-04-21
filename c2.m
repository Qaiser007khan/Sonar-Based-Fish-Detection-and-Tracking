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
    speeds = distances * scaleFactor * fps; % Convert to cm/s using scale factor and frame rate
    avgSpeed = mean(speeds); % Average speed

    % Determine direction
    avgDirectionY = mean(diffs(:, 2)); % Average change in y-coordinate

    % Improved motion classification
    speedThreshold = 100; % Adjust threshold for milling vs running
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

% Main code
MaxFrame = 1100;
videoFile = '2023-07-01_160000.mp4'; % Specify your video file path
vidReader = VideoReader(videoFile);
bgSubtractor = vision.ForegroundDetector('NumGaussians', 3, 'NumTrainingFrames', 1000, 'MinimumBackgroundRatio', 0.8);

% Prepare to save data to an Excel file
outputFile = 'fish_2023-07-01_160000.xlsx';
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

% Background subtraction setup
if hasFrame(vidReader)
    prevFrame = rgb2gray(readFrame(vidReader));
end

% Define the blue cone crop area
% Adjust these values based on your specific cone region in the video
cropX = 20; % X-coordinate of top-left corner
cropY = 200; % Y-coordinate of top-left corner
cropWidth = 660; % Width of the crop area
cropHeight = 1080; % Height of the crop area

% Process video frames
while hasFrame(vidReader) && frameCount < MaxFrame
    frameCount = frameCount + 1;
    frame = readFrame(vidReader);

    % Crop the frame to the cone-shaped region
    croppedFrame = imcrop(frame, [cropX, cropY, cropWidth, cropHeight]);
    grayFrame = rgb2gray(croppedFrame);

    % Apply foreground detection
    foregroundMask = step(bgSubtractor, grayFrame);
    foregroundMask = imopen(foregroundMask, strel('disk', 3)); % Remove noise

    % Frame difference method
    frameDiff = abs(double(grayFrame) - double(imcrop(prevFrame, [cropX, cropY, cropWidth, cropHeight])));
    threshold = 25;
    frameDiffMask = frameDiff > threshold;
    frameDiffMask = bwareaopen(frameDiffMask, 120); % Remove small noise blobs

    % Combine masks
    combinedMask = foregroundMask | frameDiffMask;

    % Find blobs (possible fishes)
    stats = regionprops(combinedMask, 'BoundingBox', 'Area', 'Centroid');
    
    % Only consider objects with a minimum area (to avoid small noise blobs)
    minArea = 220; % Minimum area for a valid fish
    validFish = stats([stats.Area] > minArea);

    % Update trackedFish and counting logic (implementation here...)
    % ... (tracking and saving logic remains)

    % Display information and masks in real time
    subplot(1, 2, 1);
    imshow(croppedFrame);
    title(['RGB Frame (Cropped) - Frame: ', num2str(frameCount)]);

    subplot(1, 2, 2);
    imshow(combinedMask);
    title(['Foreground Mask - Frame: ', num2str(frameCount)]);

    drawnow;

    % Update the previous frame
    prevFrame = grayFrame;
end

% Save tracked data to Excel
fishDetailsTable = cell2table(fishData, ...
    'VariableNames', {'FishID', 'Date', 'Timestamp', 'FrameNumber', 'Motion', 'Length(cm)', 'Species', 'Range(m)'});
writetable(fishDetailsTable, outputFile);

disp('Fish tracking complete. Data saved to Excel.');
