# Build Manifest

## Canonical Environment

| Variable | Value |
|---|---|
| Toolchain | `/data/SpacemiT/spacemit-toolchain-linux-glibc-x86_64-v1.1.2` |
| Base sysroot | `${TOOLCHAIN_ROOT}/sysroot` |
| Overlay sysroot | `/data/sysroots/k1x-gtk3-overlay` |
| ISA/ABI | `-march=rv64gcv_zvfh -mabi=lp64d` |
| Board target | `svt@banana` |

## Rules

- Source `/data/build_scripts/01-env.sh` before build/deploy work.
- Do not modify the base sysroot.
- Do not copy a full board `/usr` into any sysroot.
- Keep OpenCV and extra board dependencies in the overlay/staged deployment.

## Build and Deploy

```bash
source /data/build_scripts/01-env.sh
./scripts/fetch_vendor_runtime.sh
./scripts/fetch_models.sh
./scripts/build_cross.sh
./scripts/deploy_to_banana.sh
```

The deployed app must pass loader proof before production use.
