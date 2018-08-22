import unittest
import asyncdispatch
import os
import sequtils, strutils
import threadpool, locks
import nimobserver/message

type
    Message = object
        data: string
        `type`: string
    MessageRef* = ref Message

    Event* = enum
        EVENT_TEST_STARTED

    BaseObserver = ref object of RootObj

    BaseTestObserver* = ref object of BaseObserver

    OtherTestObserver* = ref object of BaseObserver
        testStatus: string

    TestObserver* = ref object of BaseObserver
        inTesting: bool

    Subject* = ref object of RootObj
        observers: seq[BaseObserver]
        channel: Channel[BaseMessage]

method onNotify(observer: BaseObserver, message: BaseMessage) {.base gcsafe.} = 
    echo "Base Notification:: Data value: " & $message

method onNotify(observer: TestObserver, message: BaseMessage) = 
    observer.inTesting = not observer.inTesting
    echo "Changing testing"

method onNotify(observer: OtherTestObserver, message: BaseMessage) = 
    observer.testStatus = "Stopped!"

method notify(subject: Subject, notification: BaseMessage) {.base gcsafe.} =
    for observer in subject.observers:
        echo "Calling notify"
        observer.onNotify(notification)

method update(subject: Subject, runForever: bool = true) {.base thread.} =
    while true:
        echo "Checking for messages"
        let (dataReady, msg) = tryRecv(subject.channel)
        if dataReady:
            subject.notify(msg)
            if not runForever:
                return
        else:
            echo "Sleeping"
            sleep(300)

method publish(subject: var Subject, message: SlackMessage) {.base.} =
    #[
    Add our events to the end of the queue, to be popped off the head when processed
    ]#
    subject.channel.send message

proc newSubject(): Subject =
    result = new Subject
    result.observers = @[]
    open(result.channel)
    spawn result.update()

proc newTestSubject(): Subject =
    result = new Subject
    result.observers = @[]
    open(result.channel)
    spawn result.update(false)

method addObserver(subject: var Subject, observer: BaseObserver) {.base.} =
    subject.observers.add(observer)

method removeObserver(subject: var Subject, observer: BaseObserver) {.base.} =
    assert subject.observers.contains(observer)
    subject.observers.delete(subject.observers.find(observer))

suite "MessageBusTests":

    setup:
        echo "Setup"

    test "ObserverTest":
        echo "ObserverTest"

    test "SubjectTest":
        var 
            sub = newTestSubject()
            obs = TestObserver(inTesting: false)
            otherObs = OtherTestObserver(testStatus: "Running")
            baseObs = BaseTestObserver()

        let
            msg = newSlackMessage("message", "TestUser", "TestMessageText", "TestSendingUser")

        sub.addObserver(obs)

        check sub.observers.contains obs

        sub.addObserver(otherObs)

        check sub.observers.contains otherObs
        check sub.observers.contains obs

        sub.addObserver(baseObs)

        echo "Publishing message"
        #Should get an echo from TestObserver, OtherTestObserver and a base notification from BaseTestObserver, where onNotify is not implemented
        sub.publish(msg)
        echo sub.channel.peek()
        sync()
        
        sub.removeObserver(obs)

        check (not sub.observers.contains obs)

    test "ChannelTests":

        var counterLock: Lock
        initLock(counterLock)
        var counter {.guard: counterLock.} = 0
            
        proc channelTestProc(x: int) =
            for i in 0 ..< x:
                withLock counterLock:
                    var value = counter
                    value.inc
                    counter = value

        spawn channelTestProc(10_000)
        spawn channelTestProc(10_000)
        sync()
        echo(counter)
