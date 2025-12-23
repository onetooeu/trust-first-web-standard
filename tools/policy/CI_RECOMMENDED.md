# CI recommendation (v1.4.1)

Goal: fail builds if quorum is not satisfied for required artifacts.

## Minimum CI steps
1) Install deps: `jq`, `minisign`, `python3`
2) Run policy generation / publish as needed (or just verify)
3) Verify quorum:

```bash
tools/policy/verify_quorum.sh
```

## Notes
- For true **M-of-N**, generate signatures per key id:
  - `KID=k1-provider tools/policy/publish_policy.sh`
  - `KID=k2-safety tools/policy/publish_policy.sh`
  - `KID=k3-audit tools/policy/publish_policy.sh`
- Each signer uses its own secret key (never committed).
