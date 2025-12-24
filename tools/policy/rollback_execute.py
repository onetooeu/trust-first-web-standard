#!/usr/bin/env python3
import json, os, shutil
from datetime import datetime, timezone

def iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def load(p):
    with open(p,"r",encoding="utf-8") as f: return json.load(f)

def save(p,obj):
    with open(p,"w",encoding="utf-8") as f: json.dump(obj,f,ensure_ascii=False,indent=2)

def main():
    import argparse
    ap=argparse.ArgumentParser()
    ap.add_argument("--policy_dir", default="./.well-known/policy")
    ap.add_argument("--to_version", default=None, help="Target policy_version; if omitted, uses rollback.plan.json")
    args=ap.parse_args()
    P=args.policy_dir.rstrip("/")
    ad=os.path.join(P,"archive")
    os.makedirs(ad, exist_ok=True)

    target=args.to_version
    plan_path=os.path.join(P,"rollback.plan.json")
    if not target:
        if not os.path.exists(plan_path):
            raise SystemExit("rollback.plan.json missing and --to_version not provided")
        plan=load(plan_path)
        target=plan["to_policy_version"]

    # archive files are named current.json.<ver>
    src=os.path.join(ad,f"current.json.{target}")
    if not os.path.exists(src):
        raise SystemExit(f"Archived current for target not found: {src}")

    shutil.copy2(src, os.path.join(P,"current.json"))

    # update history head metadata
    hist_path=os.path.join(P,"history.index.json")
    if os.path.exists(hist_path):
        hist=load(hist_path)
        hist["head"]={"policy_version":target,"status":"good"}
        hist["generated_utc"]=iso()
        save(hist_path,hist)

    print("Rollback executed: current.json restored to", target)

if __name__=="__main__":
    main()
