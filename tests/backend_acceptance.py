#!/usr/bin/env python3
"""Live Supabase acceptance checks for a DEDICATED, pre-seeded staging database.

Not an offline test. Writes one QA draft + image and finalizes two expired
fixture auctions. It must never be run against a production project.
See TESTING.md for the exact required accounts and fixture prerequisites.
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

BASE = os.environ.get('SUPABASE_URL', '').rstrip('/')
ANON = os.environ.get('SUPABASE_ANON_KEY', '')


def req(path, *, token=None, method='GET', data=None, raw=None, mime='application/json'):
    headers = {'apikey': ANON, 'content-type': mime}
    if token:
        headers['authorization'] = 'Bearer ' + token
    if data is not None:
        raw = json.dumps(data).encode('utf8')
        headers['prefer'] = 'return=representation'
    request = urllib.request.Request(BASE + path, data=raw, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=22) as response:
            body = response.read().decode('utf8')
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf8')
        try:
            body = json.loads(body)
        except ValueError:
            pass
        return e.code, body


def must(condition, label, evidence):
    if not condition:
        raise AssertionError(f'FAIL {label}: {evidence}')
    print('PASS ' + label)


def credentials(prefix):
    email = os.environ['TEST_' + prefix + '_EMAIL']
    password = os.environ['TEST_' + prefix + '_PASSWORD']
    status, body = req('/auth/v1/token?grant_type=password', method='POST',
                       data={'email': email, 'password': password})
    must(status == 200 and isinstance(body, dict) and body.get('access_token'),
         f'login {prefix}', (status, body))
    return body['access_token'], body['user']['id']


def rpc(name, token, payload):
    return req('/rest/v1/rpc/' + name, token=token, method='POST', data=payload)


def check_admin(buyer, admin, buyer_id):
    status, val = rpc('is_admin', buyer, {})
    must(status == 200 and val is False, 'buyer is not admin', (status, val))
    status, val = rpc('is_admin', admin, {})
    must(status == 200 and val is True, 'admin claim is server enforced', (status, val))
    status, val = rpc('admin_account_status', buyer, {'p_user': buyer_id, 'p_status': 'SUSPENDED'})
    must(status >= 400, 'buyer cannot call admin RPC', (status, val))


def check_rls(buyer, other_id):
    for table, field in [('profiles', 'id'), ('orders', 'buyer_id'),
                         ('favorites', 'user_id'), ('notifications', 'recipient_id')]:
        status, val = req(f'/rest/v1/{table}?select=*&{field}=eq.{other_id}', token=buyer)
        must(status == 200 and val == [], f'private {table} are invisible', (status, val))


def check_pending_seller(token):
    category = os.environ['TEST_CATEGORY_ID']
    area = os.environ['TEST_ADEN_AREA_ID']
    fields = {'p_type': 'DIRECT', 'p_category': category, 'p_title': 'QA testing only',
              'p_description': '', 'p_condition': '', 'p_area': area,
              'p_quantity': 1, 'p_unit': 'kg', 'p_currency': 'YER', 'p_unit_price': 100}
    status, val = rpc('create_listing', token, fields)
    must(status >= 400 and 'Seller approval required' in str(val),
         'pending seller cannot create/publish a listing', (status, val))
    return fields


def check_image_upload(approved, approved_id, fields):
    status, listing = rpc('create_listing', approved, fields)
    must(status == 200 and isinstance(listing, str), 'approved seller creates QA draft', (status, listing))
    path = f'{approved_id}/{listing}/{uuid.uuid4().hex}.png'
    # An unmodified 1x1 transparent PNG. Only in isolated staging storage.
    png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/J94AAAAASUVORK5CYII=')
    status, response = req('/storage/v1/object/listing-images/' + path,
                           token=approved, method='POST', raw=png, mime='image/png')
    must(status in (200, 201), 'seller image upload accepted', (status, response))
    status, response = req('/rest/v1/listing_images', token=approved, method='POST',
                           data={'listing_id': listing, 'storage_path': path, 'sort_order': 0})
    must(status in (200, 201), 'listing image metadata inserted', (status, response))
    status, response = rpc('change_listing_status', approved,
                           {'p_listing': listing, 'p_status': 'PENDING_REVIEW'})
    must(status == 200, 'seller submits draft for moderation', (status, response))


def check_auction_denials(buyer, seller):
    live = os.environ['TEST_LIVE_AUCTION_ID']  # Must belong to approved seller.
    expired = os.environ['TEST_EXPIRED_AUCTION_ID']  # Must be expired, unfinalized.
    st, rows = req('/rest/v1/auctions?select=start_price,current_price,minimum_increment&listing_id=eq.'+live, token=buyer)
    must(st == 200 and len(rows) == 1, 'read live auction price', (st, rows))
    current = float(rows[0]['current_price'])
    start = float(rows[0]['start_price'])
    minimum = float(rows[0]['minimum_increment'])
    # 0 is always invalid, including at the starting-price boundary.
    st, response = rpc('place_bid', buyer, {'p_listing':live,'p_amount':0,'p_request_id':str(uuid.uuid4())})
    must(st >= 400, 'invalid low bid blocked', (st, response))
    st, response = rpc('place_bid', seller, {'p_listing':live,'p_amount':max(current+minimum,start),
                                            'p_request_id':str(uuid.uuid4())})
    must(st >= 400 and 'Not allowed to bid' in str(response), 'seller cannot bid on own auction', (st, response))
    st, response = rpc('place_bid', buyer, {'p_listing':expired,'p_amount':999999,
                                           'p_request_id':str(uuid.uuid4())})
    must(st >= 400 and 'Auction is not live' in str(response), 'late bids rejected', (st, response))


def check_finalization(admin):
    # Fixture 1: ended with a bid BELOW the positive reserve price.
    no_winner = os.environ['TEST_ENDED_RESERVE_AUCTION_ID']
    st, first = rpc('finalize_auction', admin, {'p_listing':no_winner})
    must(st == 200 and first == 'ENDED_NO_WINNER', 'reserve price not met', (st, first))
    st, second = rpc('finalize_auction', admin, {'p_listing':no_winner})
    must(st == 200 and second == first, 'reserve finalization idempotent', (st, second))
    # Fixture 2: ended with an accepted winning bid and reserve satisfied.
    winner = os.environ['TEST_ENDED_WINNER_AUCTION_ID']
    st, first = rpc('finalize_auction', admin, {'p_listing':winner})
    must(st == 200 and first == 'ENDED_WITH_WINNER', 'winning bid finalized', (st, first))
    st, second = rpc('finalize_auction', admin, {'p_listing':winner})
    must(st == 200 and second == first, 'winner finalization idempotent', (st, second))
    st, rows = req('/rest/v1/orders?select=id&auction_listing_id=eq.' + winner, token=admin)
    must(st == 200 and isinstance(rows, list) and len(rows) == 1,
         'one winner order after two finalization calls', (st, rows))


def main():
    must(os.environ.get('MARSA_TEST_ENV') == 'development' and
         '--i-understand-test-writes' in sys.argv and
         BASE.startswith('https://') and ANON and
         'YOUR_' not in BASE and 'YOUR_' not in ANON,
         'explicit development environment authorization', 'Never run in production')
    buyer, buyer_id = credentials('BUYER_A')
    _, second_id = credentials('BUYER_B')
    pending, _ = credentials('PENDING_SELLER')
    approved, approved_id = credentials('APPROVED_SELLER')
    admin, _ = credentials('ADMIN')
    check_admin(buyer, admin, buyer_id)
    check_rls(buyer, second_id)
    fields = check_pending_seller(pending)
    check_image_upload(approved, approved_id, fields)
    check_auction_denials(buyer, approved)
    check_finalization(admin)
    print('ALL LIVE ACCEPTANCE CHECKS PASSED')


if __name__ == '__main__':
    main()
