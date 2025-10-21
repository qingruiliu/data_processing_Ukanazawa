# 1. Read the .nd2 file

## Using the file [step1_read_nd2.m](https://github.com/qingruiliu/data_processing_Ukanazawa/blob/main/2P_data_processing_MATLAB/step1_read_nd2.m)

### Description

- Directly read the `.nd2` file in MATLAB
- Automatically save the `.tif` sequence and `.txt` timestamps of all or individual imaging planes
- Prepare the files for next step (**suite2p** input)

### Dependency

- OME Bio-formats Toolbox for MATLAB [(links)](https://www.openmicroscopy.org/bio-formats/downloads/)

### How to use

1. load step1_read_nd2.m in MATLAB
2. select the target **resonant volume 2P** .nd2 file
