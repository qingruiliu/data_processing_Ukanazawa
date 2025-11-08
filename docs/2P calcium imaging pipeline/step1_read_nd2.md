---
layout: default
title: "Step 1: Read .nd2 file"
nav_order: 1
parent: "2P Calcium Imaging Pipeline"
---

# 1. Read the .nd2 file

- Using the file [step1_read_nd2.m](https://github.com/qingruiliu/data_processing_Ukanazawa/blob/main/2P_data_processing_MATLAB/step1_read_nd2.m)

### Description

- Directly read the `.nd2` file in MATLAB
- Automatically save the `.tif` sequence and `.txt` timestamps of all or individual imaging planes
- Prepare the files for next step (**suite2p** input)

### Dependency

- OME Bio-formats Toolbox for MATLAB [(links)](https://www.openmicroscopy.org/bio-formats/downloads/)
- Download and add the functions to the MATLAB path

### How to use

1. load step1_read_nd2.m in MATLAB
2. select the target **resonant volume 2P** .nd2 file
3. MATLAB reading the `.nd2` images
   ![MATLAB_reading](assets/images/step1_fig1.jpg)
4. When finish reading `.nd2` file, window asking to save the files pop out:
   ![saving_window](assets/images/step1_fig2.jpg)

- `Yes` for all planes
- `Select specific planes` to pick certain planes

5. Select saving path
6. Data output:
   ![step1_output](assets/images/step1_fig3.jpg)

### Output

- `dataset_info.txt`: MATLAB log in the command windw
- `*_timestamps.txt`: timestamp for each frame of the image sequence
- `*_timeseries.tif`: 8-bit grayscale image sequence for `suite2p` input
