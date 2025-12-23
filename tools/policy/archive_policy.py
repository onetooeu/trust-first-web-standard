#!/usr/bin/env python3
import json, os, shutil
from datetime import datetime, timezone

def iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def load(p):
    with open(p,"r",encoding="utf-8") as f: return json.load(f)

def main():
    import argparse
    ap=argparse.ArgumentParser()
    ap.add_argument("--policy_dir", default="./.well-known/policy")
    args=ap.parse_args()
    P=args.policy_dir.rstrip("/")

    current_path=os.path.join(P,"current.json")
    if not os.path.exists(current_path):
        raise SystemExit("current.json missing")

    cur=load(current_path)
    ver=cur.get("policy_version","unknown").replace("/","_")
    ad=os.path.join(P,"archive")
    os.makedirs(ad, exist_ok=True)

    # archive current and selected companion artifacts
    def cp(name):
        src=os.path.join(P,name)
        if os.path.exists(src):
            dst=os.path.join(ad,f"{name}.{ver}")
            shutil.copy2(src,dst)
            return dst
        return None

    archived={
        "ts_utc": iso(),
        "policy_version": ver,
        "files": {k:v for k,v in {
            "current": cp("current.json"),
            "changelog": cp("changelog.json"),
            "metrics": cp("metrics.snapshot.json"),
            "proposal": cp("proposal.json"),
            "history": cp("history.index.json"),
            "audit": cp("audit.merkle.json"),
            "safety": cp("safety.switches.json"),
        }.items() if v}
    }

    # write a small receipt for humans
    receipt=os.path.join(ad,f"receipt.{ver}.json")
    with open(receipt,"w",encoding="utf-8") as f:
        json.dump(archived,f,ensure_ascii=False,indent=2)

    print("Archived policy_version:", ver)
    print("Receipt:", receipt)

if __name__=="__main__":
    main()
