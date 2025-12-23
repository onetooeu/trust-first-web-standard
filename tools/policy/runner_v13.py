#!/usr/bin/env python3
import json, hashlib, os
from datetime import datetime, timezone, timedelta

def utc_now(): return datetime.now(timezone.utc)
def iso(dt): return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
def canonical(obj): return json.dumps(obj, separators=(",",":"), sort_keys=True).encode("utf-8")
def sha256_obj(obj): return hashlib.sha256(canonical(obj)).hexdigest()
def load(path): 
    with open(path,"r",encoding="utf-8") as f: return json.load(f)
def save(path,obj):
    with open(path,"w",encoding="utf-8") as f: json.dump(obj,f,ensure_ascii=False,indent=2)
def parse_iso(s): return datetime.strptime(s,"%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)

def count_actions_today(log, now, actions):
    day0 = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    day1 = day0 + timedelta(days=1)
    c=0
    for e in log.get("entries",[]):
        t=parse_iso(e["ts_utc"])
        if day0<=t<day1 and e.get("action") in actions and e.get("result") in ("ok","executed"):
            c+=1
    return c

def last_action_time(log, action):
    times=[]
    for e in log.get("entries",[]):
        if e.get("action")==action and e.get("result") in ("ok","executed"):
            times.append(parse_iso(e["ts_utc"]))
    return max(times) if times else None

def last_good(history, max_days_back):
    now=utc_now()
    limit=now-timedelta(days=max_days_back)
    goods=[]
    for e in history.get("entries",[]):
        if e.get("status")=="good":
            t=parse_iso(e["effective_utc"])
            if t>=limit:
                goods.append((t,e))
    if not goods: return None
    goods.sort(key=lambda x:x[0])
    return goods[-1][1]

def main():
    import argparse
    ap=argparse.ArgumentParser()
    ap.add_argument("--policy_dir", default="./.well-known/policy")
    ap.add_argument("--do", choices=["enforce","rollback_if_regression","apply_candidate_as_current"], required=True)
    args=ap.parse_args()

    P=args.policy_dir.rstrip("/")
    paths={
        "history": f"{P}/history.index.json",
        "safety": f"{P}/safety.switches.json",
        "limits": f"{P}/runner.limits.json",
        "metrics": f"{P}/metrics.snapshot.json",
        "proposal": f"{P}/proposal.json",
        "runner_log": f"{P}/runner.log.json",
        "rollback_plan": f"{P}/rollback.plan.json",
        "current": f"{P}/current.json",
        "candidate": f"{P}/candidate.policy.json",
    }
    now=utc_now()
    history=load(paths["history"])
    safety=load(paths["safety"])
    limits=load(paths["limits"])
    metrics=load(paths["metrics"]) if os.path.exists(paths["metrics"]) else None
    proposal=load(paths["proposal"]) if os.path.exists(paths["proposal"]) else None
    log=load(paths["runner_log"]) if os.path.exists(paths["runner_log"]) else {"schema":"tfws-ap.runner.log.v1","runner_id":"tfws-ap-autopilot","entries":[]}

    if args.do=="enforce":
        max_updates=limits["limits"]["max_updates_per_day"]
        min_hours=limits["limits"]["min_hours_between_updates"]
        updates_today=count_actions_today(log, now, actions=("publish","rollback"))
        last_pub=last_action_time(log, "publish")
        ok=True; reasons=[]
        if updates_today>=max_updates:
            ok=False; reasons.append("max_updates_per_day exceeded")
        if last_pub and (now-last_pub).total_seconds() < min_hours*3600:
            ok=False; reasons.append("min_hours_between_updates not met")
        log["entries"].append({"ts_utc":iso(now),"action":"enforce","result":"ok" if ok else "blocked","details":{"updates_today":updates_today,"reasons":reasons}})
        save(paths["runner_log"], log)
        print("ENFORCE", "OK" if ok else "BLOCKED", reasons)
        return

    if args.do=="rollback_if_regression":
        if not metrics:
            raise SystemExit("metrics.snapshot.json missing")
        reg_ok=bool(metrics.get("decision",{}).get("regression_ok", True))
        if reg_ok:
            log["entries"].append({"ts_utc":iso(now),"action":"rollback","result":"skipped","details":{"reason":"regression_ok"}})
            save(paths["runner_log"], log)
            print("No rollback (regression_ok=true)")
            return

        lg=last_good(history, limits["limits"]["max_days_back"])
        if not lg:
            log["entries"].append({"ts_utc":iso(now),"action":"rollback","result":"blocked","details":{"reason":"no_good_policy_in_window"}})
            save(paths["runner_log"], log)
            raise SystemExit("No good policy to rollback to")

        from_ver=history["head"]["policy_version"]
        to_ver=lg["policy_version"]
        plan={
            "schema":"tfws-ap.rollback.plan.v1",
            "policy_id":history["policy_id"],
            "created_utc":iso(now),
            "trigger":{"reason":"metrics_regression","metrics_snapshot_hash_sha256":metrics.get("snapshot_hash_sha256","")},
            "from_policy_version":from_ver,
            "to_policy_version":to_ver,
            "actions":[
                {"type":"set_policy_current","source":"history.index.json","target_path":"/.well-known/policy/current.json"},
                {"type":"append_history","set_status":"rolled_back"},
                {"type":"set_safety_mode","mode":"rollback_only"}
            ]
        }
        plan["plan_hash_sha256"]=sha256_obj(plan)
        save(paths["rollback_plan"], plan)

        # mark head rolled_back, keep last good as head
        for e in history["entries"]:
            if e["policy_version"]==from_ver:
                e["status"]="rolled_back"
        history["head"]={"policy_version":to_ver,"status":"good"}
        history["generated_utc"]=iso(now)
        save(paths["history"], history)

        safety["mode"]="rollback_only"
        save(paths["safety"], safety)

        log["entries"].append({"ts_utc":iso(now),"action":"rollback","result":"executed","details":{"from":from_ver,"to":to_ver,"plan_hash":plan["plan_hash_sha256"]}})
        save(paths["runner_log"], log)
        print("Rollback planned", from_ver, "->", to_ver)
        return

    if args.do=="apply_candidate_as_current":
        if safety["mode"]!="adaptive_enabled":
            raise SystemExit(f"Safety mode blocks apply_candidate_as_current: {safety['mode']}")
        if not metrics or not proposal:
            raise SystemExit("metrics/proposal missing")

        if not metrics["decision"]["regression_ok"]:
            raise SystemExit("Candidate not acceptable (regression_ok=false)")

        cand=load(paths["candidate"])
        save(paths["current"], cand)

        # update history append entry
        history["entries"].append({
            "policy_version": cand["policy_version"],
            "effective_utc": cand["effective_utc"],
            "current_hash_sha256": sha256_obj(cand),
            "status": "good",
            "artifacts": {
                "current": "/.well-known/policy/current.json",
                "changelog": "/.well-known/policy/changelog.json",
                "audit": "/.well-known/policy/audit.merkle.json",
                "metrics": "/.well-known/policy/metrics.snapshot.json",
                "proposal": "/.well-known/policy/proposal.json"
            },
            "evidence": {
                "metrics_snapshot_hash_sha256": metrics.get("snapshot_hash_sha256","")
            }
        })
        history["head"]={"policy_version":cand["policy_version"],"status":"good"}
        history["generated_utc"]=iso(now)
        save(paths["history"], history)

        log["entries"].append({"ts_utc":iso(now),"action":"publish","result":"ok","details":{"policy_version":cand["policy_version"]}})
        save(paths["runner_log"], log)
        print("Applied candidate as current:", cand["policy_version"])
        return

if __name__=="__main__":
    main()
