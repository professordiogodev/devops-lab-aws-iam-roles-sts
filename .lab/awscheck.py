#!/usr/bin/env python3
import json, os, subprocess, sys, time
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
os.chdir(ROOT)
ACCOUNT = sys.argv[1]
B = "clippy-iamlab-" + ACCOUNT
ROLE = "clippy-export-writer"
passed = failed = 0


def check(desc, ok, hint=""):
    global passed, failed
    if ok:
        passed += 1; print("PASS  " + desc)
    else:
        failed += 1; print("FAIL  " + desc + (("   -> " + hint) if hint else ""))


def run(cmd, env=None):
    e = dict(os.environ)
    if env:
        e.update(env)
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, env=e)


def aws(*a, env=None):
    r = subprocess.run(("aws",) + a + ("--output", "json"), capture_output=True, text=True, env=dict(os.environ, **(env or {})))
    try:
        return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else None
    except Exception:
        return None


def statements(doc):
    st = doc["Statement"]
    return st if isinstance(st, list) else [st]


def listify(x):
    return [x] if isinstance(x, str) else x


print("== The old key ==")
leg = aws("iam", "list-access-keys", "--user-name", "clippy-export-legacy")
keys = (leg or {}).get("AccessKeyMetadata", []) if leg is not None else []
check("the leaked access key of clippy-export-legacy is deactivated or deleted (the first thing you do after a leak)", all(k["Status"] != "Active" for k in keys), "aws iam update-access-key --status Inactive ...")
check("no AWS keys in the repository", run("git grep -lE 'AKIA[0-9A-Z]{16}' -- . ':!.lab' ':!verify.sh'").stdout.strip() == "")

print("== The role ==")
role = (aws("iam", "get-role", "--role-name", ROLE) or {}).get("Role")
check("the role %s exists" % ROLE, bool(role))
if not role:
    print("\nNothing else can be checked without the role.\n%d check(s) failed, %d passed" % (failed, passed)); sys.exit(1)
trust = role["AssumeRolePolicyDocument"]
princ = [s.get("Principal") for s in statements(trust)]
flat = json.dumps(princ)
check("the trust policy names a real principal, not \"*\"", '"*"' not in flat and "AWS" in flat)
check("the trust policy allows sts:AssumeRole", all("sts:AssumeRole" in listify(s["Action"]) for s in statements(trust)))
check("the maximum session is 1 hour or less", role.get("MaxSessionDuration", 43200) <= 3600, "aws iam update-role --max-session-duration 3600")
attached = (aws("iam", "list-attached-role-policies", "--role-name", ROLE) or {}).get("AttachedPolicies", [])
check("no AWS managed policy attached (no AdministratorAccess, no AmazonS3FullAccess)", not any(p["PolicyArn"].startswith("arn:aws:iam::aws:") for p in attached))
docs = []
for n in (aws("iam", "list-role-policies", "--role-name", ROLE) or {}).get("PolicyNames", []):
    docs.append((aws("iam", "get-role-policy", "--role-name", ROLE, "--policy-name", n) or {}).get("PolicyDocument", {"Statement": []}))
for p in attached:
    v = (aws("iam", "get-policy", "--policy-arn", p["PolicyArn"]) or {}).get("Policy", {}).get("DefaultVersionId")
    docs.append((aws("iam", "get-policy-version", "--policy-arn", p["PolicyArn"], "--version-id", v) or {}).get("PolicyVersion", {}).get("Document", {"Statement": []}))
acts, res = set(), set()
for d in docs:
    for s in statements(d):
        if s.get("Effect") == "Allow":
            acts |= set(listify(s["Action"])); res |= set(listify(s["Resource"]))
check("the permission policy allows only s3:PutObject", acts == {"s3:PutObject"}, "found %s" % sorted(acts))
check("... on exactly arn:aws:s3:::%s/exports/* (no *, no whole bucket)" % B, res == {"arn:aws:s3:::%s/exports/*" % B}, "found %s" % sorted(res))

print("== Assume it and try things ==")
r = run("aws sts assume-role --role-name %s --role-session-name verify --duration-seconds 900 --output json" % ROLE if False else "aws sts assume-role --role-arn %s --role-session-name verify --duration-seconds 900 --output json" % role["Arn"])
creds = None
if r.returncode == 0:
    c = json.loads(r.stdout)["Credentials"]
    creds = {"AWS_ACCESS_KEY_ID": c["AccessKeyId"], "AWS_SECRET_ACCESS_KEY": c["SecretAccessKey"], "AWS_SESSION_TOKEN": c["SessionToken"]}
check("your own identity can assume the role (sts assume-role)", creds is not None, (r.stderr or "").strip().split("\n")[-1][:140])
if creds:
    who = run("aws sts get-caller-identity --query Arn --output text", creds).stdout.strip()
    check("the temporary credentials really are the role (assumed-role/%s/...)" % ROLE, "assumed-role/%s/" % ROLE in who, who)
    k = "exports/verify-%d.csv" % int(time.time())
    put = lambda key: run("echo test | aws s3 cp - s3://%s/%s" % (B, key), creds)
    check("the role CAN write exports/...", put(k).returncode == 0)
    check("the role CANNOT write outside exports/ (private/...)", put("private/verify.csv").returncode != 0)
    check("the role CANNOT read the customer list", run("aws s3 cp s3://%s/private/customers.txt -" % B, creds).returncode != 0)
    check("the role CANNOT delete what it wrote", run("aws s3 rm s3://%s/%s" % (B, k), creds).returncode != 0)
    check("the role CANNOT list the bucket", run("aws s3 ls s3://%s/" % B, creds).returncode != 0)
    run("aws s3 rm s3://%s/%s" % (B, k))
print()
print(("ALL CHECKS PASSED (%d/%d)" % (passed, passed)) if failed == 0 else ("%d check(s) failed, %d passed" % (failed, passed)))
sys.exit(1 if failed else 0)
