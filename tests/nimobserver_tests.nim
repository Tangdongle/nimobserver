import unittest
import asyncdispatch
import deques
import sequtils
import threadpool

type
    Message = object
        data: string
        `type`: string
    MessageRef* = ref Message

    Event* = enum
        EVENT_TEST_STARTED

    Observer = ref object of RootObj

    BaseTestObserver* = ref object of Observer

    OtherTestObserver* = ref object of Observer
        testStatus: string

    TestObserver* = ref object of Observer
        inTesting: bool

    Subject* = ref object of RootObj
        observers: seq[Observer]
        observerCount: int
        events: Deque[(MessageRef, Event)]

method onNotify(observer: Observer, message: MessageRef, event: Event) {.base.} = 
    echo "Base Notification:: Data value: " & message.data

method onNotify(observer: TestObserver, message: MessageRef, event: Event) = 
    observer.inTesting = not observer.inTesting
    echo "Changing testing"

method onNotify(observer: OtherTestObserver, message: MessageRef, event: Event) = 
    observer.testStatus = "Stopped!"

method notify(subject: var Subject, notification: (MessageRef, Event)) {.base.} =
    for observer in subject.observers:
        echo "Spawning thread"
        observer.onNotify(notification[0], notification[1])

method update(subject: var Subject) {.base.} =
    while subject.events.len > 0:
        subject.notify(subject.events.popFirst())

method publish(subject: var Subject, message: MessageRef, event: Event) {.base.} =
    #[
    Add our events to the end of the queue, to be popped off the head when processed
    ]#
    subject.events.addLast((message, event))

proc newSubject(): Subject =
    result = new Subject
    result.observers = @[]
    result.events = initDeque[(MessageRef, Event)]()

method addObserver(subject: var Subject, observer: Observer) {.base.} =
    subject.observers.add(observer)

method removeObserver(subject: var Subject, observer: Observer) {.base.} =
    assert subject.observers.contains(observer)
    subject.observers.delete(subject.observers.find(observer))

suite "MessageBusTests":

    setup:
        echo "Setup"

    test "ObserverTest":
        echo "ObserverTest"

    test "SubjectTest":
        var 
            sub = newSubject()
            obs = TestObserver(inTesting: false)
            otherObs = OtherTestObserver(testStatus: "Running")
            baseObs = BaseTestObserver()

        let
            msg = MessageRef(data: "test", type: "TestMessage")

        sub.addObserver(obs)

        check sub.observers.contains obs

        sub.addObserver(otherObs)

        check sub.observers.contains otherObs
        check sub.observers.contains obs

        sub.addObserver(baseObs)

        #Should get an echo from TestObserver, OtherTestObserver and a base notification from BaseTestObserver, where onNotify is not implemented
        sub.publish(msg, EVENT_TEST_STARTED)
        
        check sub.events.len == 1
        check sub.events.peekFirst()[0].data == "test"

        sub.update()

        check sub.events.len == 0

        check obs.inTesting

        sub.removeObserver(obs)

        check (not sub.observers.contains obs)






