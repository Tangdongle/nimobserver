# messagebus
# Copyright Tangdongle
# A message event queue implementation
#
#To start listening, init a Subject object to return a pointer to a Subject on the shared heap
#so that all published messages are handled on other threads
#
#Must be compiled with --threads:on for channels and threads
#
#let globalTestSub: SubjectPtr[MessagePtr] = initSubject[MessagePtr]()
#

from threadpool import spawn
from os import sleep
from typetraits import name

type
  BaseObserver* = ref object of RootObj

  Subject*[T] = object of RootObj
    observers: seq[BaseObserver]
    channel: Channel[T]

  SubjectPtr*[T] = ptr Subject[T]

method onNotify[T](observer: BaseObserver, message: T) {.base gcsafe.} = 
  #[
  Base method for observers to implement. Observers are notified when a message is received
  ]#
  echo "Base Notification:: Data value: " & $message[]

method notify[T](subject: SubjectPtr[T], notification: T) {.base gcsafe.} =
  #[
  Base notify method. Alerts all observers when a message is processed
  ]#
  for observer in subject.observers:
    observer.onNotify(notification)

method update[T](subject: SubjectPtr[T]) {.base thread.} =
  #[
  Background watcher. Blocks until a message is published on the subject's channel
  ]#
  while true:
    let msg = recv(subject.channel)
    subject.notify(msg)

method publish*[T](subject: SubjectPtr[T], message: T) {.base.} =
  #[
  Send our message through our channel, which will notify any observers
  ]#
  subject.channel.send message

method addObserver*[T](subject: SubjectPtr[T], observer: BaseObserver) {.base.} =
  #[
  Add an Observer to be notified on a message being received
  ]#
  subject.observers.add(observer)

method removeObserver*[T](subject: SubjectPtr[T], observer: BaseObserver) {.base.} =
  #[
  Remove an Observer, causing it to no longer be notified when a message is published
  ]#
  assert subject.observers.contains(observer)
  subject.observers.delete(subject.observers.find(observer))

proc newSubject*[T](): SubjectPtr[T] =
  result = createShared(Subject[T])
  result.observers = @[]
  open(result.channel)

proc initSubject*[T](): SubjectPtr[T] =
  result = newSubject[T]()
  spawn result.update()

proc `$`*(x: BaseObserver): string =
  name(type(x))

proc `$`*[T](x: SubjectPtr[T]): string =
  result = $x.observers

