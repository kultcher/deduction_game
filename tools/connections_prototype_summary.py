"""Summarise tools/connections_prototype.gd results against the Phase 4 acceptance criteria.

  python3 tools/connections_prototype_summary.py results_a.json [results_b.json ...] [--watch LISTENER:PERSON]

Each file is one --out of connections_prototype.gd. --watch follows one listener's belief
about one person through the dawns and presentations (criterion 2; default hollis:kiran).
Prints, per log: untouched people per presentation (criterion 1) and the target's change
(3), the watched listener (2), vote shapes (4), refresh cost (5), stability (6), the
largest joint set (7), and separation by day. Reads the JSON only.
"""
import json,sys,os,statistics as st
args=[a for a in sys.argv[1:] if not a.startswith('--')]
WATCH=('hollis','kiran')
if '--watch' in sys.argv:
    WATCH=tuple(sys.argv[sys.argv.index('--watch')+1].split(':')); args=[a for a in args if ':' not in a or os.path.exists(a)]
logs={os.path.basename(a).replace('.json',''):json.load(open(a)) for a in args}
TH=['0.2','0.4','0.8']
def pct(x): return '%.0f%%'%(100*x)
print('== sanity: judge on all held vs today read-everything (max abs diff per listener-dawn)')
for name,d in logs.items():
    diffs=[]
    for r in d['records']:
        if r['kind']=='dawn':
            ev=r['everything']; ja=r['judge_all']
            m=max([abs(ev[p]-ja[p]) for p in ja if p in ev] or [0])
            diffs.append(m)
    print(name, 'n',len(diffs),'median %.3f max %.3f'%(st.median(diffs),max(diffs)))
print('\n== C1 untouched people, per presentation: first presentation per case/listener and repeat')
for lname,d in logs.items():
    if not any(r['kind']=='present' for r in d['records']): continue
    print('log',lname)
    seen={}
    C1={}
    for r in d['records']:
        if r['kind']!='present': continue
        key=(r['case'],r['listener']); rep=key in seen; seen[key]=1
        row=[]
        for t in TH:
            a=r['without'][t]['pe']
            for lab,b in (('capped',r['with'][t]['pe']),('none dropped',r['with_none_dropped'][t]['pe'])):
                un=[p for p in a if p not in r['touched'][t]]
                mv=max([abs(b[p]-a[p]) for p in un] or [0]); who=max(un,key=lambda p:abs(b[p]-a[p])) if un else '-'
                row.append('%s %s: tgt %s->%s untouched max %.1f (%s, %d untouched)'%(t,lab,pct(a[r['target']]),pct(b[r['target']]),100*mv,who,len(un)))
                if not rep: C1.setdefault((t,lab),[]).append((100*mv,r['label'],r['listener'],who, 100*(b[r['target']]-a[r['target']])))
        print(r['label'],r['listener'],'REPEAT' if rep else 'first','new',r['new_cards'],'changed',r['cited_changed'],'held',r['held_cards'],'/',r['cards'],'w %.2f'%r['weight'],'twice_same',r['twice_same'])
        for x in row: print('   ',x)
        print('    dropped',r['dropped'],'cases@0.4', [(c['label'],round(c['max_shift'],2),c['merged']) for c in r['with']['0.4']['cases']])
    print('\n-- C1 summary (first presentations): max untouched move, and count over 3 points')
    for k,v in sorted(C1.items()):
        print(k, 'n',len(v),'max %.1f'%max(x[0] for x in v), 'over 3:',sum(1 for x in v if x[0]>3), 'worst',max(v)[:4])
    print('-- C3 target change by case (0.4 capped / none dropped)')
    for lab in ('capped','none dropped'):
        for x in C1[('0.4',lab)]: print('  ',lab,x[1],x[2],'%+.1f'%x[4], 'untouched max %.1f (%s)'%(x[0],x[3]))
    print('\n== C2 the watched listener')
    for r in d['records']:
        if r['kind']=='present' and r['listener']==WATCH[0]:
            print('  at',r['label'],'seq',r['seq'],{t:(pct(r['without'][t]['pe'][WATCH[1]]),pct(r['with'][t]['pe'][WATCH[1]]), len(r['with'][t]['core'])) for t in TH})
    for r in d['records']:
        if r['kind']=='dawn' and r['listener']==WATCH[0]:
            kc=[cid for cid,desc in r['cards'].items() if WATCH[1] in desc and desc.startswith('report')]
            line='day %d held %d seed %d'%(r['day'],r['proto']['held'],r['proto']['seed'])
            for t in TH:
                core=r['proto']['thetas'][t]['core']
                line+=' | th %s: their reading in core %s, core %s, P(watched) %s (no cases %s)'%(t, any(k in core for k in kc), len(core), pct(r['proto']['thetas'][t]['pe'].get(WATCH[1],0)), pct(r['proto_no_cases'][t]['pe'].get(WATCH[1],0)))
            line+=' | today %s everything %s'%(pct(r['today'].get(WATCH[1],0)),pct(r['everything'].get(WATCH[1],0)))
            print(line, '| holds their reading:', bool(kc))
            if r['day']>=4: print('    core@0.4:', [r['cards'].get(k,k) for k in r['proto']['thetas']['0.4']['core']])
print('\n== C4 vote shapes')
for name,d in logs.items():
    tot={'today':[0,0,0],'logcheck':0,'n':0}
    for t in TH: tot[t]=[0,0,0]
    flips={t:0 for t in TH}; nv=0; stale=0
    for r in d['records']:
        if r['kind']!='vote': continue
        tot['n']+=1
        yes=set(r['yes']); order=[v for v in r['order']]
        voters=[v for v in order if v!=r['nominee']]
        def shape(y):
            una = all(v in y for v in voters)
            only = (y=={r['by']}) or (len(y)==1 and r['by'] in y)
            carried = (r['by'] in r['evil']) and len(y)>=r['threshold'] and r['threshold']>0
            return [una,only,carried]
        s0=shape(yes)
        for i in range(3): tot['today'][i]+=s0[i]
        for t in TH:
            y=set(yes)
            for v in r['voters']:
                nv+= (t=='0.4')
                if v['p_today']<0: continue
                tot_p=v['total']+v['scale']*(v['proto'][t]-v['p_today'])
                want= tot_p>=v['need']
                if (v['total']>=v['need'])!=(v['voter'] in yes) and t=='0.4': tot['logcheck']+=1
                if abs(v['logged_suspicion']-v['suspicion_now'])>0.02 and t=='0.4': stale+=1
                if want: y.add(v['voter'])
                else: y.discard(v['voter'])
                if want!=(v['voter'] in yes): flips[t]+=1
            s=shape(y)
            for i in range(3): tot[t][i]+=s[i]
    print(name,'votes',tot['n'],'good voters recomputed',nv,'| today [unanimous, nominator-only, evil-carried]',tot['today'], {t:tot[t] for t in TH},'flipped good votes',flips,'log rule mismatches',tot['logcheck'],'stale susp',stale)
print('\n== C5 cost per listener refresh (ms)')
for name,d in logs.items():
    rows=[r for r in d['records'] if r['kind']=='dawn']
    q=lambda xs:(st.median(xs), sorted(xs)[int(0.9*(len(xs)-1))])
    print(name,'n',len(rows),'today med/p90 %.0f/%.0f'%q([r['today_ms'] for r in rows]),'| proto cold %.0f/%.0f'%q([r['cold_ms'] for r in rows]),'| proto joint pass %.0f/%.0f'%q([r['cold_joint_ms'] for r in rows]),'| judgements cold %.0f/%.0f'%q([r['cold_calls'] for r in rows]), '| day>=3 today %.0f/%.0f cold %.0f/%.0f joint %.0f/%.0f'%(q([r['today_ms'] for r in rows if r['day']>=3])+q([r['cold_ms'] for r in rows if r['day']>=3])+q([r['cold_joint_ms'] for r in rows if r['day']>=3])))
print('\n== C6 stable')
for name,d in logs.items():
    print(name,'dawn recompute identical', all(r['stable'] for r in d['records'] if r['kind']=='dawn'), 'case twice identical', all(r['twice_same'] for r in d['records'] if r['kind']=='present'))
print('\n== C7 largest joint set / held, day>=3')
for name,d in logs.items():
    for t in TH:
        sh=[r['proto']['thetas'][t]['largest']/max(1,r['proto']['held']) for r in d['records'] if r['kind']=='dawn' and r['day']>=3]
        if sh: print(name,t,'n',len(sh),'median %.0f%% max %.0f%%'%(100*st.median(sh),100*max(sh)), 'core cards median', st.median([r['proto']['thetas'][t]['core_cards'] for r in d['records'] if r['kind']=='dawn' and r['day']>=3]), 'seed0', sum(1 for r in d['records'] if r['kind']=='dawn' and r['day']>=3 and r['proto']['seed']==0), 'declared', d['records'][0]['proto']['declared'])
print('\n== reported: separation (mean P on evil - mean P on good) and gaps by day')
for name,d in logs.items():
    truth=d['records'][-1]['truth']
    days=sorted(set(r['day'] for r in d['records'] if r['kind']=='dawn'))
    for day in days:
        rows=[r for r in d['records'] if r['kind']=='dawn' and r['day']==day]
        def sep(pe, keys=None):
            e=[v for p,v in pe.items() if truth[p]['evil'] and (keys is None or p in keys)]; g_=[v for p,v in pe.items() if not truth[p]['evil'] and (keys is None or p in keys)]
            return (sum(e)/len(e)-sum(g_)/len(g_)) if e and g_ else 0
        out={}
        out['today']=st.mean([sep(r['today'],r['proto']['thetas']['0.4']['pe']) for r in rows if r['today']])
        out['all']=st.mean([sep(r['everything'],r['proto']['thetas']['0.4']['pe']) for r in rows if r['everything']])
        for t in TH: out[t]=st.mean([sep(r['proto']['thetas'][t]['pe']) for r in rows])
        gap_t=st.mean([st.mean([abs(r['proto']['thetas']['0.4']['pe'][p]-r['today'][p]) for p in r['today'] if p in r['proto']['thetas']['0.4']['pe']]) for r in rows if r['today']])
        gap_a=st.mean([st.mean([abs(r['proto']['thetas']['0.4']['pe'][p]-r['everything'][p]) for p in r['everything'] if p in r['proto']['thetas']['0.4']['pe']]) for r in rows if r['everything']])
        print(name,'day',day,'n',len(rows),'sep today %.2f all %.2f proto %.2f/%.2f/%.2f'%(out['today'],out['all'],out['0.2'],out['0.4'],out['0.8']),'| mean gap proto@0.4 vs today %.2f vs read-all %.2f'%(gap_t,gap_a), '| held med',st.median([r['proto']['held'] for r in rows]),'read med',st.median([r['today_read'] for r in rows]))
    ints=[x for r in d['records'] if r['kind']=='dawn' for x in r['proto']['interactions']]
    if ints: print(name,'candidate interactions n',len(ints),'share >=0.2 %.0f%% >=0.4 %.0f%% >=0.8 %.0f%%'%tuple(100*sum(1 for x in ints if x>=t)/len(ints) for t in (0.2,0.4,0.8)))
