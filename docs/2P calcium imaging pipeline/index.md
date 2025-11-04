---
layout: default
title: "2P Calcium Imaging Pipeline"
nav_order: 2
has_children: true
---

# 2P Calcium Imaging Pipeline

This section covers the complete pipeline for processing two-photon calcium imaging data, from raw .nd2 files to final analysis results.

## Overview

The pipeline consists of four main steps:

1. **Read .nd2 file** - Convert raw Nikon .nd2 files to TIFF sequences
2. **Suite2p Processing** - Registration, ROI detection, and spike detection
3. **Functional Masks** - Create functional masks for each imaging plane
4. **Anatomical Masks** - Generate 3D anatomical masks using Cellpose

Each step builds upon the previous one to provide a comprehensive analysis workflow for calcium imaging data.
