# itchline

Reusable itch.io Butler upload helper that mirrors the Steamline workflow.

## What lives in this module

- `itchline.sh`: generic itch upload runner
- `butler-upload-builds.sh`: compatibility wrapper that forwards to `itchline.sh`
- `examples/`: starter templates for game-owned env config

## Expected game-owned files (outside module)

In your game repo, commit a config such as:

- `itchline.config.env`

Then create your local private config (ignored by git):

- `itchline.config.local.env`

You can copy a starter config from `itchline/examples/itchline.config.env.example`.

## Usage

From repo root:

```bash
./itchline/itchline.sh --check
./itchline/butler-upload-builds.sh --check
./itchline/butler-upload-builds.sh
```

Override config path if needed:

```bash
./itchline/itchline.sh --config ./itchline.config.local.env --check
./itchline/itchline.sh --config ./itchline.config.env --check
```

## Config variables

- `BUTLER_BIN`
- `ITCH_TARGET`
- `ITCH_BUILD_PATH_LINUX`
- `ITCH_BUILD_PATH_WINDOWS`
- `ITCH_BUILD_PATH_MAC`
- `ITCH_CHANNEL_LINUX`
- `ITCH_CHANNEL_WINDOWS`
- `ITCH_CHANNEL_MAC`
- `ITCH_USER_VERSION`
- `BUTLER_API_KEY`

`BUTLER_API_KEY` is optional if you already authenticated Butler locally.
