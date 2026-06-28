# Runtime Manifest

Runtime provenance is pinned in:

```text
third_party_manifest/runtime.lock
```

## Runtime Tags

| Tag | Bundle | Production Role |
|---|---|---|
| `rt123` | `spacemit-ort.riscv64.1.2.3` | vendor320 visual and fast-live |
| `rt201` | `spacemit-ort.riscv64.2.0.1` | dynamic640 production and vendor320 perf |
| `rt202b1` | `spacemit-ort.riscv64.2.0.2+beta1` | FP16 640 experimental fallback |
| `rt202` | `spacemit-ort.riscv64.2.0.2` | reproducible regression only; not adopted |

## Known Library SHA256

| Runtime | Library | SHA256 |
|---|---|---|
| `rt123` | `libonnxruntime.so.1.18.1` | `6a716a747ab456750b7154633eb956b36854808e3c8c36f270669cf1bf0ada4e` |
| `rt123` | `libspacemit_ep.so.1.2.3` | `90af14e058ffd71bd4b2e56c1aba8e6cde61c5f5fde75b865f60d832a5bbd38b` |
| `rt201` | `libonnxruntime.so.1.20.2+spacemit` | `5a28c8128a7b1ed9cb29357f42eb7a2a45eb1b23d8791c2fee1eaf0151546238` |
| `rt201` | `libspacemit_ep.so.2.0.1` | `60ad2a0f0e25c3e557250600bc51a3288007d810b1625ec2af394e84bc72a572` |
| `rt202b1` | `libonnxruntime.so.1.24.0+spacemit.a3` | `e100b2a480afd9809ea708eb1e13a68c6a8032a08aec8b712dbb803f5e9a8b6d` |
| `rt202b1` | `libspacemit_ep.so.2.0.2+beta1` | `788bbf8d49ee107f69b22c72cb5ef0ca6c270e2f77345cb705022e18d3aae3e3` |
| `rt202` | `libonnxruntime.so.1.24.2+spacemit.a1` | `e4abc60c53b1bcf0e3cde31b284d67c242ba3db8a2dbac3b10f0d817828fc289` |
| `rt202` | `libspacemit_ep.so.2.0.2` | `c7bab0898d458151ffd255f69c0df6029ff17d569133a4106239159d9e077d67` |
