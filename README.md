# TI-84 Plus Video Player

Play full-motion monochrome video on a TI-84 Plus using a custom Z80 assembly decoder and a MATLAB/Java encoding pipeline.

The project converts an ordinary video into 96 x 64, 1-bit frames, compresses those frames into calculator AppVars, and streams them directly from flash memory during playback. Delta encoding and run-length compression reduce storage and decompression work enough to make video playback practical on the calculator's 6 MHz Z80 processor.

## Demo

[![TI-84 Plus video player demonstration](https://img.youtube.com/vi/9Fys8kvQSf8/maxresdefault.jpg)](https://youtube.com/shorts/9Fys8kvQSf8)

Click the image above to watch the player running on real hardware.

## How it works

```text
Input video
    |
    v
MATLAB preprocessing
  - samples frames at the requested rate
  - resizes each frame to 96 x 64
  - converts it to grayscale
  - applies ordered Bayer dithering
  - XORs each frame with the previous frame
    |
    v
Java encoder
  - packs pixels into bytes
  - applies run/literal compression
  - divides the stream into complete-frame chunks
  - writes TI AppVar (.8xv) files
    |
    v
Z80 assembly player
  - reads archived AppVars directly from flash
  - handles flash-page and file-chunk boundaries
  - decompresses each delta frame into the graph buffer
  - copies completed frames to the LCD
```

The first frame is stored directly. Every later frame contains the XOR difference between the current and previous images. During playback, each decoded byte is XORed into the existing screen buffer, reconstructing the next frame without storing two full frames in RAM.

Each compressed block begins with a one-byte header:

- Bit 7 selects a repeated-byte run (`1`) or a literal sequence (`0`).
- Bits 0-6 store the sequence length minus one, allowing lengths from 1 to 128 bytes.
- A run stores one data byte; a literal sequence stores each byte individually.

## Requirements

- A monochrome Z80 TI calculator compatible with TI-83 Plus assembly programs, such as the TI-84 Plus
- [MATLAB](https://www.mathworks.com/products/matlab.html) with the Image Processing Toolbox
- A Java Development Kit (JDK)
- A Z80 assembler compatible with `ti83plus.inc`, such as [SPASM-ng](https://github.com/alberthdev/spasm-ng)
- TI Connect or another link utility capable of transferring `.8xp` and `.8xv` files

## Creating a video

### 1. Compile the Java encoder

From the repository root:

```bash
javac Compress.java
```

The included `Compress.class` may also be used if it is compatible with your installed Java version.

### 2. Convert the source video

Run `video2calc` from MATLAB:

```matlab
video2calc("path/to/video.mp4", "-o", "myvideo", "-c", "30000", "-fps", "15")
```

Options:

| Option | Default | Description |
| --- | ---: | --- |
| `-o` | `VIDEO` | Prefix used for the generated files on the computer |
| `-c` | `30000` | Approximate maximum compressed bytes per AppVar chunk |
| `-fps` | `15` | Number of source frames sampled per second |

For example, the command above creates files such as `myvideoa.8xv`, `myvideob.8xv`, and `myvideoc.8xv`. Internally, their calculator variable names are `VIDEOa`, `VIDEOb`, `VIDEOc`, and so forth, which is what the assembly player expects.

`video2calc.m` writes the intermediate frame data to `videodata.txt`, then invokes the Java encoder automatically. The output files are created in MATLAB's current working directory.

> The requested frame rate controls how frequently the source video is sampled. The calculator does not currently store timing metadata or delay frames to enforce an exact playback rate; actual speed depends on compressed frame complexity and calculator performance.

### 3. Assemble the player

Using SPASM-ng, assemble the main player source into a calculator program:

```bash
spasm src/main.asm bin/video.8xp
```

### 4. Transfer the files

Transfer the following to the calculator:

1. The assembled player program (`video.8xp`)
2. Every generated video chunk (`.8xv`)

Keep the AppVars archived. The player begins with `VIDEOa`, then automatically advances through `VIDEOb`, `VIDEOc`, and the remaining alphabetically named chunks. Playback ends when the next chunk cannot be found.

### 5. Run the player

Launch the assembled program using the calculator's normal assembly-program method. The screen is cleared and playback begins immediately.

## Repository layout

| Path | Purpose |
| --- | --- |
| `video2calc.m` | Main MATLAB command-line preprocessing pipeline |
| `video2calcUI.mlapp` | MATLAB App Designer interface |
| `Compress.java` | Compression, chunking, and `.8xv` AppVar generation |
| `src/main.asm` | Current Z80 playback implementation |
| `include/ti83plus.inc` | TI system calls, flags, and hardware definitions |
| `bin/` | Preassembled calculator programs |
| `Videos/` | Example input videos and encoded AppVars |
| `videodata.txt` | Intermediate comma-separated frame data |
| `test.m` | Example conversion invocation |

## Implementation highlights

- Processes native 96 x 64 monochrome calculator frames
- Uses 4 x 4 Bayer ordered dithering to preserve recognizable detail
- Encodes inter-frame differences with XOR delta frames
- Combines repeated-byte runs and literal sequences in one compact format
- Streams video from archived AppVars instead of loading the entire video into RAM
- Reads data through a 768-byte RAM buffer
- Preserves decompression state when a compressed sequence crosses a buffer boundary
- Handles reads that cross the calculator's `0x8000` flash-page boundary
- Splits long videos across multiple AppVars without dividing an individual frame

## Current limitations

- Monochrome video only
- No audio
- Playback has no pause, seek, or early-exit controls
- Frame timing is not synchronized to the source video's exact frame rate
- The player expects calculator AppVars named `VIDEOa`, `VIDEOb`, and so on
- Chunk suffixes are single letters, limiting one encoded sequence to 26 chunks

## License

No license has been added yet. Until one is provided, the source remains under the repository owner's default copyright.
