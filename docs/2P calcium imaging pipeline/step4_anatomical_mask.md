---
layout: default
title: "Step 4: Anatomical Masks"
nav_order: 4
parent: "2P Calcium Imaging Pipeline"
---

# 4. Create 3D anatomical masks

## Description

This step involves reading a static 3D Galvano scan (.nd2 file), visualizing it in 3D, and segmenting the deep layer cells. The segmented volume is then saved as a TIFF file, which can be used for further processing in Cellpose

---

## Dependency

- **Bio-Formats toolbox** (bfmatlab) installed and added to path
- Image Processing Toolbox (recommended for better 3D visualization)
- [**Cellpose**](https://github.com/MouseLand/cellpose)

---

## How to use

### input

- Run the script [`step4_anatomical_mask.m`](https://github.com/qingruiliu/data_processing_Ukanazawa/blob/main/2P_data_processing_MATLAB/step4_anatomical_mask.m) in MATLAB.
- Select the `.nd2` anatomical volume file when prompted.
- **Visualize**: The program will open a 3D viewer (e.g., `orthosliceViewer` or a custom slice viewer). Use this to inspect the volume.
- **Segment**:
  - A dialog will ask you to examine the volume and determine the starting Z-plane for deep layer cells.
  - Click **OK** when ready.
  - ![fig1](assets/images/step4_fig1.png)
  - Enter the Z-plane index (integer) where the deep layers begin. The program will keep all planes from this index to the bottom.
    - e.g. This volume can be segmented from Z = 100
    - ![fig2](assets/images/step4_fig2.png)
- **Save**:
  - The program will ask if you want to save the segmented volume.
  - Select **Yes** and choose a filename (e.g., `deep_layer_volume.tif`).

---

#### open Cellpose in your according virtual environment

```
$ conda activate cellpose-env # your environment name
$ cellpose --Zstack           # volume segmentation
```

- import the `deep_layer_volume.tif` in Cellpose
- ![fig3](assets/images/step4_fig3.png)
- click `runCPSAM`

#### manually curling of the 3D ROIs in cellpose GUI

- demo movie for drawing 3D ROI
  ![3DROI](assets/images/3DROI.gif)

- save the segmented images and ROIs as separate files
  ![fig4](assets/images/step4_fig4.png)

#### generate functional mask

- using the MATLAB script [`step4_cellPoseSliceAnd3DROI.m`](https://github.com/qingruiliu/data_processing_Ukanazawa/blob/main/2P_data_processing_MATLAB/step4_cellPoseSliceAnd3DROI.m)

- orthogonal view of the 3D ROIs after manual curation
  ![ortho_view](assets/images/ortho_view.gif)

- two tables and the sliced 3D ROIs are saved to the data directory
  ![fig5](assets/images/step4_fig5.jpg)
