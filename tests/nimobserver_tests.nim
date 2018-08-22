import unittest
import asyncdispatch
import os
import sequtils, strutils
import threadpool, locks
import nimobserver/message

type
    BaseObserver = ref object of RootObj

    TestObserver* = ref object of BaseObserver
        inTesting: bool

    Subject* = object of RootObj
        observers: seq[BaseObserver]
        channel: Channel[ptr SlackMessage]
    SubjectPtr* = ptr Subject

method onNotify(observer: BaseObserver, message: SlackMessage) {.base gcsafe.} = 
    echo "Base Notification:: Data value: " & $message

method onNotify(observer: TestObserver, message: SlackMessage) = 
    #Test observer
    if message.type == SlackRTMType.Test:
        echo "Flipping testing!"
        observer.inTesting = not observer.inTesting

method notify(subject: SubjectPtr, notification: SlackMessage) {.base gcsafe.} =
    var counter = 0
    for observer in subject.observers:
        inc counter
        echo "Calling notify on observer #" & $counter
        observer.onNotify(notification)

method update(subject: SubjectPtr) {.base thread.} =
    while true:
        let msg = recv(subject.channel)
        subject.notify(msg[])
        echo "Sleeping"
        sleep(300)

#For non-blocking polling
    #while true:
    #    let (received, msg) = tryRecv(subject.channel)
    #    echo received
    #    if received:
    #        subject.notify(msg[])
    #    else:
    #        echo "Sleeping"
    #        sleep(300)

method publish(subject: SubjectPtr, message: ptr SlackMessage) {.base.} =
    #[
    Add our events to the end of the queue, to be popped off the head when processed
    ]#
    subject.channel.send message

proc newSubject(): SubjectPtr =
    result = createShared(Subject)
    result.observers = @[]
    open(result.channel)

method addObserver(subject: SubjectPtr, observer: BaseObserver) {.base.} =
    subject.observers.add(observer)

method removeObserver(subject: SubjectPtr, observer: BaseObserver) {.base.} =
    assert subject.observers.contains(observer)
    subject.observers.delete(subject.observers.find(observer))

let globalTestSub: SubjectPtr = newSubject()

proc `$`(x: SubjectPtr): string =
    result = $x.observers.len

suite "MessageBusTests":

    setup:
        echo "Setup"

    test "ChannelTests":

        #Ask update() to run in another thead, where it will poll until it receives something
        spawn globalTestSub.update()
        var 
            obs = TestObserver(inTesting: false)
            obs2 = TestObserver(inTesting: false)
            newMsg = newSlackMessage("test", "TestUser", "TestMessageText", "TestSendingUser")

        proc updateGlobalSubject(sMsg: ptr SlackMessage) {.thread.} =
            {.gcsafe.}:
                globalTestSub.publish sMsg

        globalTestSub.addObserver(obs)
        globalTestSub.addObserver(obs2)
        echo "Spawning two globalSubjects!"
        spawn updateGlobalSubject(addr newMsg)

        echo "Sleeping in main"
        sleep(3000)
        spawn updateGlobalSubject(addr newMsg)
