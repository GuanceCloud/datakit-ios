# Copyright 2026 TRUEWATCH TECHNOLOGY INC PTE. LTD.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse, datetime, hashlib, json, pathlib, re, subprocess, time
parser=argparse.ArgumentParser()
parser.add_argument('--device',required=True)
parser.add_argument('--output',required=True)
parser.add_argument('--app',required=True)
parser.add_argument('--cases', nargs='+', choices=['primary','no-reentry','blocked-provider','restart'], default=['primary','no-reentry','blocked-provider','restart'], help='Cross-queue subprocess cases; module regressions run in FTResourceLifecycleTest.')
args=parser.parse_args()
out=pathlib.Path(args.output);out.mkdir(parents=True,exist_ok=False)
bundle='com.truewatch.audit.lc001'
commands=[]
def command(argv,stem,timeout=60):
    started=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()
    try:
        result=subprocess.run(argv,text=True,capture_output=True,timeout=timeout)
        record={'command':argv,'started_at':started,'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr}
    except subprocess.TimeoutExpired as e:
        record={'command':argv,'started_at':started,'returncode':None,'timeout':timeout,'stdout':str(e.stdout or ''),'stderr':str(e.stderr or '')}
    (out/(stem+'.json')).write_text(json.dumps(record,indent=2))
    commands.append(record)
    return record
r=command(['xcrun','simctl','install',args.device,args.app],'install',90)
if r['returncode']!=0: raise SystemExit('install failed')
r=command(['xcrun','simctl','get_app_container',args.device,bundle,'data'],'container')
if r['returncode']!=0:raise SystemExit('container failed')
container=pathlib.Path(r['stdout'].strip())
command(['xcodebuild','-version'],'xcode')
command(['xcrun','simctl','list','devices','available','-j'],'devices')
root=pathlib.Path(__file__).resolve().parents[2]
meta={'device':args.device,'bundle':bundle,'app':args.app,'container':str(container),'cases':args.cases,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'sources_tree':subprocess.check_output(['git','rev-parse','HEAD:Sources'],cwd=root,text=True).strip()}
meta['working_source_files']={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'Sources/Core/NetworkAutoInstrumentation').glob('*') if p.is_file()}
meta['test_files']={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [root/'Tests/Lifecycle/FTSDKShutdownDeadlockProbe.m',root/'scripts/testing/sdk-shutdown-deadlock-project.rb',root/'scripts/testing/lc-001-fixed-runner.py']}
(out/'manifest.json').write_text(json.dumps(meta,indent=2))
results=[]
for index,case in enumerate(args.cases,1):
    run_id=f'{out.name}-{index:02d}-{case}'
    case_dir=out/case;case_dir.mkdir()
    marker_file=container/'Documents'/'LC001'/run_id/'markers.jsonl'
    launched=command(['xcrun','simctl','launch',args.device,bundle,'--case',case,'--run-id',run_id],case+'/launch',30)
    pid_match=re.search(r':\s*(\d+)\s*$',launched['stdout'])
    result={'case':case,'run_id':run_id,'launch_returncode':launched['returncode'],'pid':int(pid_match.group(1)) if pid_match else None}
    try:
        if launched['returncode']!=0 or not pid_match:
            result['status']='launch-failed';continue
        deadline=time.monotonic()+15
        records=[]
        while time.monotonic()<deadline:
            if marker_file.exists():
                records=[json.loads(line) for line in marker_file.read_text().splitlines() if line.strip()]
            events=[x['event'] for x in records]
            if 'probe-failed' in events:
                result['status']='probe-failed';break
            if 'case-complete' in events:
                result['status']='completed';break
            time.sleep(0.05)
        else:result['status']='prerequisite-or-completion-timeout'
        if marker_file.exists():
            raw=marker_file.read_text();(case_dir/'markers.jsonl').write_text(raw)
            records=[json.loads(line) for line in raw.splitlines() if line.strip()]
        result['events']=[x['event'] for x in records]
        result['counts']={event:result['events'].count(event) for event in set(result['events'])}
        if result['status']=='completed':
            result['completion_summary']=next(x for x in records if x['event']=='case-complete')
    finally:
        if result['pid']:
            command(['xcrun','simctl','terminate',args.device,bundle],case+'/terminate',20)
        results.append(result)
        (case_dir/'result.json').write_text(json.dumps(result,indent=2))
        (out/'results.json').write_text(json.dumps(results,indent=2))
        print(json.dumps(result),flush=True)
(out/'commands.json').write_text(json.dumps(commands,indent=2))

for result in results:
    assert result['status'] == 'completed', result
    counts = result['counts']
    assert counts.get('application-completion-returning', 0) == 1, result
    expected = 1
    assert counts.get('provider-entered', 0) == expected, result
    assert counts.get('provider-returned', 0) == expected, result
    expected_stop = 1
    assert counts.get('sdk-shutdown-returned', 0) == expected_stop, result
    if result['case'] == 'restart':
        assert counts.get('restart-isolated', 0) == 1, result
        assert counts.get('new-lifecycle-verified', 0) == 1, result
        assert counts.get('new-application-completion', 0) == 1, result
        assert counts.get('new-provider-entered', 0) == 1, result
    expected_context = 0 if result['case'] == 'no-reentry' else 1
    assert counts.get('context-call-returned', 0) == expected_context, result
    assert counts.get('resource-settlement-verified', 0) == 1, result
