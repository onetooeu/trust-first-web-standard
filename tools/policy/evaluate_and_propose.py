#!/usr/bin/env python3
import json, hashlib, copy
import os
import json, hashlib, copy
from datetime import datetime, timezone

def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()

def canonical_json(obj) -> bytes:
    return json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")

def clip(x, lo, hi):
    return max(lo, min(hi, x))

def norm_clip_div(x, clip_max, div):
    return clip(x, 0, clip_max) / div

def norm_inv_clip_div(x, clip_max, div):
    return 1.0 - (clip(x, 0, clip_max) / div)

def norm_inv_clip(x, clip_max):
    return 1.0 - (clip(x, 0, clip_max) / clip_max)

def compute_score(features, params, model):
    sig = 1.0 if features["signature_valid"] else 0.0
    nc = norm_clip_div(features["continuity_days"], model["normalization"]["continuity_days"]["clip_max"], model["normalization"]["continuity_days"]["div"])
    nf = norm_inv_clip_div(features["transparency_freshness_days"], model["normalization"]["transparency_freshness_days"]["clip_max"], model["normalization"]["transparency_freshness_days"]["div"])
    ni = norm_inv_clip(features["incident_rate_30d"], model["normalization"]["incident_rate_30d"]["clip_max"])

    score = model["formula"]["base"]
    score += params.get("w_signature",0) * sig
    score += params.get("w_continuity_days",0) * nc
    score += params.get("w_transparency_freshness",0) * nf
    score += params.get("w_incident_rate",0) * ni
    score = clip(score, 0.0, 1.0)

    # invariant: if signature invalid => cap
    if not features["signature_valid"]:
        score = min(score, 0.2)

    return score

def classify(score, params):
    if score >= params.get("threshold_allow",0):
        return "allow"
    if score <= params.get("threshold_deny",0):
        return "deny"
    return "caution"

def metrics_for(policy_params, model, dataset):
    tp = fp = tn = fn = 0
    for row in dataset["rows"]:
        feat = row["features"]
        label = row["label"]
        score = compute_score(feat, policy_params, model)
        pred = classify(score, policy_params)

        if label == "trusted_should_allow":
            if pred == "allow": tp += 1
            else: fn += 1
        elif label == "untrusted_should_deny":
            if pred == "deny": tn += 1
            else: fp += 1
        else:
            raise ValueError("Unknown label: " + label)

    pos = tp + fn
    neg = tn + fp
    false_allow_rate = (fp / neg) if neg else 0.0
    false_deny_rate = (fn / pos) if pos else 0.0
    precision = (tp / (tp + fp)) if (tp + fp) else 0.0
    recall = (tp / (tp + fn)) if (tp + fn) else 0.0
    f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) else 0.0

    return {
        "false_allow_rate": round(false_allow_rate, 6),
        "false_deny_rate": round(false_deny_rate, 6),
        "precision": round(precision, 6),
        "recall": round(recall, 6),
        "f1": round(f1, 6),
        "counts": {"tp": tp, "fp": fp, "tn": tn, "fn": fn, "pos": pos, "neg": neg}
    }

def within_bounds(params, bounds):
    for k, r in bounds.get("params", {}).items():
        if k not in params:
            return False
        if not (r["min"] <= params[k] <= r["max"]):
            return False
    return True

def propose_step(params, bounds):
    # Deterministic step (no randomness): push slightly toward lower false denies.
    step = bounds["safety"]["max_param_delta_per_update"]
    cand = copy.deepcopy(params)

    def bump(name, delta):
        r = bounds["params"][name]
        cand[name] = clip(cand[name] + delta, r["min"], r["max"])

    bump("w_continuity_days", +min(step, 0.02))
    bump("w_transparency_freshness", +min(step, 0.01))
    bump("threshold_allow", -min(step, 0.01))
    return cand

def bump_version(ver: str) -> str:
    # expects "...YYYY-MM-DD.N" and increments N; else appends ".1"
    if ver.endswith(".next"):
        ver = ver[:-5]
    m = ver.rsplit(".", 1)
    if len(m) == 2 and m[1].isdigit():
        return f"{m[0]}.{int(m[1])+1}"
    return ver + ".1"

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--policy_current", required=True)
    ap.add_argument("--bounds", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--dataset", required=True)
    ap.add_argument("--out_metrics", required=True)
    ap.add_argument("--out_proposal", required=True)
    ap.add_argument("--out_candidate_policy", required=True)
    ap.add_argument("--max_far", type=float, default=0.02)
    ap.add_argument("--max_fdr", type=float, default=0.05)
    args = ap.parse_args()

    policy = json.load(open(args.policy_current, "r", encoding="utf-8"))
    bounds = json.load(open(args.bounds, "r", encoding="utf-8"))
    model = json.load(open(args.model, "r", encoding="utf-8"))
    dataset = json.load(open(args.dataset, "r", encoding="utf-8"))

    base_params = policy.get("params", {})
    if not within_bounds(base_params, bounds):
        raise SystemExit("Baseline params not within bounds")

    base_m = metrics_for(base_params, model, dataset)
    cand_params = propose_step(base_params, bounds)
    if not within_bounds(cand_params, bounds):
        raise SystemExit("Candidate params not within bounds")

    cand_m = metrics_for(cand_params, model, dataset)
    regression_ok = (cand_m["false_allow_rate"] <= args.max_far) and (cand_m["false_deny_rate"] <= args.max_fdr) and (cand_m["f1"] >= base_m["f1"])

    ds_hash = sha256_bytes(canonical_json(dataset))
    baseline_hash = sha256_bytes(canonical_json(policy))

    candidate_policy = copy.deepcopy(policy)
    candidate_policy["policy_version"] = bump_version(policy["policy_version"])
    candidate_policy["effective_utc"] = utc_now()
    candidate_policy.setdefault("derived_from", {})
    candidate_policy["derived_from"]["previous_policy_version"] = policy["policy_version"]
    candidate_policy["params"] = cand_params
    candidate_policy.setdefault("validation", {})
    candidate_policy["validation"]["regression_ok"] = regression_ok
    candidate_hash = sha256_bytes(canonical_json(candidate_policy))

    metrics_snapshot = {
        "schema": "tfws-ap.metrics.snapshot.v1",
        "policy_id": policy.get("policy_id", os.environ.get("POLICY_ID", "onetoo.eu/trust-policy")),
        "created_utc": utc_now(),
        "dataset": {
            "dataset_id": dataset["dataset_id"],
            "dataset_hash_sha256": ds_hash,
            "rows": len(dataset["rows"]),
            "label_definition": {"positive": "trusted_should_allow", "negative": "untrusted_should_deny"}
        },
        "policies": {
            "baseline": {"policy_version": policy["policy_version"], "policy_current_hash_sha256": baseline_hash},
            "candidate": {"policy_version": candidate_policy["policy_version"], "policy_current_hash_sha256": candidate_hash}
        },
        "thresholds": {"max_false_allow_rate": args.max_far, "max_false_deny_rate": args.max_fdr, "min_f1_improvement": 0.0},
        "metrics": {"baseline": base_m, "candidate": cand_m},
        "decision": {"regression_ok": regression_ok, "notes": "Deterministic propose_step evaluation."}
    }
    metrics_snapshot["snapshot_hash_sha256"] = sha256_bytes(canonical_json(metrics_snapshot))

    deltas = []
    for k in cand_params:
        if cand_params[k] != base_params[k]:
            deltas.append({"name": k, "from": base_params[k], "to": cand_params[k], "delta": round(cand_params[k]-base_params[k], 6)})

    proposal = {
        "schema": "tfws-ap.policy.proposal.v1",
        "policy_id": policy.get("policy_id", os.environ.get("POLICY_ID", "onetoo.eu/trust-policy")),
        "created_utc": utc_now(),
        "from_policy_version": policy["policy_version"],
        "to_policy_version": candidate_policy["policy_version"],
        "inputs": {
            "bounds_version": bounds["bounds_version"],
            "core_version": policy["derived_from"]["core_version"],
            "metrics_snapshot_hash_sha256": metrics_snapshot["snapshot_hash_sha256"]
        },
        "param_deltas": deltas,
        "validation": {"bounds_ok": True, "invariants_ok": True, "max_param_delta_ok": True, "regression_ok": regression_ok},
        "reasoning": {"objective": "reduce_false_deny_rate", "summary": "Candidate computed by deterministic propose_step; accept only if regression_ok."}
    }

    json.dump(metrics_snapshot, open(args.out_metrics, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    json.dump(proposal, open(args.out_proposal, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    json.dump(candidate_policy, open(args.out_candidate_policy, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

    print("Baseline metrics:", base_m)
    print("Candidate metrics:", cand_m)
    print("regression_ok:", regression_ok)

if __name__ == "__main__":
    main()
