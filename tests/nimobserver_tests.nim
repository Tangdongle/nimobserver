import unittest
import sequtils, strutils
from os import sleep
import nimobserver
from threadpool import spawn

type
  TestObserver {.final.} = ref object of BaseObserver
    inTesting: bool

  TestMessage = ref object of BaseMessage
    message: string

  TestMessagePtr = ptr TestMessage
  
proc newTestMessage(message: string): TestMessage =
  result = new TestMessage
  result.message = message

proc `$`(x: TestMessage): string =
  x.message

proc `$`(x: TestMessagePtr): string =
  $x[]

method onNotify*(observer: TestObserver, message: TestMessagePtr) =
  check(not isNil(message))
  echo "Notified of message: " & $message

suite "NimObserverTests":

  setup:
    let globalTestSub = initSubject[TestMessagePtr]()

  test "GlobalSubjectChannelTests":

    let
      obs = BaseObserver()
      obs2 = TestObserver(inTesting: true)

    var
      newMsg = newTestMessage("test")

    proc updateGlobalSubject(sMsg: TestMessagePtr) {.thread.} =
      {.gcsafe.}:
        globalTestSub.publish sMsg

    globalTestSub.addObserver(obs)
    globalTestSub.addObserver(obs2)

    spawn updateGlobalSubject(addr newMsg)

    sleep(3000)
    spawn updateGlobalSubject(addr newMsg)
