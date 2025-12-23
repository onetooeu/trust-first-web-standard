#!/usr/bin/env python3
import json, os, hashlib
from datetime import datetime, timezone

def iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def canonical(obj)->bytes:
    return json.dumps(obj, separators=(",",":"), sort_keys=True).encode("utf-8")

def sha256_path(p):
    with open(p,"rb") as f: return hashlib.sha256(f.read()).hexdigest()

def load(p):
    with open(p,"r",encoding="utf-8") as f: return json.load(f)

def save(p,obj):
    with open(p,"w",encoding="utf-8") as f: json.dump(obj,f,ensure_ascii=False,indent=2)

def main():
    import argparse
    ap=argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--policy_dir", default="./.well-known/policy")
    args=ap.parse_args()

    root=args.root
    P=args.policy_dir.rstrip("/")
    bundle_path=os.path.join(P,"policy.bundle.json")

    # include only top-level policy json (not archive receipts)
    artifacts=[]
    for name in sorted(os.listdir(P)):
        if not name.endswith(".json"): 
            continue
        full=os.path.join(P,name)
        if os.path.isfile(full):
            artifacts.append({
                "path": "/.well-known/policy/" + name,
                "sha256": sha256_path(full),
                "sig_path": "/.well-known/policy/sigs/" + name + ".minisig"
            })

    bundle={
        "schema":"tfws-ap.policy.bundle.v1",
        "policy_id":"onetoo.eu/trust-policy",
        "created_utc": iso(),
        "artifacts": artifacts
    }
    bundle["bundle_hash_sha256"]=hashlib.sha256(canonical(bundle)).hexdigest()
    save(bundle_path, bundle)
    print("Bundle written:", bundle_path)

if __name__=="__main__":
    main()
