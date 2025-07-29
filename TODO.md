# TODO - clip.lua Improvements

## Missing Features

### Medium Priority

- **Custom filename templates** - User-defined naming patterns beyond `_1`, `_2` suffixes
- **Video filters** - Support for scaling, cropping, denoising, sharpening via `-vf`
- **Subtitle burn-in option** - Hardcode subtitles into video instead of just copying streams
- **Progress indication** - Show encoding progress bar or percentage

### Low Priority

- **Multiple clip queuing** - Queue multiple clips to encode sequentially
- **Undo/redo timestamps** - Navigate back to previous start/end points
- **Audio sample rate/channels** - Override source audio settings

## Missing ffmpeg Parameters

### High Priority

- **Video filters** - `-vf scale=1920:1080`, `-vf crop=w:h:x:y`, etc.

### Medium Priority

- **Container format override** - Force `.mkv`, `.avi` regardless of encoder choice
- **Profile/level settings** - H.264/H.265 `-profile:v`, `-level`
- **Keyframe interval** - `-g` parameter for GOP size control
- **Thread count** - `-threads` for encoding performance tuning

### Low Priority

- **B-frames** - `-bf` parameter for better compression
- **Pixel format** - `-pix_fmt` for color space control (yuv420p, yuv444p, etc.)
- **Audio codec options** - More granular audio encoding settings

## Implementation Notes

- Video filters need input validation for dimensions and coordinates
