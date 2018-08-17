import unittest
import asyncdispatch
import deques
import sequtils

type
    Envelope = object
        data: string
        `type`: string
    EnvelopeRef* = ref Envelope

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

    RTMMessages* = ref object of Subject

method onNotify(observer: Observer, envelope: EnvelopeRef, event: Event) {.base.} = 
    echo "On Base Notification!"

method onNotify(observer: TestObserver, envelope: EnvelopeRef, event: Event) = 
    echo "On Test Notification!"
    observer.inTesting = not observer.inTesting

method onNotify(observer: OtherTestObserver, envelope: EnvelopeRef, event: Event) = 
    echo "On OtherTest Notification!"
    observer.testStatus = "Stopped!"

method notify(subject: var Subject, envelope: EnvelopeRef, event: Event) {.base.} =
    for obs in subject.observers:
        obs.onNotify(envelope, event)

method updateEnvelope(subject: var Subject, envelope: EnvelopeRef) {.base.} =
    subject.notify(envelope, EVENT_TEST_STARTED)

proc newSubject(): Subject =
    result = new Subject
    result.observers = @[]
    result.observerCount = 0

method addObserver(subject: var Subject, observer: Observer) {.base.} =
    subject.observers.add(observer)
    inc subject.observerCount

method removeObserver(subject: var Subject, observer: Observer) {.base.} =
    assert subject.observers.contains(observer) and subject.observerCount > 0
    subject.observers.delete(subject.observers.find(observer))
    dec subject.observerCount

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
            env = EnvelopeRef(data: "test", type: "TestMessage")

        sub.addObserver(obs)

        check sub.observerCount == 1
        check sub.observers.contains obs

        sub.addObserver(otherObs)

        check sub.observerCount == 2
        check sub.observers.contains otherObs
        check sub.observers.contains obs

        sub.addObserver(baseObs)

        #Should get an echo from TestObserver, OtherTestObserver and a base notification from BaseTestObserver, where onNotify is not implemented
        sub.updateEnvelope(env)

        check obs.inTesting

        sub.removeObserver(obs)

        check sub.observerCount == 2
        check (not sub.observers.contains obs)






