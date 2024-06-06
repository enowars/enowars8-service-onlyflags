from asyncio import StreamReader, StreamWriter
import asyncio
import random
import string

import jwt
import httpx
from python_socks.async_.asyncio import Proxy
from python_socks import ProxyConnectionError

from typing import Optional
from logging import LoggerAdapter

from enochecker3 import (
    ChainDB,
    Enochecker,
    ExploitCheckerTaskMessage,
    FlagSearcher,
    BaseCheckerTaskMessage,
    PutflagCheckerTaskMessage,
    GetflagCheckerTaskMessage,
    PutnoiseCheckerTaskMessage,
    GetnoiseCheckerTaskMessage,
    HavocCheckerTaskMessage,
    MumbleException,
    OfflineException,
    InternalErrorException,
    PutflagCheckerTaskMessage,
    AsyncSocket,
)
from enochecker3.utils import assert_equals, assert_in

"""
Checker config
"""

SERVICE_PORT = 9145
checker = Enochecker("onlyflags", SERVICE_PORT)
app = lambda: checker.app

with open('jwt_priv.pem', 'r') as file:
    priv_key = file.read()


"""
Utility functions
"""

class Connection:
    def __init__(self, client: httpx.AsyncClient, logger: LoggerAdapter):
        self.client = client
        self.logger = logger

    def _verify_302_with_redirect(self, res: httpx.Response, redir: str, message: str = "Request failed"):
        if res.status_code != 302:
            self.logger.debug(f"not a 302: {res} {res.text}")
            raise MumbleException(message)
        loc = res.headers.get('Location')
        if loc == None or loc != redir:
            self.logger.debug(f"location fail: '{loc}' {res} {res.text}")
            raise MumbleException(message)

    async def register_user(self, username: str, password: str, premium: bool = False):
        self.logger.debug(f"register user: {username} with password: {password}")
        res = await self.client.post("/index.php", data={"username":username, "password": password})
        self._verify_302_with_redirect(res, '/?success', 'User registration failed')
        
        if premium:
            key = jwt.encode({"sub":username}, priv_key, algorithm="RS256")
            self.logger.debug(f"send license key for user: {username} {key}")
            res = await self.client.post("/license.php", data={"key": key})
            self._verify_302_with_redirect(res, "/license.php?success", "Licensing failed")

class ForumConnection:
    def __init__(self, host:str, username: str, password:str, service: str):
        self.proxy = Proxy.from_url(f"socks5://{username}:{password}@{host}:1080", rdns=True)
        self.service = service
        self.rd = None
        self.wr = None

    async def connect(self):
        try:
            sock = await self.proxy.connect(self.service, 1337)
        except ProxyConnectionError:
            raise OfflineException("Could not connect to proxy")
        self.rd, self.wr = await asyncio.open_connection(
            host=None,
            port=None,
            sock=sock,
        )
        return await self.rd.readuntil(b"\n>")

    def verify_connected(self):
        if self.rd == None or self.wr == None:
            raise Exception("not connected")

    async def join(self, thread_id: str):
        self.verify_connected()
        self.wr.write(f"join {thread_id}\n".encode())
        await self.wr.drain()
        res = await self.rd.readuntil(b"\n>")
        assert_in(f"changed thread to {thread_id}", res.decode(encoding='utf-8'), f"{self.service} forum non-functional")

    async def post(self, content: str):
        self.verify_connected()
        self.wr.write(f"post {content}\n".encode())
        await self.wr.drain()
        await self.rd.readuntil(b"\n>")

    async def list_threads(self):
        self.verify_connected()
        self.wr.write(f"list\n".encode())
        await self.wr.drain()
        res = await self.rd.readuntil(b"\n>")
        chunks = res.split(b"threads: ", 1)
        if len(chunks) == 1:
            assert_in("no threads found\n", res.decode(encoding='utf-8'), f"{self.service} forum non-functional")
            return []
        threads = chunks[1].split(b'\n')[0].decode(encoding='utf-8').split(',')
        return threads

    async def show(self):
        self.verify_connected()
        self.wr.write(f"show\n".encode())
        await self.wr.drain()
        return await self.rd.readuntil(b"\n>")

    async def help(self):
        self.verify_connected()
        self.wr.write(f"help\n".encode())
        await self.wr.drain()
        return await self.rd.readuntil(b"\n>")



@checker.register_dependency
def _get_connection(client: httpx.AsyncClient, logger: LoggerAdapter) -> Connection:
    return Connection(client, logger)


"""
CHECKER FUNCTIONS
"""

@checker.putflag(0)
async def putflag_premiumkv(
    task: PutflagCheckerTaskMessage,
    db: ChainDB,
    conn: Connection,
    logger: LoggerAdapter,    
) -> None:
    # First we need to register a user. So let's create some random strings. (Your real checker should use some funny usernames or so)
    username: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    password: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    thread_id: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )

    # Register a new user
    await conn.register_user(username, password, True)

    forum = ForumConnection(task.address, username, password, 'premium-forum')
    await forum.connect()

    logger.info(f"joining thread {thread_id}")
    await forum.join(thread_id)

    logger.info("posting flag")
    await forum.post(task.flag)

    # Save the generated values for the associated getflag() call.
    await db.set("userdata", (username, password, thread_id))

    return thread_id #{"username": username, "thread_id": thread_id}

@checker.getflag(0)
async def getflag_premiumkv(
    task: GetflagCheckerTaskMessage, db: ChainDB, logger: LoggerAdapter, conn: Connection
) -> None:
    try:
        username, password, thread_id = await db.get("userdata")
    except KeyError:
        raise MumbleException("Missing database entry from putflag")

    logger.info('connecting to premium-forum')
    forum = ForumConnection(task.address, username, password, 'premium-forum')
    await forum.connect()

    logger.info(f"joining thread {thread_id}")
    await forum.join(thread_id)

    logger.info('getting thread')
    res = await forum.show()
    assert_in(task.flag, res.decode('utf-8'), "flag not found in thread")

NOISE = [
    "You have a heart of a true hacker.",
    "You make the world a funier place.",
    "Everything you do is perfect.",
    "You're the most amazing person I've ever met.",
    "I'm so lucky to follow someone as wonderful as you.",
    "that attack is beyond words.",
    "You're my inspiration.",
    "I admire that intelligence and resilience.",
    "that talent is unmatched.",
    "I could watch you spoof all day.",
    "I'm in awe of that intelligence.",
    "that trolling is infectious.",
    "I can't stop thinking about your hack.",
    "You did a masterpiece.",
    "You're simply the best B)",
    "Look at that Scoreboard.",
    "You have an amazing SLA score.",
    "You made the highlight of my day.",
    "You're incredibly talented.",
    "You're my hero.",
    "You bring so much fun into this challenge.",
    "You're so skilled.",
    "I'm so proud of you.",
    "You have the most beautiful tool.",
    "You're my dream come true.",
    "I admire that dedication.",
    "You have an incredible spirit.",
    "You hack the world.",
    "You have a persistent personality.",
    "You're a true champion.",
    "I don't know how you did that :o",
    "You're my everything.",
    "Thanks for the free stuff.",
    "You're a 7331 hax0r",
    "You have an amazing style.",
    "I love that style.",
    "You're the epitome of opsec.",
    "You're so creative.",
    "You have a unique ability.",
    "You're a treasure.",
    "I adore that personality.",
    "You have a captivating presence.",
    "You're so thoughtful when hacking.",
    "You have a beautiful mind.",
    "You're a rare gem of a hacker.",
    "You always know how to make me lol.",
    "I love that adventurous spirit.",
    "You're an incredible person.",
    "You light up any room.",
    "I'm amazed by you every day.",
    "You have a wonderful outlook on life.",
    "That's so charming.",
    "You're my guiding star.",
    "You have a magnetic smile.",
    "I love that passion for life.",
    "You're my happy place.",
    "You have a fantastic sense of humor.",
    "I'm always here for you."
    ]

@checker.putnoise(0)
async def putnoise0(task: PutnoiseCheckerTaskMessage, db: ChainDB, logger: LoggerAdapter, conn: Connection):
    # First we need to register a user. So let's create some random strings. (Your real checker should use some funny usernames or so)
    username: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    password: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )

    message_id = random.randint(0,len(NOISE))

    # Register a new user
    await conn.register_user(username, password, True)

    forum = ForumConnection(task.address, username, password, 'premium-forum')
    await forum.connect()

    threads = await forum.list_threads()
    thread_id = random.choice(threads) if threads != [] else "".join(
            random.choices(string.ascii_uppercase + string.digits, k=12)
        )

    logger.info(f"joining thread {thread_id}")
    await forum.join(thread_id)

    logger.info(f"posting noise {message_id}")
    await forum.post(NOISE[message_id])

    # Save the generated values for the associated getflag() call.
    await db.set("userdata", (username, password, thread_id, message_id))

@checker.getnoise(0)
async def getnoise0(task: GetnoiseCheckerTaskMessage, db: ChainDB, logger: LoggerAdapter, conn: Connection):
    try:
        username, password, thread_id, message_id = await db.get("userdata")
    except KeyError:
        raise MumbleException("Putnoise Failed!")

    logger.info('connecting to premium-forum')
    forum = ForumConnection(task.address, username, password, 'premium-forum')
    await forum.connect()

    logger.info(f"joining thread {thread_id}")
    await forum.join(thread_id)

    logger.info('getting thread')
    res = await forum.show()
    assert_in(NOISE[message_id], res.decode('utf-8'), "noise not found in thread")

@checker.havoc(0)
async def havoc_test_help(task: HavocCheckerTaskMessage, logger: LoggerAdapter, conn: Connection):
    username: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    password: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )

    # Register a new user
    await conn.register_user(username, password, True)

    def test(helpstr):
        for line in [
            "List of commands:",
            "HELP - Show this help",
            "LIST - List all active thread",
            "JOIN <thread> - show a thread",
            "SHOW - show a thread",
            "POST - post to current thread",
        ]:
            assert_in(line.encode(), helpstr, "Received incomplete response.")

    forum = ForumConnection(task.address, username, password, 'premium-forum')
    helpstr = await forum.connect()
    test(helpstr)

    # In variant 0, we'll check if the help text is available
    logger.debug(f"Sending help command")
    helpstr = await forum.help()
    test(helpstr)


"""
@checker.havoc(1)
async def havoc1(task: HavocCheckerTaskMessage, logger: LoggerAdapter, conn: Connection):
    logger.debug(f"Connecting to service")
    welcome = await conn.reader.readuntil(b">")

    # In variant 1, we'll check if the `user` command still works.
    username = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    password = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )

    # Register and login a dummy user
    await conn.register_user(username, password)
    await conn.login_user(username, password)

    logger.debug(f"Sending user command")
    conn.writer.write(f"user\n".encode())
    await conn.writer.drain()
    ret = await conn.reader.readuntil(b">")
    if not b"User 0: " in ret:
        raise MumbleException("User command does not return any users")

    if username:
        assert_in(username.encode(), ret, "Flag username not in user output")

    # conn.writer.close()
    # await conn.writer.wait_closed()

@checker.havoc(2)
async def havoc2(task: HavocCheckerTaskMessage, logger: LoggerAdapter, conn: Connection):
    logger.debug(f"Connecting to service")
    welcome = await conn.reader.readuntil(b">")

    # In variant 2, we'll check if the `list` command still works.
    username = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    password = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    randomNote = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=36)
    )

    # Register and login a dummy user
    await conn.register_user(username, password)
    await conn.login_user(username, password)

    logger.debug(f"Sending command to save a note")
    conn.writer.write(f"set {randomNote}\n".encode())
    await conn.writer.drain()
    await conn.reader.readuntil(b"Note saved! ID is ")

    try:
        noteId = (await conn.reader.readuntil(b"!\n>")).rstrip(b"!\n>").decode()
    except Exception as ex:
        logger.debug(f"Failed to retrieve note: {ex}")
        raise MumbleException("Could not retrieve NoteId")

    assert_equals(len(noteId) > 0, True, message="Empty noteId received")

    logger.debug(f"{noteId}")

    logger.debug(f"Sending list command")
    conn.writer.write(f"list\n".encode())
    await conn.writer.drain()

    data = await conn.reader.readuntil(b">")
    if not noteId.encode() in data:
        raise MumbleException("List command does not work as intended")
"""

@checker.exploit(0)
async def exploit0(task: ExploitCheckerTaskMessage, searcher: FlagSearcher, conn: Connection, logger:LoggerAdapter) -> Optional[str]:

    username: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    password: str = "".join(
        random.choices(string.ascii_uppercase + string.digits, k=12)
    )
    await conn.register_user(username, password)

    forum = ForumConnection(task.address, username, password, 'premium-forum')
    
    await forum.connect()

    await forum.join(task.attack_info)

    data = await forum.show()
    if flag := searcher.search_flag(data):
        return flag
    raise MumbleException("flag not found")



if __name__ == "__main__":
    checker.run()
