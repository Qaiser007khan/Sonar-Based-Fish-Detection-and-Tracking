# Sonar-Based-Fish-Detection-and-Tracking

Real-time sonar-video fish detection, tracking, behavior classification, and species estimation using MATLAB Computer Vision workflows.

## Demo Showcase

<p align="center">
	<img src="demo%20%20videos/Fish.gif" alt="Sonar fish detection demo 1" width="47%" />
	<img src="demo%20%20videos/Fish_1.gif" alt="Sonar fish detection demo 2" width="47%" />
</p>

## Overview

This project implements a full pipeline for underwater fish monitoring from sonar/video streams:

- Foreground extraction using Gaussian mixture based background subtraction
- Multi-object fish tracking with centroid matching and motion continuity
- Motion behavior classification (Milling/Running, Up/Down)
- Speed estimation in cm/s from tracked trajectories
- Rule-based species estimation (Salmon/Trout) from estimated fish length
- Timestamped result export to Excel for analytics and reporting

## Core Technical Highlights

### Detection and Segmentation

- `vision.ForegroundDetector` with tunable training frames and background ratio
- Morphological denoising (`imopen`, `imclose`, `imfill`, `bwareaopen`)
- Blob extraction with area filtering to remove small artifacts

### Tracking

- Bounding-box and centroid-based multi-object association
- Per-fish persistent IDs over frames
- Lost-track handling with configurable `maxLostFrames`
- Trajectory rendering and frame-wise visual annotations

### Motion and Speed Analytics

- Euclidean displacement from centroid history
- Mean speed estimation:

$$
v = \overline{\|p_t - p_{t-1}\|} \times s \times fps
$$

where $s$ is the pixel-to-cm scale factor.

- Motion classes:
	- Milling Up
	- Milling Down
	- Running Up
	- Running Down

### Species Estimation and Reporting

- Fish length estimated from bounding-box diagonal
- Length-threshold heuristic for Salmon vs Trout labeling
- Frame index and timestamp-based event logging
- Exported tabular output (`.xlsx`) with fish ID, date, time, motion, length, species, and range

## Important Files

- `MotionBasedMultiObjectTrackingExample.m`: Kalman-based motion tracking example with foreground segmentation
- `Optimizedcodefordetection.m`: streamlined detection script for practical experimentation
- `op7.m`: advanced tracking, motion labeling, speed analytics, and Excel export
- `c1.m`, `c2.m`, `c3.m`, `c4.m`: iterative variants for thresholding, crop region tuning, and tracking behavior logic
- `demo  videos/Fish.gif`, `demo  videos/Fish_1.gif`: showcase demos

## Requirements

- MATLAB
- Computer Vision Toolbox
- Image Processing Toolbox

## How To Run

1. Open the project in MATLAB.
2. Select one of the primary scripts (`op7.m` recommended for full analytics).
3. Set `videoFile` to your sonar/video input.
4. Tune thresholds (`minArea`, `speedThreshold`, `maxLostFrames`, `scaleFactor`) for your environment.
5. Run and review:
	 - live visualization (tracks, IDs, trajectories)
	 - output Excel file for downstream analysis

## Application Areas

- Fish passage monitoring
- Aquaculture behavior analysis
- Environmental and biodiversity studies
- Fisheries stock assessment workflows

## Project Notes

This repository contains multiple script variants that reflect practical experimentation across different data conditions and deployment scenarios.
