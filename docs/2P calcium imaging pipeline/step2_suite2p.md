---
layout: default
title: "Step 2: Suite2p Processing"
nav_order: 2
parent: "2P Calcium Imaging Pipeline"
---

# 2. Suite2p for registration, ROI detection and spike detection

## Description

---

## Dependency

- python virtual environment (managed by anaconda) with **suite2p** installed
- **cellpose** installed in the same environment is recommended (for better cell segmentation)

---

## How to use

### input

- Open suite2p through your command window

```
$ conda activate your-suite2p-environment
$ python -m suite2p
```

- File --> Run suite2P
- `Add directory to data_path` and choose the folder containing image sequence
- Adjust the necessary settings:

![suite2p_setting](assets/images/step2_fig1.jpg)

- **fs:** imaging frequency (input your actual frequency)
- **save_mat:** output .mat file
- **denoise:** denoise the image using PCA
- **anatomical_only:** 1 is recommended
- **pretrained_model:** `cpsam` (if cellpose installed), `cyto3`

### output

- suite2p log output:
  ![log_output](assets/images/step2_fig2.png)

- GUI output:
  ![gui_output](assets/images/step2_fig3.png) - including the detected ROIs which are cells (left panel) and not cells (right panel) recognized automatically （Manually adjusting the ROIs is necessary）
- File output:
  ![file_output](assets/images/step2_fig4.png)
  - separate `.npy` files for python program
  - `Fall.mat` for the data processing using MATLAB

## More info

- check https://suite2p.readthedocs.io/en/latest/settings.html
