import unittest
import asyncdispatch
import os
import sequtils, strutils
import nimobserver
import nimobserver/message
from threadpool import spawn

suite "MessageBusTests":
  type
    TestObserver = ref object of BaseObserver
      inTesting: bool

  setup:
    echo "Setup"
    let globalTestSub = initSubject[SlackMessagePtr]()

  test "ChannelTests":

    var 
      obs = TestObserver(inTesting: false)
      obs2 = TestObserver(inTesting: false)
      newMsg = newSlackMessage("test", "TestUser", "TestMessageText", "TestSendingUser")

    proc updateGlobalSubject(sMsg: SlackMessagePtr) {.thread.} =
      {.gcsafe.}:
        globalTestSub.publish sMsg

    globalTestSub.addObserver(obs)
    globalTestSub.addObserver(obs2)
    echo "Spawning two globalSubjects!"
    spawn updateGlobalSubject(addr newMsg)

    echo "Sleeping in main"
    sleep(3000)
    spawn updateGlobalSubject(addr newMsg)
