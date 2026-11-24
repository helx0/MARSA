#!/usr/bin/env python3
"""Live Supabase development-only race/security test. Requires pre-seeded accounts/listings.
USAGE: python tests/backend_concurrency.py --i-understand-test-writes
See TESTING.md. Do not point at production.
"""
import os, sys, json, uuid, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

BASE=os.environ.get('SUPABASE_URL','').rstrip('/')
ANON=os.environ.get('SUPABASE_ANON_KEY','')

def api(path, token=None, payload=None):
    h={'apikey':ANON,'content-type':'application/json'}
    if token: h['authorization']='Bearer '+token
    if payload is not None: h['prefer']='return=representation'
    req=urllib.request.Request(BASE+path,headers=h,data=json.dumps(payload).encode() if payload is not None else None,
       method='POST' if payload is not None else 'GET')
    try:
        with urllib.request.urlopen(req,timeout=18) as r:
            return r.status,json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, {'error':e.read().decode()}

def auth(which):
    email=os.environ['TEST_BUYER_'+which+'_EMAIL']
    password=os.environ['TEST_BUYER_'+which+'_PASSWORD']
    status, response=api('/auth/v1/token?grant_type=password',payload={'email':email,'password':password})
    assert status==200,(status,response)
    return response['access_token'],response['user']['id']

def assert_security(a_token,b_id):
    status,rows=api('/rest/v1/profiles?select=id&id=eq.'+b_id,a_token)
    assert status==200 and rows==[],f'RLS private profile leak: {status} {rows}'
    status,detail=api('/rest/v1/rpc/admin_account_status',a_token,
        {'p_user':b_id,'p_status':'SUSPENDED'})
    assert status>=400,f'Unexpected admin privilege: {detail}'
    print('PASS: private profiles hidden and admin RPC denied')

def race_bids(a_token,b_token):
    listing=os.environ['TEST_LIVE_AUCTION_ID']
    status,auctions=api('/rest/v1/auctions?select=current_price,minimum_increment&listing_id=eq.'+listing,a_token)
    assert status==200 and len(auctions)==1,(status,auctions)
    amount=float(auctions[0]['current_price'])+float(auctions[0]['minimum_increment'])
    keys=[str(uuid.uuid4()),str(uuid.uuid4())]
    def bid(token,key):
        return api('/rest/v1/rpc/place_bid',token,
          {'p_listing':listing,'p_amount':amount,'p_request_id':key})
    with ThreadPoolExecutor(max_workers=2) as executor:
        f1=executor.submit(bid,a_token,keys[0])
        f2=executor.submit(bid,b_token,keys[1])
        results=[f1.result(),f2.result()]
    accepted=sum(1 for code,_ in results if code<300)
    assert accepted==1,f'Race accepted {accepted} bids: {results}'
    winner=0 if results[0][0]<300 else 1
    replay=bid([a_token,b_token][winner],keys[winner])
    assert replay[0]<300 and replay[1].get('idempotent')==True, f'Identical bid replay failed: {replay}'
    mismatched=api('/rest/v1/rpc/place_bid',[a_token,b_token][winner],
      {'p_listing':listing,'p_amount':amount+1,'p_request_id':keys[winner]})
    assert mismatched[0]>=400, f'Bid idempotency collision accepted: {mismatched}'
    print('PASS: concurrent equal bids accepted once; identical replay accepted; changed replay rejected')

def race_orders(a_token,b_token):
    listing=os.environ['TEST_SINGLE_UNIT_DIRECT_LISTING_ID']
    area=os.environ['TEST_ADEN_AREA_ID']
    keys=[str(uuid.uuid4()),str(uuid.uuid4())]
    def order(token,key,quantity=1):
        return api('/rest/v1/rpc/place_order',token,{
         'p_listing':listing,'p_quantity':quantity,'p_key':key,'p_area':area,
         'p_handover':'PICKUP','p_payment':'CASH_ON_HANDOVER','p_notes':'concurrency QA'})
    with ThreadPoolExecutor(max_workers=2) as executor:
        f1=executor.submit(order,a_token,keys[0])
        f2=executor.submit(order,b_token,keys[1])
        results=[f1.result(),f2.result()]
    accepted=sum(1 for code,_ in results if code<300)
    assert accepted==1,f'Oversold one unit: {results}'
    print('PASS: one-unit stock cannot be sold twice concurrently')
    winner=0 if results[0][0]<300 else 1
    winner_token=[a_token,b_token][winner]
    loser_token=[a_token,b_token][1-winner]
    award=results[winner][1]
    replay=order(winner_token,keys[winner])
    assert replay[0]<300 and replay[1]==award, f'Identical order replay failed: {replay}'
    mismatched=order(winner_token,keys[winner],quantity=2)
    assert mismatched[0]>=400, f'Order idempotency collision accepted: {mismatched}' 
    assert isinstance(award,str),f'Expected order UUID from RPC, got: {award}'
    result=api('/rest/v1/rpc/transition_order',winner_token,
       {'p_order':award,'p_status':'CANCELLED','p_note':'QA cancellation'})
    assert result[0]<300,f'First cancellation failed: {result}'
    repeated=api('/rest/v1/rpc/transition_order',winner_token,
       {'p_order':award,'p_status':'CANCELLED','p_note':'QA duplicate'})
    assert repeated[0]>=400,f'Duplicate cancellation accepted: {repeated}'
    new_order=order(loser_token,str(uuid.uuid4()))
    assert new_order[0]<300,f'One restored unit was not purchasable: {new_order}'
    oversell=order(winner_token,str(uuid.uuid4()))
    assert oversell[0]>=400,f'Stock apparently restored twice: {oversell}'
    print('PASS: cancelled unit restores once, duplicate cancel denied, no oversell')

if __name__=='__main__':
    assert '--i-understand-test-writes' in sys.argv, 'This test places real dev orders/bids. Explicit flag required.'
    assert BASE.startswith('https://') and ANON and os.environ.get('MARSA_TEST_ENV')=='development', 'Development credentials only'
    first,aid=auth('A');second,bid=auth('B')
    assert_security(first,bid)
    race_bids(first,second)
    race_orders(first,second)
    print('ALL LIVE BACKEND CHECKS PASSED')
