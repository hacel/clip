# clip

A mpv Lua script for creating clips using ffmpeg.

## Overview

This script allows you to quickly create clips from media files playing in mpv by setting start and end timestamps via a keybind. It uses ffmpeg and allows for some configuration.

## Features

- Set start and end timestamps while watching
- Maps currently selected video, audio, and subtitle streams
- File size limits with bitrate calculation
- Two-pass encoding option
- Works on Linux, macOS, Windows

## Requirements

- `mpv` media player
- `ffmpeg` (must be available in PATH)

## Installation

1. Copy `clip.lua` to your mpv scripts directory:
   - Linux/macOS: `~/.config/mpv/scripts/`
   - Windows: `%APPDATA%/mpv/scripts/`

2. Add key bindings to your `input.conf` file (see Usage section below)

## Usage

### Basic Usage

Add this line to your `input.conf` file for basic clipping with default settings:

```
x script-message-to clip clip
```

### Custom Parameters

Specify custom parameters using key-value pairs:

```
# 10MiB file size with two-pass encoding
x script-message-to clip clip file_size=10 two_pass=true

# High quality H.265 encoding with custom audio bitrate
X script-message-to clip clip video_encoder=libx265 audio_bitrate=192 preset=slow

# WebM output with VP9 encoder
c script-message-to clip clip video_encoder=libvpx-vp9 file_size=25

# Fast encoding preset
C script-message-to clip clip preset=fast file_size=50

# Save clips to custom directory
v script-message-to clip clip output_dir=/home/user/clips
```

### Available Parameters

- `file_size`: Maximum file size in mebibytes (MiB) (default: 0 = unlimited)
  - Automatically calculates video bitrate based on duration and audio bitrate
  - Recommended to set ~95% of desired size due to ffmpeg variance
- `video_encoder`: Video codec (default: 'libx264')
  - Supports any ffmpeg video encoder (libx264, libx265, libvpx, libvpx-vp9, etc.)
  - Automatically selects container (.mp4 for most, .webm for VP8/VP9)
- `audio_encoder`: Audio codec (default: 'aac')
- `audio_bitrate`: Audio bitrate in kbps (default: 128)
- `two_pass`: Enable two-pass encoding for better quality (default: false)
  - Requires `file_size` to be specified
- `preset`: Encoding speed/quality preset (default: 'medium')
- `output_dir`: Custom output directory (default: same as source file)
  - Directory must already exist

List available encoders: `ffmpeg -encoders`

### How to Create Clips

1. Start playing a video in mpv
2. Press your configured key binding at the desired start time
3. Navigate to the desired end time
4. Press the same key binding again to start clipping
5. Press ESC to cancel timestamp selection at any time

### Stream Mapping

To create clips without audio or subtitles, simply disable those streams in mpv before clipping - the script only includes currently active streams.

### Output Files

Files are saved in the same directory as the source video with numbered filenames (`original_filename_1.ext`, `original_filename_2.ext`, etc.).

### Error Handling

The script handles common errors and displays messages in the OSD. If clipping fails, check the mpv console (`` ` `` key by default) for ffmpeg error details.
